import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/format_helpers.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/statut_chip.dart';
import '../../../data/models/client_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../controllers/clients_controller.dart';

class ClientsListView extends GetView<ClientsController> {
  const ClientsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Écran de premier niveau : le bouton du tiroir à gauche, et jamais
        // de flèche de retour — on circule par le menu.
        // `automaticallyImplyLeading: false` empêche `Scaffold` de poser sa
        // propre flèche ; le bouton du tiroir, lui, est posé explicitement
        // et ne dépend donc pas de ce qu'il y a dans la pile.
        automaticallyImplyLeading: false,
        leading: const DrawerButton(),
        title: const Text('Clients'),
        actions: [
          Obx(
            () => IconButton(
              tooltip: controller.masquerInactifs.value
                  ? 'Afficher les inactifs'
                  : 'Masquer les inactifs',
              icon: Icon(
                controller.masquerInactifs.value
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined,
              ),
              onPressed: () => controller.masquerInactifs.toggle(),
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(AppRoutes.clientForm),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Client'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => controller.recherche.value = v,
              decoration: const InputDecoration(
                hintText: 'Rechercher par nom, téléphone ou adresse…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          _Bandeau(controller: controller),
          Expanded(
            child: Obx(() {
              if (controller.chargement.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final liste = controller.resultats;
              if (liste.isEmpty) {
                return EmptyState(
                  icone: Icons.people_outline,
                  titre: controller.clients.isEmpty
                      ? 'Aucun client'
                      : 'Aucun résultat',
                  description: controller.clients.isEmpty
                      ? 'Ajoutez vos clients pour suivre leurs factures et '
                            'leur solde. Les ventes comptant passent par le '
                            'client divers.'
                      : 'Aucun client ne correspond à cette recherche.',
                  action: controller.clients.isEmpty
                      ? ElevatedButton.icon(
                          onPressed: () => Get.toNamed(AppRoutes.clientForm),
                          icon: const Icon(Icons.person_add_alt),
                          label: const Text('Ajouter un client'),
                        )
                      : null,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: liste.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _ClientCard(
                  client: liste[i],
                  devise: controller.devise,
                  onOuvrir: () =>
                      Get.toNamed(AppRoutes.clientDetail, arguments: liste[i]),
                  onModifier: () =>
                      Get.toNamed(AppRoutes.clientForm, arguments: liste[i]),
                  onBasculer: () => controller.basculerActivation(liste[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Compteur d'actifs et total des créances, avec le filtre « uniquement les
/// clients qui doivent » — le geste le plus fréquent avant une tournée de
/// recouvrement.
class _Bandeau extends StatelessWidget {
  const _Bandeau({required this.controller});

  final ClientsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final total = controller.totalCreances;
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 12, 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${controller.nbActifs} actif(s) sur '
                    '${controller.clients.length}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                  if (total > 0)
                    Text(
                      'Créances en cours : '
                      '${Formats.montant(total, devise: controller.devise)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                ],
              ),
            ),
            // `FilterChip` garde `labelStyle` même coché, contrairement à
            // `ChoiceChip` : le thème ne peut pas le passer en blanc.
            FilterChip(
              label: const Text('Avec solde'),
              selected: controller.soldeSeulement.value,
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: controller.soldeSeulement.value
                    ? FontWeight.w700
                    : FontWeight.w600,
                color: controller.soldeSeulement.value
                    ? Colors.white
                    : AppColors.textMuted(context),
              ),
              onSelected: (_) => controller.soldeSeulement.toggle(),
            ),
          ],
        ),
      );
    });
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({
    required this.client,
    required this.devise,
    required this.onOuvrir,
    required this.onModifier,
    required this.onBasculer,
  });

  final ClientModel client;
  final String devise;
  final VoidCallback onOuvrir;
  final VoidCallback onModifier;
  final VoidCallback onBasculer;

  @override
  Widget build(BuildContext context) {
    final couleurAvatar = client.estDivers
        ? AppColors.brandAccent
        : AppColors.primary(context);

    return Card(
      child: InkWell(
        onTap: onOuvrir,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: couleurAvatar.withValues(alpha: 0.15),
                child: client.estDivers
                    ? Icon(
                        Icons.storefront_outlined,
                        size: 20,
                        color: couleurAvatar,
                      )
                    : Text(
                        client.initiales,
                        style: TextStyle(
                          color: couleurAvatar,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.nom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text(context),
                      ),
                    ),
                    if ((client.telephone ?? '').isNotEmpty)
                      Text(
                        client.telephone!,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted(context),
                        ),
                      ),
                    if (client.solde != 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          client.aUneDette
                              ? 'Doit ${Formats.montant(client.solde, devise: devise)}'
                              : 'Avance ${Formats.montant(-client.solde, devise: devise)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: client.aUneDette
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!client.active) const StatutChip(actif: false),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'modifier') onModifier();
                  if (v == 'bascule') onBasculer();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'modifier',
                    child: Text('Modifier'),
                  ),
                  if (!client.estDivers)
                    PopupMenuItem(
                      value: 'bascule',
                      child: Text(
                        client.active ? 'Désactiver' : 'Réactiver',
                        style: TextStyle(
                          color: client.active
                              ? AppColors.danger
                              : AppColors.success,
                        ),
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
