import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_keys.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/categorie_model.dart';

class CategorieRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col => _fs.categories;
  CollectionReference<Map<String, dynamic>> get _articles => _fs.articles;

  /// Le filtre `tenantId` est obligatoire : les rules Firestore ne peuvent
  /// qu'autoriser ou refuser une query, jamais en restreindre le résultat.
  /// Sans lui, la requête est rejetée en bloc (PERMISSION_DENIED).
  Stream<List<CategorieModel>> watchByTenant(
    String tenantId, {
    bool actifsSeulement = false,
  }) {
    if (tenantId.isEmpty) return Stream.value(const <CategorieModel>[]);
    Query<Map<String, dynamic>> q =
        _col.where(FirestoreKeys.fieldTenantId, isEqualTo: tenantId);
    if (actifsSeulement) {
      q = q.where(FirestoreKeys.fieldActive, isEqualTo: true);
    }
    return q.orderBy('libelle').snapshots().ignorePermissionDenied().map(
          (snap) => snap.docs.map(CategorieModel.fromFirestore).toList(),
        );
  }

  Future<CategorieModel?> getById(String id) async {
    if (id.isEmpty) return null;
    final doc = await _col.doc(id).get();
    return doc.exists ? CategorieModel.fromFirestore(doc) : null;
  }

  Future<String> create(CategorieModel c) async {
    final data = c.toMap()..['createdAt'] = FieldValue.serverTimestamp();
    final ref = await _col.add(data);
    return ref.id;
  }

  Future<void> update(CategorieModel c) {
    final data = c.toMap()..remove('createdAt');
    return _col.doc(c.id).update(data);
  }

  /// Nombre d'articles rattachés, filtré sur leur statut si [active] est
  /// fourni. Sert à annoncer l'ampleur de la cascade avant de basculer la
  /// catégorie.
  Future<int> compterArticles(
    String categorieId, {
    required String tenantId,
    bool? active,
  }) async {
    if (categorieId.isEmpty || tenantId.isEmpty) return 0;
    Query<Map<String, dynamic>> q = _articles
        .where(FirestoreKeys.fieldTenantId, isEqualTo: tenantId)
        .where('categorieId', isEqualTo: categorieId);
    if (active != null) {
      q = q.where(FirestoreKeys.fieldActive, isEqualTo: active);
    }
    final snap = await q.count().get();
    return snap.count ?? 0;
  }

  /// Active ou désactive une catégorie.
  ///
  /// **Désactiver propage à tous ses articles** (règle du CDC §4) : un
  /// article dont la catégorie est fermée ne doit plus apparaître dans les
  /// listes de sélection à la facturation.
  ///
  /// **Réactiver ne propage pas par défaut** : certains articles ont pu être
  /// désactivés individuellement, pour rupture définitive ou fin de
  /// commercialisation, et les rouvrir en masse ferait réapparaître des
  /// lignes que personne n'a demandé à revoir.
  ///
  /// [reactiverArticles] laisse néanmoins le choix à l'administrateur : quand
  /// la désactivation des articles n'était qu'un dommage collatéral de la
  /// fermeture de la catégorie, les rouvrir un par un est du travail pour
  /// rien. La décision lui revient, l'écran la lui pose explicitement.
  Future<void> setActive(
    String categorieId,
    bool active, {
    required String tenantId,
    bool reactiverArticles = false,
  }) async {
    await _col.doc(categorieId).update({FirestoreKeys.fieldActive: active});

    if (active && !reactiverArticles) return;

    // À la désactivation on ferme les articles ouverts ; à la réactivation
    // demandée, on rouvre les articles fermés.
    final snap = await _articles
        .where(FirestoreKeys.fieldTenantId, isEqualTo: tenantId)
        .where('categorieId', isEqualTo: categorieId)
        .where(FirestoreKeys.fieldActive, isEqualTo: !active)
        .get();
    if (snap.docs.isEmpty) return;

    // Un batch Firestore plafonne à 500 écritures : on découpe, sinon un
    // catalogue fourni ferait échouer toute la cascade.
    const tailleLot = 400;
    for (var i = 0; i < snap.docs.length; i += tailleLot) {
      final lot = snap.docs.skip(i).take(tailleLot);
      final batch = _fs.db.batch();
      for (final doc in lot) {
        batch.update(doc.reference, {FirestoreKeys.fieldActive: active});
      }
      await batch.commit();
    }
  }
}
