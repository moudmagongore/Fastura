import 'package:get/get.dart';

import '../modules/admin/home/views/admin_home_view.dart';
import '../modules/auth/bindings/auth_binding.dart';
import '../modules/auth/views/login_view.dart';
import '../modules/auth/views/mot_de_passe_oublie_view.dart';
import '../modules/splash/bindings/splash_binding.dart';
import '../modules/splash/views/splash_view.dart';
import '../modules/super_admin/tenants/bindings/tenants_binding.dart';
import '../modules/super_admin/tenants/views/tenant_form_view.dart';
import '../modules/super_admin/tenants/views/tenants_list_view.dart';
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

    // ---- Administrateur ----
    GetPage(
      name: AppRoutes.adminHome,
      page: () => const AdminHomeView(),
      middlewares: [AdminGuard()],
    ),

    // ---- Vendeur (et administrateur tenant la caisse) ----
    GetPage(
      name: AppRoutes.vendeurHome,
      page: () => const VendeurHomeView(),
      middlewares: [TenantGuard()],
    ),
  ];
}
