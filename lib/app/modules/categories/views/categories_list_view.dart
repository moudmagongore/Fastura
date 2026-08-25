import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/statut_chip.dart';
import '../../../data/models/categorie_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../controllers/categories_controller.dart';

class CategoriesListView extends GetView<CategoriesController> {
  const CategoriesListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catégories'),
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
        onPressed: () => Get.toNamed(AppRoutes.categorieForm),
        icon: const Icon(Icons.add),
        label: const Text('Catégorie'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => controller.recherche.value = v,
              decoration: const InputDecoration(
                hintText: 'Rechercher par code ou libellé…',
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
                  '${controller.categories.length}',
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
                  icone: Icons.category_outlined,
                  titre: controller.categories.isEmpty
                      ? 'Aucune catégorie'
                      : 'Aucun résultat',
                  description: controller.categories.isEmpty
                      ? 'Les catégories regroupent vos articles. Créez-en une '
                          'avant d\'alimenter le catalogue.'
                      : 'Aucune catégorie ne correspond à cette recherche.',
                  action: controller.categories.isEmpty
                      ? ElevatedButton.icon(
                          onPressed: () => Get.toNamed(AppRoutes.categorieForm),
                          icon: const Icon(Icons.add),
                          label: const Text('Créer une catégorie'),
                        )
                      : null,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: liste.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _CategorieCard(
                  categorie: liste[i],
                  onModifier: () => Get.toNamed(
                    AppRoutes.categorieForm,
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

class _CategorieCard extends StatelessWidget {
  const _CategorieCard({
    required this.categorie,
    required this.onModifier,
    required this.onBasculer,
  });

  final CategorieModel categorie;
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary(context).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  categorie.code,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary(context),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  categorie.libelle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text(context),
                  ),
                ),
              ),
              StatutChip(actif: categorie.active),
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
                      categorie.active ? 'Désactiver' : 'Réactiver',
                      style: TextStyle(
                        color: categorie.active
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
