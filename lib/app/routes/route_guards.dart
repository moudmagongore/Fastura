import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../core/services/session_controller.dart';
import 'app_routes.dart';

/// Exige une session ouverte. Un visiteur non authentifié part au login.
class AuthGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (!SessionController.to.isLoggedIn) {
      return const RouteSettings(name: AppRoutes.login);
    }
    return null;
  }
}

/// Réserve la route au super-administrateur (gestion des entreprises).
/// Un utilisateur de tenant est renvoyé vers son propre accueil.
class SuperAdminGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final session = SessionController.to;
    if (!session.isLoggedIn) {
      return const RouteSettings(name: AppRoutes.login);
    }
    if (session.isSuperAdmin) return null;
    return RouteSettings(name: session.routeAccueil);
  }
}

/// Réserve la route à l'administrateur d'un tenant : référentiels,
/// utilisateurs, paramètres, annulations. Un vendeur est renvoyé chez lui.
///
/// Le guard protège la navigation ; il ne remplace pas les `firestore.rules`,
/// qui restent la seule barrière que le client ne peut pas contourner.
class AdminGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final session = SessionController.to;
    if (!session.isLoggedIn) {
      return const RouteSettings(name: AppRoutes.login);
    }
    if (session.isAdmin) return null;
    return RouteSettings(name: session.routeAccueil);
  }
}

/// Routes de saisie courante : ouvertes à l'administrateur comme au
/// vendeur, fermées au super-administrateur qui n'a aucun accès métier.
class TenantGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final session = SessionController.to;
    if (!session.isLoggedIn) {
      return const RouteSettings(name: AppRoutes.login);
    }
    if (session.isSuperAdmin) {
      return const RouteSettings(name: AppRoutes.superAdminTenants);
    }
    return null;
  }
}
