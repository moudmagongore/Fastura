import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_keys.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/nature_depense_model.dart';

class NatureDepenseRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col => _fs.naturesDepense;
  CollectionReference<Map<String, dynamic>> get _depenses => _fs.depenses;

  /// Le filtre `tenantId` est obligatoire : les rules Firestore ne peuvent
  /// qu'autoriser ou refuser une query, jamais en restreindre le résultat.
  Stream<List<NatureDepenseModel>> watchByTenant(
    String tenantId, {
    bool actifsSeulement = false,
  }) {
    if (tenantId.isEmpty) return Stream.value(const <NatureDepenseModel>[]);
    Query<Map<String, dynamic>> q = _col.where(
      FirestoreKeys.fieldTenantId,
      isEqualTo: tenantId,
    );
    if (actifsSeulement) {
      q = q.where(FirestoreKeys.fieldActive, isEqualTo: true);
    }
    return q
        .orderBy('libelle')
        .snapshots()
        .ignorePermissionDenied()
        .map(
          (snap) => snap.docs.map(NatureDepenseModel.fromFirestore).toList(),
        );
  }

  Future<NatureDepenseModel?> getById(String id) async {
    if (id.isEmpty) return null;
    final doc = await _col.doc(id).get();
    return doc.exists ? NatureDepenseModel.fromFirestore(doc) : null;
  }

  Future<String> create(NatureDepenseModel n) async {
    final data = n.toMap()..['createdAt'] = FieldValue.serverTimestamp();
    final ref = await _col.add(data);
    return ref.id;
  }

  Future<void> update(NatureDepenseModel n) {
    final data = n.toMap()..remove('createdAt');
    return _col.doc(n.id).update(data);
  }

  /// Active ou désactive une nature.
  ///
  /// Aucune cascade, contrairement aux catégories d'articles : une dépense
  /// est une écriture datée, déjà passée. Fermer sa nature la retire du
  /// formulaire de saisie, pas de l'historique ni des totaux (CDC §7).
  Future<void> setActive(String id, bool active) {
    return _col.doc(id).update({FirestoreKeys.fieldActive: active});
  }

  /// Nombre de dépenses déjà enregistrées sous cette nature. Sert à dire à
  /// l'administrateur ce qu'il touche avant de la fermer.
  Future<int> compterDepenses(
    String natureId, {
    required String tenantId,
  }) async {
    if (natureId.isEmpty || tenantId.isEmpty) return 0;
    final snap = await _depenses
        .where(FirestoreKeys.fieldTenantId, isEqualTo: tenantId)
        .where('natureId', isEqualTo: natureId)
        .count()
        .get();
    return snap.count ?? 0;
  }
}
