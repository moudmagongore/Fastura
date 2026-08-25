import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/format_helpers.dart';
import '../../../core/widgets/message_banner.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../factures/widgets/selecteurs.dart';
import '../../../data/models/paiement_model.dart';
import '../controllers/paiement_form_controller.dart';

class PaiementFormView extends GetView<PaiementFormController> {
  const PaiementFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Encaisser un règlement')),
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
                  _CarteMontant(controller: controller),
                  const SizedBox(height: 12),
                  _CarteLettrage(controller: controller),
                ],
              ),
            ),
            _BarreValidation(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _CarteClient extends StatelessWidget {
  const _CarteClient({required this.controller});

  final PaiementFormController controller;

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
              subtitle: c == null
                  ? null
                  : Text(
                      c.solde > 0
                          ? 'Doit ${Formats.montant(c.solde, devise: controller.devise)}'
                          : (c.solde < 0
                              ? 'Avance ${Formats.montant(-c.solde, devise: controller.devise)}'
                              : 'Compte soldé'),
                      style: TextStyle(
                        color: c.solde > 0
                            ? AppColors.warning
                            : AppColors.textMuted(context),
                      ),
                    ),
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
              subtitle: const Text('Date du règlement'),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () => controller.choisirDate(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarteMontant extends StatelessWidget {
  const _CarteMontant({required this.controller});

  final PaiementFormController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller.montantCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => controller.update(),
              decoration: InputDecoration(
                labelText: 'Montant reçu *',
                suffixText: controller.devise,
                prefixIcon: const Icon(Icons.payments_outlined),
              ),
            ),
            Obx(() {
              if (controller.totalAApurer <= 0) return const SizedBox.shrink();
              return Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: controller.solderTout,
                  icon: const Icon(Icons.done_all, size: 18),
                  label: Text(
                    'Solder tout '
                    '(${Formats.montant(controller.totalAApurer, devise: controller.devise)})',
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
            Obx(
              () => Wrap(
                spacing: 8,
                children: [
                  for (final m in ModePaiement.values)
                    ChoiceChip(
                      label: Text(m.label),
                      selected: controller.mode.value == m,
                      onSelected: (_) => controller.mode.value = m,
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

/// Aperçu du lettrage FIFO. C'est la pièce maîtresse de l'écran : le vendeur
/// doit voir ce que son encaissement va solder **avant** de valider, faute de
/// quoi le lettrage automatique reste une boîte noire au comptoir.
class _CarteLettrage extends StatelessWidget {
  const _CarteLettrage({required this.controller});

  final PaiementFormController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.client.value == null) return const SizedBox.shrink();
      if (controller.chargementFactures.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        );
      }

      if (controller.aApurer.isEmpty) {
        return MessageBanner.info(
          'Ce client n\'a aucune facture impayée. Le montant encaissé restera '
          'en avance à son crédit et se déduira de ses prochaines factures.',
        );
      }

      final apercu = controller.apercu;

      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'LETTRAGE AUTOMATIQUE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.primary(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Les factures les plus anciennes sont soldées en premier.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted(context),
                ),
              ),
              const SizedBox(height: 12),
              for (final f in controller.aApurer) ...[
                Builder(builder: (context) {
                  final imputation = apercu
                      .where((a) => a.facture.id == f.id)
                      .firstOrNull;
                  return _LigneLettrage(
                    numero: f.numero,
                    date: f.date,
                    resteDu: f.resteDu,
                    impute: imputation?.montant ?? 0,
                    solde: imputation?.solde ?? false,
                    devise: controller.devise,
                  );
                }),
              ],
              if (controller.avance > 0) ...[
                const Divider(height: 20),
                Row(
                  children: [
                    const Icon(Icons.savings_outlined,
                        size: 18, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Avance conservée au crédit du client',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted(context),
                        ),
                      ),
                    ),
                    Text(
                      Formats.montant(controller.avance,
                          devise: controller.devise),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

class _LigneLettrage extends StatelessWidget {
  const _LigneLettrage({
    required this.numero,
    required this.date,
    required this.resteDu,
    required this.impute,
    required this.solde,
    required this.devise,
  });

  final String numero;
  final DateTime date;
  final double resteDu;
  final double impute;
  final bool solde;
  final String devise;

  @override
  Widget build(BuildContext context) {
    final touchee = impute > 0;

    return Opacity(
      opacity: touchee ? 1 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              solde
                  ? Icons.check_circle
                  : (touchee
                      ? Icons.incomplete_circle
                      : Icons.radio_button_unchecked),
              size: 18,
              color: solde
                  ? AppColors.success
                  : (touchee
                      ? AppColors.warning
                      : AppColors.textMuted(context)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    numero,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text(context),
                    ),
                  ),
                  Text(
                    '${Formats.date(date)} · reste '
                    '${Formats.montant(resteDu, devise: devise)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                ],
              ),
            ),
            if (touchee)
              Text(
                '− ${Formats.montant(impute, devise: devise)}',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: solde ? AppColors.success : AppColors.warning,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BarreValidation extends StatelessWidget {
  const _BarreValidation({required this.controller});

  final PaiementFormController controller;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PaiementFormController>(
      builder: (_) => Obx(() {
        final apercu = controller.apercu;
        final nbSoldees = apercu.where((a) => a.solde).length;

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Montant reçu',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                  Text(
                    Formats.montant(controller.montant,
                        devise: controller.devise),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text(context),
                    ),
                  ),
                ],
              ),
              if (apercu.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '$nbSoldees facture(s) soldée(s) sur '
                    '${apercu.length} touchée(s)',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted(context),
                    ),
                  ),
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
                      : const Text('Encaisser'),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
