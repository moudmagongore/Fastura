import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/format_helpers.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../controllers/accueil_controller.dart';

/// Les chiffres de l'accueil : le jour en détail, le mois en résumé.
///
/// Une carte pleine largeur pour le facturé du jour — c'est le chiffre qu'on
/// vient voir — puis l'encaissé et les dépenses côte à côte. Le mois suit, en
/// résumé de trois lignes : au comptoir on regarde sa journée, en fin de mois
/// on regarde le mois, et aucun des deux n'a à se mériter par un filtre.
class StatistiquesAccueil extends StatelessWidget {
  const StatistiquesAccueil({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AccueilController>();

    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TitreSection('Aujourd\'hui'),
          const SizedBox(height: 12),
          CarteStatVedette(
            icone: Icons.trending_up_rounded,
            libelle: 'Facturé aujourd\'hui',
            montant: Formats.montant(c.factureJour, devise: c.devise),
            precision: c.nombreFacturesJour == 0
                ? 'Aucune facture'
                : '${c.nombreFacturesJour} facture'
                      '${c.nombreFacturesJour > 1 ? 's' : ''}',
            couleur: AppColors.primary(context),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: CarteStat(
                    icone: Icons.payments_rounded,
                    libelle: 'Encaissé',
                    valeur: Formats.montant(c.encaisseJour, devise: c.devise),
                    couleur: AppColors.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CarteStat(
                    icone: Icons.trending_down_rounded,
                    libelle: 'Dépenses',
                    valeur: Formats.montant(c.depensesJour, devise: c.devise),
                    couleur: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const TitreSection('Ce mois-ci'),
          const SizedBox(height: 12),
          CarteResumeMois(
            facture: Formats.montant(c.factureMois, devise: c.devise),
            encaisse: Formats.montant(c.encaisseMois, devise: c.devise),
            depenses: Formats.montant(c.depensesMoisTotal, devise: c.devise),
            nombreFactures: c.nombreFacturesMois,
          ),
          if (c.tronque) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppColors.textMuted(context),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Mois très chargé : les totaux ne portent que sur les '
                    'documents les plus récents.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Le mois en résumé : trois lignes dans une seule carte, libellé à gauche et
/// montant à droite.
///
/// Trois cartes côte à côte ne tiendraient pas : à un tiers de largeur, un
/// montant en francs guinéens devient illisible. Widget de présentation pure,
/// pour que la planche de contrôle (`tool/apercu_theme.dart`) puisse le rendre
/// sans base de données.
class CarteResumeMois extends StatelessWidget {
  const CarteResumeMois({
    super.key,
    required this.facture,
    required this.encaisse,
    required this.depenses,
    required this.nombreFactures,
  });

  final String facture;
  final String encaisse;
  final String depenses;
  final int nombreFactures;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          _LigneMois(
            icone: Icons.trending_up_rounded,
            libelle: nombreFactures == 0
                ? 'Facturé'
                : 'Facturé · $nombreFactures facture'
                      '${nombreFactures > 1 ? 's' : ''}',
            valeur: facture,
            couleur: AppColors.primary(context),
          ),
          const Divider(height: 1),
          _LigneMois(
            icone: Icons.payments_rounded,
            libelle: 'Encaissé',
            valeur: encaisse,
            couleur: AppColors.success,
          ),
          const Divider(height: 1),
          _LigneMois(
            icone: Icons.trending_down_rounded,
            libelle: 'Dépenses',
            valeur: depenses,
            couleur: AppColors.danger,
          ),
        ],
      ),
    );
  }
}

class _LigneMois extends StatelessWidget {
  const _LigneMois({
    required this.icone,
    required this.libelle,
    required this.valeur,
    required this.couleur,
  });

  final IconData icone;
  final String libelle;
  final String valeur;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Icon(icone, size: 17, color: couleur),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              libelle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 10),
          // Montant sans flex : dans une `Row`, les enfants non flexibles
          // prennent leur largeur naturelle avant que le reste ne se partage.
          // Le montant est donc toujours entier, et c'est le libellé qui se
          // coupe — l'inverse serait absurde sur une carte de chiffres.
          Text(
            valeur,
            maxLines: 1,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: couleur,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte du chiffre principal. Publique pour que la planche de contrôle
/// (`tool/apercu_theme.dart`) puisse la rendre sans base de données.
class CarteStatVedette extends StatelessWidget {
  const CarteStatVedette({
    super.key,
    required this.icone,
    required this.libelle,
    required this.montant,
    required this.precision,
    required this.couleur,
  });

  final IconData icone;
  final String libelle;
  final String montant;
  final String precision;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall + 2),
            ),
            child: Icon(icone, color: couleur, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(libelle, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 3),
                // Un montant en francs guinéens est long : il se réduit
                // plutôt que de déborder de la carte.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    montant,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: couleur,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Le nombre de factures en pastille et non en ligne grise :
                // c'est le second chiffre qu'on vient chercher, « combien de
                // ventes ai-je faites ? » suit « combien ai-je facturé ? ».
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: couleur.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 13,
                        color: couleur,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        precision,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: couleur,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte d'un chiffre secondaire.
class CarteStat extends StatelessWidget {
  const CarteStat({
    super.key,
    required this.icone,
    required this.libelle,
    required this.valeur,
    required this.couleur,
  });

  final IconData icone;
  final String libelle;
  final String valeur;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, color: couleur, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  libelle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valeur,
              maxLines: 1,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: couleur,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Intertitre des sections de l'accueil.
class TitreSection extends StatelessWidget {
  const TitreSection(this.libelle, {super.key});

  final String libelle;

  @override
  Widget build(BuildContext context) =>
      Text(libelle, style: Theme.of(context).textTheme.labelSmall);
}

/// Les dernières factures du jour, sous les chiffres.
///
/// Sert de journal de bord : au comptoir, la question qui suit « combien ai-je
/// facturé ? » est « qu'est-ce que je viens de facturer ? ». Le titre dit le jour :
/// sans lui, on ne saurait pas de quoi cette liste est l'extrait.
class DernieresFactures extends StatelessWidget {
  const DernieresFactures({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AccueilController>();

    return Obx(() {
      final entete = Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: const TitreSection('Dernières factures du jour'),
      );

      if (c.chargement.value) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            entete,
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        );
      }

      if (c.facturesJour.isEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            entete,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 34,
                    color: AppColors.textMuted(context),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Aucune facture aujourd\'hui',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'La prochaine vente s\'affichera ici.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        );
      }

      return Column(
        // Sans ça, la colonne centre ses enfants : le titre, qui ne prend
        // que sa largeur de texte, se retrouvait au milieu de l'écran.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          entete,
          for (final f in c.dernieresFactures)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(AppTheme.radius),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  onTap: () =>
                      Get.toNamed(AppRoutes.factureDetail, arguments: f),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primary(
                              context,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSmall,
                            ),
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            size: 19,
                            color: AppColors.primary(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                f.clientAffiche,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                '${f.numero} · ${Formats.heure(f.date)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          Formats.montant(f.montantTotal, devise: f.devise),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: f.annulee
                                ? AppColors.cancelled
                                : AppColors.text(context),
                            decoration: f.annulee
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (c.facturesJour.length > 5)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Get.toNamed(AppRoutes.factures),
                child: const Text('Voir le journal complet'),
              ),
            ),
        ],
      );
    });
  }
}
