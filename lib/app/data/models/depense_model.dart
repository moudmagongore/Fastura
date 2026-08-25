import 'package:cloud_firestore/cloud_firestore.dart';

/// Sortie d'argent de l'entreprise (cf. CDC §7).
///
/// Une dépense n'a aucune contrepartie à mettre à jour : ni solde client, ni
/// compteur, ni lettrage. Sa création et son annulation sont donc de simples
/// écritures, là où une facture exige une transaction.
class DepenseModel {
  final String id;
  final DateTime date;

  final String natureId;

  /// Libellé de la nature au moment de la saisie.
  ///
  /// Recopié comme le nom du client sur une facture : une dépense est une
  /// écriture datée, renommer la nomenclature ne doit pas réécrire le passé.
  /// Les récapitulatifs regroupent sur [natureId] et préfèrent le libellé
  /// courant du référentiel quand il existe — ce champ est le filet quand la
  /// nature a disparu des listes.
  final String natureLibelle;

  final double montant;

  /// Texte libre : à qui, pourquoi, quelle référence de pièce.
  final String? description;

  /// Photo ou pièce jointe justifiant la dépense.
  ///
  /// Toujours nul aujourd'hui : le téléversement attend que Firebase Storage
  /// soit provisionné sur le projet. Le champ existe pour que la reprise ne
  /// touche ni au modèle ni aux rules.
  final String? justificatifUrl;

  /// Une dépense annulée reste dans l'historique mais sort des totaux.
  /// L'annulation est réservée à l'administrateur (CDC §1.3, §7).
  final bool annulee;
  final DateTime? annuleeLe;
  final String? annuleeParNom;
  final String? motifAnnulation;

  final String tenantId;
  final String creeParId;
  final String creeParNom;
  final DateTime? createdAt;

  const DepenseModel({
    required this.id,
    required this.date,
    required this.natureId,
    required this.natureLibelle,
    required this.montant,
    required this.tenantId,
    required this.creeParId,
    required this.creeParNom,
    this.description,
    this.justificatifUrl,
    this.annulee = false,
    this.annuleeLe,
    this.annuleeParNom,
    this.motifAnnulation,
    this.createdAt,
  });

  factory DepenseModel.fromMap(Map<String, dynamic> map, String id) {
    return DepenseModel(
      id: id,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      natureId: (map['natureId'] ?? '') as String,
      natureLibelle: (map['natureLibelle'] ?? '') as String,
      montant: (map['montant'] as num?)?.toDouble() ?? 0,
      description: map['description'] as String?,
      justificatifUrl: map['justificatifUrl'] as String?,
      annulee: (map['annulee'] ?? false) as bool,
      annuleeLe: (map['annuleeLe'] as Timestamp?)?.toDate(),
      annuleeParNom: map['annuleeParNom'] as String?,
      motifAnnulation: map['motifAnnulation'] as String?,
      tenantId: (map['tenantId'] ?? '') as String,
      creeParId: (map['creeParId'] ?? '') as String,
      creeParNom: (map['creeParNom'] ?? '') as String,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory DepenseModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => DepenseModel.fromMap(doc.data() ?? const {}, doc.id);

  Map<String, dynamic> toMap() => {
    'date': Timestamp.fromDate(date),
    'natureId': natureId,
    'natureLibelle': natureLibelle,
    'montant': montant,
    'description': description,
    'justificatifUrl': justificatifUrl,
    'annulee': annulee,
    if (annuleeLe != null) 'annuleeLe': Timestamp.fromDate(annuleeLe!),
    'annuleeParNom': annuleeParNom,
    'motifAnnulation': motifAnnulation,
    'tenantId': tenantId,
    'creeParId': creeParId,
    'creeParNom': creeParNom,
    if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
  };
}

/// Cumul d'une nature sur une période : ce qu'attend le récapitulatif
/// imprimable du CDC §7.
class TotalNature {
  const TotalNature({
    required this.natureId,
    required this.libelle,
    required this.montant,
    required this.nombre,
  });

  final String natureId;
  final String libelle;
  final double montant;
  final int nombre;
}
