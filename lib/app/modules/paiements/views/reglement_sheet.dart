import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/services/recu_pdf_service.dart';
import '../../../core/services/session_controller.dart';
import '../../../core/utils/bottom_sheet_helpers.dart';
import '../../../core/utils/pdf_helper.dart';
import '../../../core/utils/format_helpers.dart';
import '../../../core/widgets/message_banner.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/paiement_model.dart';
import '../../../theme/app_colors.dart';
import '../controllers/paiement_form_controller.dart';

/// Feuille de saisie d'un règlement pour un client donné.
///
/// Le montant est pré-rempli avec la dette en cours : c'est ce que le client
/// vient solder neuf fois sur dix. L'aperçu du lettrage montre en dessous
/// quelles factures seront soldées, avant validation — un lettrage
/// automatique qu'on ne peut pas prévisualiser reste une boîte noire au
/// comptoir.
class ReglementSheet extends StatefulWidget {
  const ReglementSheet({super.key});

  /// Ouvre la feuille pour [client]. Renvoie le règlement enregistré, ou
  /// `null` si l'utilisateur renonce.
  static Future<PaiementModel?> ouvrir(ClientModel client) async {
    Get.put(PaiementFormController(client: client));
    final resultat = await Get.bottomSheet<PaiementModel>(
      const ReglementSheet(),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );

    if (resultat != null) await _proposerRecu(client, resultat);
    return resultat;
  }

  @override
  State<ReglementSheet> createState() => _ReglementSheetState();

  /// Propose le reçu dans la foulée : c'est la preuve que le client attend
  /// avant de repartir.
  static Future<void> _proposerRecu(
    ClientModel client,
    PaiementModel paiement,
  ) async {
    final tenant = SessionController.to.tenant.value;
    if (tenant == null) return;

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Imprimer le reçu ?'),
        content: Text(
          'Voulez-vous remettre un reçu à ${client.nom} pour les '
          '${Formats.montant(paiement.montant, devise: tenant.devise)} '
          'encaissés ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Plus tard'),
          ),
          ElevatedButton.icon(
            onPressed: () => Get.back(result: true),
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text('Imprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // Le document client lu peut ne pas encore refléter l'encaissement : on
    // déduit le solde du montant versé plutôt que d'attendre le stream.
    final soldeApres = client.solde - paiement.montant;

    await genererPuisImprimer(
      generer: () => RecuPdfService.construire(
        paiement: paiement,
        tenant: tenant,
        soldeApres: soldeApres,
      ),
      nomFichier: 'Recu-${client.nom}-${paiement.id}',
      titre: 'Recu de ${client.nom}',
    );
  }
}

class _ReglementSheetState extends State<ReglementSheet> {
  /// Le contrôleur meurt avec le widget, pas avec le futur de la feuille.
  ///
  /// `Get.back()` résout ce futur immédiatement, mais la feuille continue de
  /// se construire pendant son animation de fermeture : le détruire là
  /// disposait `montantCtrl` sous les pieds d'un `TextField` encore à
  /// l'écran — « A TextEditingController was used after being disposed ».
  /// `dispose()` n'est appelé qu'une fois la route réellement retirée.
  @override
  void dispose() {
    Get.delete<PaiementFormController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PaiementFormController>();
    final client = controller.client;

    return CadreSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PoigneeSheet(),
          EnteteSheet(
            icone: Icons.payments_rounded,
            couleur: AppColors.success,
            titre: 'Encaisser ${client.nom}',
            sousTitre: client.solde > 0
                ? 'Solde dû : '
                      '${Formats.montant(client.solde, devise: controller.devise)}'
                : (client.solde < 0
                      ? 'Avance en cours : '
                            '${Formats.montant(-client.solde, devise: controller.devise)}'
                      : 'Aucune créance en cours'),
            couleurSousTitre: client.solde > 0 ? AppColors.warning : null,
          ),
          const SizedBox(height: 18),

          Obx(() {
            final message = controller.erreur.value;
            if (message == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: MessageBanner.erreur(message),
            );
          }),

          TextField(
            controller: controller.montantCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onChanged: (_) => controller.update(),
            decoration: InputDecoration(
              labelText: 'Montant reçu *',
              suffixText: controller.devise,
              prefixIcon: const Icon(Icons.payments_outlined),
            ),
          ),

          GetBuilder<PaiementFormController>(
            builder: (_) => Obx(() {
              if (controller.totalAApurer <= 0) {
                return const SizedBox(height: 10);
              }
              return Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: controller.solderTout,
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: Text(
                    'Solder tout '
                    '(${Formats.montant(controller.totalAApurer, devise: controller.devise)})',
                  ),
                ),
              );
            }),
          ),

          Row(
            children: [
              Text(
                'MODE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: AppColors.textMuted(context),
                ),
              ),
              const Spacer(),
              Obx(
                () => TextButton.icon(
                  onPressed: () => controller.choisirDate(context),
                  icon: const Icon(Icons.event_outlined, size: 16),
                  label: Text(Formats.date(controller.date.value)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Obx(
            () => Wrap(
              spacing: 8,
              runSpacing: 4,
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

          const SizedBox(height: 14),
          TextField(
            controller: controller.noteCtrl,
            minLines: 1,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Note (facultatif)',
              hintText: 'N° de chèque, référence de transfert…',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),

          const SizedBox(height: 16),
          _Lettrage(controller: controller),

          const SizedBox(height: 18),
          GetBuilder<PaiementFormController>(
            builder: (_) => Obx(
              () => ElevatedButton.icon(
                onPressed:
                    controller.enregistrement.value ||
                        !controller.pretAEnregistrer
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
                    : const Icon(Icons.check_rounded),
                label: Text(
                  controller.enregistrement.value
                      ? 'Enregistrement…'
                      : 'Enregistrer le règlement',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aperçu du lettrage FIFO, recalculé à chaque frappe.
class _Lettrage extends StatelessWidget {
  const _Lettrage({required this.controller});

  final PaiementFormController controller;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PaiementFormController>(
      builder: (_) => Obx(() {
        if (controller.chargement.value) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (controller.aApurer.isEmpty) {
          return MessageBanner.info(
            'Ce client n\'a aucune facture impayée. Le montant encaissé '
            'restera en avance à son crédit et se déduira de ses prochaines '
            'factures.',
          );
        }

        final apercu = controller.apercu;

        return Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: AppColors.background(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.playlist_add_check_rounded,
                    size: 16,
                    color: AppColors.primary(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LETTRAGE AUTOMATIQUE',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.primary(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Les factures les plus anciennes sont soldées en premier.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted(context),
                ),
              ),
              const SizedBox(height: 10),
              for (final f in controller.aApurer)
                _LigneLettrage(
                  numero: f.numero,
                  date: f.date,
                  resteDu: f.resteDu,
                  impute:
                      apercu
                          .where((a) => a.facture.id == f.id)
                          .firstOrNull
                          ?.montant ??
                      0,
                  solde:
                      apercu
                          .where((a) => a.facture.id == f.id)
                          .firstOrNull
                          ?.solde ??
                      false,
                  devise: controller.devise,
                ),
              if (controller.avance > 0) ...[
                const Divider(height: 18),
                Row(
                  children: [
                    const Icon(
                      Icons.savings_outlined,
                      size: 16,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Avance conservée au crédit du client',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted(context),
                        ),
                      ),
                    ),
                    Text(
                      Formats.montant(
                        controller.avance,
                        devise: controller.devise,
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      }),
    );
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
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(
              solde
                  ? Icons.check_circle_rounded
                  : (touchee
                        ? Icons.incomplete_circle_rounded
                        : Icons.radio_button_unchecked_rounded),
              size: 17,
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
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${Formats.date(date)} · reste '
                    '${Formats.montant(resteDu, devise: devise)}',
                    style: TextStyle(
                      fontSize: 11,
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
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: solde ? AppColors.success : AppColors.warning,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
