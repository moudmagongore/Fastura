import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/format_helpers.dart';
import '../../../core/utils/marges_ecran.dart';
import '../../../core/widgets/message_banner.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../controllers/import_articles_controller.dart';
import '../import_articles.dart';

/// Import d'articles par collage : saisie du lot, puis aperçu avant écriture.
class ImportArticlesView extends GetView<ImportArticlesController> {
  const ImportArticlesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importer une liste'),
        actions: [
          Obx(
            () => controller.analysee.value
                ? TextButton(
                    onPressed: controller.modifierLaListe,
                    child: const Text('Modifier'),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Obx(
          () => controller.analysee.value
              ? _Apercu(controller: controller)
              : _Saisie(controller: controller),
        ),
      ),
      bottomNavigationBar: Obx(
        () => controller.analysee.value
            ? _BarreValidation(controller: controller)
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _Saisie extends StatelessWidget {
  const _Saisie({required this.controller});

  final ImportArticlesController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 32 + margeBasse(context)),
      children: [
        Obx(() {
          final message = controller.erreur.value;
          if (message == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: MessageBanner.erreur(message),
          );
        }),
        Text('Le lot', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Une catégorie par collage. Pour plusieurs rayons, importez '
          'plusieurs fois.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        Obx(
          () => DropdownButtonFormField<String>(
            initialValue: controller.categorieId.value,
            decoration: const InputDecoration(
              labelText: 'Catégorie *',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: [
              for (final c in controller.categories)
                DropdownMenuItem(value: c.id, child: Text(c.libelle)),
            ],
            onChanged: (v) => controller.categorieId.value = v,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: controller.uniteCtrl,
          decoration: const InputDecoration(
            labelText: 'Unité par défaut',
            helperText: 'Utilisée quand la ligne n\'en précise pas.',
            prefixIcon: Icon(Icons.straighten_outlined),
          ),
        ),
        const SizedBox(height: 26),
        Text('La liste', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Une ligne par article : désignation, prix, et l\'unité si elle '
          'change. Séparez par « ; », une tabulation ou « | » — copier deux '
          'colonnes d\'un tableur fonctionne tel quel.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.texteCtrl,
          minLines: 8,
          maxLines: 16,
          keyboardType: TextInputType.multiline,
          style: const TextStyle(fontSize: 13.5, height: 1.5),
          decoration: const InputDecoration(
            hintText:
                'Sac de riz parfumé 50 kg ; 425000 ; sac\n'
                'Bidon d\'huile 20 L ; 310000 ; bidon\n'
                'Sucre en poudre 1 kg ; 12500',
            hintMaxLines: 3,
          ),
        ),
        const SizedBox(height: 20),
        Obx(
          () => ElevatedButton.icon(
            onPressed: controller.analyse.value ? null : controller.analyser,
            icon: controller.analyse.value
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.fact_check_outlined),
            label: Text(
              controller.analyse.value ? 'Analyse…' : 'Vérifier la liste',
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Rien n\'est enregistré à cette étape : vous verrez d\'abord ce qui '
          'sera créé.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Apercu extends StatelessWidget {
  const _Apercu({required this.controller});

  final ImportArticlesController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lignes = controller.lignes;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${controller.nbCreables} à créer · '
                  '${controller.nbDoublons} déjà au catalogue · '
                  '${controller.nbErreurs} à corriger',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Catégorie : ${controller.categorie?.libelle ?? '—'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (controller.tronquee.value) ...[
                  const SizedBox(height: 10),
                  MessageBanner.attention(
                    'Liste trop longue : seules les '
                    '${AnalyseImport.maxLignes} premières lignes sont '
                    'reprises. Importez le reste en un second collage.',
                  ),
                ],
                Obx(() {
                  final message = controller.erreur.value;
                  if (message == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: MessageBanner.erreur(message),
                  );
                }),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: lignes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _LigneApercu(
                ligne: lignes[i],
                devise: controller.devise,
                onTap: () => controller.basculer(lignes[i]),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _LigneApercu extends StatelessWidget {
  const _LigneApercu({
    required this.ligne,
    required this.devise,
    required this.onTap,
  });

  final LigneImport ligne;
  final String devise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (couleur, icone) = switch (ligne.statut) {
      StatutLigne.creable => (AppColors.success, Icons.check_circle_rounded),
      StatutLigne.doublon => (AppColors.warning, Icons.content_copy_rounded),
      StatutLigne.erreur => (AppColors.danger, Icons.error_outline_rounded),
    };

    return Material(
      color: ligne.retenue
          ? AppColors.surface(context)
          : AppColors.surfaceMuted(context),
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: ligne.modifiable ? onTap : null,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: ligne.retenue
                  ? couleur.withValues(alpha: 0.35)
                  : AppColors.border(context),
            ),
          ),
          child: Row(
            children: [
              Icon(
                ligne.modifiable
                    ? (ligne.retenue
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded)
                    : icone,
                size: 20,
                color: ligne.modifiable
                    ? (ligne.retenue ? couleur : AppColors.textMuted(context))
                    : couleur,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ligne.statut == StatutLigne.erreur &&
                              ligne.designation.isEmpty
                          ? 'Ligne ${ligne.numero} : ${ligne.texte}'
                          : ligne.designation,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ligne.probleme ??
                          '${Formats.montant(ligne.prix, devise: devise)} · '
                              '${ligne.unite}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: ligne.probleme == null
                            ? FontWeight.w400
                            : FontWeight.w600,
                        color: ligne.probleme == null
                            ? AppColors.textMuted(context)
                            : couleur,
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

class _BarreValidation extends StatelessWidget {
  const _BarreValidation({required this.controller});

  final ImportArticlesController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface(context),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Obx(
            () => ElevatedButton.icon(
              onPressed:
                  controller.nbRetenues == 0 || controller.enregistrement.value
                  ? null
                  : controller.creer,
              icon: controller.enregistrement.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.playlist_add_check_rounded),
              label: Text(
                controller.enregistrement.value
                    ? 'Création…'
                    : 'Créer ${controller.nbRetenues} article(s)',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
