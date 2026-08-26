import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/session_controller.dart';
import '../../../core/utils/validators.dart';
import '../../../data/repositories/user_repository.dart';

/// Fiche personnelle du compte connecté.
///
/// Trois opérations bien séparées, et c'est voulu : le nom et le téléphone
/// s'écrivent dans Firestore, le mot de passe et l'adresse de connexion
/// appartiennent à Firebase Auth et exigent chacun le mot de passe courant.
/// Les mélanger dans un seul bouton « Enregistrer » obligerait à retaper son
/// mot de passe pour corriger une faute dans son nom.
///
/// Ce que l'utilisateur **ne** touche pas ici : son rôle, son entreprise et
/// son état actif. Ils appartiennent à l'administrateur, et `firestore.rules`
/// les refuse par ce chemin.
class ProfilController extends GetxController {
  final UserRepository _repo = UserRepository();

  final formIdentite = GlobalKey<FormState>();
  final formMotDePasse = GlobalKey<FormState>();
  final formEmail = GlobalKey<FormState>();

  final nomCtrl = TextEditingController();
  final telephoneCtrl = TextEditingController();

  final motDePasseActuelCtrl = TextEditingController();
  final nouveauMotDePasseCtrl = TextEditingController();
  final confirmationCtrl = TextEditingController();

  final nouvelEmailCtrl = TextEditingController();
  final motDePasseEmailCtrl = TextEditingController();

  final enregistrementIdentite = false.obs;
  final enregistrementMotDePasse = false.obs;
  final enregistrementEmail = false.obs;

  final erreurIdentite = RxnString();
  final erreurMotDePasse = RxnString();
  final erreurEmail = RxnString();

  /// Message d'attente affiché tant que le lien de vérification n'a pas été
  /// ouvert : sans lui, l'utilisateur croit son adresse déjà changée.
  final emailEnAttente = RxnString();

  @override
  void onInit() {
    super.onInit();
    final u = SessionController.to.user.value;
    nomCtrl.text = u?.nom ?? '';
    telephoneCtrl.text = u?.telephone ?? '';
  }

  @override
  void onClose() {
    nomCtrl.dispose();
    telephoneCtrl.dispose();
    motDePasseActuelCtrl.dispose();
    nouveauMotDePasseCtrl.dispose();
    confirmationCtrl.dispose();
    nouvelEmailCtrl.dispose();
    motDePasseEmailCtrl.dispose();
    super.onClose();
  }

  String get email => SessionController.to.user.value?.email ?? '';
  String get role => SessionController.to.user.value?.role.label ?? '';
  String get initiales => SessionController.to.user.value?.initiales ?? '';

  String? validerConfirmation(String? v) {
    if (v != nouveauMotDePasseCtrl.text) {
      return 'Les deux saisies diffèrent.';
    }
    return Validators.motDePasse(v);
  }

  Future<void> enregistrerIdentite() async {
    erreurIdentite.value = null;
    if (!(formIdentite.currentState?.validate() ?? false)) return;

    final uid = SessionController.to.user.value?.id;
    if (uid == null) return;

    enregistrementIdentite.value = true;
    try {
      final telephone = telephoneCtrl.text.trim();
      await _repo.updateProfilPersonnel(
        uid,
        nom: nomCtrl.text.trim(),
        telephone: telephone.isEmpty ? null : telephone,
      );
      // Pas de rafraîchissement à faire : `SessionController` suit le
      // document en stream, l'écran se remet à jour tout seul.
      Get.snackbar(
        'Profil mis à jour',
        'Vos informations ont été enregistrées.',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      erreurIdentite.value = 'Enregistrement impossible : $e';
    } finally {
      enregistrementIdentite.value = false;
    }
  }

  Future<void> changerMotDePasse() async {
    erreurMotDePasse.value = null;
    if (!(formMotDePasse.currentState?.validate() ?? false)) return;

    enregistrementMotDePasse.value = true;
    try {
      await AuthService.to.changerMotDePasse(
        actuel: motDePasseActuelCtrl.text,
        nouveau: nouveauMotDePasseCtrl.text,
      );
      motDePasseActuelCtrl.clear();
      nouveauMotDePasseCtrl.clear();
      confirmationCtrl.clear();
      Get.snackbar(
        'Mot de passe changé',
        'Utilisez le nouveau mot de passe à la prochaine connexion.',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      erreurMotDePasse.value = AuthService.messageErreur(e);
    } finally {
      enregistrementMotDePasse.value = false;
    }
  }

  Future<void> changerEmail() async {
    erreurEmail.value = null;
    if (!(formEmail.currentState?.validate() ?? false)) return;

    final nouveau = nouvelEmailCtrl.text.trim();
    if (nouveau.toLowerCase() == email.toLowerCase()) {
      erreurEmail.value = 'C\'est déjà votre adresse actuelle.';
      return;
    }

    enregistrementEmail.value = true;
    try {
      await AuthService.to.demanderChangementEmail(
        nouvelEmail: nouveau,
        motDePasse: motDePasseEmailCtrl.text,
      );
      motDePasseEmailCtrl.clear();
      nouvelEmailCtrl.clear();
      emailEnAttente.value = nouveau;
    } catch (e) {
      erreurEmail.value = AuthService.messageErreur(e);
    } finally {
      enregistrementEmail.value = false;
    }
  }
}
