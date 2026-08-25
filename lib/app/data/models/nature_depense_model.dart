import 'package:cloud_firestore/cloud_firestore.dart';

/// Nature de dépense : la nomenclature que l'entreprise définit elle-même
/// (loyer, carburant, fournitures, salaires…) — cf. CDC §7.
///
/// Comme les catégories d'articles, une nature n'est jamais supprimée : la
/// désactiver la retire du formulaire de saisie sans toucher aux dépenses
/// déjà enregistrées avec elle.
class NatureDepenseModel {
  final String id;
  final String libelle;
  final String tenantId;
  final bool active;
  final DateTime? createdAt;

  const NatureDepenseModel({
    required this.id,
    required this.libelle,
    required this.tenantId,
    this.active = true,
    this.createdAt,
  });

  factory NatureDepenseModel.fromMap(Map<String, dynamic> map, String id) {
    return NatureDepenseModel(
      id: id,
      libelle: (map['libelle'] ?? '') as String,
      tenantId: (map['tenantId'] ?? '') as String,
      active: (map['active'] ?? true) as bool,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory NatureDepenseModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => NatureDepenseModel.fromMap(doc.data() ?? const {}, doc.id);

  Map<String, dynamic> toMap() => {
    'libelle': libelle,
    'tenantId': tenantId,
    'active': active,
    if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
  };

  NatureDepenseModel copyWith({String? libelle, bool? active}) {
    return NatureDepenseModel(
      id: id,
      libelle: libelle ?? this.libelle,
      tenantId: tenantId,
      active: active ?? this.active,
      createdAt: createdAt,
    );
  }
}
