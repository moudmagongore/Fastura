import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import 'format_impression.dart';

/// Une entreprise cliente de Fastura. Porte tous les paramètres qui varient
/// d'une entreprise à l'autre : devise, TVA, logo, adresse, format
/// d'impression (cf. CDC §2 et §7).
///
/// Seul le Super-Administrateur crée, active ou désactive un tenant.
/// L'Administrateur du tenant en modifie les paramètres, jamais le statut.
class TenantModel {
  /// Doc-id Firestore. C'est la valeur portée par le champ `tenantId` de
  /// tous les documents métier de cette entreprise.
  final String id;

  final String nom;
  final String? adresse;
  final String? telephone;
  final String? email;

  /// URL du logo affiché en en-tête des factures et reçus imprimés.
  final String? logoUrl;

  /// Code ou symbole de la devise (ex : `GNF`, `XOF`, `EUR`).
  final String devise;

  /// Taux de TVA en pourcentage. Ignoré tant que [tvaActive] est faux.
  final double tauxTva;

  /// Une entreprise non assujettie facture sans TVA.
  final bool tvaActive;

  /// Format unique retenu pour toutes les impressions du tenant.
  final FormatImpression formatImpression;

  /// Préfixe des numéros de facture (ex : `FA` → `FA-2026-00001`).
  final String prefixeFacture;

  /// Un tenant désactivé par le super-admin ne peut plus être utilisé :
  /// ses utilisateurs sont bloqués à la connexion.
  final bool active;

  final DateTime? createdAt;

  const TenantModel({
    required this.id,
    required this.nom,
    this.adresse,
    this.telephone,
    this.email,
    this.logoUrl,
    this.devise = AppConstants.defaultDevise,
    this.tauxTva = AppConstants.defaultTauxTva,
    this.tvaActive = false,
    this.formatImpression = FormatImpression.a4,
    this.prefixeFacture = 'FA',
    this.active = true,
    this.createdAt,
  });

  factory TenantModel.fromMap(Map<String, dynamic> map, String id) {
    return TenantModel(
      id: id,
      nom: (map['nom'] ?? '') as String,
      adresse: map['adresse'] as String?,
      telephone: map['telephone'] as String?,
      email: map['email'] as String?,
      logoUrl: map['logoUrl'] as String?,
      devise: (map['devise'] ?? AppConstants.defaultDevise) as String,
      tauxTva:
          (map['tauxTva'] as num?)?.toDouble() ?? AppConstants.defaultTauxTva,
      tvaActive: (map['tvaActive'] ?? false) as bool,
      formatImpression: FormatImpression.parse(
        map['formatImpression'] as String?,
      ),
      prefixeFacture: (map['prefixeFacture'] ?? 'FA') as String,
      active: (map['active'] ?? true) as bool,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory TenantModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => TenantModel.fromMap(doc.data() ?? const {}, doc.id);

  Map<String, dynamic> toMap() => {
    'nom': nom,
    'adresse': adresse,
    'telephone': telephone,
    'email': email,
    'logoUrl': logoUrl,
    'devise': devise,
    'tauxTva': tauxTva,
    'tvaActive': tvaActive,
    'formatImpression': formatImpression.name,
    'prefixeFacture': prefixeFacture,
    'active': active,
    if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
  };

  TenantModel copyWith({
    String? nom,
    String? adresse,
    String? telephone,
    String? email,
    String? logoUrl,
    String? devise,
    double? tauxTva,
    bool? tvaActive,
    FormatImpression? formatImpression,
    String? prefixeFacture,
    bool? active,
  }) {
    return TenantModel(
      id: id,
      nom: nom ?? this.nom,
      adresse: adresse ?? this.adresse,
      telephone: telephone ?? this.telephone,
      email: email ?? this.email,
      logoUrl: logoUrl ?? this.logoUrl,
      devise: devise ?? this.devise,
      tauxTva: tauxTva ?? this.tauxTva,
      tvaActive: tvaActive ?? this.tvaActive,
      formatImpression: formatImpression ?? this.formatImpression,
      prefixeFacture: prefixeFacture ?? this.prefixeFacture,
      active: active ?? this.active,
      createdAt: createdAt,
    );
  }
}
