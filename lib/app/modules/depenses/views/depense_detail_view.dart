import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/format_helpers.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/message_banner.dart';
import '../../../data/models/depense_model.dart';
import '../../../theme/app_colors.dart';
import '../../../core/utils/marges_ecran.dart';
import '../controllers/depense_detail_controller.dart';

class DepenseDetailView extends GetView<DepenseDetailController> {
  const DepenseDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dépense')),
      body: SafeArea(
        bottom: false,
        child: Obx(() {
          if (controller.introuvable.value) {
            return const EmptyState(
              icone: Icons.trending_down,
              titre: 'Dépense introuvable',
              description: 'Cette écriture n\'est plus accessible.',
            );
          }
          final d = controller.depense.value;
          if (d == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + margeBasse(context)),
            children: [
              if (d.annulee) ...[
                MessageBanner.attention(
                  'Dépense annulée le ${Formats.date(d.annuleeLe)}'
                  '${d.annuleeParNom == null ? '' : ' par ${d.annuleeParNom}'}'
                  '${d.motifAnnulation == null ? '' : '.\nMotif : ${d.motifAnnulation}'}',
                ),
                const SizedBox(height: 16),
              ],
              _Entete(depense: d, devise: controller.devise),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.event_outlined,
                        color: AppColors.primary(context),
                      ),
                      title: Text(Formats.date(d.date)),
                      subtitle: const Text('Date de la dépense'),
                    ),
                    if ((d.description ?? '').isNotEmpty)
                      ListTile(
                        leading: Icon(
                          Icons.notes_rounded,
                          color: AppColors.primary(context),
                        ),
                        title: Text(d.description!),
                        subtitle: const Text('Description'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Saisie par ${d.creeParNom}'
                '${d.createdAt == null ? '' : ' le ${Formats.dateHeure(d.createdAt)}'}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted(context),
                ),
              ),
              const SizedBox(height: 20),
              Obx(() {
                if (!controller.peutAnnuler) return const SizedBox.shrink();
                return OutlinedButton.icon(
                  onPressed: controller.annulationEnCours.value
                      ? null
                      : controller.annuler,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  icon: const Icon(Icons.block, size: 18),
                  label: const Text('Annuler cette dépense'),
                );
              }),
            ],
          );
        }),
      ),
    );
  }
}

class _Entete extends StatelessWidget {
  const _Entete({required this.depense, required this.devise});

  final DepenseModel depense;
  final String devise;

  @override
  Widget build(BuildContext context) {
    final couleur = depense.annulee ? AppColors.cancelled : AppColors.danger;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: couleur.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            depense.natureLibelle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            Formats.montant(depense.montant, devise: devise),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: couleur,
              decoration: depense.annulee ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}
