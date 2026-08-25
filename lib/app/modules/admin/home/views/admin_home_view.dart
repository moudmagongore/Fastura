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
/// Les tuiles sans `onTap` correspondent aux modules restant à développer.
class AdminHomeView extends StatelessWidget {
  const AdminHomeView({super.key});

  static void _ouvrirUtilisateurs() => Get.toNamed(AppRoutes.users);
  static void _ouvrirArticles() => Get.toNamed(AppRoutes.articles);
  static void _ouvrirCategories() => Get.toNamed(AppRoutes.categories);
  static void _ouvrirClients() => Get.toNamed(AppRoutes.clients);
  static void _nouvelleFacture() => Get.toNamed(AppRoutes.factureForm);
  static void _ouvrirPaiements() => Get.toNamed(AppRoutes.paiements);
  static void _ouvrirDepenses() => Get.toNamed(AppRoutes.depenses);

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
                ModuleTile(
                  libelle: 'Nouvelle facture',
                  icone: Icons.receipt_long_outlined,
                  onTap: _nouvelleFacture,
                ),
                ModuleTile(
                  libelle: 'Paiements',
                  icone: Icons.payments_outlined,
                  couleur: AppColors.brandAccent,
                  onTap: _ouvrirPaiements,
                ),
                ModuleTile(
                  libelle: 'Clients',
                  icone: Icons.people_outline,
                  onTap: _ouvrirClients,
                ),
                ModuleTile(
                  libelle: 'Articles',
                  icone: Icons.inventory_2_outlined,
                  onTap: _ouvrirArticles,
                ),
                ModuleTile(
                  libelle: 'Catégories',
                  icone: Icons.category_outlined,
                  onTap: _ouvrirCategories,
                ),
                ModuleTile(
                  libelle: 'Dépenses',
                  icone: Icons.trending_down,
                  couleur: AppColors.danger,
                  onTap: _ouvrirDepenses,
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
