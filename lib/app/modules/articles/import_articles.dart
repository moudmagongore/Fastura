/// Analyse d'une liste d'articles collée par l'administrateur.
///
/// Séparé du contrôleur pour être éprouvé seul : c'est du texte qui vient de
/// partout — un tableur, un message, un cahier recopié — et c'est là que se
/// jouent les surprises. Aucune dépendance à Firebase ni à Flutter.
library;

/// Ce que devient une ligne collée.
enum StatutLigne {
  /// Prête à être créée.
  creable,

  /// Une désignation déjà présente dans la catégorie choisie, ou répétée
  /// plus haut dans la liste collée.
  doublon,

  /// Illisible : pas de prix, prix nul, désignation vide.
  erreur,
}

/// Une ligne de la liste collée, telle qu'elle sera créée — ou refusée.
class LigneImport {
  LigneImport({
    required this.numero,
    required this.texte,
    required this.designation,
    required this.prix,
    required this.unite,
    required this.statut,
    this.probleme,
  }) : retenue = statut == StatutLigne.creable;

  /// Numéro dans le texte collé, pour que l'utilisateur retrouve la ligne
  /// fautive dans sa source.
  final int numero;

  /// La ligne d'origine, affichée telle quelle quand elle est illisible.
  final String texte;

  final String designation;
  final double prix;
  final String unite;
  final StatutLigne statut;

  /// Ce qui cloche, en clair. Nul quand la ligne est créable.
  final String? probleme;

  /// Cochée dans l'aperçu. Un doublon est décoché par défaut mais peut être
  /// forcé : deux articles de même nom restent permis par le catalogue.
  bool retenue;

  bool get modifiable => statut != StatutLigne.erreur;
}

/// Résultat d'une analyse.
class AnalyseImport {
  const AnalyseImport({required this.lignes, required this.tronquee});

  final List<LigneImport> lignes;

  /// Vrai quand le collage dépassait [maxLignes] : le surplus est écarté
  /// plutôt que de rendre l'aperçu impraticable au doigt.
  final bool tronquee;

  /// Plafond d'un collage. Au-delà, l'aperçu ne se relit plus et la liste
  /// se colle en deux fois — ce qui reste sans commune mesure avec une
  /// saisie article par article.
  static const int maxLignes = 500;

  static const List<String> _separateurs = ['\t', ';', '|'];

  /// Découpe le texte collé.
  ///
  /// [existantes] sont les désignations déjà au catalogue **dans la
  /// catégorie choisie** : le catalogue n'interdit pas les homonymes, c'est
  /// donc ici qu'on prévient le double import.
  static AnalyseImport analyser(
    String texte, {
    required String uniteParDefaut,
    Iterable<String> existantes = const [],
  }) {
    final connues = {for (final d in existantes) _cle(d)};
    final vues = <String>{};
    final lignes = <LigneImport>[];
    var numero = 0;
    var tronquee = false;

    for (final brute in texte.split('\n')) {
      final ligne = brute.trim();
      if (ligne.isEmpty) continue;
      numero++;
      if (lignes.length >= maxLignes) {
        tronquee = true;
        break;
      }

      final parts = _decouper(ligne);
      final designation = parts.isEmpty ? '' : _espaces(parts.first);
      final prix = parts.length > 1 ? montant(parts[1]) : null;
      final unite = parts.length > 2 && parts[2].trim().isNotEmpty
          ? parts[2].trim()
          : uniteParDefaut;

      String? probleme;
      if (designation.isEmpty) {
        probleme = 'Désignation vide';
      } else if (parts.length < 2) {
        // Une ligne sans séparateur est presque toujours une liste sans
        // prix : la créer à zéro franc ferait facturer à zéro.
        probleme = 'Prix absent';
      } else if (prix == null) {
        probleme = 'Prix illisible : « ${parts[1].trim()} »';
      } else if (prix <= 0) {
        probleme = 'Prix nul';
      }

      if (probleme != null) {
        lignes.add(
          LigneImport(
            numero: numero,
            texte: ligne,
            designation: designation,
            prix: 0,
            unite: unite,
            statut: StatutLigne.erreur,
            probleme: probleme,
          ),
        );
        continue;
      }

      final cle = _cle(designation);
      final dejaPlusHaut = vues.contains(cle);
      vues.add(cle);
      final doublon = dejaPlusHaut || connues.contains(cle);

      lignes.add(
        LigneImport(
          numero: numero,
          texte: ligne,
          designation: designation,
          prix: prix!,
          unite: unite,
          statut: doublon ? StatutLigne.doublon : StatutLigne.creable,
          probleme: doublon
              ? (dejaPlusHaut
                    ? 'Répété plus haut dans la liste'
                    : 'Déjà au catalogue')
              : null,
        ),
      );
    }

    return AnalyseImport(lignes: lignes, tronquee: tronquee);
  }

  /// Le séparateur n'est pas demandé : il est reconnu.
  ///
  /// La tabulation d'abord — c'est ce qu'on obtient en copiant deux colonnes
  /// d'un tableur, le chemin le plus court quand le catalogue existe déjà.
  /// La virgule est volontairement exclue : elle sert de décimale.
  static List<String> _decouper(String ligne) {
    for (final s in _separateurs) {
      if (ligne.contains(s)) return ligne.split(s);
    }
    return [ligne];
  }

  /// Espaces multiples réduits : « Sac   de riz » et « Sac de riz » sont le
  /// même article, et l'un des deux vient d'un copier-coller maladroit.
  static String _espaces(String v) => v.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String _cle(String designation) => _espaces(designation).toLowerCase();

  /// Lit un prix écrit par un humain : « 425 000 », « 425.000 »,
  /// « 425000 GNF », « 12 500,50 ».
  ///
  /// Nul si rien d'exploitable — mieux vaut une ligne signalée qu'un article
  /// créé à un prix inventé.
  static double? montant(String brut) {
    // Espaces de toutes sortes, insécables compris : un tableur en produit.
    var v = brut.replaceAll(RegExp(r'[\s  ]'), '');
    // Devise et autres lettres collées au nombre.
    v = v.replaceAll(RegExp(r'[^0-9.,-]'), '');
    if (v.isEmpty) return null;

    if (v.contains(',')) {
      // La virgule décide : elle est décimale en français, le point ne peut
      // alors qu'être un séparateur de milliers.
      v = v.replaceAll('.', '').replaceAll(',', '.');
    } else if (v.contains('.')) {
      final apres = v.split('.').last;
      // « 425.000 » est un millier, « 425.5 » une décimale : trois chiffres
      // après le dernier point tranchent, c'est la convention d'ici.
      if (apres.length == 3 && v.split('.').length >= 2) {
        v = v.replaceAll('.', '');
      }
    }

    return double.tryParse(v);
  }
}
