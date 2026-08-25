import 'package:cloud_firestore/cloud_firestore.dart';

/// Produit ou service facturable (cf. CDC §4).
///
/// Le module Articles est un **catalogue de prix** : la gestion de stock est
/// hors périmètre V1, il n'y a donc aucune quantité ici.
class ArticleModel {
  final String id;

  final String categorieId;
  final String designation;

  /// Prix de vente unitaire, dans la devise du tenant.
  final double prixVente;

  /// Unité de facturation : pièce, carton, kg, heure…
  final String unite;

  final String tenantId;
  final bool active;
  final DateTime? createdAt;

  const ArticleModel({
    required this.id,
    required this.categorieId,
    required this.designation,
    required this.prixVente,
    required this.unite,
    required this.tenantId,
    this.active = true,
    this.createdAt,
  });

  factory ArticleModel.fromMap(Map<String, dynamic> map, String id) {
    return ArticleModel(
      id: id,
      categorieId: (map['categorieId'] ?? '') as String,
      designation: (map['designation'] ?? '') as String,
      prixVente: (map['prixVente'] as num?)?.toDouble() ?? 0,
      unite: (map['unite'] ?? '') as String,
      tenantId: (map['tenantId'] ?? '') as String,
      active: (map['active'] ?? true) as bool,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory ArticleModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      ArticleModel.fromMap(doc.data() ?? const {}, doc.id);

  Map<String, dynamic> toMap() => {
        'categorieId': categorieId,
        'designation': designation,
        'prixVente': prixVente,
        'unite': unite,
        'tenantId': tenantId,
        'active': active,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      };

  ArticleModel copyWith({
    String? categorieId,
    String? designation,
    double? prixVente,
    String? unite,
    bool? active,
  }) {
    return ArticleModel(
      id: id,
      categorieId: categorieId ?? this.categorieId,
      designation: designation ?? this.designation,
      prixVente: prixVente ?? this.prixVente,
      unite: unite ?? this.unite,
      tenantId: tenantId,
      active: active ?? this.active,
      createdAt: createdAt,
    );
  }
}

/// Unités proposées en saisie rapide. Le champ reste libre : une entreprise
/// peut facturer au « bidon » ou au « voyage ».
const unitesCourantes = <String>[
  'pièce',
  'carton',
  'sac',
  'kg',
  'litre',
  'mètre',
  'heure',
  'jour',
  'forfait',
];
