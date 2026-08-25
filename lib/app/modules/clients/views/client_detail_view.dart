import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/format_helpers.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/statut_chip.dart';
import '../../../data/models/client_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../controllers/client_detail_controller.dart';

class ClientDetailView extends GetView<ClientDetailController> {
  const ClientDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiche client'),
        actions: [
          Obx(() {
            final c = controller.client.value;
            if (c == null) return const SizedBox.shrink();
            return IconButton(
              tooltip: 'Modifier',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  Get.toNamed(AppRoutes.clientForm, arguments: c),
            );
          }),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.introuvable.value) {
            return const EmptyState(
              icone: Icons.person_off_outlined,
              titre: 'Client introuvable',
              description: 'Cette fiche n\'est plus accessible.',
            );
          }
          final c = controller.client.value;
          if (c == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _Entete(client: c, devise: controller.devise),
              const SizedBox(height: 20),
              _Coordonnees(client: c),
              const SizedBox(height: 20),
              const _HistoriqueAVenir(),
            ],
          );
        }),
      ),
    );
  }
}

class _Entete extends StatelessWidget {
  const _Entete({required this.client, required this.devise});

  final ClientModel client;
  final String devise;

  @override
  Widget build(BuildContext context) {
    final couleurSolde = client.aUneDette
        ? AppColors.warning
        : (client.aUneAvance ? AppColors.success : Colors.white70);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandPrimary, AppColors.brandPrimaryDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white24,
                child: client.estDivers
                    ? const Icon(Icons.storefront_outlined,
                        color: Colors.white)
                    : Text(
                        client.initiales,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  client.nom,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!client.active)
                const StatutChip(actif: false, labelInactif: 'Inactif'),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            client.aUneDette
                ? 'Reste à payer'
                : (client.aUneAvance ? 'Avance versée' : 'Solde'),
            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
          const SizedBox(height: 2),
          Text(
            Formats.montant(client.solde.abs(), devise: devise),
            style: TextStyle(
              color: couleurSolde,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Coordonnees extends StatelessWidget {
  const _Coordonnees({required this.client});

  final ClientModel client;

  @override
  Widget build(BuildContext context) {
    final telephone = client.telephone ?? '';
    final adresse = client.adresse ?? '';
    if (telephone.isEmpty && adresse.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            if (telephone.isNotEmpty)
              ListTile(
                leading: Icon(Icons.phone_outlined,
                    color: AppColors.primary(context)),
                title: Text(telephone),
                subtitle: const Text('Téléphone'),
              ),
            if (telephone.isNotEmpty && adresse.isNotEmpty)
              const Divider(height: 1, indent: 16, endIndent: 16),
            if (adresse.isNotEmpty)
              ListTile(
                leading: Icon(Icons.place_outlined,
                    color: AppColors.primary(context)),
                title: Text(adresse),
                subtitle: const Text('Adresse'),
              ),
          ],
        ),
      ),
    );
  }
}

/// L'historique par client — factures, paiements et relevé de compte — est
/// prévu par le CDC §5 mais dépend des collections `factures` et
/// `paiements`, qui n'existent pas encore. La place est réservée ici plutôt
/// que de laisser croire que la fiche est complète.
class _HistoriqueAVenir extends StatelessWidget {
  const _HistoriqueAVenir();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 36, color: AppColors.textMuted(context)),
          const SizedBox(height: 12),
          Text(
            'Historique',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Les factures et paiements de ce client apparaîtront ici avec le '
            'module Facturation.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }
}
