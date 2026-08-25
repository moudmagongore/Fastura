import 'package:flutter/material.dart';

/// Palette Fastura.
///
/// Les couleurs de marque (bleu pétrole, vert) sont fixes ; tout le reste
/// est adaptatif clair/sombre et se lit via les helpers qui prennent le
/// `BuildContext`. Ne jamais coder une couleur de fond ou de texte en dur
/// dans une vue : le thème sombre casserait.
abstract class AppColors {
  AppColors._();

  // ---- Couleurs de marque (identiques dans les deux thèmes) ----

  /// Bleu pétrole — couleur primaire Fastura.
  static const Color brandPrimary = Color(0xFF1F4E5F);

  /// Vert — couleur d'accent Fastura.
  static const Color brandAccent = Color(0xFF2E7D6E);

  /// Variantes dérivées, utilisées pour les dégradés (splash, en-têtes).
  static const Color brandPrimaryDark = Color(0xFF163A47);
  static const Color brandPrimaryLight = Color(0xFF2C6C82);

  // ---- Couleurs sémantiques métier ----

  /// Facture payée / paiement encaissé.
  static const Color success = Color(0xFF2E7D6E);

  /// Facture partiellement payée.
  static const Color warning = Color(0xFFE0A106);

  /// Facture impayée, dépense, annulation.
  static const Color danger = Color(0xFFC0392B);

  /// Document annulé (grisé, barré).
  static const Color cancelled = Color(0xFF8A94A6);

  // ---- Neutres clairs ----

  static const Color _lightBackground = Color(0xFFF5F7F8);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightText = Color(0xFF1A2027);
  static const Color _lightTextMuted = Color(0xFF6B7785);
  static const Color _lightBorder = Color(0xFFE1E6EA);

  // ---- Neutres sombres ----

  static const Color _darkBackground = Color(0xFF10161A);
  static const Color _darkSurface = Color(0xFF1A2329);
  static const Color _darkText = Color(0xFFECF1F4);
  static const Color _darkTextMuted = Color(0xFF9AA7B2);
  static const Color _darkBorder = Color(0xFF2C3941);

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Primaire adaptée : le bleu pétrole est trop sombre sur fond noir,
  /// on l'éclaircit en thème sombre pour garder le contraste.
  static Color primary(BuildContext context) =>
      _isDark(context) ? brandPrimaryLight : brandPrimary;

  static Color accent(BuildContext context) => brandAccent;

  static Color background(BuildContext context) =>
      _isDark(context) ? _darkBackground : _lightBackground;

  static Color surface(BuildContext context) =>
      _isDark(context) ? _darkSurface : _lightSurface;

  static Color text(BuildContext context) =>
      _isDark(context) ? _darkText : _lightText;

  static Color textMuted(BuildContext context) =>
      _isDark(context) ? _darkTextMuted : _lightTextMuted;

  static Color border(BuildContext context) =>
      _isDark(context) ? _darkBorder : _lightBorder;
}
