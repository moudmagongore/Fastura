import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firestore_service.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/tenant_model.dart';

/// Accès aux entreprises clientes. Réservé au super-administrateur pour la
/// création et l'activation ; l'administrateur d'un tenant ne peut lire et
/// modifier que son propre document (cf. `firestore.rules`).
class TenantRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col => _fs.tenants;

  /// Liste complète des tenants — super-admin uniquement.
  Stream<List<TenantModel>> watchAll({bool? actifsSeulement}) {
    Query<Map<String, dynamic>> q = _col;
    if (actifsSeulement == true) {
      q = q.where('active', isEqualTo: true);
    }
    return q.orderBy('nom').snapshots().ignorePermissionDenied().map(
          (snap) => snap.docs.map(TenantModel.fromFirestore).toList(),
        );
  }

  /// Suit le tenant de l'utilisateur connecté. Un changement de devise, de
  /// TVA ou de format d'impression fait par l'admin se propage aux écrans
  /// sans redémarrer l'application ; une désactivation par le super-admin
  /// déclenche la déconnexion (cf. `SessionController`).
  Stream<TenantModel?> watchById(String id) {
    if (id.isEmpty) return Stream.value(null);
    return _col.doc(id).snapshots().ignorePermissionDenied().map(
          (doc) => doc.exists ? TenantModel.fromFirestore(doc) : null,
        );
  }

  Future<TenantModel?> getById(String id) async {
    if (id.isEmpty) return null;
    final doc = await _col.doc(id).get();
    return doc.exists ? TenantModel.fromFirestore(doc) : null;
  }

  Future<String> create(TenantModel tenant) async {
    final data = tenant.toMap()..['createdAt'] = FieldValue.serverTimestamp();
    final ref = await _col.add(data);
    return ref.id;
  }

  Future<void> update(TenantModel tenant) {
    final data = tenant.toMap()..remove('createdAt');
    return _col.doc(tenant.id).update(data);
  }

  /// Active ou désactive une entreprise. Jamais de suppression physique :
  /// l'historique de facturation doit rester intact.
  Future<void> setActive(String id, bool active) {
    return _col.doc(id).update({'active': active});
  }
}
