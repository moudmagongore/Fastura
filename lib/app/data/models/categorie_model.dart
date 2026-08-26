import 'package:cloud_firestore/cloud_firestore.dart';

/// Regroupement d'articles, propre à un tenant (cf. CDC §4).
///
/// Désactiver une catégorie désactive en cascade tous ses articles — voir
/// [CategorieRepository.setActive]. L'inverse n'est pas vrai : réactiver une
/// catégorie ne réactive pas ses articles, dont certains ont pu être
/// désactivés individuellement pour leurs propres raisons.
class CategorieModel {
  final String id;

  final String libelle;
  final String tenantId;
  final bool active;
  final DateTime? createdAt;

  const CategorieModel({
    required this.id,
    required this.libelle,
    required this.tenantId,
    this.active = true,
    this.createdAt,
  });

  factory CategorieModel.fromMap(Map<String, dynamic> map, String id) {
    return CategorieModel(
      id: id,
      libelle: (map['libelle'] ?? '') as String,
      tenantId: (map['tenantId'] ?? '') as String,
      active: (map['active'] ?? true) as bool,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory CategorieModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => CategorieModel.fromMap(doc.data() ?? const {}, doc.id);

  Map<String, dynamic> toMap() => {
    'libelle': libelle,
    'tenantId': tenantId,
    'active': active,
    if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
  };

  CategorieModel copyWith({String? libelle, bool? active}) {
    return CategorieModel(
      id: id,
      libelle: libelle ?? this.libelle,
      tenantId: tenantId,
      active: active ?? this.active,
      createdAt: createdAt,
    );
  }
}
