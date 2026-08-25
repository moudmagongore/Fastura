/// Format d'impression des factures et reçus. Un seul est actif à la fois
/// pour tout le tenant (cf. CDC §6).
enum FormatImpression {
  a4,

  /// Demi-A4 : la facture de comptoir, moins encombrante et deux fois moins
  /// coûteuse en papier qu'un A4 pour une vente de quelques lignes.
  a5,

  /// Petit format reçu pour imprimante thermique (type supermarché).
  ticket;

  /// Les tenants créés avant le remplacement de l'A3 par l'A5 peuvent porter
  /// `'a3'` en base : la valeur n'existe plus, `parse` les ramène sur A4
  /// plutôt que d'échouer au tirage.
  static FormatImpression parse(String? value) =>
      tryParse(value) ?? FormatImpression.a4;

  static FormatImpression? tryParse(String? value) {
    for (final f in FormatImpression.values) {
      if (f.name == value) return f;
    }
    return null;
  }

  String get label => switch (this) {
        FormatImpression.a4 => 'A4',
        FormatImpression.a5 => 'A5 (demi-page)',
        FormatImpression.ticket => 'Ticket (imprimante thermique)',
      };

  /// Largeur de rouleau usuelle pour le format ticket, en millimètres.
  /// Sert au rendu PDF du module Facturation.
  static const double ticketLargeurMm = 80;
}
