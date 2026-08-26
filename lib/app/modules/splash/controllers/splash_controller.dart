import 'dart:async';

import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../routes/app_routes.dart';

/// Attend que la session soit résolue (profil + tenant chargés, ou absence
/// de session) puis route vers l'accueil du rôle.
class SplashController extends GetxController {
  static const _dureeMinimale = Duration(milliseconds: 1200);

  /// Au-delà, on part sur le login plutôt que de laisser l'utilisateur
  /// devant un loader sans fin. Fastura étant 100 % en ligne, une session
  /// qui ne se résout pas signifie réseau absent ou backend injoignable :
  /// l'écran de connexion est l'endroit où le dire.
  static const _delaiMax = Duration(seconds: 12);

  @override
  void onReady() {
    super.onReady();
    _router();
  }

  Future<void> _router() async {
    final session = SessionController.to;

    // Laisse le logo à l'écran le temps minimal, sans jamais bloquer si la
    // session met plus longtemps à se résoudre.
    final attenteMinimale = Future<void>.delayed(_dureeMinimale);

    if (!session.isReady.value) {
      try {
        await session.isReady.stream
            .firstWhere((ready) => ready)
            .timeout(_delaiMax);
      } on TimeoutException {
        Get.offAllNamed(AppRoutes.login);
        return;
      }
    }
    await attenteMinimale;

    Get.offAllNamed(
      session.isLoggedIn ? session.routeAccueil : AppRoutes.login,
    );
  }
}
