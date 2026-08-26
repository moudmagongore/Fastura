import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/widgets/message_banner.dart';
import '../../../data/models/article_model.dart';
import '../../../data/models/categorie_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../core/utils/marges_ecran.dart';
import '../controllers/article_form_controller.dart';

class ArticleFormView extends GetView<ArticleFormController> {
  const ArticleFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(controller.titre)),
      body: SafeArea(
        bottom: false,
        child: Obx(
          () => controller.aucuneCategorie
              ? _AucuneCategorie()
              : _Formulaire(controller: controller),
        ),
      ),
    );
  }
}

/// Un article ne peut exister sans catégorie de rattachement : plutôt qu'un
/// sélecteur vide et un message d'erreur au moment d'enregistrer, on renvoie
/// directement vers la création d'une catégorie.
class _AucuneCategorie extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.category_outlined,
              size: 56,
              color: AppColors.textMuted(context),
            ),
            const SizedBox(height: 18),
            Text(
              'Aucune catégorie',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chaque article appartient à une catégorie. Créez-en une avant '
              'd\'alimenter le catalogue.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppColors.textMuted(context),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Get.offAndToNamed(AppRoutes.categorieForm),
              icon: const Icon(Icons.add),
              label: const Text('Créer une catégorie'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Formulaire extends StatelessWidget {
  const _Formulaire({required this.controller});

  final ArticleFormController controller;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: controller.formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 32 + margeBasse(context)),
        children: [
          Obx(() {
            final message = controller.erreur.value;
            if (message == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: MessageBanner.erreur(message),
            );
          }),

          Obx(
            () => DropdownButtonFormField<String>(
              initialValue: controller.categorieId.value,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Catégorie *',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: [
                for (final CategorieModel c
                    in controller.categoriesSelectionnables)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      c.active ? c.libelle : '${c.libelle} (inactive)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => controller.categorieId.value = v,
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: controller.designationCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Désignation *',
              helperText: 'Le libellé imprimé sur la facture',
              prefixIcon: Icon(Icons.description_outlined),
            ),
            validator: controller.validerDesignation,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: controller.prixCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Prix de vente *',
              suffixText: controller.devise,
              prefixIcon: const Icon(Icons.sell_outlined),
            ),
            validator: controller.validerPrix,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: controller.uniteCtrl,
            decoration: const InputDecoration(
              labelText: 'Unité *',
              helperText: 'Ce qui suit la quantité sur la facture',
              prefixIcon: Icon(Icons.straighten),
            ),
            validator: controller.validerUnite,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final u in unitesCourantes)
                ActionChip(
                  label: Text(u),
                  onPressed: () => controller.uniteCtrl.text = u,
                ),
            ],
          ),

          const SizedBox(height: 28),
          Obx(
            () => ElevatedButton(
              onPressed: controller.enregistrement.value
                  ? null
                  : controller.enregistrer,
              child: controller.enregistrement.value
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text('Enregistrer'),
            ),
          ),
        ],
      ),
    );
  }
}
