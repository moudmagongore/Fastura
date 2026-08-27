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
  /// unique, pour qu'une désactivation, un changement de rôle ou une
  /// affectation à une nouvelle boutique prenne effet immédiatement.
  Stream<UserModel?> watchById(String uid) {
    if (uid.isEmpty) return Stream.value(null);
    return _col
        .doc(uid)
        .snapshots()
        .ignorePermissionDenied()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  Future<UserModel?> getById(String uid) async {
    if (uid.isEmpty) return null;
    final doc = await _col.doc(uid).get();
    return doc.exists ? UserModel.fromFirestore(doc) : null;
  }

  /// Utilisateurs d'une boutique. Le filtre est obligatoire : les rules
  /// Firestore refusent toute query non scopée (PERMISSION_DENIED), elles
  /// ne peuvent pas restreindre le résultat à notre place.
  ///
  /// **Deux requêtes fusionnées**, faute d'un OU entre deux champs chez
  /// Firestore :
  ///   • `tenantId` — la boutique d'origine, seul champ que portent les
  ///     comptes créés avant les affectations multiples ;
  ///   • `tenantIds` — la liste complète, qui remonte en plus les
  ///     administrateurs affectés ici par le super-administrateur.
  ///
  /// Ne garder que la seconde ferait disparaître de la liste tous les
  /// comptes existants tant qu'ils n'ont pas été réenregistrés.
  Stream<List<UserModel>> watchByTenant(
    String tenantId, {
    bool? actifsSeulement,
  }) {
    if (tenantId.isEmpty) return Stream.value(const <UserModel>[]);

    Query<Map<String, dynamic>> filtrer(Query<Map<String, dynamic>> q) {
      if (actifsSeulement == true) {
        q = q.where(FirestoreKeys.fieldActive, isEqualTo: true);
      }
      return q.orderBy('nom');
    }

    Stream<List<UserModel>> lire(Query<Map<String, dynamic>> q) => filtrer(q)
        .snapshots()
        .ignorePermissionDenied(contexte: 'users/$tenantId')
        .map((snap) => snap.docs.map(UserModel.fromFirestore).toList());

    return fusionnerListes<UserModel>(
      [
        lire(_col.where(FirestoreKeys.fieldTenantId, isEqualTo: tenantId)),
        lire(_col.where(FirestoreKeys.fieldTenantIds, arrayContains: tenantId)),
      ],
      cle: (u) => u.id,
      tri: (a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()),
    );
  }

  /// Tous les administrateurs de la plateforme, toutes boutiques confondues.
  ///
  /// Requête volontairement non scopée : seul le super-administrateur peut
  /// la lancer (les rules lui ouvrent `users` en entier), et c'est
  /// précisément parce qu'il cherche un administrateur **d'une autre
  /// boutique** à affecter ici.
  Stream<List<UserModel>> watchAdmins() {
    return _col
        .where('role', isEqualTo: UserRole.admin.name)
        .orderBy('nom')
        .snapshots()
        .ignorePermissionDenied(contexte: 'users/admins')
        .map((snap) => snap.docs.map(UserModel.fromFirestore).toList());
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

  /// Mise à jour d'un profil **par son propre titulaire** : le nom et le
  /// téléphone, rien d'autre.
  ///
  /// Écriture volontairement minimale : le rôle, les boutiques et l'état
  /// actif appartiennent à l'administrateur. Les rules refusent d'y toucher
  /// depuis ce chemin — un vendeur se promouvrait administrateur.
  Future<void> updateProfilPersonnel(
    String uid, {
    required String nom,
    String? telephone,
  }) {
    return _col.doc(uid).update({'nom': nom, 'telephone': telephone});
  }

  /// Recale l'email du profil sur celui du compte Auth.
  ///
  /// Un changement d'adresse ne prend effet qu'après ouverture du lien de
  /// vérification, souvent sur un autre appareil : le document Firestore
  /// n'apprend le nouvel email qu'à la connexion suivante.
  Future<void> synchroniserEmail(String uid, String email) {
    return _col.doc(uid).update({'email': email});
  }

  /// Bloque ou débloque l'accès d'un utilisateur. Ses factures, paiements et
  /// dépenses déjà enregistrés restent visibles dans l'historique.
  Future<void> setActive(String uid, bool active) {
    return _col.doc(uid).update({FirestoreKeys.fieldActive: active});
  }

  /// Rattache un compte à une boutique de plus — réservé au
  /// super-administrateur (cf. `firestore.rules`).
  ///
  /// En transaction, et non par un simple `arrayUnion` : la liste doit
  /// toujours commencer par la boutique d'origine, y compris sur un
  /// document ancien qui ne porte pas encore le champ. Un `arrayUnion` sur
  /// un champ absent créerait une liste réduite à la seule boutique
  /// affectée, et le compte perdrait la sienne.
  Future<void> affecterTenant(String uid, String tenantId) {
    return _fs.db.runTransaction((tx) async {
      final ref = _col.doc(uid);
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('Ce compte n\'existe plus.');
      }
      final user = UserModel.fromFirestore(snap);
      if (user.appartientA(tenantId)) return;
      tx.update(ref, {
        FirestoreKeys.fieldTenantIds: [...user.tenantIds, tenantId],
      });
    });
  }

  /// Retire une boutique affectée. La boutique d'origine n'est jamais
  /// retirée : elle est le rattachement du compte, pas une affectation.
  Future<void> retirerTenant(String uid, String tenantId) {
    return _fs.db.runTransaction((tx) async {
      final ref = _col.doc(uid);
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('Ce compte n\'existe plus.');
      }
      final user = UserModel.fromFirestore(snap);
      if (user.tenantId == tenantId) {
        throw StateError(
          'C\'est la boutique d\'origine de ce compte : elle ne peut pas '
          'être retirée.',
        );
      }
      if (!user.appartientA(tenantId)) return;
      tx.update(ref, {
        FirestoreKeys.fieldTenantIds: user.tenantIds
            .where((id) => id != tenantId)
            .toList(),
      });
    });
  }

  /// Vrai s'il reste au moins un autre administrateur actif dans la
  /// boutique. Sert de garde-fou avant de désactiver ou de rétrograder un
  /// admin : une boutique sans admin actif n'a plus personne pour gérer ses
  /// référentiels.
  ///
  /// Deux lectures, pour la même raison que [watchByTenant] : un
  /// administrateur affecté ici compte autant que celui qui y a été créé.
  Future<bool> resteUnAutreAdminActif(
    String tenantId, {
    required String saufUid,
  }) async {
    if (tenantId.isEmpty) return false;

    Future<bool> interroger(Query<Map<String, dynamic>> q) async {
      final snap = await q
          .where('role', isEqualTo: UserRole.admin.name)
          .where(FirestoreKeys.fieldActive, isEqualTo: true)
          .limit(2)
          .get();
      return snap.docs.any((d) => d.id != saufUid);
    }

    if (await interroger(
      _col.where(FirestoreKeys.fieldTenantId, isEqualTo: tenantId),
    )) {
      return true;
    }
    return interroger(
      _col.where(FirestoreKeys.fieldTenantIds, arrayContains: tenantId),
    );
  }
}
