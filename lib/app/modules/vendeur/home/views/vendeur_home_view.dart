import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/app_drawer.dart';
import '../../../../core/widgets/marque_fastura.dart';
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
    return Scaffold(
      appBar: AppBar(
        // Écran de premier niveau : le bouton du tiroir à gauche, et jamais
        // de flèche de retour — on circule par le menu.
        // `automaticallyImplyLeading: false` empêche `Scaffold` de poser sa
        // propre flèche ; le bouton du tiroir, lui, est posé explicitement
        // et ne dépend donc pas de ce qu'il y a dans la pile.
        automaticallyImplyLeading: false,
        leading: const DrawerButton(),
        // La marque au centre : sans action à droite, un titre calé à
        // gauche laissait la barre déséquilibrée, tout le poids du côté du
        // bouton du tiroir.
        centerTitle: true,
        title: const MarqueFastura(),
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
