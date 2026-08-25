import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/format_helpers.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/statut_chip.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/paiement_model.dart';
import '../../../modules/factures/views/factures_list_view.dart'
    show FactureCard;
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
            return Row(
              children: [
                // Raccourci vers l'encaissement, avec le client déjà choisi :
                // c'est depuis sa fiche qu'on constate qu'il doit de l'argent.
                if (c.solde > 0)
                  IconButton(
                    tooltip: 'Encaisser un règlement',
                    icon: const Icon(Icons.payments_outlined),
                    onPressed: () =>
                        Get.toNamed(AppRoutes.paiementForm, arguments: c),
                  ),
                IconButton(
                  tooltip: 'Modifier',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      Get.toNamed(AppRoutes.clientForm, arguments: c),
                ),
              ],
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
              _Historique(controller: controller),
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

/// Historique du client : ses factures et ses règlements.
///
/// Les deux listes sont bornées côté repository — une fiche client n'a pas
/// vocation à rejouer trois ans d'activité à chaque ouverture.
class _Historique extends StatelessWidget {
  const _Historique({required this.controller});

  final ClientDetailController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final factures = controller.factures;
      final paiements = controller.paiements;

      if (factures.isEmpty && paiements.isEmpty) {
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
                'Aucun mouvement',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Les factures et règlements de ce client apparaîtront ici.',
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

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (factures.isNotEmpty) ...[
            _TitreSection(
              titre: 'Factures',
              compteur: '${factures.length}',
            ),
            for (final f in factures)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FactureCard(
                  facture: f,
                  afficherClient: false,
                  onTap: () =>
                      Get.toNamed(AppRoutes.factureDetail, arguments: f),
                ),
              ),
          ],
          if (paiements.isNotEmpty) ...[
            const SizedBox(height: 10),
            _TitreSection(
              titre: 'Règlements',
              compteur: '${paiements.length}',
            ),
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < paiements.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                    _LignePaiement(
                      paiement: paiements[i],
                      devise: controller.devise,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _TitreSection extends StatelessWidget {
  const _TitreSection({required this.titre, required this.compteur});

  final String titre;
  final String compteur;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Text(
            titre.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.primary(context),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            compteur,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _LignePaiement extends StatelessWidget {
  const _LignePaiement({required this.paiement, required this.devise});

  final PaiementModel paiement;
  final String devise;

  @override
  Widget build(BuildContext context) {
    final imputations = paiement.imputations
        .map((i) => i.factureNumero)
        .where((n) => n.isNotEmpty)
        .join(', ');

    return ListTile(
      leading: Icon(
        Icons.payments_outlined,
        color: paiement.annule ? AppColors.cancelled : AppColors.success,
      ),
      title: Text(
        Formats.montant(paiement.montant, devise: devise),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: paiement.annule
              ? AppColors.cancelled
              : AppColors.text(context),
          decoration: paiement.annule ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        '${Formats.date(paiement.date)} · ${paiement.mode.label}'
        '${imputations.isEmpty ? '' : ' · $imputations'}',
        style: TextStyle(fontSize: 12.5, color: AppColors.textMuted(context)),
      ),
      trailing: paiement.annule
          ? const Text(
              'Annulé',
              style: TextStyle(fontSize: 11.5, color: AppColors.cancelled),
            )
          : null,
    );
  }
}
