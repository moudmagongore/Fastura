import 'package:cloud_firestore/cloud_firestore.dart';

/// Statut de règlement d'une facture. Déduit du rapport entre le montant
/// total et le montant déjà encaissé — jamais saisi à la main.
enum StatutFacture {
  impayee,
  partielle,
  payee;

  String get label => switch (this) {
    StatutFacture.impayee => 'Impayée',
    StatutFacture.partielle => 'Partiellement payée',
    StatutFacture.payee => 'Payée',
  };
}

/// Une ligne d'article sur une facture.
///
/// La désignation et le prix unitaire sont **recopiés** depuis le catalogue
/// au moment de l'émission. C'est ce qui permet à une facture de rester
/// lisible à l'identique après qu'un article a changé de prix, a été renommé
/// ou désactivé (cf. CDC §4).
class LigneFacture {
  final String articleId;

  /// Code de l'article au moment de l'émission.
  ///
  /// Le catalogue n'a plus de code : ce champ reste vide sur toute facture
  /// émise depuis. Il n'est conservé que pour les factures antérieures, qui
  /// l'affichaient sur la copie remise au client — une pièce comptable ne se
  /// réécrit pas. Rien ne l'alimente plus.
  final String code;

  final String designation;

  /// Catégorie de l'article au moment de l'émission.
  ///
  /// Recopiée comme la désignation et le prix : deux boutiques vendent
  /// volontiers deux « Sac 50 kg » différents, et c'est la catégorie qui les
  /// départage sur le papier. Vide sur les factures émises avant qu'elle
  /// soit reprise — elle ne s'imprime alors pas, plutôt que d'aller la
  /// chercher au catalogue d'aujourd'hui : une pièce comptable ne se
  /// réécrit pas.
  final String categorieLibelle;

  final String unite;
  final double prixUnitaire;
  final double quantite;

  const LigneFacture({
    required this.articleId,
    required this.designation,
    required this.unite,
    required this.prixUnitaire,
    required this.quantite,
    this.categorieLibelle = '',
    this.code = '',
  });

  double get montant => prixUnitaire * quantite;

  factory LigneFacture.fromMap(Map<String, dynamic> map) {
    return LigneFacture(
      articleId: (map['articleId'] ?? '') as String,
      code: (map['code'] ?? '') as String,
      designation: (map['designation'] ?? '') as String,
      categorieLibelle: (map['categorieLibelle'] ?? '') as String,
      unite: (map['unite'] ?? '') as String,
      prixUnitaire: (map['prixUnitaire'] as num?)?.toDouble() ?? 0,
      quantite: (map['quantite'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'articleId': articleId,
    if (code.isNotEmpty) 'code': code,
    'designation': designation,
    if (categorieLibelle.isNotEmpty) 'categorieLibelle': categorieLibelle,
    'unite': unite,
    'prixUnitaire': prixUnitaire,
    'quantite': quantite,
    // Redondant avec le calcul, mais stocké pour que le document soit
    // lisible tel quel côté backend futur, sans rejouer l'arithmétique.
    'montant': prixUnitaire * quantite,
  };

  LigneFacture copyWith({double? quantite, double? prixUnitaire}) {
    return LigneFacture(
      articleId: articleId,
      code: code,
      designation: designation,
      categorieLibelle: categorieLibelle,
      unite: unite,
      prixUnitaire: prixUnitaire ?? this.prixUnitaire,
      quantite: quantite ?? this.quantite,
    );
  }
}

/// Document de vente (cf. CDC §6).
///
/// Plusieurs champs sont des instantanés pris à l'émission — nom du client,
/// devise, taux de TVA, lignes d'articles. Une facture est une pièce
/// comptable : elle doit rester identique à ce qui a été imprimé et remis au
/// client, même si le référentiel change ensuite.
class FactureModel {
  final String id;

  /// Séquentiel par tenant, sans trou ni doublon. Attribué dans la
  /// transaction de création — voir [FactureRepository.creer].
  final String numero;

  final DateTime date;

  final String clientId;

  /// Nom du client au moment de l'émission.
  final String clientNom;

  /// Identité du client de passage, saisie à l'émission et **facultative**.
  ///
  /// N'a de sens qu'avec le « client divers » : c'est le nom qu'on écrit sur
  /// la facture quand l'acheteur n'a pas vocation à entrer au fichier — une
  /// vente unique, un dépannage. Il ne crée aucune fiche et n'ouvre aucun
  /// compte : le solde reste celui du client divers, et [clientId] aussi.
  /// C'est le seul moyen de ne pas gonfler le fichier client d'une fiche par
  /// passant.
  final String? clientNomLibre;
  final String? clientTelephoneLibre;

  final List<LigneFacture> lignes;

  /// Taux de TVA appliqué, en pourcentage. Zéro si le tenant n'est pas
  /// assujetti au moment de l'émission.
  final double tauxTva;

  /// Devise du tenant au moment de l'émission.
  final String devise;

  /// Mention libre saisie à l'émission : référence de commande, condition
  /// particulière, précision de livraison. Figée comme le reste de la
  /// facture — une pièce comptable ne se réécrit pas après coup.
  final String? note;

  /// Cumul des règlements imputés sur cette facture.
  final double montantPaye;

  /// Identifiant du règlement encaissé au moment même de la facturation,
  /// s'il y en a eu un. Stocké pour que l'annulation de la facture puisse
  /// annuler ce règlement dans la même transaction : une requête est
  /// impossible à l'intérieur d'une transaction Firestore, seule une
  /// lecture par identifiant l'est.
  final String? paiementDirectId;

  /// Tous les règlements imputés sur cette facture, direct compris.
  ///
  /// Même raison d'être que [paiementDirectId] : sans cette liste,
  /// l'annulation d'une facture déjà réglée devrait retrouver les règlements
  /// concernés par une requête, ce qu'une transaction Firestore n'autorise
  /// pas. La liste reste courte — un client solde rarement une facture en
  /// plus de quelques versements.
  final List<String> paiementIds;

  /// Une facture annulée ne compte plus ni dans le solde du client ni dans
  /// le chiffre d'affaires, mais reste dans l'historique : la numérotation
  /// séquentielle interdit de la faire disparaître.
  final bool annulee;
  final DateTime? annuleeLe;
  final String? annuleeParNom;
  final String? motifAnnulation;

  final String tenantId;

  /// Utilisateur qui a émis la facture.
  final String creeParId;
  final String creeParNom;

  final DateTime? createdAt;

  const FactureModel({
    required this.id,
    required this.numero,
    required this.date,
    required this.clientId,
    required this.clientNom,
    this.clientNomLibre,
    this.clientTelephoneLibre,
    required this.lignes,
    required this.tenantId,
    required this.creeParId,
    required this.creeParNom,
    this.tauxTva = 0,
    this.devise = '',
    this.note,
    this.montantPaye = 0,
    this.paiementDirectId,
    this.paiementIds = const [],
    this.annulee = false,
    this.annuleeLe,
    this.annuleeParNom,
    this.motifAnnulation,
    this.createdAt,
  });

  // ------------------------------------------------------------- montants

  double get montantHT =>
      lignes.fold<double>(0, (somme, l) => somme + l.montant);

  double get montantTva => montantHT * tauxTva / 100;

  /// Nom à afficher et à imprimer : celui du passant s'il a été saisi, le
  /// client enregistré sinon. Tout ce qui montre une facture passe par là.
  String get clientAffiche {
    final libre = clientNomLibre?.trim() ?? '';
    return libre.isEmpty ? clientNom : libre;
  }

  /// Vrai quand la facture porte l'identité d'un passant plutôt qu'un client
  /// du fichier : les écrans le signalent, sinon on croirait à une fiche.
  bool get estClientDePassage => (clientNomLibre?.trim() ?? '').isNotEmpty;

  double get montantTotal => montantHT + montantTva;

  /// Ce qu'il reste à encaisser. Nul sur une facture annulée : elle ne
  /// pèse plus sur le solde du client.
  double get resteDu {
    if (annulee) return 0;
    final reste = montantTotal - montantPaye;
    // Les arrondis de virgule flottante peuvent laisser des reliquats de
    // l'ordre de 10⁻¹⁰, qui feraient afficher « partiellement payée » une
    // facture soldée.
    return reste.abs() < 0.005 ? 0 : reste;
  }

  StatutFacture get statut {
    if (montantPaye <= 0) return StatutFacture.impayee;
    if (resteDu <= 0) return StatutFacture.payee;
    return StatutFacture.partielle;
  }

  bool get estSoldee => resteDu <= 0;

  int get nombreArticles => lignes.length;

  // -------------------------------------------------------- sérialisation

  factory FactureModel.fromMap(Map<String, dynamic> map, String id) {
    final brutes = (map['lignes'] as List<dynamic>? ?? const []);
    return FactureModel(
      id: id,
      numero: (map['numero'] ?? '') as String,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      clientId: (map['clientId'] ?? '') as String,
      clientNom: (map['clientNom'] ?? '') as String,
      clientNomLibre: map['clientNomLibre'] as String?,
      clientTelephoneLibre: map['clientTelephoneLibre'] as String?,
      lignes: brutes
          .map((l) => LigneFacture.fromMap(Map<String, dynamic>.from(l as Map)))
          .toList(),
      tauxTva: (map['tauxTva'] as num?)?.toDouble() ?? 0,
      devise: (map['devise'] ?? '') as String,
      note: map['note'] as String?,
      montantPaye: (map['montantPaye'] as num?)?.toDouble() ?? 0,
      paiementDirectId: map['paiementDirectId'] as String?,
      paiementIds: (map['paiementIds'] as List<dynamic>? ?? const [])
          .cast<String>(),
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

  factory FactureModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => FactureModel.fromMap(doc.data() ?? const {}, doc.id);

  Map<String, dynamic> toMap() => {
    'numero': numero,
    'date': Timestamp.fromDate(date),
    'clientId': clientId,
    'clientNom': clientNom,
    'clientNomLibre': clientNomLibre,
    'clientTelephoneLibre': clientTelephoneLibre,
    'lignes': lignes.map((l) => l.toMap()).toList(),
    'tauxTva': tauxTva,
    'devise': devise,
    'note': note,
    // Totaux figés dans le document : ils doivent survivre tels quels à
    // toute évolution du calcul côté application.
    'montantHT': montantHT,
    'montantTva': montantTva,
    'montantTotal': montantTotal,
    'montantPaye': montantPaye,
    'paiementDirectId': paiementDirectId,
    'paiementIds': paiementIds,
    'statut': statut.name,
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
