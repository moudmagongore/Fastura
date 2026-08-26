import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/marges_ecran.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';

/// Ce que fait l'application, et à qui écrire quand ça coince.
///
/// Écran sans contrôleur : rien n'y est lu ni écrit, tout vient de
/// [AppConstants]. Les coordonnées se copient d'un appui — l'app n'embarque
/// pas de lanceur d'URL, et un numéro qu'on ne peut ni composer ni copier ne
/// sert à personne.
class AproposView extends StatelessWidget {
  const AproposView({super.key});

  static const _modules = <(IconData, String, String)>[
    (
      Icons.receipt_long_outlined,
      'Facturation',
      'Émission des factures, numérotation continue, règlement immédiat ou '
          'à crédit, impression et partage.',
    ),
    (
      Icons.payments_outlined,
      'Paiements',
      'Encaissement avec lettrage automatique : le versement solde d\'abord '
          'la facture la plus ancienne.',
    ),
    (
      Icons.people_outline,
      'Clients',
      'Fiches, créances en cours, historique des factures et des '
          'règlements. Les ventes de passage n\'ouvrent pas de fiche.',
    ),
    (
      Icons.inventory_2_outlined,
      'Catalogue',
      'Articles et catégories, avec leurs prix. Le prix reste ajustable au '
          'comptoir, sans toucher au catalogue.',
    ),
    (
      Icons.trending_down,
      'Dépenses',
      'Saisie par nature, récapitulatif de la période et suivi du solde de '
          'caisse.',
    ),
    (
      Icons.settings_outlined,
      'Paramètres',
      'Devise, TVA, logo, adresse et format d\'impression (A4, A5 ou '
          'ticket), propres à chaque entreprise.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('À propos'),
        automaticallyImplyLeading: false,
        actions: const [DrawerButton()],
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 32 + margeBasse(context)),
          children: [
            const _Entete(),
            const SizedBox(height: 26),
            Text(
              'Nous joindre',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Une question, une anomalie, une demande d\'évolution.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _Contact(
              icone: Icons.mail_outline_rounded,
              libelle: 'Email',
              valeur: AppConstants.contactEmail,
            ),
            for (final tel in AppConstants.contactTelephones) ...[
              const SizedBox(height: 10),
              _Contact(
                icone: Icons.phone_outlined,
                libelle: 'Téléphone',
                valeur: tel,
              ),
            ],
            const SizedBox(height: 28),
            Text(
              'Ce que fait l\'application',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (final (icone, titre, texte) in _modules) ...[
              _Module(icone: icone, titre: titre, texte: texte),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

class _Entete extends StatelessWidget {
  const _Entete();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandPrimaryLight, AppColors.brandPrimary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            AppConstants.appName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            AppConstants.appDescription,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Module extends StatelessWidget {
  const _Module({
    required this.icone,
    required this.titre,
    required this.texte,
  });

  final IconData icone;
  final String titre;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(icone, size: 19, color: AppColors.primary(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(titre, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(texte, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Contact extends StatelessWidget {
  const _Contact({
    required this.icone,
    required this.libelle,
    required this.valeur,
  });

  final IconData icone;
  final String libelle;
  final String valeur;

  void _copier() {
    Clipboard.setData(ClipboardData(text: valeur));
    Get.snackbar(
      'Copié',
      '$valeur est dans le presse-papiers.',
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface(context),
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: _copier,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Row(
            children: [
              Icon(icone, size: 19, color: AppColors.primary(context)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      libelle,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    Text(
                      valeur,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.copy_rounded,
                size: 17,
                color: AppColors.textMuted(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
