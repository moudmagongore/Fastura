import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/session_controller.dart';
import '../../../../core/utils/format_helpers.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../core/widgets/tenant_header.dart';
import '../../../../modules/accueil/widgets/statistiques_accueil.dart';
import '../../../../routes/app_routes.dart';
import '../../../../core/utils/marges_ecran.dart';

/// Accueil du Vendeur. Même socle que l'administrateur, sans les
/// référentiels ni les utilisateurs : le vendeur saisit et consulte,
/// il ne paramètre rien et n'annule rien.
class VendeurHomeView extends StatelessWidget {
  const VendeurHomeView({super.key});

  static void _nouvelleFacture() => Get.toNamed(AppRoutes.factureForm);

  @override
  Widget build(BuildContext context) {
    final session = SessionController.to;

    return Scaffold(
      // La salutation tient lieu de titre : « Accueil » n'apprenait rien, et
      // le nom rappelle sous quel compte on facture.
      appBar: AppBar(
        // Écran de premier niveau : pas de flèche de retour, on circule par
        // le tiroir. `automaticallyImplyLeading: false` couvre les deux
        // boutons que `Scaffold` poserait à gauche — celui du tiroir, qui
        // vit maintenant à droite en dernière action, et le retour.
        automaticallyImplyLeading: false,
        title: Obx(
          () => Text(
            Formats.salutationPour(session.user.value?.nom ?? ''),
            // Un nom long est coupé, jamais poussé hors de la barre : la
            // salutation et le geste restent lisibles, c'est la fin du nom
            // qui cède.
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: const [DrawerButton()],
      ),
      drawer: const AppDrawer(),
      // Le geste du comptoir, à portée de pouce depuis n'importe où dans la
      // page — la tuile d'accès rapide, elle, sort de l'écran dès qu'on
      // déroule les chiffres.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nouvelleFacture,
        icon: const Icon(Icons.add),
        label: const Text('Facturer'),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // La carte de l'entreprise reste en place : c'est le repère qui
            // dit sous quelle enseigne on facture, il ne doit pas partir au
            // premier coup de pouce.
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TenantHeader(),
            ),
            Expanded(
              child: ListView(
                // 96 en bas : la place du bouton flottant, comme sur les
                // journaux.
                padding: EdgeInsets.fromLTRB(
                  16,
                  18,
                  16,
                  96 + margeBasse(context),
                ),
                children: const [
                  StatistiquesAccueil(),
                  SizedBox(height: 24),
                  DernieresFactures(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
