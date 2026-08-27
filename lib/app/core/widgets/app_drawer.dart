import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../data/models/user_role.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_controller.dart';
import '../constants/app_constants.dart';
import '../services/session_controller.dart';
import 'confirm_dialog.dart';
import 'drawer_open_guard.dart';
import 'selecteur_boutique.dart';

/// Entrée de menu. [route] nulle = module pas encore développé : l'entrée
/// reste visible mais grisée, pour donner la carte des modules à venir sans
/// laisser croire qu'ils sont livrés.
class _Entree {
  const _Entree(this.libelle, this.icone, {this.route});

  final String libelle;
  final IconData icone;
  final String? route;

  bool get disponible => route != null;
}

/// Menu latéral, construit à partir du rôle de la session courante.
///
/// Le super-administrateur n'a aucune entrée métier : il ne voit que les
/// entreprises, conformément au cloisonnement du cahier des charges.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  static List<_Entree> _entreesPour(UserRole role) {
    return switch (role) {
      UserRole.superAdmin => const [
        _Entree(
          'Entreprises',
          Icons.apartment_outlined,
          route: AppRoutes.superAdminTenants,
        ),
        _Entree('Mon profil', Icons.badge_outlined, route: AppRoutes.profil),
        _Entree('À propos', Icons.info_outline, route: AppRoutes.apropos),
      ],
      UserRole.admin => const [
        _Entree('Accueil', Icons.home_outlined, route: AppRoutes.adminHome),
        _Entree(
          'Facturation',
          Icons.receipt_long_outlined,
          route: AppRoutes.factures,
        ),
        _Entree(
          'Paiements',
          Icons.payments_outlined,
          route: AppRoutes.paiements,
        ),
        _Entree('Clients', Icons.people_outline, route: AppRoutes.clients),
        _Entree(
          'Articles',
          Icons.inventory_2_outlined,
          route: AppRoutes.articles,
        ),
        _Entree(
          'Catégories',
          Icons.category_outlined,
          route: AppRoutes.categories,
        ),
        _Entree('Dépenses', Icons.trending_down, route: AppRoutes.depenses),
        _Entree(
          'Natures de dépense',
          Icons.label_outline,
          route: AppRoutes.naturesDepense,
        ),
        _Entree(
          'Utilisateurs',
          Icons.manage_accounts_outlined,
          route: AppRoutes.users,
        ),
        _Entree('Mon profil', Icons.badge_outlined, route: AppRoutes.profil),
        _Entree(
          'Paramètres',
          Icons.settings_outlined,
          route: AppRoutes.parametres,
        ),
        // « À propos » ferme la marche dans les trois rôles : c'est la
        // dernière chose qu'on cherche, et elle ne se cherche qu'une fois.
        _Entree('À propos', Icons.info_outline, route: AppRoutes.apropos),
      ],
      UserRole.vendeur => const [
        _Entree('Accueil', Icons.home_outlined, route: AppRoutes.vendeurHome),
        _Entree(
          'Facturation',
          Icons.receipt_long_outlined,
          route: AppRoutes.factures,
        ),
        _Entree(
          'Paiements',
          Icons.payments_outlined,
          route: AppRoutes.paiements,
        ),
        _Entree('Clients', Icons.people_outline, route: AppRoutes.clients),
        _Entree('Dépenses', Icons.trending_down, route: AppRoutes.depenses),
        _Entree('Mon profil', Icons.badge_outlined, route: AppRoutes.profil),
        _Entree('À propos', Icons.info_outline, route: AppRoutes.apropos),
      ],
    };
  }

  /// Ouvre une destination du tiroir.
  ///
  /// `Get.offNamed` **remplace** l'écran courant, comme dans gongore_App :
  ///   • la page arrive toujours du même côté, en avant — repartir vers
  ///     l'accueil par un `pop` la faisait glisser à l'envers, et le tiroir
  ///     encore ouvert partait vers la droite avec l'écran sortant avant de
  ///     se refermer vers la gauche ;
  ///   • la pile ne grossit pas et ne contient jamais deux fois le même
  ///     écran. C'est ce doublon qui donnait deux instances d'un même
  ///     contrôleur GetX, donc deux fois la même `GlobalKey` de formulaire —
  ///     que Flutter refuse (« Duplicate GlobalKey »).
  ///
  /// Rien à attendre avant de naviguer : le tiroir se referme par-dessus une
  /// page qui ne recule pas.
  static void _ouvrir(String route, String routeCourante) {
    HapticFeedback.selectionClick();
    Get.back(); // le tiroir n'est qu'une entrée d'historique de la route
    if (route == routeCourante) return;
    Get.offNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionController.to;

    return Drawer(
      // `top: false` : l'en-tête doit filer jusque sous la barre d'état,
      // sinon un bandeau blanc la sépare du haut de l'écran. C'est
      // l'en-tête qui reprend l'encoche à son compte, dans son padding.
      child: SafeArea(
        top: false,
        // Le garde ignore les appuis tant que le tiroir n'a pas fini de
        // s'ouvrir : sans lui, un appui pendant le glissement atterrit sur
        // une entrée que personne n'a visée.
        child: DrawerOpenGuard(
          child: Obx(() {
            final user = session.user.value;
            if (user == null) return const SizedBox.shrink();

            final entrees = _entreesPour(user.role);
            final routeCourante = Get.currentRoute;

            return Column(
              children: [
                _Entete(
                  nom: user.nom,
                  initiales: user.initiales,
                  sousTitre: user.role.isSuperAdmin
                      ? AppConstants.appName
                      : (session.tenant.value?.nom ?? '—'),
                  role: user.role.label,
                  // Le compte sert plusieurs boutiques : la ligne devient le
                  // sélecteur. C'est le seul endroit où la boutique servie est
                  // toujours affichée — la changer se décide en la voyant.
                  // La feuille s'ouvre **par-dessus** le tiroir, sans le
                  // refermer : annuler ramène là d'où l'on vient, et le
                  // changement de boutique repart de toute façon de l'accueil.
                  onChangerBoutique: session.multiBoutique
                      ? () {
                          HapticFeedback.selectionClick();
                          ouvrirSelecteurBoutique();
                        }
                      : null,
                ),
                Expanded(
                  child: ListView(
                    // Aucune marge verticale : elle laissait huit pixels de
                    // vide au-dessus de la première entrée, que la teinte de
                    // l'écran courant ne pouvait pas couvrir. Les entrées se
                    // touchent, du bas de l'en-tête au séparateur.
                    padding: EdgeInsets.zero,
                    // Sans rebond : l'élan iOS découvrait le fond du tiroir
                    // au-dessus de l'en-tête de marque.
                    physics: const ClampingScrollPhysics(),
                    children: [
                      for (final e in entrees)
                        _TuileMenu(
                          entree: e,
                          actif: routeCourante == e.route,
                          onTap: () => _ouvrir(e.route!, routeCourante),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Obx(() {
                  // Ce qui est affiché, et non ce qui est enregistré : au
                  // premier lancement le mode vaut « système ».
                  final sombre = ThemeController.to.estSombre(context);
                  return SwitchListTile(
                    secondary: Icon(
                      sombre
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      color: AppColors.primary(context),
                    ),
                    title: const Text('Thème sombre'),
                    value: sombre,
                    onChanged: (_) => ThemeController.to.basculer(context),
                  );
                }),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.danger),
                  title: const Text(
                    'Se déconnecter',
                    style: TextStyle(color: AppColors.danger),
                  ),
                  onTap: () async {
                    final ok = await confirmer(
                      titre: 'Se déconnecter',
                      message: 'Voulez-vous fermer votre session ?',
                      libelleConfirmer: 'Se déconnecter',
                      destructif: true,
                    );
                    if (!ok) return;
                    Get.back(); // referme le tiroir avant de rendre la main
                    await session.signOut();
                  },
                ),
                const SizedBox(height: 8),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// Entrée du menu. L'écran courant est marqué par un fond teinté : le seul
/// gras ne se repère pas d'un coup d'œil, surtout au comptoir et à bout de
/// bras.
class _TuileMenu extends StatelessWidget {
  const _TuileMenu({
    required this.entree,
    required this.actif,
    required this.onTap,
  });

  final _Entree entree;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaire = AppColors.primary(context);
    final couleur = !entree.disponible
        ? AppColors.textMuted(context)
        : (actif ? primaire : AppColors.text(context));

    // Pleine largeur et sans arrondi : la teinte de l'écran courant se lit
    // comme un bandeau, et l'effet d'appui couvre toute la ligne.
    return ListTile(
      selected: actif,
      selectedTileColor: primaire.withValues(alpha: 0.12),
      leading: Icon(
        entree.icone,
        color: entree.disponible ? primaire : AppColors.textMuted(context),
      ),
      title: Text(
        entree.libelle,
        style: TextStyle(
          fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
          color: couleur,
        ),
      ),
      trailing: entree.disponible
          ? null
          : Text(
              'Bientôt',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted(context),
              ),
            ),
      onTap: entree.disponible ? onTap : null,
    );
  }
}

class _Entete extends StatelessWidget {
  const _Entete({
    required this.nom,
    required this.initiales,
    required this.sousTitre,
    required this.role,
    this.onChangerBoutique,
  });

  final String nom;
  final String initiales;
  final String sousTitre;
  final String role;

  /// Nul quand le compte n'a qu'une boutique : la ligne reste alors un
  /// simple rappel, sans effet d'appui qui promettrait une action.
  final VoidCallback? onChangerBoutique;

  @override
  Widget build(BuildContext context) {
    // Hauteur de la barre d'état : le dégradé passe dessous, le contenu
    // reste dessous d'elle.
    final hautStatut = MediaQuery.paddingOf(context).top;

    // Les barres de titre sont claires, donc les icônes système sombres.
    // Le temps que ce dégradé les recouvre, il faut les repasser en clair —
    // le tiroir se dessine par-dessus l'écran, son annotation l'emporte.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20, hautStatut + 24, 20, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.brandPrimaryLight, AppColors.brandPrimary],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white24,
                  child: Text(
                    initiales,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        role,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _LigneBoutique(nom: sousTitre, onTap: onChangerBoutique),
          ],
        ),
      ),
    );
  }
}

/// Ligne « entreprise » du bas de l'en-tête. Cliquable — et signalée comme
/// telle — quand le compte sert plusieurs boutiques.
class _LigneBoutique extends StatelessWidget {
  const _LigneBoutique({required this.nom, this.onTap});

  final String nom;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final contenu = Row(
      children: [
        const Icon(Icons.apartment, size: 15, color: Colors.white70),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            nom,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 6),
          const Icon(Icons.swap_horiz_rounded, size: 18, color: Colors.white),
        ],
      ],
    );

    if (onTap == null) return contenu;

    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: contenu,
        ),
      ),
    );
  }
}
