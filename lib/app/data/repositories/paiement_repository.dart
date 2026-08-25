import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_keys.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/facture_model.dart';
import '../models/paiement_model.dart';
import 'facture_repository.dart' show FacturationException;

class PaiementRepository {
  final FirestoreService _fs = FirestoreService.to;

  /// Au-delà, on ne remonte pas plus loin dans l'ardoise du client. Un
  /// règlement qui devrait solder plus de cinquante factures relève d'un
  /// apurement exceptionnel, à faire en plusieurs fois.
  static const int maxFacturesLettrees = 50;

  CollectionReference<Map<String, dynamic>> get _col => _fs.paiements;
  CollectionReference<Map<String, dynamic>> get _factures => _fs.factures;
  CollectionReference<Map<String, dynamic>> get _clients => _fs.clients;

  Stream<List<PaiementModel>> watchByTenant(
    String tenantId, {
    int limite = 200,
    DateTime? depuis,
  }) {
    if (tenantId.isEmpty) return Stream.value(const <PaiementModel>[]);
    Query<Map<String, dynamic>> q =
        _col.where(FirestoreKeys.fieldTenantId, isEqualTo: tenantId);
    if (depuis != null) {
      q = q.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(depuis));
    }
    return q
        .orderBy('date', descending: true)
        .limit(limite)
        .snapshots()
        .ignorePermissionDenied(contexte: 'paiements du tenant')
        .map((snap) => snap.docs.map(PaiementModel.fromFirestore).toList());
  }

  /// Règlements d'un client, du plus récent au plus ancien.
  Stream<List<PaiementModel>> watchByClient(
    String clientId, {
    required String tenantId,
    int limite = 100,
  }) {
    if (clientId.isEmpty || tenantId.isEmpty) {
      return Stream.value(const <PaiementModel>[]);
    }
    return _col
        .where(FirestoreKeys.fieldTenantId, isEqualTo: tenantId)
        .where('clientId', isEqualTo: clientId)
        .orderBy('date', descending: true)
        .limit(limite)
        .snapshots()
        .ignorePermissionDenied(contexte: 'règlements du client')
        .map((snap) => snap.docs.map(PaiementModel.fromFirestore).toList());
  }

  Stream<PaiementModel?> watchById(String id) {
    if (id.isEmpty) return Stream.value(null);
    return _col.doc(id).snapshots().ignorePermissionDenied().map(
          (doc) => doc.exists ? PaiementModel.fromFirestore(doc) : null,
        );
  }

  /// Factures d'un client encore à encaisser, **de la plus ancienne à la plus
  /// récente** : l'ordre exact dans lequel le lettrage FIFO les soldera.
  ///
  /// Sert aussi à l'écran d'encaissement, qui montre au vendeur ce que son
  /// règlement va solder avant qu'il ne valide.
  Future<List<FactureModel>> facturesAApurer(
    String clientId, {
    required String tenantId,
  }) async {
    if (clientId.isEmpty || tenantId.isEmpty) return const [];
    final snap = await _factures
        .where(FirestoreKeys.fieldTenantId, isEqualTo: tenantId)
        .where('clientId', isEqualTo: clientId)
        .where('annulee', isEqualTo: false)
        .orderBy('date')
        .limit(maxFacturesLettrees)
        .get();

    // Le reste dû se déduit de montantTotal et montantPaye : Firestore ne
    // sait pas comparer deux champs entre eux dans un `where`, le tri se
    // fait donc ici.
    return snap.docs
        .map(FactureModel.fromFirestore)
        .where((f) => f.resteDu > 0)
        .toList();
  }

  /// Encaisse un règlement et l'impute en **FIFO** sur les factures impayées
  /// du client, la plus ancienne d'abord (CDC §6).
  ///
  /// Si le montant dépasse la plus ancienne facture, le reliquat s'applique à
  /// la suivante par ordre d'ancienneté, et ainsi de suite. Ce qui dépasse
  /// l'ardoise reste en avance au crédit du client — son solde passe négatif.
  ///
  /// Les factures candidates sont lues **hors transaction**, puis relues
  /// **dedans** : une transaction Firestore n'autorise aucune requête, mais
  /// relire chaque document par identifiant garantit que le lettrage
  /// s'appuie sur des montants à jour, même si un autre appareil a encaissé
  /// entre-temps.
  Future<PaiementModel> creer({
    required String tenantId,
    required String clientId,
    required String clientNom,
    required double montant,
    required ModePaiement mode,
    required DateTime date,
    required String creeParId,
    required String creeParNom,
  }) async {
    if (montant <= 0) {
      throw const FacturationException(
        'Le montant réglé doit être supérieur à 0.',
      );
    }
    if (clientId.isEmpty || tenantId.isEmpty) {
      throw const FacturationException('Client ou entreprise absent.');
    }

    final candidates = await facturesAApurer(clientId, tenantId: tenantId);

    return _fs.db.runTransaction<PaiementModel>((tx) async {
      // ---- Lectures ----

      final clientRef = _clients.doc(clientId);
      final clientSnap = await tx.get(clientRef);
      if (!clientSnap.exists) {
        throw const FacturationException('Client introuvable.');
      }

      final fraiches = <FactureModel>[];
      for (final c in candidates) {
        final snap = await tx.get(_factures.doc(c.id));
        if (!snap.exists) continue;
        final f = FactureModel.fromFirestore(snap);
        if (!f.annulee && f.resteDu > 0) fraiches.add(f);
      }
      fraiches.sort((a, b) => a.date.compareTo(b.date));

      // ---- Lettrage FIFO ----

      final paiementRef = _col.doc();
      final imputations = <ImputationPaiement>[];
      var reste = montant;

      for (final f in fraiches) {
        if (reste <= 0.005) break;
        final part = reste >= f.resteDu ? f.resteDu : reste;
        imputations.add(
          ImputationPaiement(
            factureId: f.id,
            factureNumero: f.numero,
            montant: part,
          ),
        );
        reste -= part;

        tx.update(_factures.doc(f.id), {
          'montantPaye': f.montantPaye + part,
          'statut': (f.montantPaye + part) >= f.montantTotal - 0.005
              ? StatutFacture.payee.name
              : StatutFacture.partielle.name,
          'paiementIds': FieldValue.arrayUnion([paiementRef.id]),
        });
      }

      // ---- Écritures ----

      final paiement = PaiementModel(
        id: paiementRef.id,
        date: date,
        clientId: clientId,
        clientNom: clientNom,
        montant: montant,
        mode: mode,
        imputations: imputations,
        tenantId: tenantId,
        creeParId: creeParId,
        creeParNom: creeParNom,
      );

      tx.set(
        paiementRef,
        paiement.toMap()..['createdAt'] = FieldValue.serverTimestamp(),
      );

      // Le solde baisse du montant **total** encaissé, imputé ou non :
      // l'éventuelle avance est bien de l'argent reçu, elle doit apparaître
      // au crédit du client.
      tx.update(clientRef, {'solde': FieldValue.increment(-montant)});

      return paiement;
    });
  }

  /// Annule un règlement. Réservé à l'administrateur (CDC §1.3).
  ///
  /// Chaque facture qu'il avait soldée redevient due à hauteur de ce qui lui
  /// avait été imputé, et le solde du client remonte du montant encaissé.
  /// Les factures annulées entre-temps sont ignorées : leurs imputations ont
  /// déjà été défaites par l'annulation de la facture.
  Future<void> annuler(
    PaiementModel paiement, {
    required String parNom,
    String? motif,
  }) async {
    if (paiement.annule) return;

    await _fs.db.runTransaction((tx) async {
      final ref = _col.doc(paiement.id);
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw const FacturationException('Règlement introuvable.');
      }

      final courant = PaiementModel.fromFirestore(snap);
      if (courant.annule) return;

      final clientRef = _clients.doc(courant.clientId);
      final clientSnap = await tx.get(clientRef);

      final factureSnaps =
          <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final i in courant.imputations) {
        if (i.factureId.isEmpty) continue;
        factureSnaps[i.factureId] = await tx.get(_factures.doc(i.factureId));
      }

      // ---- Écritures ----

      tx.update(ref, {
        'annule': true,
        'annuleLe': FieldValue.serverTimestamp(),
        'annuleParNom': parNom,
        'motifAnnulation': motif,
        // Les imputations sont défaites : les conserver laisserait croire que
        // ces factures sont encore couvertes par ce règlement.
        'imputations': <Map<String, dynamic>>[],
      });

      for (final i in courant.imputations) {
        final fs = factureSnaps[i.factureId];
        if (fs == null || !fs.exists) continue;
        final f = FactureModel.fromFirestore(fs);
        if (f.annulee) continue;

        final nouveauPaye = (f.montantPaye - i.montant).clamp(0, double.infinity);
        tx.update(fs.reference, {
          'montantPaye': nouveauPaye,
          'statut': nouveauPaye <= 0.005
              ? StatutFacture.impayee.name
              : (nouveauPaye >= f.montantTotal - 0.005
                  ? StatutFacture.payee.name
                  : StatutFacture.partielle.name),
          'paiementIds': FieldValue.arrayRemove([courant.id]),
        });
      }

      if (clientSnap.exists) {
        tx.update(clientRef, {
          'solde': FieldValue.increment(courant.montant),
        });
      }
    });
  }
}
