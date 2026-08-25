import 'package:flutter/material.dart';
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
          _Entree('Entreprises', Icons.apartment_outlined,
              route: AppRoutes.superAdminTenants),
        ],
      UserRole.admin => const [
          _Entree('Accueil', Icons.home_outlined, route: AppRoutes.adminHome),
          _Entree('Facturation', Icons.receipt_long_outlined,
              route: AppRoutes.factures),
          _Entree('Paiements', Icons.payments_outlined,
              route: AppRoutes.paiements),
          _Entree('Clients', Icons.people_outline, route: AppRoutes.clients),
          _Entree('Articles', Icons.inventory_2_outlined,
              route: AppRoutes.articles),
          _Entree('Catégories', Icons.category_outlined,
              route: AppRoutes.categories),
          _Entree('Dépenses', Icons.trending_down),
          _Entree('Utilisateurs', Icons.manage_accounts_outlined,
              route: AppRoutes.users),
          _Entree('Paramètres', Icons.settings_outlined),
        ],
      UserRole.vendeur => const [
          _Entree('Accueil', Icons.home_outlined, route: AppRoutes.vendeurHome),
          _Entree('Facturation', Icons.receipt_long_outlined,
              route: AppRoutes.factures),
          _Entree('Paiements', Icons.payments_outlined,
              route: AppRoutes.paiements),
          _Entree('Clients', Icons.people_outline, route: AppRoutes.clients),
          _Entree('Dépenses', Icons.trending_down),
        ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionController.to;

    return Drawer(
      child: SafeArea(
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
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final e in entrees)
                      ListTile(
                        leading: Icon(
                          e.icone,
                          color: e.disponible
                              ? AppColors.primary(context)
                              : AppColors.textMuted(context),
                        ),
                        title: Text(
                          e.libelle,
                          style: TextStyle(
                            fontWeight: routeCourante == e.route
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: e.disponible
                                ? AppColors.text(context)
                                : AppColors.textMuted(context),
                          ),
                        ),
                        trailing: e.disponible
                            ? null
                            : Text(
                                'Bientôt',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted(context),
                                ),
                              ),
                        selected: routeCourante == e.route,
                        onTap: !e.disponible
                            ? null
                            : () {
                                Get.back();
                                if (routeCourante != e.route) {
                                  Get.toNamed(e.route!);
                                }
                              },
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Obx(() {
                final sombre =
                    ThemeController.to.mode.value == ThemeMode.dark;
                return SwitchListTile(
                  secondary: Icon(
                    sombre ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandPrimary, AppColors.brandPrimaryDark],
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
    );
  }
}
