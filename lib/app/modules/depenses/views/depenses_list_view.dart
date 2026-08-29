import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/format_helpers.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/barre_periode.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/models/depense_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../controllers/depenses_controller.dart';

class DepensesListView extends GetView<DepensesController> {
  const DepensesListView({super.key});

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
        title: const Text('Dépenses'),
        actions: [
          IconButton(
            tooltip: 'Récapitulatif de la période',
            icon: const Icon(Icons.print_outlined),
            onPressed: controller.imprimerRecapitulatif,
          ),
          Obx(
            () => IconButton(
              tooltip: controller.masquerAnnulees.value
                  ? 'Afficher les annulées'
                  : 'Masquer les annulées',
              icon: Icon(
                controller.masquerAnnulees.value
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined,
              ),
              onPressed: () => controller.masquerAnnulees.toggle(),
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(AppRoutes.depenseForm),
        icon: const Icon(Icons.add),
        label: const Text('Dépense'),
      ),
      body: Column(
        children: [
          BarrePeriode(filtre: controller.periode),
          _Total(controller: controller),
          _FiltreNatures(controller: controller),
          Expanded(
            child: Obx(() {
              if (controller.chargement.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final liste = controller.resultats;
              if (liste.isEmpty) {
                return EmptyState(
                  icone: Icons.trending_down,
                  titre: controller.depenses.isEmpty
                      ? 'Aucune dépense sur la période'
                      : 'Aucun résultat',
                  description: controller.depenses.isEmpty
                      ? 'Changez de période, ou enregistrez la première '
                            'dépense de ${controller.libellePeriode.toLowerCase()}.'
                      : 'Aucune dépense ne correspond à ce filtre.',
                  action: controller.depenses.isEmpty
                      ? ElevatedButton.icon(
                          onPressed: () => Get.toNamed(AppRoutes.depenseForm),
                          icon: const Icon(Icons.add),
                          label: const Text('Enregistrer une dépense'),
                        )
                      : null,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: liste.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _DepenseCard(
                  depense: liste[i],
                  nature: controller.libelleNature(liste[i]),
                  devise: controller.devise,
                  onTap: () =>
                      Get.toNamed(AppRoutes.depenseDetail, arguments: liste[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.controller});

  final DepensesController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                // « Tout l'historique » ou « Du … au … » : sans borne
                // posée, deux tirets ne diraient pas ce que le total
                // couvre.
                controller.libellePeriode,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted(context),
                ),
              ),
            ),
            Text(
              Formats.montant(controller.total, devise: controller.devise),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FiltreNatures extends StatelessWidget {
  const _FiltreNatures({required this.controller});

  final DepensesController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final natures = controller.naturesFiltrables;
      if (natures.isEmpty) return const SizedBox(height: 8);
      return SizedBox(
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          children: [
            // `ChoiceChip` et non `FilterChip` : on ne retient qu'une nature
            // à la fois. C'est aussi le seul des deux dont le libellé passe
            // en blanc une fois coché (`secondaryLabelStyle` du thème) —
            // avec un `FilterChip`, il restait gris sur le bleu pétrole.
            ChoiceChip(
              label: const Text('Toutes'),
              selected: controller.filtreNatureId.value.isEmpty,
              onSelected: (_) => controller.filtreNatureId.value = '',
            ),
            const SizedBox(width: 8),
            for (final n in natures) ...[
              ChoiceChip(
                label: Text(n.active ? n.libelle : '${n.libelle} (inactive)'),
                selected: controller.filtreNatureId.value == n.id,
                onSelected: (v) =>
                    controller.filtreNatureId.value = v ? n.id : '',
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      );
    });
  }
}

class _DepenseCard extends StatelessWidget {
  const _DepenseCard({
    required this.depense,
    required this.nature,
    required this.devise,
    required this.onTap,
  });

  final DepenseModel depense;
  final String nature;
  final String devise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final couleur = depense.annulee ? AppColors.cancelled : AppColors.danger;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: couleur.withValues(alpha: 0.15),
                child: Icon(Icons.trending_down, size: 20, color: couleur),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nature,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text(context),
                        decoration: depense.annulee
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    Text(
                      '${Formats.date(depense.date)} · ${depense.creeParNom}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                    if ((depense.description ?? '').isNotEmpty)
                      Text(
                        depense.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted(context),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formats.montant(depense.montant, devise: devise),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: couleur,
                    ),
                  ),
                  if (depense.annulee)
                    const Text(
                      'Annulée',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.cancelled,
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
