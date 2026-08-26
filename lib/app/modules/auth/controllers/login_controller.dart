import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/session_controller.dart';
import '../../../core/utils/validators.dart';

class LoginController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  final isLoading = false.obs;
  final motDePasseVisible = false.obs;
  final erreur = RxnString();

  @override
  void onInit() {
    super.onInit();
    // Motif d'une éventuelle déconnexion forcée (compte ou entreprise
    // désactivé), affiché une seule fois.
    erreur.value = SessionController.to.consommerMotifDeconnexion();
  }

  @override
  void onClose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.onClose();
  }

  String? validerEmail(String? v) => Validators.email(v);
  String? validerMotDePasse(String? v) => Validators.motDePasse(v);

  Future<void> seConnecter() async {
    erreur.value = null;
    if (!(formKey.currentState?.validate() ?? false)) return;

    isLoading.value = true;
    try {
      await AuthService.to.signIn(
        email: emailCtrl.text,
        password: passwordCtrl.text,
      );

      final session = SessionController.to;
      // `signIn` ne fait qu'ouvrir la session Auth : le profil et le tenant
      // arrivent par les streams de SessionController. On attend qu'ils
      // soient résolus avant de router, sinon le guard renverrait au login.
      session.isReady.value = false;
      await session.isReady.stream.firstWhere((ready) => ready);

      if (!session.isLoggedIn) {
        // Session refusée (compte inactif, entreprise suspendue) : le motif
        // a été posé par SessionController.
        erreur.value =
            session.consommerMotifDeconnexion() ??
            'Connexion refusée. Contactez votre administrateur.';
        return;
      }

      passwordCtrl.clear();
      Get.offAllNamed(session.routeAccueil);
    } catch (e) {
      erreur.value = AuthService.messageErreur(e);
    } finally {
      isLoading.value = false;
    }
  }
}
