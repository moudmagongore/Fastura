import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_keys.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';

/// Accès aux comptes de connexion.
///
/// Le doc-id est l'uid Firebase Auth. La création d'un compte se fait donc
/// en deux temps (compte Auth puis document `users/{uid}`) — voir
/// [createProfile].
class UserRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col => _fs.users;

  /// Suit le profil de l'utilisateur connecté. En stream et non en lecture
  /// unique, pour qu'une désactivation ou un changement de rôle décidé par
  /// l'administrateur prenne effet immédiatement.
  Stream<UserModel?> watchById(String uid) {
    if (uid.isEmpty) return Stream.value(null);
    return _col.doc(uid).snapshots().ignorePermissionDenied().map(
          (doc) => doc.exists ? UserModel.fromFirestore(doc) : null,
        );
  }

  Future<UserModel?> getById(String uid) async {
    if (uid.isEmpty) return null;
    final doc = await _col.doc(uid).get();
    return doc.exists ? UserModel.fromFirestore(doc) : null;
  }

  /// Utilisateurs d'un tenant. Le filtre `tenantId` est obligatoire : les
  /// rules Firestore refusent toute query non scopée (PERMISSION_DENIED),
  /// elles ne peuvent pas restreindre le résultat à notre place.
  Stream<List<UserModel>> watchByTenant(
    String tenantId, {
    bool? actifsSeulement,
  }) {
    if (tenantId.isEmpty) return Stream.value(const <UserModel>[]);
    Query<Map<String, dynamic>> q =
        _col.where(FirestoreKeys.fieldTenantId, isEqualTo: tenantId);
    if (actifsSeulement == true) {
      q = q.where(FirestoreKeys.fieldActive, isEqualTo: true);
    }
    return q.orderBy('nom').snapshots().ignorePermissionDenied().map(
          (snap) => snap.docs.map(UserModel.fromFirestore).toList(),
        );
  }

  /// Crée le document de profil associé à un compte Auth déjà existant.
  /// L'uid est imposé comme doc-id.
  Future<void> createProfile(UserModel user) {
    final data = user.toMap()..['createdAt'] = FieldValue.serverTimestamp();
    return _col.doc(user.id).set(data);
  }

  Future<void> update(UserModel user) {
    final data = user.toMap()
      ..remove('createdAt')
      // L'email est porté par Firebase Auth : le modifier ici ne changerait
      // pas l'identifiant de connexion et créerait une incohérence.
      ..remove('email');
    return _col.doc(user.id).update(data);
  }

  /// Bloque ou débloque l'accès d'un utilisateur. Ses factures, paiements et
  /// dépenses déjà enregistrés restent visibles dans l'historique.
  Future<void> setActive(String uid, bool active) {
    return _col.doc(uid).update({FirestoreKeys.fieldActive: active});
  }

  /// Vrai s'il reste au moins un autre administrateur actif dans le tenant.
  /// Sert de garde-fou avant de désactiver ou de rétrograder un admin : un
  /// tenant sans admin actif n'a plus personne pour gérer ses référentiels.
  Future<bool> resteUnAutreAdminActif(
    String tenantId, {
    required String saufUid,
  }) async {
    if (tenantId.isEmpty) return false;
    final snap = await _col
        .where(FirestoreKeys.fieldTenantId, isEqualTo: tenantId)
        .where('role', isEqualTo: UserRole.admin.name)
        .where(FirestoreKeys.fieldActive, isEqualTo: true)
        .limit(2)
        .get();
    return snap.docs.any((d) => d.id != saufUid);
  }
}
