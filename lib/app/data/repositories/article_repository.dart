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

  /// Désignations déjà présentes dans une catégorie.
  ///
  /// Lecture ponctuelle, au moment d'analyser un collage : le catalogue
  /// n'interdit pas les homonymes, c'est donc à l'import de prévenir le
  /// double enregistrement.
  Future<List<String>> designationsDe(
    String tenantId,
    String categorieId,
  ) async {
    if (tenantId.isEmpty || categorieId.isEmpty) return const [];
    final snap = await _col
        .where(FirestoreKeys.fieldTenantId, isEqualTo: tenantId)
        .where('categorieId', isEqualTo: categorieId)
        .get();
    return snap.docs
        .map((d) => (d.data()['designation'] ?? '') as String)
        .toList();
  }

  /// Crée des articles en masse, par lots de 400.
  ///
  /// Le plafond d'un batch Firestore est de 500 écritures : on reste en
  /// dessous, comme la désactivation en cascade des catégories. Les lots
  /// partent l'un après l'autre — un échec au troisième laisse les deux
  /// premiers créés, ce que le compte rendu doit refléter.
  Future<int> creerLot(List<ArticleModel> articles) async {
    var crees = 0;
    for (var i = 0; i < articles.length; i += 400) {
      final tranche = articles.skip(i).take(400).toList();
      final batch = _fs.db.batch();
      for (final a in tranche) {
        final data = a.toMap()..['createdAt'] = FieldValue.serverTimestamp();
        batch.set(_col.doc(), data);
      }
      await batch.commit();
      crees += tranche.length;
    }
    return crees;
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
