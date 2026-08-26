import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_keys.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/article_model.dart';

class ArticleRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col => _fs.articles;

  /// Catalogue du tenant.
  ///
  /// [actifsSeulement] est ce que consommera la facturation : un article
  /// désactivé disparaît des listes de sélection mais reste lisible dans
  /// l'historique des factures déjà émises (cf. CDC §4).
  Stream<List<ArticleModel>> watchByTenant(
    String tenantId, {
    bool actifsSeulement = false,
    String? categorieId,
  }) {
    if (tenantId.isEmpty) return Stream.value(const <ArticleModel>[]);
    Query<Map<String, dynamic>> q = _col.where(
      FirestoreKeys.fieldTenantId,
      isEqualTo: tenantId,
    );
    if (categorieId != null && categorieId.isNotEmpty) {
      q = q.where('categorieId', isEqualTo: categorieId);
    }
    if (actifsSeulement) {
      q = q.where(FirestoreKeys.fieldActive, isEqualTo: true);
    }
    return q
        .orderBy('designation')
        .snapshots()
        .ignorePermissionDenied()
        .map((snap) => snap.docs.map(ArticleModel.fromFirestore).toList());
  }

  Future<ArticleModel?> getById(String id) async {
    if (id.isEmpty) return null;
    final doc = await _col.doc(id).get();
    return doc.exists ? ArticleModel.fromFirestore(doc) : null;
  }

  Future<String> create(ArticleModel a) async {
    final data = a.toMap()..['createdAt'] = FieldValue.serverTimestamp();
    final ref = await _col.add(data);
    return ref.id;
  }

  Future<void> update(ArticleModel a) {
    final data = a.toMap()..remove('createdAt');
    return _col.doc(a.id).update(data);
  }

  Future<void> setActive(String id, bool active) {
    return _col.doc(id).update({FirestoreKeys.fieldActive: active});
  }
}
