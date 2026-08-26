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

  /// Variantes dérivées, utilisées pour les dégradés (en-têtes).
  static const Color brandPrimaryDark = Color(0xFF163A47);
  static const Color brandPrimaryLight = Color(0xFF2C6C82);

  /// Fond des écrans de marque (splash), clair dans les deux thèmes.
  ///
  /// Le logo horizontal est encré en [brandPrimary] et [brandAccent] sur fond
  /// transparent : sur un fond sombre, « Fast » disparaît dans le décor. Il
  /// lui faut le fond clair sur lequel il a été dessiné — le même que l'écran
  /// de lancement natif, blanc sur Android comme sur iOS, qui précède le
  /// splash Flutter. Le forcer sombre y ajouterait un flash.
  static const Color brandCanvas = Color(0xFFFFFFFF);
  static const Color brandCanvasTint = Color(0xFFE8EFF1);

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
  //
  // Publics parce que [AppTheme] les monte en `ThemeData` ; les vues, elles,
  // passent par les helpers adaptatifs plus bas.

  static const Color lightBackground = Color(0xFFF4F6F8);
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// Fond des champs, des chips et des blocs discrets : un ton entre le fond
  /// et la surface, qui délimite sans qu'il faille tracer un cadre.
  static const Color lightSurfaceMuted = Color(0xFFEDF1F4);
  static const Color lightText = Color(0xFF16202A);
  static const Color lightTextMuted = Color(0xFF6B7785);
  static const Color lightBorder = Color(0xFFE4E9ED);

  // ---- Neutres sombres ----

  static const Color darkBackground = Color(0xFF0F1519);
  static const Color darkSurface = Color(0xFF19222A);
  static const Color darkSurfaceMuted = Color(0xFF212C35);
  static const Color darkText = Color(0xFFECF1F4);
  static const Color darkTextMuted = Color(0xFF95A3AF);
  static const Color darkBorder = Color(0xFF2A3640);

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Primaire adaptée : le bleu pétrole est trop sombre sur fond noir,
  /// on l'éclaircit en thème sombre pour garder le contraste.
  static Color primary(BuildContext context) =>
      _isDark(context) ? brandPrimaryLight : brandPrimary;

  static Color accent(BuildContext context) => brandAccent;

  static Color background(BuildContext context) =>
      _isDark(context) ? darkBackground : lightBackground;

  static Color surface(BuildContext context) =>
      _isDark(context) ? darkSurface : lightSurface;

  /// Fond des champs, chips et blocs discrets — voir [lightSurfaceMuted].
  static Color surfaceMuted(BuildContext context) =>
      _isDark(context) ? darkSurfaceMuted : lightSurfaceMuted;

  static Color text(BuildContext context) =>
      _isDark(context) ? darkText : lightText;

  static Color textMuted(BuildContext context) =>
      _isDark(context) ? darkTextMuted : lightTextMuted;

  static Color border(BuildContext context) =>
      _isDark(context) ? darkBorder : lightBorder;
}
