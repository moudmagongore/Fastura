import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/user_repository.dart';
import '../users_args.dart';
import '../widgets/selecteur_admin.dart';

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
  /// l'administrateur initial, affecte les administrateurs existants, mais
  /// ne gère pas les vendeurs au quotidien.
  bool get vueSuperAdmin => nomTenant != null;

  /// Le compte est ici par affectation du super-administrateur : sa
  /// boutique d'origine est ailleurs.
  bool estAffecte(UserModel u) => u.tenantId != tenantId;

  /// Un compte qui sert plusieurs boutiques n'appartient plus à l'une
  /// d'elles : l'administrateur de celle-ci ne peut ni le modifier ni le
  /// désactiver — il fermerait la porte de la boutique voisine. Les rules
  /// Firestore posent la même limite, celle-ci n'est que l'explication.
  bool peutModifier(UserModel u) =>
      SessionController.to.isSuperAdmin || !u.estMultiBoutique;

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
    if (!peutModifier(u)) {
      _erreur(
        '${u.nom} administre ${u.tenantIds.length} boutiques. Le désactiver '
        'ici le déconnecterait des autres : seul le super-administrateur '
        'peut le faire.',
      );
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

  /// Affecte un administrateur déjà en poste ailleurs à cette boutique.
  ///
  /// Le compte n'est ni dupliqué ni recréé : il gagne une boutique de plus,
  /// entre lesquelles il basculera depuis son tiroir. Un même
  /// administrateur qui ouvre une seconde boutique garde ainsi un seul
  /// identifiant et un seul mot de passe.
  Future<void> affecterAdminExistant() async {
    final choisi = await choisirAdminExistant(
      tenantId: tenantId,
      nomBoutique: nomTenant ?? 'cette boutique',
    );
    if (choisi == null) return;

    final ok = await confirmer(
      titre: 'Affecter ${choisi.nom}',
      message:
          '${choisi.nom} pourra administrer ${nomTenant ?? 'cette boutique'} '
          'avec son compte actuel (${choisi.email}), en plus de '
          '${choisi.tenantIds.length == 1 ? 'sa boutique' : 'ses '
                    '${choisi.tenantIds.length} boutiques'}. '
          'Il basculera de l\'une à l\'autre depuis son menu.',
      libelleConfirmer: 'Affecter',
    );
    if (!ok) return;

    try {
      await _repo.affecterTenant(choisi.id, tenantId);
      Get.snackbar(
        'Administrateur affecté',
        '${choisi.nom} administre maintenant '
            '${nomTenant ?? 'cette boutique'}.',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      _erreur('Affectation impossible : $e');
    }
  }

  /// Retire l'affectation. Le compte reste entier dans sa boutique
  /// d'origine — c'est un rattachement qu'on défait, pas un compte qu'on
  /// supprime.
  Future<void> retirerAffectation(UserModel u) async {
    final ok = await confirmer(
      titre: 'Retirer ${u.nom}',
      message:
          '${u.nom} n\'aura plus accès à ${nomTenant ?? 'cette boutique'}. '
          'Son compte et sa boutique d\'origine ne changent pas, et les '
          'factures qu\'il a émises ici restent dans l\'historique.',
      libelleConfirmer: 'Retirer',
      destructif: true,
    );
    if (!ok) return;

    try {
      await _repo.retirerTenant(u.id, tenantId);
      Get.snackbar(
        'Affectation retirée',
        '${u.nom} n\'administre plus cette boutique.',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      _erreur('Retrait impossible : $e');
    }
  }

  void _erreur(String message) {
    Get.snackbar(
      'Action impossible',
      message,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 5),
    );
  }
}
