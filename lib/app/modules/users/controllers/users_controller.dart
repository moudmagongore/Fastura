import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/user_repository.dart';
import '../users_args.dart';

/// Liste des utilisateurs d'un tenant.
///
/// Utilisée par l'administrateur pour son propre tenant, et par le
/// super-administrateur pour l'entreprise qu'il consulte.
class UsersController extends GetxController {
  final UserRepository _repo = UserRepository();

  final utilisateurs = <UserModel>[].obs;
  final chargement = true.obs;
  final recherche = ''.obs;
  final masquerInactifs = false.obs;

  late final String tenantId;

  /// Renseigné seulement en consultation super-admin, pour afficher le nom
  /// de l'entreprise dans l'AppBar.
  String? nomTenant;

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    if (arg is UsersArgs) {
      tenantId = arg.tenant.id;
      nomTenant = arg.tenant.nom;
    } else {
      tenantId = SessionController.to.requireTenantId;
    }

    utilisateurs.bindStream(
      _repo.watchByTenant(tenantId).map((liste) {
        chargement.value = false;
        return liste;
      }),
    );
  }

  /// Vrai quand l'écran est ouvert par le super-administrateur : il crée
  /// l'administrateur initial mais ne gère pas les vendeurs au quotidien.
  bool get vueSuperAdmin => nomTenant != null;

  List<UserModel> get resultats {
    final q = recherche.value.trim().toLowerCase();
    return utilisateurs.where((u) {
      if (masquerInactifs.value && !u.active) return false;
      if (q.isEmpty) return true;
      return u.nom.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          (u.telephone ?? '').contains(q);
    }).toList();
  }

  int get nbActifs => utilisateurs.where((u) => u.active).length;

  bool estMoi(UserModel u) => u.id == SessionController.to.user.value?.id;

  /// Active ou désactive un compte, avec deux garde-fous : on ne se
  /// désactive pas soi-même, et on ne retire pas le dernier administrateur
  /// actif — le tenant n'aurait plus personne pour gérer ses référentiels.
  Future<void> basculerActivation(UserModel u) async {
    if (estMoi(u)) {
      _erreur('Vous ne pouvez pas désactiver votre propre compte.');
      return;
    }

    final desactivation = u.active;
    if (desactivation && u.role.isAdmin) {
      final reste = await _repo.resteUnAutreAdminActif(tenantId, saufUid: u.id);
      if (!reste) {
        _erreur(
          'C\'est le dernier administrateur actif de l\'entreprise. '
          'Nommez-en un autre avant de désactiver celui-ci.',
        );
        return;
      }
    }

    final ok = await confirmer(
      titre: desactivation ? 'Désactiver le compte' : 'Réactiver le compte',
      message: desactivation
          ? '${u.nom} ne pourra plus se connecter. Les factures, paiements '
              'et dépenses qu\'il a enregistrés restent dans l\'historique.'
          : '${u.nom} pourra à nouveau se connecter.',
      libelleConfirmer: desactivation ? 'Désactiver' : 'Réactiver',
      destructif: desactivation,
    );
    if (!ok) return;

    try {
      await _repo.setActive(u.id, !u.active);
    } catch (e) {
      _erreur('Modification impossible : $e');
    }
  }

  void _erreur(String message) {
    Get.snackbar(
      'Action impossible',
      message,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 5),
    );
  }
}
