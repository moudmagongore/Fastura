import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/statut_chip.dart';
import '../../../data/models/nature_depense_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../controllers/natures_depense_controller.dart';

class NaturesDepenseListView extends GetView<NaturesDepenseController> {
  const NaturesDepenseListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Natures de dépense'),
        actions: [
          Obx(
            () => IconButton(
              tooltip: controller.masquerInactives.value
                  ? 'Afficher les inactives'
                  : 'Masquer les inactives',
              icon: Icon(
                controller.masquerInactives.value
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined,
              ),
              onPressed: () => controller.masquerInactives.toggle(),
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(AppRoutes.natureDepenseForm),
        icon: const Icon(Icons.add),
        label: const Text('Nature'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => controller.recherche.value = v,
              decoration: const InputDecoration(
                hintText: 'Rechercher une nature…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Obx(
            () => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${controller.nbActives} active(s) sur '
                  '${controller.natures.length}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted(context),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.chargement.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final liste = controller.resultats;
              if (liste.isEmpty) {
                return EmptyState(
                  icone: Icons.label_outline,
                  titre: controller.natures.isEmpty
                      ? 'Aucune nature de dépense'
                      : 'Aucun résultat',
                  description: controller.natures.isEmpty
                      ? 'La nomenclature des dépenses est la vôtre : loyer, '
                            'carburant, fournitures… Créez-en une avant de '
                            'saisir une dépense.'
                      : 'Aucune nature ne correspond à cette recherche.',
                  action: controller.natures.isEmpty
                      ? ElevatedButton.icon(
                          onPressed: () =>
                              Get.toNamed(AppRoutes.natureDepenseForm),
                          icon: const Icon(Icons.add),
                          label: const Text('Créer une nature'),
                        )
                      : null,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: liste.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _NatureCard(
                  nature: liste[i],
                  onModifier: () => Get.toNamed(
                    AppRoutes.natureDepenseForm,
                    arguments: liste[i],
                  ),
                  onBasculer: () => controller.basculerActivation(liste[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _NatureCard extends StatelessWidget {
  const _NatureCard({
    required this.nature,
    required this.onModifier,
    required this.onBasculer,
  });

  final NatureDepenseModel nature;
  final VoidCallback onModifier;
  final VoidCallback onBasculer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onModifier,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.label_outline,
                  size: 18,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nature.libelle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text(context),
                  ),
                ),
              ),
              StatutChip(actif: nature.active),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'modifier') onModifier();
                  if (v == 'bascule') onBasculer();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'modifier',
                    child: Text('Modifier'),
                  ),
                  PopupMenuItem(
                    value: 'bascule',
                    child: Text(
                      nature.active ? 'Désactiver' : 'Réactiver',
                      style: TextStyle(
                        color: nature.active
                            ? AppColors.danger
                            : AppColors.success,
                      ),
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
