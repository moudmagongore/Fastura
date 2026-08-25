import 'package:cloud_firestore/cloud_firestore.dart';

/// Moyen par lequel le client a réglé.
enum ModePaiement {
  especes,
  mobileMoney,
  virement,
  cheque,
  autre;

  static ModePaiement parse(String? value) {
    for (final m in ModePaiement.values) {
      if (m.name == value) return m;
    }
    return ModePaiement.especes;
  }

  String get label => switch (this) {
        ModePaiement.especes => 'Espèces',
        ModePaiement.mobileMoney => 'Mobile Money',
        ModePaiement.virement => 'Virement',
        ModePaiement.cheque => 'Chèque',
        ModePaiement.autre => 'Autre',
      };
}

/// Part d'un règlement affectée à une facture précise.
///
/// Un paiement direct n'en porte qu'une. Un règlement passé par le menu de
/// paiement dédié en porte autant que de factures soldées au fil du lettrage
/// FIFO (cf. CDC §6).
class ImputationPaiement {
  final String factureId;

  /// Numéro de la facture au moment de l'imputation, pour que le reçu reste
  /// lisible sans relire la facture.
  final String factureNumero;

  final double montant;

  const ImputationPaiement({
    required this.factureId,
    required this.factureNumero,
    required this.montant,
  });

  factory ImputationPaiement.fromMap(Map<String, dynamic> map) {
    return ImputationPaiement(
      factureId: (map['factureId'] ?? '') as String,
      factureNumero: (map['factureNumero'] ?? '') as String,
      montant: (map['montant'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'factureId': factureId,
        'factureNumero': factureNumero,
        'montant': montant,
      };
}

/// Règlement d'un client (cf. CDC §6).
class PaiementModel {
  final String id;
  final DateTime date;
  final String clientId;
  final String clientNom;
  final double montant;
  final ModePaiement mode;

  /// Mention libre : numéro de chèque, référence de transfert, nom du
  /// porteur venu régler pour le compte du client.
  final String? note;

  /// Répartition du montant sur les factures. Vide si le règlement dépasse
  /// les dettes du client : le surplus reste en avance à son crédit.
  final List<ImputationPaiement> imputations;

  /// Vrai quand le règlement a été encaissé au moment même de la
  /// facturation, par opposition au menu de paiement dédié.
  final bool directALaFacturation;

  final bool annule;
  final DateTime? annuleLe;
  final String? annuleParNom;
  final String? motifAnnulation;

  final String tenantId;
  final String creeParId;
  final String creeParNom;
  final DateTime? createdAt;

  const PaiementModel({
    required this.id,
    required this.date,
    required this.clientId,
    required this.clientNom,
    required this.montant,
    required this.mode,
    required this.tenantId,
    required this.creeParId,
    required this.creeParNom,
    this.note,
    this.imputations = const [],
    this.directALaFacturation = false,
    this.annule = false,
    this.annuleLe,
    this.annuleParNom,
    this.motifAnnulation,
    this.createdAt,
  });

  /// Part du règlement effectivement affectée à des factures.
  double get montantImpute =>
      imputations.fold<double>(0, (somme, i) => somme + i.montant);

  /// Surplus laissé en avance au crédit du client.
  double get montantEnAvance {
    final reste = montant - montantImpute;
    return reste.abs() < 0.005 ? 0 : reste;
  }

  factory PaiementModel.fromMap(Map<String, dynamic> map, String id) {
    final brutes = (map['imputations'] as List<dynamic>? ?? const []);
    return PaiementModel(
      id: id,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      clientId: (map['clientId'] ?? '') as String,
      clientNom: (map['clientNom'] ?? '') as String,
      montant: (map['montant'] as num?)?.toDouble() ?? 0,
      mode: ModePaiement.parse(map['mode'] as String?),
      note: map['note'] as String?,
      imputations: brutes
          .map((i) =>
              ImputationPaiement.fromMap(Map<String, dynamic>.from(i as Map)))
          .toList(),
      directALaFacturation: (map['directALaFacturation'] ?? false) as bool,
      annule: (map['annule'] ?? false) as bool,
      annuleLe: (map['annuleLe'] as Timestamp?)?.toDate(),
      annuleParNom: map['annuleParNom'] as String?,
      motifAnnulation: map['motifAnnulation'] as String?,
      tenantId: (map['tenantId'] ?? '') as String,
      creeParId: (map['creeParId'] ?? '') as String,
      creeParNom: (map['creeParNom'] ?? '') as String,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory PaiementModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      PaiementModel.fromMap(doc.data() ?? const {}, doc.id);

  Map<String, dynamic> toMap() => {
        'date': Timestamp.fromDate(date),
        'clientId': clientId,
        'clientNom': clientNom,
        'montant': montant,
        'mode': mode.name,
        'note': note,
        'imputations': imputations.map((i) => i.toMap()).toList(),
        'directALaFacturation': directALaFacturation,
        'annule': annule,
        if (annuleLe != null) 'annuleLe': Timestamp.fromDate(annuleLe!),
        'annuleParNom': annuleParNom,
        'motifAnnulation': motifAnnulation,
        'tenantId': tenantId,
        'creeParId': creeParId,
        'creeParNom': creeParNom,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      };
}
