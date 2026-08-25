import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_keys.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/depense_model.dart';
import 'facture_repository.dart' show FacturationException;

class DepenseRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col => _fs.depenses;

  /// Dépenses du tenant sur une période, de la plus récente à la plus
  /// ancienne.
  ///
  /// La période est filtrée **côté serveur** : c'est elle qui borne le
  /// volume. La nature l'est côté écran — ajouter `natureId` à la requête
  /// coûterait un index composite de plus pour un filtre qui s'applique à
  /// une liste déjà réduite au mois courant.
  Stream<List<DepenseModel>> watchByTenant(
    String tenantId, {
    DateTime? debut,
    DateTime? fin,
    int limite = 500,
  }) {
    if (tenantId.isEmpty) return Stream.value(const <DepenseModel>[]);
    Query<Map<String, dynamic>> q = _col.where(
      FirestoreKeys.fieldTenantId,
      isEqualTo: tenantId,
    );
    if (debut != null) {
      q = q.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(debut));
    }
    if (fin != null) {
      q = q.where('date', isLessThanOrEqualTo: Timestamp.fromDate(fin));
    }
    return q
        .orderBy('date', descending: true)
        .limit(limite)
        .snapshots()
        .ignorePermissionDenied(contexte: 'dépenses du tenant')
        .map((snap) => snap.docs.map(DepenseModel.fromFirestore).toList());
  }

  Stream<DepenseModel?> watchById(String id) {
    if (id.isEmpty) return Stream.value(null);
    return _col
        .doc(id)
        .snapshots()
        .ignorePermissionDenied()
        .map((doc) => doc.exists ? DepenseModel.fromFirestore(doc) : null);
  }

  /// Enregistre une dépense.
  ///
  /// Pas de transaction : une dépense ne met à jour aucune contrepartie —
  /// ni solde, ni compteur, ni lettrage. C'est une écriture isolée.
  Future<DepenseModel> creer({
    required String tenantId,
    required String natureId,
    required String natureLibelle,
    required double montant,
    required DateTime date,
    required String creeParId,
    required String creeParNom,
    String? description,
  }) async {
    if (montant <= 0) {
      throw const FacturationException(
        'Le montant de la dépense doit être supérieur à 0.',
      );
    }
    if (natureId.isEmpty) {
      throw const FacturationException('Choisissez une nature de dépense.');
    }
    if (tenantId.isEmpty) {
      throw const FacturationException('Entreprise absente de la session.');
    }

    final ref = _col.doc();
    final depense = DepenseModel(
      id: ref.id,
      date: date,
      natureId: natureId,
      natureLibelle: natureLibelle,
      montant: montant,
      description: description,
      tenantId: tenantId,
      creeParId: creeParId,
      creeParNom: creeParNom,
    );

    await ref.set(
      depense.toMap()..['createdAt'] = FieldValue.serverTimestamp(),
    );
    return depense;
  }

  /// Annule une dépense. Réservé à l'administrateur (CDC §1.3, §7).
  ///
  /// Jamais de suppression : l'écriture reste dans l'historique, barrée et
  /// motivée, mais sort des totaux. Un justificatif classé sous ce montant
  /// doit pouvoir être retrouvé même après correction.
  Future<void> annuler(
    DepenseModel depense, {
    required String parNom,
    String? motif,
  }) async {
    if (depense.annulee) return;
    await _col.doc(depense.id).update({
      'annulee': true,
      'annuleeLe': FieldValue.serverTimestamp(),
      'annuleeParNom': parNom,
      'motifAnnulation': motif,
    });
  }
}
