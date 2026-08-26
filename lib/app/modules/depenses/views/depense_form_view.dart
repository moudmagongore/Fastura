import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../core/utils/format_helpers.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/message_banner.dart';
import '../../../data/models/nature_depense_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../core/utils/marges_ecran.dart';
import '../controllers/depense_form_controller.dart';

class DepenseFormView extends GetView<DepenseFormController> {
  const DepenseFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle dépense')),
      body: SafeArea(
        bottom: false,
        child: Obx(() {
          if (controller.chargement.value) {
            return const Center(child: CircularProgressIndicator());
          }

          // Sans nomenclature, rien à saisir. Dire lequel des deux rôles
          // peut la créer évite au vendeur de chercher un écran qu'il n'a
          // pas (CDC §7).
          if (controller.aucuneNature) {
            return EmptyState(
              icone: Icons.label_off_outlined,
              titre: 'Aucune nature de dépense',
              description: controller.peutGererNatures
                  ? 'Définissez d\'abord votre nomenclature : loyer, '
                        'carburant, fournitures… Une dépense se range toujours '
                        'dans une nature.'
                  : 'Votre administrateur doit définir la nomenclature des '
                        'dépenses avant que vous puissiez en enregistrer une.',
              action: controller.peutGererNatures
                  ? ElevatedButton.icon(
                      onPressed: () => Get.toNamed(AppRoutes.naturesDepense),
                      icon: const Icon(Icons.label_outline),
                      label: const Text('Gérer les natures'),
                    )
                  : null,
            );
          }

          return Form(
            key: controller.formKey,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                32 + margeBasse(context),
              ),
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
                    initialValue: controller.natureId.value,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Nature *',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    items: [
                      for (final NatureDepenseModel n in controller.natures)
                        DropdownMenuItem(
                          value: n.id,
                          child: Text(
                            n.libelle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => controller.natureId.value = v,
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: controller.montantCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Montant *',
                    suffixText: controller.devise,
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                  validator: controller.validerMontant,
                ),
                const SizedBox(height: 16),

                Obx(
                  () => InkWell(
                    onTap: () => controller.choisirDate(context),
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        prefixIcon: Icon(Icons.event_outlined),
                      ),
                      child: Text(Formats.date(controller.date.value)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: controller.descriptionCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    helperText: 'À qui, pourquoi, référence de la pièce',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 20),

                // Le justificatif photo du CDC §7 attend que Firebase
                // Storage soit provisionné sur le projet.
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.photo_camera_outlined,
                        color: AppColors.textMuted(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Justificatif photo : bientôt disponible',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                      ),
                    ],
                  ),
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
                        : const Text('Enregistrer la dépense'),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Une dépense ne se modifie pas après coup : comme une '
                  'facture, elle se corrige par annulation puis nouvelle '
                  'saisie.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted(context),
                  ),
                ),
                if (!SessionController.to.peutAnnuler) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Seul un administrateur peut annuler.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}
