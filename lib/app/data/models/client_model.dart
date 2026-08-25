import 'package:cloud_firestore/cloud_firestore.dart';

/// Client d'une entreprise (cf. CDC §5).
class ClientModel {
  final String id;
  final String nom;
  final String? telephone;
  final String? adresse;

  /// Créances non réglées, en devise du tenant.
  ///
  /// Champ **calculé et maintenu par les modules Facturation et Paiements**,
  /// dans la même transaction que la facture ou le règlement : le recalculer
  /// à la lecture obligerait à relire tout l'historique du client à chaque
  /// affichage de liste. Positif = le client doit de l'argent ; négatif =
  /// il a payé d'avance.
  final double solde;

  /// Le « client divers » préconfiguré, qui permet de facturer une vente
  /// comptant sans créer de fiche (cf. CDC §5). Il y en a exactement un par
  /// tenant, il ne peut être ni renommé ni désactivé.
  final bool estDivers;

  final String tenantId;
  final bool active;
  final DateTime? createdAt;

  const ClientModel({
    required this.id,
    required this.nom,
    required this.tenantId,
    this.telephone,
    this.adresse,
    this.solde = 0,
    this.estDivers = false,
    this.active = true,
    this.createdAt,
  });

  factory ClientModel.fromMap(Map<String, dynamic> map, String id) {
    return ClientModel(
      id: id,
      nom: (map['nom'] ?? '') as String,
      telephone: map['telephone'] as String?,
      adresse: map['adresse'] as String?,
      solde: (map['solde'] as num?)?.toDouble() ?? 0,
      estDivers: (map['estDivers'] ?? false) as bool,
      tenantId: (map['tenantId'] ?? '') as String,
      active: (map['active'] ?? true) as bool,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory ClientModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      ClientModel.fromMap(doc.data() ?? const {}, doc.id);

  Map<String, dynamic> toMap() => {
        'nom': nom,
        'telephone': telephone,
        'adresse': adresse,
        'solde': solde,
        'estDivers': estDivers,
        'tenantId': tenantId,
        'active': active,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      };

  ClientModel copyWith({
    String? nom,
    String? telephone,
    String? adresse,
    double? solde,
    bool? active,
  }) {
    return ClientModel(
      id: id,
      nom: nom ?? this.nom,
      telephone: telephone ?? this.telephone,
      adresse: adresse ?? this.adresse,
      solde: solde ?? this.solde,
      estDivers: estDivers,
      tenantId: tenantId,
      active: active ?? this.active,
      createdAt: createdAt,
    );
  }

  /// Vrai si le client doit de l'argent à l'entreprise.
  bool get aUneDette => solde > 0;

  /// Vrai s'il a payé plus que ce qu'il devait (avance).
  bool get aUneAvance => solde < 0;

  String get initiales {
    final parts =
        nom.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
