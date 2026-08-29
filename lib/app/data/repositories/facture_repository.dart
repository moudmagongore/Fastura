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
    DateTime? jusqua,
  }) {
    if (tenantId.isEmpty) return Stream.value(const <FactureModel>[]);
    Query<Map<String, dynamic>> q = _col.where(
      FirestoreKeys.fieldTenantId,
      isEqualTo: tenantId,
    );
    // Bornes posées au serveur : un journal se borne à la source, pas
    // après avoir lu six mois de documents. Les deux portent sur `date`,
    // qui sert aussi au tri — pas d'index composite supplémentaire.
    if (depuis != null) {
      q = q.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(depuis));
    }
    if (jusqua != null) {
      q = q.where('date', isLessThanOrEqualTo: Timestamp.fromDate(jusqua));
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
    return _col
        .doc(id)
        .snapshots()
        .ignorePermissionDenied()
        .map((doc) => doc.exists ? FactureModel.fromFirestore(doc) : null);
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
      final numero = '$prefixe-$annee-${suivant.toString().padLeft(5, '0')}';

      // ---- Écritures ----

      final factureRef = _col.doc();
      final paiementRef = paiementImmediat > 0 ? _paiements.doc() : null;

      final persistee = FactureModel(
        id: factureRef.id,
        numero: numero,
        date: facture.date,
        clientId: facture.clientId,
        clientNom: facture.clientNom,
        clientNomLibre: facture.clientNomLibre,
        clientTelephoneLibre: facture.clientTelephoneLibre,
        lignes: facture.lignes,
        tauxTva: facture.tauxTva,
        devise: facture.devise,
        note: facture.note,
        montantPaye: paiementImmediat,
        paiementDirectId: paiementRef?.id,
        paiementIds: paiementRef == null ? const [] : [paiementRef.id],
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
          // Le reçu porte le nom écrit sur la facture : sur une vente de
          // passage, « Client divers » ne dirait rien à celui qui le reçoit.
          clientNom: facture.clientAffiche,
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
  /// La facture n'est jamais supprimée : la séquence de numérotation interdit
  /// de faire disparaître une pièce. Elle est marquée annulée et sort du
  /// solde du client. Ses règlements sont traités différemment selon leur
  /// nature :
  ///
  ///   • le **règlement direct**, encaissé au moment même de la facturation,
  ///     est annulé avec elle : c'était le même acte de vente, l'argent
  ///     repart avec la marchandise ;
  ///   • un **règlement enregistré séparément** reste valide — le client a
  ///     bien versé cet argent. Seule son imputation sur cette facture est
  ///     défaite, et le montant bascule en avance à son crédit.
  ///
  /// D'où le solde retiré : le total de la facture **moins** la part réglée
  /// directement, qui n'avait jamais été une créance et repart avec.
  ///
  /// Les règlements concernés sont relus par identifiant grâce à
  /// [FactureModel.paiementIds] : une transaction Firestore n'autorise
  /// aucune requête.
  Future<void> annuler(
    FactureModel facture, {
    required String parNom,
    String? motif,
  }) async {
    if (facture.annulee) return;

    await _fs.db.runTransaction((tx) async {
      // ---- Lectures ----

      final factureRef = _col.doc(facture.id);
      final factureSnap = await tx.get(factureRef);
      if (!factureSnap.exists) {
        throw const FacturationException('Facture introuvable.');
      }

      final courante = FactureModel.fromFirestore(factureSnap);
      if (courante.annulee) return;

      final clientRef = _clients.doc(courante.clientId);
      final clientSnap = await tx.get(clientRef);

      final paiementSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final pid in courante.paiementIds) {
        if (pid.isEmpty) continue;
        paiementSnaps[pid] = await tx.get(_paiements.doc(pid));
      }

      // ---- Écritures ----

      var montantDirect = 0.0;

      for (final entry in paiementSnaps.entries) {
        final snap = entry.value;
        if (!snap.exists) continue;
        final p = PaiementModel.fromFirestore(snap);
        // Déjà annulé séparément : l'argent est retourné au client et le
        // solde en a tenu compte à ce moment-là. Ne rien recompter ici.
        if (p.annule) continue;

        final estDirect = entry.key == courante.paiementDirectId;

        if (estDirect) {
          // Cette part n'a jamais pesé sur le solde du client : elle a été
          // déduite du reste dû dès l'émission. Elle est donc retranchée de
          // ce qu'on retire au solde, sans quoi on créditerait le client
          // d'un argent qu'on lui rend par ailleurs.
          montantDirect += p.montant;
          tx.update(snap.reference, {
            'annule': true,
            'annuleLe': FieldValue.serverTimestamp(),
            'annuleParNom': parNom,
            'motifAnnulation':
                motif ?? 'Annulation de la facture ${courante.numero}',
            'imputations': <Map<String, dynamic>>[],
          });
        } else {
          // Le règlement subsiste, seule son affectation à cette facture
          // disparaît : le montant devient une avance au crédit du client.
          final restantes = p.imputations
              .where((i) => i.factureId != courante.id)
              .map((i) => i.toMap())
              .toList();
          tx.update(snap.reference, {'imputations': restantes});
        }
      }

      tx.update(factureRef, {
        'annulee': true,
        'annuleeLe': FieldValue.serverTimestamp(),
        'annuleeParNom': parNom,
        'motifAnnulation': motif,
        // Les imputations sont défaites : garder un montant réglé laisserait
        // croire que des règlements couvrent encore cette facture, et le
        // total des imputations ne correspondrait plus à celui des montants
        // réglés.
        'montantPaye': 0,
        'paiementIds': <String>[],
        'statut': StatutFacture.impayee.name,
      });

      final aRetirerDuSolde = courante.montantTotal - montantDirect;
      if (clientSnap.exists && aRetirerDuSolde.abs() > 0.005) {
        tx.update(clientRef, {'solde': FieldValue.increment(-aRetirerDuSolde)});
      }
    });
  }
}
