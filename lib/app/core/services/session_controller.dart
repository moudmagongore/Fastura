import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:get/get.dart';

import '../../data/models/format_impression.dart';
import '../../data/models/tenant_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/user_role.dart';
import '../../data/repositories/tenant_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../routes/app_routes.dart';
import 'auth_service.dart';

/// Session de l'utilisateur connecté : son profil, son tenant, ses droits.
///
/// Contrôleur permanent, source de vérité unique pour :
///   • le `tenantId` que tout repository doit passer à ses queries ;
///   • les droits (annulation, référentiels) consommés par les vues et les
///     guards de routes ;
///   • les paramètres du tenant (devise, TVA, format d'impression).
///
/// Profil et tenant sont suivis en **stream** et non lus une fois : si
/// l'administrateur désactive un vendeur, ou si le super-admin désactive
/// l'entreprise, la session se ferme sans attendre la prochaine connexion.
class SessionController extends GetxController {
  static SessionController get to => Get.find();

  final UserRepository _userRepo = UserRepository();
  final TenantRepository _tenantRepo = TenantRepository();

  final Rxn<UserModel> user = Rxn<UserModel>();
  final Rxn<TenantModel> tenant = Rxn<TenantModel>();

  /// Faux tant que le premier chargement du profil n'a pas abouti — le
  /// splash attend ce drapeau avant de router.
  final isReady = false.obs;

  /// Renseigné quand la session est refusée (compte ou entreprise
  /// désactivé), pour affichage sur l'écran de connexion.
  final motifDeconnexion = RxnString();

  StreamSubscription<fb.User?>? _authSub;
  StreamSubscription<UserModel?>? _userSub;
  StreamSubscription<TenantModel?>? _tenantSub;

  @override
  void onInit() {
    super.onInit();
    _authSub = AuthService.to.authStateChanges.listen(_onAuthChanged);
  }

  @override
  void onClose() {
    _authSub?.cancel();
    _userSub?.cancel();
    _tenantSub?.cancel();
    super.onClose();
  }

  // ---------------------------------------------------------------- état

  bool get isLoggedIn => user.value != null;

  UserRole? get role => user.value?.role;

  bool get isSuperAdmin => role?.isSuperAdmin ?? false;
  bool get isAdmin => role?.isAdmin ?? false;
  bool get isVendeur => role?.isVendeur ?? false;

  /// Seul l'administrateur annule une facture, un paiement ou une dépense.
  bool get peutAnnuler => role?.peutAnnuler ?? false;

  /// Accès aux catégories, articles, natures de dépense, utilisateurs et
  /// paramètres du tenant.
  bool get peutGererReferentiels => role?.peutGererReferentiels ?? false;

  /// Identifiant du tenant courant. Nul pour le super-admin, qui n'opère
  /// sur aucune donnée métier.
  String? get tenantId => user.value?.tenantId;

  /// À utiliser dans les repositories qui exigent un tenant : lève plutôt
  /// que de laisser passer une query non scopée, qui remonterait les
  /// données d'une autre entreprise si les rules venaient à s'assouplir.
  String get requireTenantId {
    final id = tenantId;
    if (id == null || id.isEmpty) {
      throw StateError(
        'Aucun tenant sur la session courante (rôle ${role?.name}).',
      );
    }
    return id;
  }

  // ------------------------------------------------- paramètres du tenant

  String get devise => tenant.value?.devise ?? '';
  bool get tvaActive => tenant.value?.tvaActive ?? false;
  double get tauxTva => tvaActive ? (tenant.value?.tauxTva ?? 0) : 0;
  FormatImpression get formatImpression =>
      tenant.value?.formatImpression ?? FormatImpression.a4;

  /// Route d'accueil correspondant au rôle courant.
  String get routeAccueil {
    return switch (role) {
      UserRole.superAdmin => AppRoutes.superAdminTenants,
      UserRole.admin => AppRoutes.adminHome,
      UserRole.vendeur => AppRoutes.vendeurHome,
      null => AppRoutes.login,
    };
  }

  // ------------------------------------------------------------- cycle

  void _onAuthChanged(fb.User? account) {
    _userSub?.cancel();
    _tenantSub?.cancel();
    _userSub = null;
    _tenantSub = null;

    if (account == null) {
      user.value = null;
      tenant.value = null;
      isReady.value = true;
      return;
    }

    _userSub = _userRepo
        .watchById(account.uid)
        .listen(
          _onProfileChanged,
          onError: (_) {
            // Profil illisible (rules, réseau) : on ne laisse pas une session
            // à moitié chargée circuler dans l'app.
            _refuser('Profil inaccessible. Contactez votre administrateur.');
          },
        );
  }

  void _onProfileChanged(UserModel? profile) {
    if (profile == null) {
      _refuser('Aucun profil n\'est associé à ce compte.');
      return;
    }
    if (!profile.active) {
      _refuser('Votre compte a été désactivé.');
      return;
    }
    if (profile.role.appartientAUnTenant &&
        (profile.tenantId == null || profile.tenantId!.isEmpty)) {
      _refuser('Votre compte n\'est rattaché à aucune entreprise.');
      return;
    }

    user.value = profile;
    _recalerEmail(profile);

    if (!profile.role.appartientAUnTenant) {
      // Le super-admin n'a pas de tenant : la session est complète.
      tenant.value = null;
      isReady.value = true;
      return;
    }

    _ecouterTenant(profile.tenantId!);
  }

  /// Remet l'email du profil au niveau de celui du compte Auth.
  ///
  /// Un changement d'adresse ne prend effet qu'une fois le lien de
  /// vérification ouvert, souvent ailleurs et plus tard : le document
  /// Firestore ne l'apprend qu'ici, au chargement de session suivant. Sans
  /// ce recalage, l'écran de profil et la liste des utilisateurs
  /// afficheraient éternellement l'ancienne adresse.
  void _recalerEmail(UserModel profile) {
    final emailAuth = AuthService.to.currentUser?.email;
    if (emailAuth == null || emailAuth.isEmpty) return;
    if (emailAuth == profile.email) return;
    _userRepo.synchroniserEmail(profile.id, emailAuth).ignore();
  }

  void _ecouterTenant(String id) {
    if (tenant.value?.id == id && _tenantSub != null) return;
    _tenantSub?.cancel();
    _tenantSub = _tenantRepo.watchById(id).listen((t) {
      if (t == null) {
        _refuser('L\'entreprise associée à votre compte est introuvable.');
        return;
      }
      if (!t.active) {
        _refuser('L\'accès de votre entreprise a été suspendu.');
        return;
      }
      tenant.value = t;
      isReady.value = true;
    }, onError: (_) => _refuser('Paramètres de l\'entreprise inaccessibles.'));
  }

  /// Ferme la session en cours en conservant le motif à afficher sur le
  /// login. Utilisé pour tous les cas de refus (compte ou tenant désactivé).
  Future<void> _refuser(String motif) async {
    motifDeconnexion.value = motif;
    await signOut(silencieux: true);
  }

  Future<void> signOut({bool silencieux = false}) async {
    if (!silencieux) motifDeconnexion.value = null;
    _userSub?.cancel();
    _tenantSub?.cancel();
    _userSub = null;
    _tenantSub = null;
    user.value = null;
    tenant.value = null;
    isReady.value = true;
    await AuthService.to.signOut();
    if (Get.currentRoute != AppRoutes.login) {
      Get.offAllNamed(AppRoutes.login);
    }
  }

  /// Consomme le motif de refus : l'écran de connexion l'affiche une fois
  /// puis le vide, pour ne pas le re-montrer à la tentative suivante.
  String? consommerMotifDeconnexion() {
    final m = motifDeconnexion.value;
    motifDeconnexion.value = null;
    return m;
  }
}
