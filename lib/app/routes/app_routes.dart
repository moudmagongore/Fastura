/// Noms de routes. `part`-agnostique : cette classe est importée aussi bien
/// par les guards que par les vues, elle ne doit dépendre de rien.
abstract class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const motDePasseOublie = '/mot-de-passe-oublie';

  // ---- Super-administrateur (plateforme) ----
  static const superAdminTenants = '/super-admin/entreprises';
  static const superAdminTenantForm = '/super-admin/entreprises/form';
  static const superAdminTenantUsers = '/super-admin/entreprises/utilisateurs';
  static const superAdminTenantUserForm =
      '/super-admin/entreprises/utilisateurs/form';

  // ---- Administrateur (tenant) ----
  static const adminHome = '/admin/accueil';
  static const users = '/admin/utilisateurs';
  static const userForm = '/admin/utilisateurs/form';

  // ---- Vendeur (tenant) ----
  static const vendeurHome = '/vendeur/accueil';
}
