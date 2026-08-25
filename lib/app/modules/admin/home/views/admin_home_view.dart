import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/session_controller.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../core/widgets/module_tile.dart';
import '../../../../core/widgets/tenant_header.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';

/// Accueil de l'Administrateur d'un tenant.
///
/// Les tuiles sans `onTap` correspondent aux modules restant à développer :
/// facturation, paiements, clients, articles, catégories, dépenses,
/// utilisateurs, paramètres.
class AdminHomeView extends StatelessWidget {
  const AdminHomeView({super.key});

  static void _ouvrirUtilisateurs() => Get.toNamed(AppRoutes.users);

  @override
  Widget build(BuildContext context) {
    final session = SessionController.to;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil'),
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const TenantHeader(),
            const SizedBox(height: 20),
            Obx(
              () => Text(
                'Bonjour ${session.user.value?.nom ?? ''}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text(context),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                const ModuleTile(
                  libelle: 'Nouvelle facture',
                  icone: Icons.receipt_long_outlined,
                ),
                const ModuleTile(
                  libelle: 'Paiements',
                  icone: Icons.payments_outlined,
                  couleur: AppColors.brandAccent,
                ),
                const ModuleTile(
                    libelle: 'Clients', icone: Icons.people_outline),
                const ModuleTile(
                  libelle: 'Articles',
                  icone: Icons.inventory_2_outlined,
                ),
                const ModuleTile(
                  libelle: 'Catégories',
                  icone: Icons.category_outlined,
                ),
                const ModuleTile(
                  libelle: 'Dépenses',
                  icone: Icons.trending_down,
                  couleur: AppColors.danger,
                ),
                ModuleTile(
                  libelle: 'Utilisateurs',
                  icone: Icons.manage_accounts_outlined,
                  onTap: _ouvrirUtilisateurs,
                ),
                const ModuleTile(
                  libelle: 'Paramètres',
                  icone: Icons.settings_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
