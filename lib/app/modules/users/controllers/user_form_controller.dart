import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../core/services/user_creation_service.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/user_role.dart';
import '../../../data/repositories/user_repository.dart';
import '../users_args.dart';

/// Création et modification d'un compte utilisateur.
///
/// En création, deux écritures sont nécessaires : le compte Firebase Auth
/// (via [UserCreationService], sur une instance secondaire pour ne pas
/// déconnecter l'appelant) puis le document `users/{uid}`. Les deux ne sont
/// pas atomiques — voir [_creer] pour le traitement de l'échec intermédiaire.
class UserFormController extends GetxController {
  final UserRepository _repo = UserRepository();
  final UserCreationService _creation = UserCreationService();

  final formKey = GlobalKey<FormState>();

  final nomCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final telephoneCtrl = TextEditingController();
  final motDePasseCtrl = TextEditingController();

  final role = UserRole.vendeur.obs;
  final motDePasseVisible = false.obs;
  final enregistrement = false.obs;
  final erreur = RxnString();

  late final UserFormArgs _args;

  bool get estEdition => _args.estEdition;
  bool get roleModifiable => !_args.forcerAdmin;
  String get titre => estEdition ? 'Modifier l\'utilisateur' : 'Nouvel utilisateur';

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    _args = arg is UserFormArgs
        ? arg
        : UserFormArgs(tenantId: SessionController.to.requireTenantId);

    final u = _args.user;
    if (u != null) {
      nomCtrl.text = u.nom;
      emailCtrl.text = u.email;
      telephoneCtrl.text = u.telephone ?? '';
      role.value = u.role;
    } else if (_args.forcerAdmin) {
      role.value = UserRole.admin;
    } else {
      motDePasseCtrl.text = UserCreationService.genererMotDePasse();
    }
  }

  @override
  void onClose() {
    nomCtrl.dispose();
    emailCtrl.dispose();
    telephoneCtrl.dispose();
    motDePasseCtrl.dispose();
    super.onClose();
  }

  String? validerNom(String? v) => Validators.requis(v, champ: 'Le nom');
  String? validerEmail(String? v) => Validators.email(v);

  String? validerMotDePasse(String? v) =>
      estEdition ? null : Validators.motDePasse(v);

  void regenererMotDePasse() {
    motDePasseCtrl.text = UserCreationService.genererMotDePasse();
    motDePasseVisible.value = true;
  }

  Future<void> enregistrer() async {
    erreur.value = null;
    if (!(formKey.currentState?.validate() ?? false)) return;

    enregistrement.value = true;
    try {
      if (estEdition) {
        await _modifier();
      } else {
        await _creer();
      }
    } on CreationCompteException catch (e) {
      erreur.value = e.message;
    } catch (e) {
      erreur.value = 'Enregistrement impossible : $e';
    } finally {
      enregistrement.value = false;
    }
  }

  Future<void> _creer() async {
    final uid = await _creation.creerCompte(
      email: emailCtrl.text,
      motDePasse: motDePasseCtrl.text,
    );

    try {
      await _repo.createProfile(
        UserModel(
          id: uid,
          nom: nomCtrl.text.trim(),
          email: emailCtrl.text.trim(),
          telephone: _telephoneOuNull,
          role: role.value,
          tenantId: _args.tenantId,
          active: true,
        ),
      );
    } catch (e) {
      // Le compte Auth existe mais son profil n'a pas pu être écrit : sans
      // document `users/{uid}`, la connexion sera refusée par
      // SessionController. On le dit explicitement plutôt que de laisser un
      // compte fantôme dont personne ne comprendra le comportement.
      throw CreationCompteException(
        'Le compte de connexion a été créé mais son profil n\'a pas pu être '
        'enregistré ($e). Reprenez la création avec le même email : '
        'contactez le support si l\'email est signalé comme déjà utilisé.',
      );
    }

    Get.back();
    Get.snackbar(
      'Utilisateur créé',
      '${nomCtrl.text.trim()} peut se connecter avec ${emailCtrl.text.trim()} '
          'et le mot de passe que vous lui communiquez.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 6),
    );
  }

  Future<void> _modifier() async {
    final u = _args.user!;

    // Rétrograder le dernier administrateur actif laisserait l'entreprise
    // sans personne pour gérer ses référentiels et ses annulations.
    if (u.role.isAdmin && role.value != UserRole.admin && u.active) {
      final reste =
          await _repo.resteUnAutreAdminActif(_args.tenantId, saufUid: u.id);
      if (!reste) {
        erreur.value =
            'C\'est le dernier administrateur actif de l\'entreprise. '
            'Nommez-en un autre avant de changer son rôle.';
        return;
      }
    }

    // Construction explicite plutôt que copyWith : ce dernier retombe sur
    // l'ancienne valeur quand on lui passe null, ce qui rendrait impossible
    // d'effacer un numéro de téléphone déjà saisi.
    await _repo.update(
      UserModel(
        id: u.id,
        nom: nomCtrl.text.trim(),
        email: u.email,
        telephone: _telephoneOuNull,
        role: role.value,
        tenantId: u.tenantId,
        active: u.active,
        createdAt: u.createdAt,
      ),
    );

    Get.back();
    Get.snackbar(
      'Enregistré',
      'Le compte de ${nomCtrl.text.trim()} a été mis à jour.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  String? get _telephoneOuNull {
    final t = telephoneCtrl.text.trim();
    return t.isEmpty ? null : t;
  }
}
