import 'package:get/get.dart';

import '../modules/apropos/views/apropos_view.dart';
import '../modules/profil/bindings/profil_binding.dart';
import '../modules/profil/views/profil_view.dart';
import '../modules/accueil/bindings/accueil_binding.dart';
import '../modules/admin/home/views/admin_home_view.dart';
import '../modules/articles/bindings/articles_binding.dart';
import '../modules/articles/views/article_form_view.dart';
import '../modules/articles/views/articles_list_view.dart';
import '../modules/articles/views/import_articles_view.dart';
import '../modules/auth/bindings/auth_binding.dart';
import '../modules/auth/views/login_view.dart';
import '../modules/auth/views/mot_de_passe_oublie_view.dart';
import '../modules/categories/bindings/categories_binding.dart';
import '../modules/categories/views/categorie_form_view.dart';
import '../modules/categories/views/categories_list_view.dart';
import '../modules/clients/bindings/clients_binding.dart';
import '../modules/clients/views/client_detail_view.dart';
import '../modules/clients/views/client_form_view.dart';
import '../modules/clients/views/clients_list_view.dart';
import '../modules/depenses/bindings/depenses_binding.dart';
import '../modules/depenses/views/depense_detail_view.dart';
import '../modules/depenses/views/depense_form_view.dart';
import '../modules/depenses/views/depenses_list_view.dart';
import '../modules/factures/bindings/factures_binding.dart';
import '../modules/factures/views/facture_detail_view.dart';
import '../modules/factures/views/facture_form_view.dart';
import '../modules/factures/views/factures_list_view.dart';
import '../modules/natures_depense/bindings/natures_depense_binding.dart';
import '../modules/natures_depense/views/nature_depense_form_view.dart';
import '../modules/natures_depense/views/natures_depense_list_view.dart';
import '../modules/paiements/bindings/paiements_binding.dart';
import '../modules/parametres/bindings/parametres_binding.dart';
import '../modules/parametres/views/parametres_view.dart';
import '../modules/paiements/views/paiement_detail_view.dart';
import '../modules/paiements/views/paiements_list_view.dart';
import '../modules/splash/bindings/splash_binding.dart';
import '../modules/splash/views/splash_view.dart';
import '../modules/super_admin/tenants/bindings/tenants_binding.dart';
import '../modules/super_admin/tenants/views/tenant_form_view.dart';
import '../modules/super_admin/tenants/views/tenants_list_view.dart';
import '../modules/users/bindings/users_binding.dart';
import '../modules/users/views/user_form_view.dart';
import '../modules/users/views/users_list_view.dart';
import '../modules/vendeur/home/views/vendeur_home_view.dart';
import 'app_routes.dart';
import 'route_guards.dart';

abstract class AppPages {
  AppPages._();

  static const initial = AppRoutes.splash;

  static final routes = <GetPage>[
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginView(),
      binding: LoginBinding(),
    ),
    GetPage(
      name: AppRoutes.motDePasseOublie,
      page: () => const MotDePasseOublieView(),
      binding: MotDePasseOublieBinding(),
    ),

    // ---- Super-administrateur ----
    GetPage(
      name: AppRoutes.superAdminTenants,
      page: () => const TenantsListView(),
      binding: TenantsBinding(),
      middlewares: [SuperAdminGuard()],
    ),
    GetPage(
      name: AppRoutes.superAdminTenantForm,
      page: () => const TenantFormView(),
      binding: TenantFormBinding(),
      middlewares: [SuperAdminGuard()],
    ),

    GetPage(
      name: AppRoutes.superAdminTenantUsers,
      page: () => const UsersListView(),
      binding: UsersBinding(),
      middlewares: [SuperAdminGuard()],
    ),
    GetPage(
      name: AppRoutes.superAdminTenantUserForm,
      page: () => const UserFormView(),
      binding: UserFormBinding(),
      middlewares: [SuperAdminGuard()],
    ),

    // ---- Administrateur ----
    GetPage(
      name: AppRoutes.adminHome,
      page: () => const AdminHomeView(),
      binding: AccueilBinding(),
      middlewares: [AdminGuard()],
    ),

    GetPage(
      name: AppRoutes.users,
      page: () => const UsersListView(),
      binding: UsersBinding(),
      middlewares: [AdminGuard()],
    ),
    GetPage(
      name: AppRoutes.userForm,
      page: () => const UserFormView(),
      binding: UserFormBinding(),
      middlewares: [AdminGuard()],
    ),

    // Référentiels : réservés à l'administrateur (CDC §1.3).
    GetPage(
      name: AppRoutes.categories,
      page: () => const CategoriesListView(),
      binding: CategoriesBinding(),
      middlewares: [AdminGuard()],
    ),
    GetPage(
      name: AppRoutes.categorieForm,
      page: () => const CategorieFormView(),
      binding: CategorieFormBinding(),
      middlewares: [AdminGuard()],
    ),
    GetPage(
      name: AppRoutes.articles,
      page: () => const ArticlesListView(),
      binding: ArticlesBinding(),
      middlewares: [AdminGuard()],
    ),
    GetPage(
      name: AppRoutes.articleForm,
      page: () => const ArticleFormView(),
      binding: ArticleFormBinding(),
      middlewares: [AdminGuard()],
    ),
    GetPage(
      name: AppRoutes.articlesImport,
      page: () => const ImportArticlesView(),
      binding: ImportArticlesBinding(),
      middlewares: [AdminGuard()],
    ),
    GetPage(
      name: AppRoutes.naturesDepense,
      page: () => const NaturesDepenseListView(),
      binding: NaturesDepenseBinding(),
      middlewares: [AdminGuard()],
    ),
    GetPage(
      name: AppRoutes.natureDepenseForm,
      page: () => const NatureDepenseFormView(),
      binding: NatureDepenseFormBinding(),
      middlewares: [AdminGuard()],
    ),
    GetPage(
      name: AppRoutes.parametres,
      page: () => const ParametresView(),
      binding: ParametresBinding(),
      middlewares: [AdminGuard()],
    ),

    // Fiche personnelle : ouverte à tous les comptes, super-admin compris —
    // chacun doit pouvoir corriger son nom ou changer son mot de passe.
    GetPage(
      name: AppRoutes.profil,
      page: () => const ProfilView(),
      binding: ProfilBinding(),
      middlewares: [AuthGuard()],
    ),

    // Écran de présentation : aucune donnée, aucun rôle requis au-delà de la
    // connexion.
    GetPage(
      name: AppRoutes.apropos,
      page: () => const AproposView(),
      middlewares: [AuthGuard()],
    ),

    // ---- Vendeur (et administrateur tenant la caisse) ----
    GetPage(
      name: AppRoutes.vendeurHome,
      page: () => const VendeurHomeView(),
      binding: AccueilBinding(),
      middlewares: [TenantGuard()],
    ),

    // Opérations courantes : ouvertes aux deux rôles du tenant (CDC §5).
    GetPage(
      name: AppRoutes.clients,
      page: () => const ClientsListView(),
      binding: ClientsBinding(),
      middlewares: [TenantGuard()],
    ),
    GetPage(
      name: AppRoutes.clientForm,
      page: () => const ClientFormView(),
      binding: ClientFormBinding(),
      middlewares: [TenantGuard()],
    ),
    GetPage(
      name: AppRoutes.clientDetail,
      page: () => const ClientDetailView(),
      binding: ClientDetailBinding(),
      middlewares: [TenantGuard()],
    ),
    GetPage(
      name: AppRoutes.factures,
      page: () => const FacturesListView(),
      binding: FacturesBinding(),
      middlewares: [TenantGuard()],
    ),
    GetPage(
      name: AppRoutes.factureForm,
      page: () => const FactureFormView(),
      binding: FactureFormBinding(),
      middlewares: [TenantGuard()],
    ),
    GetPage(
      name: AppRoutes.factureDetail,
      page: () => const FactureDetailView(),
      binding: FactureDetailBinding(),
      middlewares: [TenantGuard()],
    ),
    GetPage(
      name: AppRoutes.paiements,
      page: () => const PaiementsListView(),
      binding: PaiementsBinding(),
      middlewares: [TenantGuard()],
    ),
    GetPage(
      name: AppRoutes.paiementDetail,
      page: () => const PaiementDetailView(),
      binding: PaiementDetailBinding(),
      middlewares: [TenantGuard()],
    ),

    // Le vendeur enregistre une dépense mais n'annule pas et ne touche pas
    // à la nomenclature — le partage passe par les écrans, pas les routes.
    GetPage(
      name: AppRoutes.depenses,
      page: () => const DepensesListView(),
      binding: DepensesBinding(),
      middlewares: [TenantGuard()],
    ),
    GetPage(
      name: AppRoutes.depenseForm,
      page: () => const DepenseFormView(),
      binding: DepenseFormBinding(),
      middlewares: [TenantGuard()],
    ),
    GetPage(
      name: AppRoutes.depenseDetail,
      page: () => const DepenseDetailView(),
      binding: DepenseDetailBinding(),
      middlewares: [TenantGuard()],
    ),
  ];
}
