import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Thèmes clair et sombre de Fastura, construits à partir de la palette
/// de marque. Les vues ne doivent pas redéfinir de couleurs : elles lisent
/// `Theme.of(context)` ou les helpers de [AppColors].
///
/// Parti pris visuel : **du blanc, des filets, et la couleur réservée à ce
/// qui compte**. Aucune ombre, aucune barre pleine — la teinte de marque
/// sert aux actions, aux montants et aux statuts, jamais au décor. Un écran
/// de facturation se lit d'un coup d'œil au comptoir : plus il est calme,
/// plus le chiffre ressort.
abstract class AppTheme {
  AppTheme._();

  /// Rayons : un seul jeu pour toute l'app.
  /// [radiusSmall] pastilles et pictos, [radius] champs, boutons et cartes,
  /// [radiusLarge] feuilles, dialogues et bandeaux.
  static const double radiusSmall = 10.0;
  static const double radius = 14.0;
  static const double radiusLarge = 20.0;

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final primaire = isDark
        ? AppColors.brandPrimaryLight
        : AppColors.brandPrimary;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandPrimary,
      brightness: brightness,
      primary: primaire,
      secondary: AppColors.brandAccent,
      error: AppColors.danger,
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
    );

    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final fond = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final filet = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final texte = isDark ? AppColors.darkText : AppColors.lightText;
    final discret = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final teinte = isDark
        ? AppColors.darkSurfaceMuted
        : AppColors.lightSurfaceMuted;

    final formes = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );

    OutlineInputBorder bordure(Color couleur, [double epaisseur = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: couleur, width: epaisseur),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: fond,

      // Les couleurs viennent de la palette et non du calcul M3 : le voile
      // mauve que Material 3 applique aux surfaces élevées jure avec le bleu
      // pétrole.
      splashFactory: InkSparkle.splashFactory,

      textTheme: _typographie(texte, discret),

      // Barre de titre fondue dans le fond : la bande pleine couleur écrasait
      // le contenu de chaque écran. La marque reste au tiroir, sur la carte
      // d'entreprise et sur les actions.
      appBarTheme: AppBarTheme(
        backgroundColor: fond,
        foregroundColor: texte,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // Le tiroir s'ouvrant à droite, la barre n'a plus de bouton à
        // gauche : le titre commence au ras du contenu des écrans.
        titleSpacing: 16,
        iconTheme: IconThemeData(color: texte, size: 24),
        actionsIconTheme: IconThemeData(color: primaire, size: 23),
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: texte,
        ),
        // Fond clair : il faut des icônes système sombres, et l'inverse.
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
              ),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: filet),
        ),
      ),

      // Champs remplis d'une teinte plutôt que cernés d'un trait : à la
      // saisie d'une facture, l'œil suit la ligne du montant, pas le cadre.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: teinte,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        prefixIconColor: discret,
        suffixIconColor: discret,
        hintStyle: TextStyle(color: discret, fontSize: 14.5),
        labelStyle: TextStyle(color: discret, fontSize: 14.5),
        helperStyle: TextStyle(color: discret, fontSize: 11.5),
        floatingLabelStyle: TextStyle(color: primaire, fontSize: 14),
        border: bordure(Colors.transparent),
        enabledBorder: bordure(Colors.transparent),
        focusedBorder: bordure(primaire, 1.6),
        errorBorder: bordure(AppColors.danger),
        focusedErrorBorder: bordure(AppColors.danger, 1.6),
        errorStyle: const TextStyle(color: AppColors.danger, fontSize: 11.5),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaire,
          foregroundColor: Colors.white,
          disabledBackgroundColor: discret.withValues(alpha: 0.25),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: formes,
          textStyle: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaire,
          minimumSize: const Size.fromHeight(52),
          // Contour teinté de la primaire, pas un filet neutre : sur le fond
          // clair, un bouton cerné de gris se confond avec un champ de
          // saisie.
          side: BorderSide(color: primaire.withValues(alpha: 0.35)),
          shape: formes,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaire,
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.brandAccent,
        foregroundColor: Colors.white,
        elevation: 2,
        highlightElevation: 2,
        extendedTextStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),

      // Filtres de liste : pleins et sans contour quand ils sont actifs,
      // discrets sinon. Un chip sélectionné doit se voir de loin.
      chipTheme: ChipThemeData(
        backgroundColor: teinte,
        selectedColor: primaire,
        checkmarkColor: Colors.white,
        showCheckmark: false,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        // Un `WidgetStateTextStyle` n'est **pas** honoré ici : la couleur se
        // perd et les libellés sortent en blanc, illisibles sur un chip non
        // coché. D'où deux styles figés — celui-ci pour l'état normal,
        // `secondaryLabelStyle` pour l'état coché.
        //
        // Attention : `secondaryLabelStyle` ne vaut que pour `ChoiceChip`.
        // `FilterChip` garde `labelStyle` même coché : là où il en faut un,
        // la couleur du libellé se passe au widget (voir la feuille
        // d'encaissement).
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: discret,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),

      dividerTheme: DividerThemeData(color: filet, thickness: 1, space: 1),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
        titleTextStyle: TextStyle(
          fontSize: 17.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: texte,
        ),
        contentTextStyle: TextStyle(fontSize: 14, height: 1.45, color: discret),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusLarge),
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.lightSurface : AppColors.lightText,
        contentTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.lightText : Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        iconColor: discret,
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: texte,
        ),
        subtitleTextStyle: TextStyle(fontSize: 12.5, color: discret),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaire,
        linearTrackColor: teinte,
        circularTrackColor: Colors.transparent,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? AppColors.brandAccent : null,
        ),
      ),

      drawerTheme: DrawerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        // Aucun arrondi : le tiroir occupe la pleine hauteur, bord à bord.
        // Son bouton, lui, est à droite de la barre de titre — voir les
        // écrans.
        shape: const RoundedRectangleBorder(),
      ),
    );
  }

  /// Une seule échelle typographique pour toute l'app : trois tailles de
  /// titre, deux de texte, une de mention. Les interlignes serrés
  /// (`letterSpacing` négatif) donnent des titres nets sur petit écran.
  static TextTheme _typographie(Color texte, Color discret) {
    return TextTheme(
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: texte,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: texte,
      ),
      titleMedium: TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: texte,
      ),
      titleSmall: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: texte,
      ),
      bodyLarge: TextStyle(fontSize: 15, height: 1.35, color: texte),
      bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: texte),
      bodySmall: TextStyle(fontSize: 12.5, height: 1.35, color: discret),
      labelLarge: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: texte,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: discret,
      ),
      labelSmall: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: discret,
      ),
    );
  }
}
