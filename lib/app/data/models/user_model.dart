import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_role.dart';

/// Un compte de connexion. Le doc-id est l'uid Firebase Auth, ce qui permet
/// aux rules Firestore de lire le rôle et le tenant de l'appelant en un
/// `get(/users/$(request.auth.uid))`.
///
/// Un utilisateur n'appartient qu'à un seul tenant (cf. CDC §3), sauf le
/// super-admin dont le [tenantId] est nul.
class UserModel {
  final String id;
  final String nom;
  final String email;
  final String? telephone;
  final UserRole role;

  /// Nul uniquement pour le super-administrateur.
  final String? tenantId;

  /// Un utilisateur désactivé ne peut plus se connecter ni opérer, mais les
  /// documents qu'il a saisis restent visibles dans l'historique.
  final bool active;

  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.nom,
    required this.email,
    required this.role,
    this.telephone,
    this.tenantId,
    this.active = true,
    this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      nom: (map['nom'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      telephone: map['telephone'] as String?,
      role: UserRole.tryParse(map['role'] as String?) ?? UserRole.vendeur,
      tenantId: map['tenantId'] as String?,
      active: (map['active'] ?? true) as bool,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory UserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      UserModel.fromMap(doc.data() ?? const {}, doc.id);

  Map<String, dynamic> toMap() => {
        'nom': nom,
        'email': email,
        'telephone': telephone,
        'role': role.name,
        'tenantId': tenantId,
        'active': active,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      };

  UserModel copyWith({
    String? nom,
    String? email,
    String? telephone,
    UserRole? role,
    String? tenantId,
    bool? active,
  }) {
    return UserModel(
      id: id,
      nom: nom ?? this.nom,
      email: email ?? this.email,
      telephone: telephone ?? this.telephone,
      role: role ?? this.role,
      tenantId: tenantId ?? this.tenantId,
      active: active ?? this.active,
      createdAt: createdAt,
    );
  }

  /// Initiales pour l'avatar du drawer (« Mamadou Diallo » → « MD »).
  String get initiales {
    final parts =
        nom.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
