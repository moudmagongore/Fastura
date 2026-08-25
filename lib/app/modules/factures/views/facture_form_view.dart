import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../core/utils/format_helpers.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/message_banner.dart';
import '../../../data/models/facture_model.dart';
import '../../../data/models/paiement_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../controllers/facture_form_controller.dart';
import '../widgets/selecteurs.dart';

class FactureFormView extends GetView<FactureFormController> {
  const FactureFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle facture')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Obx(() {
                    final message = controller.erreur.value;
                    if (message == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: MessageBanner.erreur(message),
                    );
                  }),
                  _CarteClient(controller: controller),
                  const SizedBox(height: 12),
                  _CarteLignes(controller: controller),
                  const SizedBox(height: 12),
                  _CarteReglement(controller: controller),
                ],
              ),
            ),
            _BarreTotaux(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _CarteClient extends StatelessWidget {
  const _CarteClient({required this.controller});

  final FactureFormController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Obx(() {
            final c = controller.client.value;
            return ListTile(
              leading: Icon(Icons.person_outline,
                  color: AppColors.primary(context)),
              title: Text(c?.nom ?? 'Choisir un client'),
              subtitle: c != null && c.solde > 0
                  ? Text(
                      'Solde actuel : '
                      '${Formats.montant(c.solde, devise: controller.devise)}',
                      style: const TextStyle(color: AppColors.warning),
                    )
                  : null,
              trailing: const Icon(Icons.expand_more),
              onTap: () async {
                final choisi = await choisirClient(
                  controller.clients,
                  selection: controller.client.value,
                );
                if (choisi != null) controller.choisirClient(choisi);
              },
            );
          }),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Obx(
            () => ListTile(
              leading: Icon(Icons.event_outlined,
                  color: AppColors.primary(context)),
              title: Text(Formats.dateLongue(controller.date.value)),
              subtitle: const Text('Date de la facture'),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () => controller.choisirDate(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarteLignes extends StatelessWidget {
  const _CarteLignes({required this.controller});

  final FactureFormController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'ARTICLES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.primary(context),
                  ),
                ),
                const Spacer(),
                Obx(
                  () => Text(
                    '${controller.lignes.length} ligne(s)',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Obx(() {
              if (controller.lignes.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Aucun article. Ajoutez-en un pour commencer.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted(context)),
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < controller.lignes.length; i++)
                    _Ligne(
                      ligne: controller.lignes[i],
                      devise: controller.devise,
                      onQuantite: (q) => controller.modifierQuantite(i, q),
                      onPrix: (p) => controller.modifierPrix(i, p),
                      onRetirer: () => controller.retirerLigne(i),
                    ),
                ],
              );
            }),
            const SizedBox(height: 8),
            Obx(() {
              // Un bouton grisé ne dit pas pourquoi il l'est. Les deux causes
              // possibles appellent deux gestes différents, on les nomme.
              if (controller.catalogueVide) {
                return _CatalogueIndisponible(
                  message: 'Votre catalogue est vide. Ajoutez au moins un '
                      'article pour pouvoir facturer.',
                  libelleAction: 'Ouvrir le catalogue',
                );
              }
              if (controller.toutDesactive) {
                return _CatalogueIndisponible(
                  message: 'Tous vos articles sont désactivés, ils ne sont '
                      'donc pas facturables. C\'est souvent la conséquence '
                      'd\'une catégorie désactivée, qui ferme ses articles '
                      'en cascade : réactivez la catégorie, puis les articles '
                      'dont vous avez besoin.',
                  libelleAction: 'Ouvrir le catalogue',
                );
              }
              return OutlinedButton.icon(
                onPressed: () async {
                  final a = await choisirArticle(
                    controller.articles,
                    devise: controller.devise,
                  );
                  if (a != null) controller.ajouterArticle(a);
                },
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un article'),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.ligne,
    required this.devise,
    required this.onQuantite,
    required this.onPrix,
    required this.onRetirer,
  });

  final LigneFacture ligne;
  final String devise;
  final ValueChanged<double> onQuantite;
  final ValueChanged<double> onPrix;
  final VoidCallback onRetirer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ligne.designation,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text(context),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18),
                color: AppColors.danger,
                onPressed: onRetirer,
              ),
            ],
          ),
          Row(
            children: [
              _Compteur(
                quantite: ligne.quantite,
                unite: ligne.unite,
                onChange: onQuantite,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => _modifierPrix(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '× ${Formats.montant(ligne.prixUnitaire)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted(context),
                        decoration: TextDecoration.underline,
                        decorationStyle: TextDecorationStyle.dotted,
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                Formats.montant(ligne.montant, devise: devise),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent(context),
                ),
              ),
            ],
          ),
          const Divider(height: 12),
        ],
      ),
    );
  }

  /// Le prix reste modifiable ligne à ligne : une remise ou un prix négocié
  /// se décide au comptoir, sans passer par une modification du catalogue.
  Future<void> _modifierPrix(BuildContext context) async {
    final ctrl = TextEditingController(
      text: ligne.prixUnitaire == ligne.prixUnitaire.roundToDouble()
          ? ligne.prixUnitaire.toStringAsFixed(0)
          : ligne.prixUnitaire.toString(),
    );
    final resultat = await Get.dialog<double>(
      AlertDialog(
        title: Text(ligne.designation),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Prix unitaire',
            suffixText: devise,
            helperText: 'Ne modifie pas le prix du catalogue',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Annuler')),
          TextButton(
            onPressed: () =>
                Get.back(result: Validators.parseMontant(ctrl.text)),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (resultat != null && resultat > 0) onPrix(resultat);
  }
}

class _Compteur extends StatelessWidget {
  const _Compteur({
    required this.quantite,
    required this.unite,
    required this.onChange,
  });

  final double quantite;
  final String unite;
  final ValueChanged<double> onChange;

  @override
  Widget build(BuildContext context) {
    final texte = quantite == quantite.roundToDouble()
        ? quantite.toStringAsFixed(0)
        : quantite.toString();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border(context)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BoutonCompteur(
            icone: Icons.remove,
            onTap: () => onChange(quantite - 1),
          ),
          InkWell(
            onTap: () => _saisirQuantite(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                '$texte $unite',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          _BoutonCompteur(
            icone: Icons.add,
            onTap: () => onChange(quantite + 1),
          ),
        ],
      ),
    );
  }

  /// Saisie directe : au-delà de quelques unités, taper la quantité est plus
  /// rapide que de marteler le bouton.
  Future<void> _saisirQuantite(BuildContext context) async {
    final ctrl = TextEditingController(
      text: quantite == quantite.roundToDouble()
          ? quantite.toStringAsFixed(0)
          : quantite.toString(),
    );
    final resultat = await Get.dialog<double>(
      AlertDialog(
        title: const Text('Quantité'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: unite),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Annuler')),
          TextButton(
            onPressed: () =>
                Get.back(result: Validators.parseMontant(ctrl.text)),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (resultat != null) onChange(resultat);
  }
}

class _BoutonCompteur extends StatelessWidget {
  const _BoutonCompteur({required this.icone, required this.onTap});

  final IconData icone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icone, size: 18, color: AppColors.primary(context)),
      ),
    );
  }
}

class _CarteReglement extends StatelessWidget {
  const _CarteReglement({required this.controller});

  final FactureFormController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'RÈGLEMENT IMMÉDIAT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.primary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Laissez vide si le client règlera plus tard.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted(context),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.paiementCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('Solder la facture'),
              ),
            ),
            Obx(
              () => Wrap(
                spacing: 8,
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
          ],
        ),
      ),
    );
  }
}

/// Barre de totaux fixée en bas : le montant à annoncer au client doit
/// rester visible pendant toute la saisie, sans avoir à faire défiler.
class _BarreTotaux extends StatelessWidget {
  const _BarreTotaux({required this.controller});

  final FactureFormController controller;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<FactureFormController>(
      builder: (_) => Obx(() {
        // Lecture des observables pour que la barre se reconstruise à chaque
        // modification de ligne.
        controller.lignes.length;
        final ht = controller.montantHT;
        final tva = controller.montantTva;
        final total = controller.montantTotal;
        final reste = controller.resteDu;

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            border: Border(top: BorderSide(color: AppColors.border(context))),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radius),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.tvaActive) ...[
                _LigneTotal(
                  libelle: 'Montant HT',
                  valeur: Formats.montant(ht, devise: controller.devise),
                ),
                _LigneTotal(
                  libelle: 'TVA ${Formats.pourcentage(controller.tauxTva)}',
                  valeur: Formats.montant(tva, devise: controller.devise),
                ),
                const Divider(height: 14),
              ],
              _LigneTotal(
                libelle: 'Total',
                valeur: Formats.montant(total, devise: controller.devise),
                gras: true,
              ),
              if (reste > 0 && controller.paiementImmediat > 0)
                _LigneTotal(
                  libelle: 'Reste à payer',
                  valeur: Formats.montant(reste, devise: controller.devise),
                  couleur: AppColors.warning,
                ),
              const SizedBox(height: 12),
              Obx(
                () => ElevatedButton(
                  onPressed: controller.enregistrement.value ||
                          !controller.pretAEnregistrer
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
                      : const Text('Émettre la facture'),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _LigneTotal extends StatelessWidget {
  const _LigneTotal({
    required this.libelle,
    required this.valeur,
    this.gras = false,
    this.couleur,
  });

  final String libelle;
  final String valeur;
  final bool gras;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: gras ? 17 : 13.5,
      fontWeight: gras ? FontWeight.w700 : FontWeight.w500,
      color: couleur ?? (gras ? AppColors.text(context) : AppColors.textMuted(context)),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(libelle, style: style), Text(valeur, style: style)],
      ),
    );
  }
}

/// Explique pourquoi aucun article n'est proposable, et renvoie là où le
/// problème se corrige. Seul l'administrateur gère le catalogue ; le vendeur
/// voit le même message mais devra le signaler.
class _CatalogueIndisponible extends StatelessWidget {
  const _CatalogueIndisponible({
    required this.message,
    required this.libelleAction,
  });

  final String message;
  final String libelleAction;

  @override
  Widget build(BuildContext context) {
    final estAdmin = SessionController.to.peutGererReferentiels;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 20, color: AppColors.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          if (estAdmin) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Get.toNamed(AppRoutes.articles),
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: Text(libelleAction),
            ),
          ],
        ],
      ),
    );
  }
}
