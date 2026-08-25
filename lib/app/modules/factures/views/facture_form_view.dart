import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../core/utils/bottom_sheet_helpers.dart';
import '../../../core/utils/format_helpers.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/message_banner.dart';
import '../../../data/models/facture_model.dart';
import '../../../data/models/paiement_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../controllers/facture_form_controller.dart';
import '../widgets/selecteurs.dart';

/// Saisie d'une facture.
///
/// Structure reprise de l'écran de vente de Gongoré, éprouvé au comptoir :
/// une barre client compacte en haut, la liste des articles au centre qui
/// occupe tout l'espace disponible, et en bas le total avec le bouton de
/// validation. Les options de règlement partent dans une feuille, pour ne
/// pas voler de la place à la liste — c'est elle qu'on manipule le plus.
class FactureFormView extends GetView<FactureFormController> {
  const FactureFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle facture'),
        actions: [
          Obx(
            () => controller.lignes.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Vider',
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: _confirmerVidage,
                  ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _BarreClient(controller: controller),
            const Divider(height: 1),
            Expanded(child: _SectionLignes(controller: controller)),
            const Divider(height: 1),
            _TotalEtAction(controller: controller),
          ],
        ),
      ),
    );
  }

  void _confirmerVidage() {
    Get.dialog(
      AlertDialog(
        title: const Text('Vider la facture ?'),
        content: const Text('Tous les articles seront retirés.'),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () {
              controller.viderLignes();
              Get.back();
            },
            child: const Text('Vider'),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Barre client
// ===========================================================================

class _BarreClient extends StatelessWidget {
  const _BarreClient({required this.controller});

  final FactureFormController controller;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final choisi = await choisirClient(
          controller.clients,
          selection: controller.client.value,
        );
        if (choisi != null) controller.choisirClient(choisi);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Obx(
                () => Icon(
                  controller.client.value?.estDivers ?? true
                      ? Icons.storefront_outlined
                      : Icons.person_rounded,
                  color: AppColors.primary(context),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CLIENT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Obx(
                    () => Text(
                      controller.client.value?.nom ?? 'Choisir un client',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Obx(() {
                    final c = controller.client.value;
                    if (c == null || c.solde == 0) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        c.aUneDette
                            ? 'Créance en cours : '
                                '${Formats.montant(c.solde, devise: controller.devise)}'
                            : 'Avance disponible : '
                                '${Formats.montant(-c.solde, devise: controller.devise)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: c.aUneDette
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            Obx(
              () => IconButton(
                tooltip: 'Changer la date',
                onPressed: () => controller.choisirDate(context),
                icon: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_outlined,
                        size: 20, color: AppColors.primary(context)),
                    Text(
                      Formats.date(controller.date.value),
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted(context)),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Liste des lignes
// ===========================================================================

class _SectionLignes extends StatelessWidget {
  const _SectionLignes({required this.controller});

  final FactureFormController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.catalogueVide || controller.toutDesactive) {
        return _CatalogueIndisponible(controller: controller);
      }
      if (controller.lignes.isEmpty) {
        return _AucuneLigne(onAjouter: () => _ajouter(controller));
      }
      return Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              itemCount: controller.lignes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) =>
                  _TuileLigne(controller: controller, index: i),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: OutlinedButton.icon(
              onPressed: () => _ajouter(controller),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter un article'),
            ),
          ),
        ],
      );
    });
  }

  static Future<void> _ajouter(FactureFormController controller) async {
    final a = await choisirArticle(
      controller.articles,
      devise: controller.devise,
    );
    if (a != null) controller.ajouterArticle(a);
  }
}

class _AucuneLigne extends StatelessWidget {
  const _AucuneLigne({required this.onAjouter});

  final VoidCallback onAjouter;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary(context).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inventory_2_outlined,
                  size: 32, color: AppColors.primary(context)),
            ),
            const SizedBox(height: 14),
            const Text(
              'Aucun article sur la facture',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Ajoutez les articles vendus pour construire la facture.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.textMuted(context),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAjouter,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter un article'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Explique pourquoi aucun article n'est proposable, et renvoie là où le
/// problème se corrige. Seul l'administrateur gère le catalogue ; le vendeur
/// voit le même message mais devra le signaler.
class _CatalogueIndisponible extends StatelessWidget {
  const _CatalogueIndisponible({required this.controller});

  final FactureFormController controller;

  @override
  Widget build(BuildContext context) {
    final vide = controller.catalogueVide;
    final message = vide
        ? 'Votre catalogue est vide. Ajoutez au moins un article pour '
            'pouvoir facturer.'
        : 'Tous vos articles sont désactivés, ils ne sont donc pas '
            'facturables. C\'est souvent la conséquence d\'une catégorie '
            'désactivée, qui ferme ses articles en cascade : réactivez la '
            'catégorie, puis les articles dont vous avez besoin.';

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inventory_2_outlined,
                  size: 32, color: AppColors.warning),
            ),
            const SizedBox(height: 14),
            Text(
              vide ? 'Catalogue vide' : 'Catalogue entièrement désactivé',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.textMuted(context),
              ),
            ),
            if (SessionController.to.peutGererReferentiels) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => Get.toNamed(AppRoutes.articles),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Ouvrir le catalogue'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TuileLigne extends StatelessWidget {
  const _TuileLigne({required this.controller, required this.index});

  final FactureFormController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (index >= controller.lignes.length) return const SizedBox.shrink();
      final l = controller.lignes[index];
      final devise = controller.devise;

      return Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.designation,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary(context)
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          l.code,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary(context),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${Formats.montant(l.prixUnitaire, devise: devise)} '
                        'la ${l.unite}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  Formats.montant(l.montant, devise: devise),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppColors.primary(context),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: AppColors.textMuted(context)),
                  onPressed: () => controller.retirerLigne(index),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _CompteurQuantite(
                  quantite: l.quantite,
                  unite: l.unite,
                  onMoins: () =>
                      controller.modifierQuantite(index, l.quantite - 1),
                  onPlus: () =>
                      controller.modifierQuantite(index, l.quantite + 1),
                  onSaisir: () => _saisirQuantite(context, l),
                ),
                const Spacer(),
                _PastillePrix(
                  negocie: controller.prixNegocie(l),
                  onTap: () => _modifierPrix(context, l, devise),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Future<void> _saisirQuantite(BuildContext context, LigneFacture l) async {
    final valeur = await _demanderNombre(
      context,
      titre: l.designation,
      label: 'Quantité',
      suffixe: l.unite,
      initial: l.quantite,
    );
    if (valeur != null) controller.modifierQuantite(index, valeur);
  }

  /// Le prix reste modifiable ligne à ligne : une remise ou un prix négocié
  /// se décide au comptoir, sans passer par une modification du catalogue.
  Future<void> _modifierPrix(
    BuildContext context,
    LigneFacture l,
    String devise,
  ) async {
    final valeur = await _demanderNombre(
      context,
      titre: l.designation,
      label: 'Prix unitaire',
      suffixe: devise,
      initial: l.prixUnitaire,
      aide: 'Ne modifie pas le prix du catalogue',
    );
    if (valeur != null && valeur > 0) controller.modifierPrix(index, valeur);
  }
}

/// Saisie d'un nombre en feuille : plus confortable au pouce qu'une
/// AlertDialog, et cohérent avec le reste des interactions de l'écran.
Future<double?> _demanderNombre(
  BuildContext context, {
  required String titre,
  required String label,
  required String suffixe,
  required double initial,
  String? aide,
}) async {
  final ctrl = TextEditingController(
    text: initial == initial.roundToDouble()
        ? initial.toStringAsFixed(0)
        : initial.toString(),
  );

  final resultat = await Get.bottomSheet<double>(
    Builder(
      builder: (context) => Container(
        color: AppColors.surface(context),
        padding: EdgeInsets.fromLTRB(20, 18, 20, paddingBasSheet(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PoigneeSheet(),
            Text(
              titre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              onSubmitted: (_) =>
                  Get.back(result: Validators.parseMontant(ctrl.text)),
              decoration: InputDecoration(
                labelText: label,
                suffixText: suffixe,
                helperText: aide,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () =>
                  Get.back(result: Validators.parseMontant(ctrl.text)),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Valider'),
            ),
          ],
        ),
      ),
    ),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );

  ctrl.dispose();
  return resultat;
}

class _CompteurQuantite extends StatelessWidget {
  const _CompteurQuantite({
    required this.quantite,
    required this.unite,
    required this.onMoins,
    required this.onPlus,
    required this.onSaisir,
  });

  final double quantite;
  final String unite;
  final VoidCallback onMoins;
  final VoidCallback onPlus;
  final VoidCallback onSaisir;

  @override
  Widget build(BuildContext context) {
    final texte = quantite == quantite.roundToDouble()
        ? quantite.toStringAsFixed(0)
        : quantite.toString();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary(context).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BoutonRond(icone: Icons.remove_rounded, onTap: onMoins),
          // Taper la quantité est plus rapide que de marteler le bouton
          // au-delà de quelques unités.
          InkWell(
            onTap: onSaisir,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(minWidth: 44),
              padding: const EdgeInsets.symmetric(vertical: 4),
              alignment: Alignment.center,
              child: Text(
                texte,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary(context),
                ),
              ),
            ),
          ),
          _BoutonRond(icone: Icons.add_rounded, onTap: onPlus),
        ],
      ),
    );
  }
}

class _BoutonRond extends StatelessWidget {
  const _BoutonRond({required this.icone, required this.onTap});

  final IconData icone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icone, size: 18, color: AppColors.primary(context)),
        ),
      ),
    );
  }
}

class _PastillePrix extends StatelessWidget {
  const _PastillePrix({required this.negocie, required this.onTap});

  /// Vrai quand le prix s'écarte de celui du catalogue.
  final bool negocie;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final couleur =
        negocie ? AppColors.success : AppColors.textMuted(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: negocie
                ? AppColors.success.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: negocie
                  ? AppColors.success.withValues(alpha: 0.4)
                  : AppColors.border(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                negocie ? Icons.local_offer_rounded : Icons.sell_outlined,
                size: 14,
                color: couleur,
              ),
              const SizedBox(width: 6),
              Text(
                negocie ? 'Prix modifié' : 'Prix',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: couleur,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Total et validation
// ===========================================================================

class _TotalEtAction extends StatelessWidget {
  const _TotalEtAction({required this.controller});

  final FactureFormController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(() {
              final message = controller.erreur.value;
              if (message == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: MessageBanner.erreur(message),
              );
            }),
            GetBuilder<FactureFormController>(
              builder: (_) => Obx(() {
                // Lecture des lignes pour que la barre se reconstruise à
                // chaque modification de quantité ou de prix.
                controller.lignes.length;
                return Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary(context).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary(context).withValues(alpha: 0.20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'TOTAL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AppColors.textMuted(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            Formats.montant(controller.montantTotal,
                                devise: controller.devise),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: AppColors.primary(context),
                            ),
                          ),
                          if (controller.tvaActive)
                            Text(
                              'dont TVA '
                              '${Formats.montant(controller.montantTva, devise: controller.devise)}'
                              ' (${Formats.pourcentage(controller.tauxTva)})',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textMuted(context),
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Flexible(
                        child: _PastilleReglement(controller: controller),
                      ),
                      IconButton(
                        tooltip: 'Règlement',
                        onPressed: () =>
                            _FeuilleReglement.ouvrir(controller),
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            Obx(
              () => ElevatedButton.icon(
                onPressed:
                    controller.enregistrement.value || !controller.pretAEnregistrer
                        ? null
                        : controller.enregistrer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  minimumSize: const Size.fromHeight(50),
                ),
                icon: controller.enregistrement.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded),
                label: Text(
                  controller.enregistrement.value
                      ? 'Émission…'
                      : 'Émettre la facture',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Résumé du règlement à droite du total : ce que le client reste devoir, ou
/// le mode d'encaissement retenu. Cliquable, ouvre la feuille de règlement.
class _PastilleReglement extends StatelessWidget {
  const _PastilleReglement({required this.controller});

  final FactureFormController controller;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<FactureFormController>(
      builder: (_) => Obx(() {
        controller.lignes.length;
        final reste = controller.resteDu;
        final regle = controller.paiementImmediat;

        final (couleur, icone, libelle) = switch (0) {
          _ when controller.tropPercu => (
              AppColors.danger,
              Icons.error_outline_rounded,
              'Trop perçu',
            ),
          _ when regle <= 0 => (
              AppColors.warning,
              Icons.schedule_rounded,
              'À crédit',
            ),
          _ when reste > 0 => (
              AppColors.warning,
              Icons.warning_amber_rounded,
              'Reste ${Formats.montant(reste, devise: controller.devise)}',
            ),
          _ => (
              AppColors.success,
              Icons.check_circle_rounded,
              controller.modePaiement.value.label,
            ),
        };

        return InkWell(
          onTap: () => _FeuilleReglement.ouvrir(controller),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: couleur.withValues(alpha: 0.30)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icone, size: 13, color: couleur),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    libelle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: couleur,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// Feuille de règlement immédiat.
///
/// Sortie du corps de l'écran pour rendre toute la hauteur à la liste des
/// articles : la plupart des ventes sont réglées comptant d'un geste, il
/// n'y a pas de raison d'occuper l'écran en permanence avec ce formulaire.
class _FeuilleReglement extends StatelessWidget {
  const _FeuilleReglement({required this.controller});

  final FactureFormController controller;

  static void ouvrir(FactureFormController controller) {
    Get.bottomSheet(
      _FeuilleReglement(controller: controller),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, paddingBasSheet(context)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PoigneeSheet(),
            EnteteSheet(
              icone: Icons.payments_rounded,
              couleur: AppColors.success,
              titre: 'Règlement immédiat',
              sousTitre: 'Laissez vide si le client règlera plus tard',
            ),
            const SizedBox(height: 18),
            GetBuilder<FactureFormController>(
              builder: (_) => Obx(
                () => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.background(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total de la facture',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted(context),
                        ),
                      ),
                      Text(
                        Formats.montant(controller.montantTotal,
                            devise: controller.devise),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller.paiementCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              onChanged: (_) => controller.update(),
              decoration: InputDecoration(
                labelText: 'Montant réglé',
                suffixText: controller.devise,
                prefixIcon: const Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: controller.reglerTout,
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('Solder la facture'),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'MODE DE PAIEMENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: AppColors.textMuted(context),
              ),
            ),
            const SizedBox(height: 8),
            Obx(
              () => Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final m in ModePaiement.values)
                    ChoiceChip(
                      label: Text(m.label),
                      selected: controller.modePaiement.value == m,
                      onSelected: (_) => controller.modePaiement.value = m,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GetBuilder<FactureFormController>(
              builder: (_) => Obx(() {
                controller.lignes.length;
                if (controller.tropPercu) {
                  return MessageBanner.erreur(
                    'Le montant réglé dépasse le total. Le surplus se saisit '
                    'depuis le menu de paiement, où il devient une avance au '
                    'crédit du client.',
                  );
                }
                final reste = controller.resteDu;
                if (reste <= 0) {
                  return MessageBanner.info(
                    'La facture sera soldée à l\'émission.',
                  );
                }
                return MessageBanner.attention(
                  '${Formats.montant(reste, devise: controller.devise)} '
                  'resteront à encaisser, et s\'ajouteront au solde du client.',
                );
              }),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: Get.back,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }
}
