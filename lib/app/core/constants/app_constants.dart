/// Constantes globales de l'application (indépendantes du tenant).
///
/// Tout ce qui varie d'une entreprise à l'autre (devise, TVA, format
/// d'impression, logo, adresse) vit dans le document `tenants/{id}` et non
/// ici — voir [TenantModel]. Les valeurs ci-dessous ne servent que de
/// défaut à la création d'un tenant.
abstract class AppConstants {
  AppConstants._();

  static const String appName = 'Fastura';
  static const String defaultLocale = 'fr_FR';

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
