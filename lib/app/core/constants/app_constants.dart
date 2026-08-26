import 'dart:ui' show Locale;

/// Constantes globales de l'application (indépendantes du tenant).
///
/// Tout ce qui varie d'une entreprise à l'autre (devise, TVA, format
/// d'impression, logo, adresse) vit dans le document `tenants/{id}` et non
/// ici — voir [TenantModel]. Les valeurs ci-dessous ne servent que de
/// défaut à la création d'un tenant.
abstract class AppConstants {
  AppConstants._();

  static const String appName = 'Fastura';

  /// Coordonnées de l'éditeur, affichées sur l'écran « À propos » et en pied
  /// des reçus. Une seule source : elles se recopiaient sinon dans un écran
  /// et dans un PDF, qui divergeraient au premier changement de numéro.
  static const String contactEmail = 'fasturapp@gmail.com';
  static const List<String> contactTelephones = [
    '+224 621 78 56 45',
    '+224 623 28 59 87',
  ];

  /// Résumé affiché en tête de l'écran « À propos ».
  static const String appDescription =
      'Fastura tient la facturation d\'une entreprise, du devis remis au '
      'comptoir jusqu\'au suivi des créances.';

  /// Locale unique de l'application, sous les deux formes attendues :
  /// la chaîne pour `intl` (formats de date et de nombre), le [Locale]
  /// pour le framework (libellés des calendriers et des dialogues).
  static const String defaultLocale = 'fr_FR';
  static const Locale locale = Locale('fr', 'FR');

  /// Devise proposée par défaut à la création d'un tenant (modifiable).
  static const String defaultDevise = 'GNF';

  /// Taux de TVA proposé par défaut (en %). La TVA est désactivée par
  /// défaut : une entreprise non assujettie ne doit rien avoir à décocher.
  static const double defaultTauxTva = 18.0;

  static const String defaultPhoneCountryCode = '+224';

  /// Nom du client générique créé à l'ouverture de chaque tenant, qui
  /// permet de facturer une vente comptant sans créer de fiche dédiée.
  static const String clientDiversNom = 'Client divers';
}
