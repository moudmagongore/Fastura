import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/format_helpers.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/message_banner.dart';
import '../../../data/models/facture_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../controllers/facture_detail_controller.dart';
import 'factures_list_view.dart' show StatutFactureChip;

class FactureDetailView extends GetView<FactureDetailController> {
  const FactureDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(controller.facture.value?.numero ?? 'Facture'),
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.introuvable.value) {
            return const EmptyState(
              icone: Icons.receipt_long_outlined,
              titre: 'Facture introuvable',
              description: 'Ce document n\'est plus accessible.',
            );
          }
          final f = controller.facture.value;
          if (f == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (f.annulee) ...[
                MessageBanner.attention(
                  'Facture annulée le ${Formats.date(f.annuleeLe)}'
                  '${f.annuleeParNom == null ? '' : ' par ${f.annuleeParNom}'}'
                  '${f.motifAnnulation == null ? '' : '.\nMotif : ${f.motifAnnulation}'}',
                ),
                const SizedBox(height: 16),
              ],
              _Entete(facture: f),
              const SizedBox(height: 16),
              _Lignes(facture: f),
              if ((f.note ?? '').isNotEmpty) ...[
                const SizedBox(height: 16),
                _Note(texte: f.note!),
              ],
              const SizedBox(height: 16),
              _Totaux(facture: f),
              const SizedBox(height: 16),
              _Tracabilite(facture: f),
              const SizedBox(height: 24),
              const _ImpressionAVenir(),
              const SizedBox(height: 16),
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
                  label: const Text('Annuler cette facture'),
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
  const _Entete({required this.facture});

  final FactureModel facture;

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
          colors: facture.annulee
              ? [AppColors.cancelled, const Color(0xFF6B7785)]
              : [AppColors.brandPrimary, AppColors.brandPrimaryDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  facture.clientNom,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatutFactureChip(facture: facture),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            Formats.dateLongue(facture.date),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 18),
          Text(
            Formats.montant(facture.montantTotal, devise: facture.devise),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!facture.annulee && facture.resteDu > 0)
            Text(
              'Reste à encaisser '
              '${Formats.montant(facture.resteDu, devise: facture.devise)}',
              style: const TextStyle(color: AppColors.warning, fontSize: 13.5),
            ),
        ],
      ),
    );
  }
}

class _Lignes extends StatelessWidget {
  const _Lignes({required this.facture});

  final FactureModel facture;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'DÉTAIL',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.primary(context),
              ),
            ),
            const SizedBox(height: 8),
            for (final l in facture.lignes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.designation,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text(context),
                            ),
                          ),
                          Text(
                            '${Formats.montant(l.quantite)} ${l.unite} × '
                            '${Formats.montant(l.prixUnitaire)}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textMuted(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      Formats.montant(l.montant, devise: facture.devise),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text(context),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

/// Mention libre saisie à l'émission. Affichée telle quelle : c'est souvent
/// une référence que le client redemandera.
class _Note extends StatelessWidget {
  const _Note({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.notes_rounded,
                size: 18, color: AppColors.primary(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NOTE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    texte,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: AppColors.text(context),
                    ),
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

class _Totaux extends StatelessWidget {
  const _Totaux({required this.facture});

  final FactureModel facture;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (facture.tauxTva > 0) ...[
              _Ligne(
                libelle: 'Montant HT',
                valeur: Formats.montant(facture.montantHT,
                    devise: facture.devise),
              ),
              _Ligne(
                libelle: 'TVA ${Formats.pourcentage(facture.tauxTva)}',
                valeur: Formats.montant(facture.montantTva,
                    devise: facture.devise),
              ),
              const Divider(height: 16),
            ],
            _Ligne(
              libelle: 'Total',
              valeur:
                  Formats.montant(facture.montantTotal, devise: facture.devise),
              gras: true,
            ),
            _Ligne(
              libelle: 'Déjà réglé',
              valeur:
                  Formats.montant(facture.montantPaye, devise: facture.devise),
              couleur: AppColors.success,
            ),
            if (!facture.annulee && facture.resteDu > 0)
              _Ligne(
                libelle: 'Reste à payer',
                valeur:
                    Formats.montant(facture.resteDu, devise: facture.devise),
                couleur: AppColors.warning,
                gras: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({
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
      fontSize: gras ? 16 : 13.5,
      fontWeight: gras ? FontWeight.w700 : FontWeight.w500,
      color: couleur ??
          (gras ? AppColors.text(context) : AppColors.textMuted(context)),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(libelle, style: style), Text(valeur, style: style)],
      ),
    );
  }
}

class _Tracabilite extends StatelessWidget {
  const _Tracabilite({required this.facture});

  final FactureModel facture;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Émise par ${facture.creeParNom}'
      '${facture.createdAt == null ? '' : ' le ${Formats.dateHeure(facture.createdAt)}'}',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, color: AppColors.textMuted(context)),
    );
  }
}

/// L'impression A4 / A3 / Ticket est prévue par le CDC §6 mais dépend du
/// format paramétré sur le tenant et, pour le ticket, d'une liaison
/// Bluetooth avec l'imprimante thermique. Elle arrive dans un second temps.
class _ImpressionAVenir extends StatelessWidget {
  const _ImpressionAVenir();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Icon(Icons.print_outlined,
              size: 32, color: AppColors.textMuted(context)),
          const SizedBox(height: 10),
          Text(
            'L\'impression et le partage du reçu arrivent avec le format '
            'paramétré sur l\'entreprise.',
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
