import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../data/models/format_impression.dart';
import '../../data/models/tenant_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/user_role.dart';
import '../../data/repositories/tenant_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../routes/app_routes.dart';
import 'auth_service.dart';

/// Session de l'utilisateur connecté : son profil, sa boutique, ses droits.
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
///
/// Un administrateur peut être affecté à plusieurs boutiques. La session
/// n'en sert qu'une à la fois — [tenantId] désigne la **boutique courante**,
/// que l'utilisateur change depuis le tiroir ([changerBoutique]).
class SessionController extends GetxController {
  static SessionController get to => Get.find();

  final UserRepository _userRepo = UserRepository();
  final TenantRepository _tenantRepo = TenantRepository();
  final GetStorage _box = GetStorage();

  final Rxn<UserModel> user = Rxn<UserModel>();
  final Rxn<TenantModel> tenant = Rxn<TenantModel>();

  /// Les boutiques du compte, dans l'ordre de `UserModel.tenantIds`.
  /// Alimentée seulement quand il y en a plus d'une : c'est le sélecteur du
  /// tiroir qui en a besoin, et lui seul.
  final boutiques = <TenantModel>[].obs;

  /// Faux tant que le premier chargement du profil n'a pas abouti — le
  /// splash attend ce drapeau avant de router.
  final isReady = false.obs;

  /// Renseigné quand la session est refusée (compte ou entreprise
  /// désactivé), pour affichage sur l'écran de connexion.
  final motifDeconnexion = RxnString();

  /// Boutique servie par la session. Toujours l'une de `user.tenantIds`.
  final _boutiqueCourante = RxnString();

  /// Boutiques écartées en cours de session (suspendues, ou disparues) : on
  /// n'y retombe pas au repli suivant, sinon la session ferait la navette
  /// entre deux boutiques fermées sans jamais s'arrêter.
  final _boutiquesEcartees = <String>{};

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

  /// Identifiant de la boutique courante. Nul pour le super-admin, qui
  /// n'opère sur aucune donnée métier.
  String? get tenantId => _boutiqueCourante.value;

  /// Vrai quand le compte sert plusieurs boutiques : le tiroir affiche
  /// alors le sélecteur.
  bool get multiBoutique => (user.value?.tenantIds.length ?? 0) > 1;

  /// À utiliser dans les repositories qui exigent un tenant : lève plutôt
  /// que de laisser passer une query non scopée, qui remonterait les
  /// données d'une autre entreprise si les rules venaient à s'assouplir.
  String get requireTenantId {
    final id = tenantId;
    if (id == null || id.isEmpty) {
      throw StateError(
        'Aucune boutique sur la session courante (rôle ${role?.name}).',
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
    _boutiquesEcartees.clear();

    if (account == null) {
      user.value = null;
      tenant.value = null;
      _boutiqueCourante.value = null;
      boutiques.clear();
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
    if (profile.role.appartientAUnTenant && profile.tenantIds.isEmpty) {
      _refuser('Votre compte n\'est rattaché à aucune entreprise.');
      return;
    }

    user.value = profile;
    _recalerEmail(profile);

    if (!profile.role.appartientAUnTenant) {
      // Le super-admin n'a pas de boutique : la session est complète.
      tenant.value = null;
      _boutiqueCourante.value = null;
      boutiques.clear();
      isReady.value = true;
      return;
    }

    _chargerBoutiques(profile);

    final courante = _choisirBoutique(profile);
    if (courante == null) {
      _refuser('Aucune de vos boutiques n\'est accessible.');
      return;
    }
    _boutiqueCourante.value = courante;
    _ecouterTenant(courante);
  }

  /// Boutique à servir : celle déjà ouverte si elle tient toujours, sinon la
  /// dernière choisie sur cet appareil, sinon la boutique d'origine.
  ///
  /// Le choix est mémorisé par compte : deux personnes qui se relaient sur
  /// le même téléphone ne se renvoient pas l'une l'autre dans leur boutique.
  String? _choisirBoutique(UserModel profile) {
    final candidates = profile.tenantIds
        .where((id) => !_boutiquesEcartees.contains(id))
        .toList();
    if (candidates.isEmpty) return null;

    final courante = _boutiqueCourante.value;
    if (courante != null && candidates.contains(courante)) return courante;

    final memorisee = _box.read<String>(_cleBoutique(profile.id));
    if (memorisee != null && candidates.contains(memorisee)) return memorisee;

    return candidates.first;
  }

  String _cleBoutique(String uid) => 'boutique_courante_$uid';

  /// Charge le nom des boutiques du compte, pour le sélecteur du tiroir.
  ///
  /// Lecture ponctuelle et non stream : c'est un libellé de menu. Les
  /// paramètres de la boutique **servie**, eux, restent suivis en continu
  /// par [_ecouterTenant].
  Future<void> _chargerBoutiques(UserModel profile) async {
    if (profile.tenantIds.length < 2) {
      boutiques.clear();
      return;
    }
    final dejaChargees = boutiques.map((t) => t.id).toList();
    if (dejaChargees.length == profile.tenantIds.length &&
        profile.tenantIds.every(dejaChargees.contains)) {
      return;
    }
    final chargees = await Future.wait(
      profile.tenantIds.map((id) => _tenantRepo.getById(id)),
    );
    boutiques.assignAll(chargees.whereType<TenantModel>());
  }

  /// Bascule la session sur une autre boutique du compte.
  ///
  /// Tous les contrôleurs de module ont des flux liés à l'ancienne boutique :
  /// on repart de l'accueil (`Get.offAllNamed`), ce qui les reconstruit tous
  /// sur la nouvelle. Rafraîchir en place obligerait chaque module à savoir
  /// se rebrancher, pour un geste qui reste rare.
  Future<void> changerBoutique(String id) async {
    final profile = user.value;
    if (profile == null || !profile.appartientA(id)) return;
    if (id == _boutiqueCourante.value) return;

    _boutiquesEcartees.remove(id);
    await _box.write(_cleBoutique(profile.id), id);

    // La boutique ne devient courante qu'une fois ses paramètres chargés :
    // facturer avec la devise de la boutique précédente inscrirait un
    // montant faux sur une pièce comptable.
    tenant.value = null;
    isReady.value = false;
    _boutiqueCourante.value = id;
    _ecouterTenant(id);

    Get.offAllNamed(routeAccueil);
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
        _ecarterBoutique(
          id,
          'L\'entreprise associée à votre compte est introuvable.',
        );
        return;
      }
      if (!t.active) {
        _ecarterBoutique(id, 'L\'accès de votre entreprise a été suspendu.');
        return;
      }
      tenant.value = t;
      isReady.value = true;
    }, onError: (_) => _refuser('Paramètres de l\'entreprise inaccessibles.'));
  }

  /// Boutique courante devenue inaccessible : on se replie sur une autre du
  /// compte s'il en reste une, sinon la session se ferme.
  ///
  /// Un administrateur de trois boutiques ne doit pas se retrouver dehors
  /// parce que l'une d'elles a été suspendue.
  void _ecarterBoutique(String id, String motif) {
    _boutiquesEcartees.add(id);
    _tenantSub?.cancel();
    _tenantSub = null;
    tenant.value = null;

    final profile = user.value;
    final repli = profile == null ? null : _choisirBoutique(profile);
    if (repli == null) {
      _refuser(motif);
      return;
    }

    _boutiqueCourante.value = repli;
    _ecouterTenant(repli);
    Get.snackbar(
      'Boutique indisponible',
      '$motif Vous travaillez maintenant sur une autre de vos boutiques.',
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 5),
    );
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
    _boutiqueCourante.value = null;
    boutiques.clear();
    _boutiquesEcartees.clear();
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
