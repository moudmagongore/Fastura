import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/format_helpers.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/statut_chip.dart';
import '../../../data/models/article_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../controllers/articles_controller.dart';

class ArticlesListView extends GetView<ArticlesController> {
  const ArticlesListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Articles'),
        actions: [
          Obx(
            () => IconButton(
              tooltip: controller.masquerInactifs.value
                  ? 'Afficher les inactifs'
                  : 'Masquer les inactifs',
              icon: Icon(
                controller.masquerInactifs.value
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined,
              ),
              onPressed: () => controller.masquerInactifs.toggle(),
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(AppRoutes.articleForm),
        icon: const Icon(Icons.add),
        label: const Text('Article'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => controller.recherche.value = v,
              decoration: const InputDecoration(
                hintText: 'Rechercher un article…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          _FiltreCategories(controller: controller),
          Obx(
            () => Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${controller.nbActifs} actif(s) sur '
                  '${controller.articles.length}',
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
                  icone: Icons.inventory_2_outlined,
                  titre: controller.articles.isEmpty
                      ? 'Catalogue vide'
                      : 'Aucun résultat',
                  description: controller.articles.isEmpty
                      ? 'Ajoutez les produits et services que vous facturez, '
                          'avec leur prix de vente.'
                      : 'Aucun article ne correspond à cette recherche.',
                  action: controller.articles.isEmpty
                      ? ElevatedButton.icon(
                          onPressed: () => Get.toNamed(AppRoutes.articleForm),
                          icon: const Icon(Icons.add),
                          label: const Text('Ajouter un article'),
                        )
                      : null,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: liste.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _ArticleCard(
                  article: liste[i],
                  categorie: controller.libelleCategorie(liste[i]),
                  devise: controller.devise,
                  onModifier: () => Get.toNamed(
                    AppRoutes.articleForm,
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

class _FiltreCategories extends StatelessWidget {
  const _FiltreCategories({required this.controller});

  final ArticlesController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.categories.isEmpty) return const SizedBox.shrink();
      final selection = controller.filtreCategorieId.value;

      return SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            ChoiceChip(
              label: const Text('Toutes'),
              selected: selection.isEmpty,
              onSelected: (_) => controller.filtreCategorieId.value = '',
            ),
            for (final c in controller.categories) ...[
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(c.active ? c.libelle : '${c.libelle} (inactive)'),
                selected: selection == c.id,
                onSelected: (_) => controller.filtreCategorieId.value =
                    selection == c.id ? '' : c.id,
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({
    required this.article,
    required this.categorie,
    required this.devise,
    required this.onModifier,
    required this.onBasculer,
  });

  final ArticleModel article;
  final String categorie;
  final String devise;
  final VoidCallback onModifier;
  final VoidCallback onBasculer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onModifier,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article.designation,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text(context),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          categorie,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatutChip(actif: article.active),
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
                          article.active ? 'Désactiver' : 'Réactiver',
                          style: TextStyle(
                            color: article.active
                                ? AppColors.danger
                                : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Text(
                      Formats.montant(article.prixVente, devise: devise),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent(context),
                      ),
                    ),
                    Text(
                      ' / ${article.unite}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
