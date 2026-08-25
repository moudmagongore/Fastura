import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/format_helpers.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/models/paiement_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../controllers/paiements_controller.dart';

class PaiementsListView extends GetView<PaiementsController> {
  const PaiementsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiements'),
        actions: [
          Obx(
            () => IconButton(
              tooltip: controller.masquerAnnules.value
                  ? 'Afficher les annulés'
                  : 'Masquer les annulés',
              icon: Icon(
                controller.masquerAnnules.value
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined,
              ),
              onPressed: () => controller.masquerAnnules.toggle(),
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(AppRoutes.paiementForm),
        icon: const Icon(Icons.add),
        label: const Text('Encaisser'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => controller.recherche.value = v,
              decoration: const InputDecoration(
                hintText: 'Rechercher par client ou numéro de facture…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Obx(
            () => Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Encaissé : '
                  '${Formats.montant(controller.totalEncaisse, devise: controller.devise)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
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
                  icone: Icons.payments_outlined,
                  titre: controller.paiements.isEmpty
                      ? 'Aucun règlement'
                      : 'Aucun résultat',
                  description: controller.paiements.isEmpty
                      ? 'Les règlements encaissés apparaîtront ici, du plus '
                          'récent au plus ancien.'
                      : 'Aucun règlement ne correspond à cette recherche.',
                  action: controller.paiements.isEmpty
                      ? ElevatedButton.icon(
                          onPressed: () => Get.toNamed(AppRoutes.paiementForm),
                          icon: const Icon(Icons.add),
                          label: const Text('Encaisser un règlement'),
                        )
                      : null,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: liste.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _PaiementCard(
                  paiement: liste[i],
                  devise: controller.devise,
                  onTap: () => Get.toNamed(
                    AppRoutes.paiementDetail,
                    arguments: liste[i],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _PaiementCard extends StatelessWidget {
  const _PaiementCard({
    required this.paiement,
    required this.devise,
    required this.onTap,
  });

  final PaiementModel paiement;
  final String devise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final numeros = paiement.imputations
        .map((i) => i.factureNumero)
        .where((n) => n.isNotEmpty)
        .join(', ');

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: (paiement.annule
                        ? AppColors.cancelled
                        : AppColors.success)
                    .withValues(alpha: 0.15),
                child: Icon(
                  Icons.payments_outlined,
                  size: 20,
                  color: paiement.annule
                      ? AppColors.cancelled
                      : AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paiement.clientNom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text(context),
                        decoration: paiement.annule
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    Text(
                      '${Formats.date(paiement.date)} · '
                      '${paiement.mode.label}'
                      '${paiement.directALaFacturation ? ' · à la facturation' : ''}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                    if (numeros.isNotEmpty)
                      Text(
                        numeros,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted(context),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formats.montant(paiement.montant, devise: devise),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: paiement.annule
                          ? AppColors.cancelled
                          : AppColors.success,
                    ),
                  ),
                  if (paiement.annule)
                    const Text(
                      'Annulé',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.cancelled,
                      ),
                    )
                  else if (paiement.montantEnAvance > 0)
                    Text(
                      'dont ${Formats.montant(paiement.montantEnAvance)} '
                      'en avance',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
