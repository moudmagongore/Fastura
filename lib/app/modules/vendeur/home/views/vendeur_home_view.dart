import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/session_controller.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../core/widgets/module_tile.dart';
import '../../../../core/widgets/tenant_header.dart';
import '../../../../theme/app_colors.dart';

/// Accueil du Vendeur. Même socle que l'administrateur, sans les
/// référentiels ni les utilisateurs : le vendeur saisit et consulte,
/// il ne paramètre rien et n'annule rien.
class VendeurHomeView extends StatelessWidget {
  const VendeurHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionController.to;

    return Scaffold(
      appBar: AppBar(title: const Text('Accueil')),
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
              children: const [
                ModuleTile(
                  libelle: 'Nouvelle facture',
                  icone: Icons.receipt_long_outlined,
                ),
                ModuleTile(
                  libelle: 'Paiements',
                  icone: Icons.payments_outlined,
                  couleur: AppColors.brandAccent,
                ),
                ModuleTile(libelle: 'Clients', icone: Icons.people_outline),
                ModuleTile(
                  libelle: 'Dépenses',
                  icone: Icons.trending_down,
                  couleur: AppColors.danger,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
