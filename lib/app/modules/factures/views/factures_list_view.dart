import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/format_helpers.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/models/facture_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../controllers/factures_controller.dart';

class FacturesListView extends GetView<FacturesController> {
  const FacturesListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Factures'),
        // Écran de premier niveau : le bouton du tiroir à gauche, et jamais
        // de flèche de retour — on circule par le menu.
        // `automaticallyImplyLeading: false` empêche `Scaffold` de poser sa
        // propre flèche ; le bouton du tiroir, lui, est posé explicitement
        // et ne dépend donc pas de ce qu'il y a dans la pile.
        automaticallyImplyLeading: false,
        leading: const DrawerButton(),
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(AppRoutes.factureForm),
        icon: const Icon(Icons.add),
        label: const Text('Facturer'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => controller.recherche.value = v,
              decoration: const InputDecoration(
                hintText: 'Rechercher par numéro ou client…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: Obx(
              () => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final f in FiltreFacture.values) ...[
                    ChoiceChip(
                      label: Text(f.label),
                      selected: controller.filtre.value == f,
                      onSelected: (_) => controller.filtre.value = f,
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          _Bandeau(controller: controller),
          Expanded(
            child: Obx(() {
              if (controller.chargement.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final liste = controller.resultats;
              if (liste.isEmpty) {
                return EmptyState(
                  icone: Icons.receipt_long_outlined,
                  titre: controller.factures.isEmpty
                      ? 'Aucune facture'
                      : 'Aucun résultat',
                  description: controller.factures.isEmpty
                      ? 'Les factures que vous émettez apparaîtront ici, de '
                            'la plus récente à la plus ancienne.'
                      : 'Aucune facture ne correspond à ce filtre.',
                  action: controller.factures.isEmpty
                      ? ElevatedButton.icon(
                          onPressed: () => Get.toNamed(AppRoutes.factureForm),
                          icon: const Icon(Icons.add),
                          label: const Text('Émettre une facture'),
                        )
                      : null,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: liste.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => FactureCard(
                  facture: liste[i],
                  onTap: () =>
                      Get.toNamed(AppRoutes.factureDetail, arguments: liste[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _Bandeau extends StatelessWidget {
  const _Bandeau({required this.controller});

  final FacturesController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final reste = controller.totalResteDu;
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Facturé : ${Formats.montant(controller.totalFacture, devise: controller.devise)}',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted(context),
              ),
            ),
            if (reste > 0)
              Text(
                'Reste dû : ${Formats.montant(reste, devise: controller.devise)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning,
                ),
              ),
          ],
        ),
      );
    });
  }
}

/// Carte de facture, réutilisée par le journal et par l'historique client.
class FactureCard extends StatelessWidget {
  const FactureCard({
    super.key,
    required this.facture,
    required this.onTap,
    this.afficherClient = true,
  });

  final FactureModel facture;
  final VoidCallback onTap;
  final bool afficherClient;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    facture.numero,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text(context),
                      decoration: facture.annulee
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const Spacer(),
                  StatutFactureChip(facture: facture),
                ],
              ),
              const SizedBox(height: 4),
              if (afficherClient)
                Text(
                  facture.clientAffiche,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textMuted(context),
                  ),
                ),
              Text(
                '${Formats.date(facture.date)} · '
                '${facture.nombreArticles} article(s)',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted(context),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formats.montant(
                      facture.montantTotal,
                      devise: facture.devise,
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: facture.annulee
                          ? AppColors.cancelled
                          : AppColors.text(context),
                    ),
                  ),
                  const Spacer(),
                  if (!facture.annulee && facture.resteDu > 0)
                    Text(
                      'Reste ${Formats.montant(facture.resteDu, devise: facture.devise)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastille de statut. L'annulation prime sur le statut de règlement : une
/// facture annulée n'est ni payée ni impayée, elle est sortie du circuit.
class StatutFactureChip extends StatelessWidget {
  const StatutFactureChip({super.key, required this.facture});

  final FactureModel facture;

  @override
  Widget build(BuildContext context) {
    final (libelle, couleur) = facture.annulee
        ? ('Annulée', AppColors.cancelled)
        : switch (facture.statut) {
            StatutFacture.payee => ('Payée', AppColors.success),
            StatutFacture.partielle => ('Partielle', AppColors.warning),
            StatutFacture.impayee => ('Impayée', AppColors.danger),
          };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: couleur.withValues(alpha: 0.4)),
      ),
      child: Text(
        libelle,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: couleur,
        ),
      ),
    );
  }
}
