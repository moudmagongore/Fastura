/// Format d'impression des factures et reçus. Un seul est actif à la fois
/// pour tout le tenant (cf. CDC §6).
enum FormatImpression {
  a4,
  a3,

  /// Petit format reçu pour imprimante thermique (type supermarché).
  ticket;

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
        FormatImpression.a3 => 'A3',
        FormatImpression.ticket => 'Ticket (imprimante thermique)',
      };

  /// Largeur de rouleau usuelle pour le format ticket, en millimètres.
  /// Sert au rendu PDF du module Facturation.
  static const double ticketLargeurMm = 80;
}
