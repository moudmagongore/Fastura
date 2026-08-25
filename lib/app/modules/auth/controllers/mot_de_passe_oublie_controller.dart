import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/utils/validators.dart';

class MotDePasseOublieController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();

  final isLoading = false.obs;
  final erreur = RxnString();
  final envoye = false.obs;

  @override
  void onClose() {
    emailCtrl.dispose();
    super.onClose();
  }

  String? validerEmail(String? v) => Validators.email(v);

  Future<void> envoyer() async {
    erreur.value = null;
    if (!(formKey.currentState?.validate() ?? false)) return;

    isLoading.value = true;
    try {
      await AuthService.to.sendPasswordResetEmail(emailCtrl.text);
      // On confirme l'envoi même si l'adresse est inconnue : indiquer le
      // contraire révélerait quels comptes existent.
      envoye.value = true;
    } catch (e) {
      erreur.value = AuthService.messageErreur(e);
    } finally {
      isLoading.value = false;
    }
  }
}
