import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/format_helpers.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/message_banner.dart';
import '../../../data/models/paiement_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../core/utils/marges_ecran.dart';
import '../controllers/paiement_detail_controller.dart';

class PaiementDetailView extends GetView<PaiementDetailController> {
  const PaiementDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Règlement'),
        actions: [
          Obx(
            () => controller.paiement.value == null
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Imprimer ou partager le reçu',
                    icon: const Icon(Icons.print_outlined),
                    onPressed: controller.imprimer,
                  ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Obx(() {
          if (controller.introuvable.value) {
            return const EmptyState(
              icone: Icons.payments_outlined,
              titre: 'Règlement introuvable',
              description: 'Ce document n\'est plus accessible.',
            );
          }
          final p = controller.paiement.value;
          if (p == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + margeBasse(context)),
            children: [
              if (p.annule) ...[
                MessageBanner.attention(
                  'Règlement annulé le ${Formats.date(p.annuleLe)}'
                  '${p.annuleParNom == null ? '' : ' par ${p.annuleParNom}'}'
                  '${p.motifAnnulation == null ? '' : '.\nMotif : ${p.motifAnnulation}'}',
                ),
                const SizedBox(height: 16),
              ],
              _Entete(paiement: p, devise: controller.devise),
              if ((p.note ?? '').isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.notes_rounded,
                      color: AppColors.primary(context),
                    ),
                    title: Text(p.note!),
                    subtitle: const Text('Note'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _Imputations(paiement: p, devise: controller.devise),
              const SizedBox(height: 16),
              Text(
                'Encaissé par ${p.creeParNom}'
                '${p.createdAt == null ? '' : ' le ${Formats.dateHeure(p.createdAt)}'}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted(context),
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: controller.imprimer,
                icon: const Icon(Icons.print_outlined, size: 18),
                label: const Text('Imprimer ou partager le reçu'),
              ),
              const SizedBox(height: 12),
              Obx(() {
                if (!controller.peutAnnuler) return const SizedBox.shrink();
                return OutlinedButton.icon(
                  onPressed: controller.annulationEnCours.value
                      ? null
                      : () => controller.annuler(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  icon: const Icon(Icons.block, size: 18),
                  label: const Text('Annuler ce règlement'),
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
  const _Entete({required this.paiement, required this.devise});

  final PaiementModel paiement;
  final String devise;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: paiement.annule
              ? [AppColors.cancelled, const Color(0xFF6B7785)]
              : [AppColors.brandAccent, AppColors.brandPrimaryDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            paiement.clientNom,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${Formats.dateLongue(paiement.date)} · ${paiement.mode.label}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 18),
          Text(
            Formats.montant(paiement.montant, devise: devise),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!paiement.annule && paiement.montantEnAvance > 0)
            Text(
              'dont ${Formats.montant(paiement.montantEnAvance, devise: devise)} '
              'conservés en avance',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
        ],
      ),
    );
  }
}

class _Imputations extends StatelessWidget {
  const _Imputations({required this.paiement, required this.devise});

  final PaiementModel paiement;
  final String devise;

  @override
  Widget build(BuildContext context) {
    if (paiement.imputations.isEmpty) {
      return MessageBanner.info(
        paiement.annule
            ? 'Les imputations de ce règlement ont été défaites lors de son '
                  'annulation.'
            : 'Ce règlement n\'a soldé aucune facture : il reste entièrement '
                  'en avance au crédit du client.',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'FACTURES SOLDÉES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.primary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Lettrage automatique, de la plus ancienne à la plus récente.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted(context),
              ),
            ),
            const SizedBox(height: 6),
            for (final i in paiement.imputations)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.receipt_long_outlined,
                  color: AppColors.primary(context),
                ),
                title: Text(i.factureNumero),
                trailing: Text(
                  Formats.montant(i.montant, devise: devise),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
                onTap: i.factureId.isEmpty
                    ? null
                    : () => Get.toNamed(
                        AppRoutes.factureDetail,
                        arguments: i.factureId,
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
