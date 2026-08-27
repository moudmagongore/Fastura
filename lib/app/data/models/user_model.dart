import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_role.dart';

/// Un compte de connexion. Le doc-id est l'uid Firebase Auth, ce qui permet
/// aux rules Firestore de lire le rôle et les boutiques de l'appelant en un
/// `get(/users/$(request.auth.uid))`.
///
/// Un compte est rattaché à une **boutique d'origine** ([tenantId]) et,
/// depuis les affectations du super-administrateur, éventuellement à
/// d'autres ([tenantIds]). Le super-administrateur n'a ni l'une ni les
/// autres.
class UserModel {
  final String id;
  final String nom;
  final String email;
  final String? telephone;
  final UserRole role;

  /// Boutique d'origine — celle où le compte a été créé. Nulle uniquement
  /// pour le super-administrateur.
  ///
  /// Elle reste le champ historique du document : les comptes créés avant
  /// les affectations multiples ne portent que lui, et les requêtes
  /// continuent de s'y appuyer (cf. `UserRepository.watchByTenant`).
  final String? tenantId;

  /// Toutes les boutiques du compte, la boutique d'origine en tête.
  ///
  /// Jamais lue telle quelle depuis Firestore : [fromMap] la reconstruit
  /// toujours à partir de [tenantId], pour qu'un document ancien — qui ne
  /// porte pas le champ — se lise comme un compte mono-boutique.
  final List<String> tenantIds;

  /// Un utilisateur désactivé ne peut plus se connecter ni opérer, mais les
  /// documents qu'il a saisis restent visibles dans l'historique.
  final bool active;

  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.nom,
    required this.email,
    required this.role,
    this.telephone,
    this.tenantId,
    List<String>? tenantIds,
    this.active = true,
    this.createdAt,
  }) : tenantIds = normaliserTenantIds(tenantId, tenantIds);

  /// Boutique d'origine en tête, sans doublon ni valeur vide.
  ///
  /// L'ordre porte du sens : la tête est la boutique par défaut à
  /// l'ouverture de session, et la seule dont un administrateur ne peut pas
  /// être retiré.
  static List<String> normaliserTenantIds(
    String? principal,
    List<String>? autres,
  ) {
    final liste = <String>[];
    if (principal != null && principal.isNotEmpty) liste.add(principal);
    for (final id in autres ?? const <String>[]) {
      if (id.isNotEmpty && !liste.contains(id)) liste.add(id);
    }
    return List.unmodifiable(liste);
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      nom: (map['nom'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      telephone: map['telephone'] as String?,
      role: UserRole.tryParse(map['role'] as String?) ?? UserRole.vendeur,
      tenantId: map['tenantId'] as String?,
      tenantIds: (map['tenantIds'] as List?)?.whereType<String>().toList(),
      active: (map['active'] ?? true) as bool,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      UserModel.fromMap(doc.data() ?? const {}, doc.id);

  Map<String, dynamic> toMap() => {
    'nom': nom,
    'email': email,
    'telephone': telephone,
    'role': role.name,
    'tenantId': tenantId,
    'tenantIds': tenantIds,
    'active': active,
    if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
  };

  UserModel copyWith({
    String? nom,
    String? email,
    String? telephone,
    UserRole? role,
    String? tenantId,
    List<String>? tenantIds,
    bool? active,
  }) {
    return UserModel(
      id: id,
      nom: nom ?? this.nom,
      email: email ?? this.email,
      telephone: telephone ?? this.telephone,
      role: role ?? this.role,
      tenantId: tenantId ?? this.tenantId,
      tenantIds: tenantIds ?? this.tenantIds,
      active: active ?? this.active,
      createdAt: createdAt,
    );
  }

  /// Vrai si le compte opère dans cette boutique, d'origine ou par
  /// affectation.
  bool appartientA(String id) => tenantIds.contains(id);

  /// Un compte affecté à plusieurs boutiques bascule de l'une à l'autre
  /// depuis le tiroir, et n'est plus modifiable par les administrateurs
  /// d'une seule d'entre elles.
  bool get estMultiBoutique => tenantIds.length > 1;

  /// Boutiques ajoutées par le super-administrateur, hors boutique
  /// d'origine — les seules dont le compte peut être retiré.
  List<String> get boutiquesAffectees => tenantIds.skip(1).toList();

  /// Initiales pour l'avatar du drawer (« Mamadou Diallo » → « MD »).
  String get initiales {
    final parts = nom
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
