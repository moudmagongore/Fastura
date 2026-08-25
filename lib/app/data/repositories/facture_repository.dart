import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_keys.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/facture_model.dart';
import '../models/paiement_model.dart';

/// Erreur métier de la facturation, destinée à être affichée telle quelle.
class FacturationException implements Exception {
  const FacturationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FactureRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col => _fs.factures;
  CollectionReference<Map<String, dynamic>> get _paiements => _fs.paiements;
  CollectionReference<Map<String, dynamic>> get _clients => _fs.clients;

  /// Factures du tenant, de la plus récente à la plus ancienne.
  ///
  /// [limite] borne volontairement la lecture : l'historique d'une boutique
  /// active grossit vite, et Firestore facture au document lu.
  Stream<List<FactureModel>> watchByTenant(
    String tenantId, {
    int limite = 200,
    DateTime? depuis,
  }) {
    if (tenantId.isEmpty) return Stream.value(const <FactureModel>[]);
    Query<Map<String, dynamic>> q =
        _col.where(FirestoreKeys.fieldTenantId, isEqualTo: tenantId);
    if (depuis != null) {
      q = q.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(depuis));
    }
    return q
        .orderBy('date', descending: true)
        .limit(limite)
        .snapshots()
        .ignorePermissionDenied()
        .map((snap) => snap.docs.map(FactureModel.fromFirestore).toList());
  }

  /// Historique de facturation d'un client.
  Stream<List<FactureModel>> watchByClient(
    String clientId, {
    required String tenantId,
    int limite = 100,
  }) {
    if (clientId.isEmpty || tenantId.isEmpty) {
      return Stream.value(const <FactureModel>[]);
    }
    return _col
        .where(FirestoreKeys.fieldTenantId, isEqualTo: tenantId)
        .where('clientId', isEqualTo: clientId)
        .orderBy('date', descending: true)
        .limit(limite)
        .snapshots()
        .ignorePermissionDenied()
        .map((snap) => snap.docs.map(FactureModel.fromFirestore).toList());
  }

  Stream<FactureModel?> watchById(String id) {
    if (id.isEmpty) return Stream.value(null);
    return _col.doc(id).snapshots().ignorePermissionDenied().map(
          (doc) => doc.exists ? FactureModel.fromFirestore(doc) : null,
        );
  }

  /// Émet une facture et, le cas échéant, encaisse son règlement immédiat.
  ///
  /// Tout se joue dans une seule transaction, parce que quatre écritures
  /// doivent réussir ou échouer ensemble :
  ///   1. le compteur `counters/{tenantId}.factures{AAAA}` est incrémenté,
  ///      ce qui **garantit une numérotation sans trou ni doublon** (CDC §6) ;
  ///   2. la facture est écrite avec le numéro ainsi réservé ;
  ///   3. le solde du client augmente du reste dû ;
  ///   4. si le client règle sur-le-champ, le paiement est écrit et rattaché.
  ///
  /// Incrémenter le compteur hors transaction laisserait un trou dans la
  /// séquence dès qu'une écriture échoue — inacceptable sur une pièce
  /// comptable.
  ///
  /// [prefixe] est celui paramétré sur le tenant (ex. `FA`). Renvoie la
  /// facture persistée, avec son identifiant et son numéro.
  Future<FactureModel> creer(
    FactureModel facture, {
    required String prefixe,
    double paiementImmediat = 0,
    ModePaiement modePaiement = ModePaiement.especes,
  }) async {
    if (facture.lignes.isEmpty) {
      throw const FacturationException(
        'Une facture doit comporter au moins une ligne.',
      );
    }
    if (facture.tenantId.isEmpty) {
      throw const FacturationException('Tenant absent sur la facture.');
    }

    final total = facture.montantTotal;
    if (paiementImmediat < 0) {
      throw const FacturationException(
        'Le montant réglé ne peut être négatif.',
      );
    }
    if (paiementImmediat - total > 0.005) {
      throw const FacturationException(
        'Le montant réglé dépasse le total de la facture. Enregistrez le '
        'surplus depuis le menu de paiement.',
      );
    }

    return _fs.db.runTransaction<FactureModel>((tx) async {
      // ---- Toutes les lectures d'abord : Firestore l'impose ----

      final counterRef = _fs.counters.doc(facture.tenantId);
      final counterSnap = await tx.get(counterRef);

      final clientRef = _clients.doc(facture.clientId);
      final clientSnap = await tx.get(clientRef);
      if (!clientSnap.exists) {
        throw const FacturationException('Client introuvable.');
      }

      // ---- Numéro séquentiel ----

      final annee = facture.date.year;
      final champ = 'factures$annee';
      final courant =
          ((counterSnap.data() ?? const {})[champ] as num?)?.toInt() ?? 0;
      final suivant = courant + 1;
      final numero =
          '$prefixe-$annee-${suivant.toString().padLeft(5, '0')}';

      // ---- Écritures ----

      final factureRef = _col.doc();
      final paiementRef = paiementImmediat > 0 ? _paiements.doc() : null;

      final persistee = FactureModel(
        id: factureRef.id,
        numero: numero,
        date: facture.date,
        clientId: facture.clientId,
        clientNom: facture.clientNom,
        lignes: facture.lignes,
        tauxTva: facture.tauxTva,
        devise: facture.devise,
        montantPaye: paiementImmediat,
        paiementDirectId: paiementRef?.id,
        tenantId: facture.tenantId,
        creeParId: facture.creeParId,
        creeParNom: facture.creeParNom,
      );

      tx.set(
        factureRef,
        persistee.toMap()..['createdAt'] = FieldValue.serverTimestamp(),
      );

      tx.set(counterRef, {champ: suivant}, SetOptions(merge: true));

      if (paiementRef != null) {
        final paiement = PaiementModel(
          id: paiementRef.id,
          date: facture.date,
          clientId: facture.clientId,
          clientNom: facture.clientNom,
          montant: paiementImmediat,
          mode: modePaiement,
          imputations: [
            ImputationPaiement(
              factureId: factureRef.id,
              factureNumero: numero,
              montant: paiementImmediat,
            ),
          ],
          directALaFacturation: true,
          tenantId: facture.tenantId,
          creeParId: facture.creeParId,
          creeParNom: facture.creeParNom,
        );
        tx.set(
          paiementRef,
          paiement.toMap()..['createdAt'] = FieldValue.serverTimestamp(),
        );
      }

      // Le solde ne bouge que du reste dû : la part réglée sur-le-champ n'a
      // jamais été une créance.
      final resteDu = persistee.resteDu;
      if (resteDu != 0) {
        tx.update(clientRef, {'solde': FieldValue.increment(resteDu)});
      }

      return persistee;
    });
  }

  /// Annule une facture. Réservé à l'administrateur (CDC §1.3) — le contrôle
  /// est aussi porté par `firestore.rules`, que le client ne peut contourner.
  ///
  /// La facture n'est jamais supprimée : la séquence de numérotation
  /// interdit de faire disparaître une pièce. Elle est marquée annulée,
  /// sort du solde du client, et le règlement encaissé au moment de la
  /// facturation est annulé avec elle — c'était le même acte de vente.
  Future<void> annuler(
    FactureModel facture, {
    required String parNom,
    String? motif,
  }) async {
    if (facture.annulee) return;

    await _fs.db.runTransaction((tx) async {
      final factureRef = _col.doc(facture.id);
      final factureSnap = await tx.get(factureRef);
      if (!factureSnap.exists) {
        throw const FacturationException('Facture introuvable.');
      }

      final courante = FactureModel.fromFirestore(factureSnap);
      if (courante.annulee) return;

      // Un règlement encaissé depuis le menu de paiement dédié serait imputé
      // sur cette facture sans en être le paiement direct : le désimputer
      // demanderait de retrouver tous les règlements concernés, ce qu'une
      // transaction Firestore ne permet pas — aucune requête à l'intérieur.
      // Le cas n'existe pas encore, le menu de paiement arrive avec le
      // lettrage FIFO ; il faudra alors désimputer hors transaction, ou
      // passer par une Cloud Function.
      final aUnPaiementExterne =
          courante.montantPaye > 0 && courante.paiementDirectId == null;
      if (aUnPaiementExterne) {
        throw const FacturationException(
          'Cette facture a reçu un règlement enregistré séparément. '
          'Annulez d\'abord ce règlement.',
        );
      }

      final clientRef = _clients.doc(courante.clientId);
      final clientSnap = await tx.get(clientRef);

      DocumentSnapshot<Map<String, dynamic>>? paiementSnap;
      final paiementId = courante.paiementDirectId;
      if (paiementId != null && paiementId.isNotEmpty) {
        paiementSnap = await tx.get(_paiements.doc(paiementId));
      }

      // ---- Écritures ----

      final resteDu = courante.resteDu;

      tx.update(factureRef, {
        'annulee': true,
        'annuleeLe': FieldValue.serverTimestamp(),
        'annuleeParNom': parNom,
        'motifAnnulation': motif,
      });

      if (paiementSnap != null && paiementSnap.exists) {
        tx.update(paiementSnap.reference, {
          'annule': true,
          'annuleLe': FieldValue.serverTimestamp(),
          'annuleParNom': parNom,
          'motifAnnulation':
              motif ?? 'Annulation de la facture ${courante.numero}',
        });
      }

      // Seul le reste dû pesait sur le solde : la part déjà réglée n'y
      // figurait pas, son annulation ne le touche donc pas.
      if (clientSnap.exists && resteDu != 0) {
        tx.update(clientRef, {'solde': FieldValue.increment(-resteDu)});
      }
    });
  }
}
