import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../data/models/user_role.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_controller.dart';
import '../constants/app_constants.dart';
import '../services/session_controller.dart';
import 'confirm_dialog.dart';

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
        _Entree('À propos', Icons.info_outline, route: AppRoutes.apropos),
        _Entree(
          'Paramètres',
          Icons.settings_outlined,
          route: AppRoutes.parametres,
        ),
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

  @override
  Widget build(BuildContext context) {
    final session = SessionController.to;

    return Drawer(
      // `top: false` : l'en-tête doit filer jusque sous la barre d'état,
      // sinon un bandeau blanc la sépare du haut de l'écran. C'est
      // l'en-tête qui reprend l'encoche à son compte, dans son padding.
      child: SafeArea(
        top: false,
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
              ),
              Expanded(
                child: ListView(
                  // Aucune marge verticale : elle laissait huit pixels de
                  // vide au-dessus de la première entrée, que la teinte de
                  // l'écran courant ne pouvait pas couvrir. Les entrées se
                  // touchent, du bas de l'en-tête au séparateur.
                  padding: EdgeInsets.zero,
                  children: [
                    for (final e in entrees)
                      _TuileMenu(
                        entree: e,
                        actif: routeCourante == e.route,
                        onTap: () {
                          Get.back();
                          if (routeCourante != e.route) Get.toNamed(e.route!);
                        },
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Obx(() {
                final sombre = ThemeController.to.mode.value == ThemeMode.dark;
                return SwitchListTile(
                  secondary: Icon(
                    sombre
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                    color: AppColors.primary(context),
                  ),
                  title: const Text('Thème sombre'),
                  value: sombre,
                  onChanged: (_) => ThemeController.to.toggle(),
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
                  if (ok) await session.signOut();
                },
              ),
              const SizedBox(height: 8),
            ],
          );
        }),
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
  });

  final String nom;
  final String initiales;
  final String sousTitre;
  final String role;

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
            Row(
              children: [
                const Icon(Icons.apartment, size: 15, color: Colors.white70),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    sousTitre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
