import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Pastille actif / inactif. Aucune entité de référentiel n'étant jamais
/// supprimée, ce chip est le repère visuel du statut dans toutes les listes.
class StatutChip extends StatelessWidget {
  const StatutChip({
    super.key,
    required this.actif,
    this.labelActif = 'Actif',
    this.labelInactif = 'Inactif',
  });

  final bool actif;
  final String labelActif;
  final String labelInactif;

  @override
  Widget build(BuildContext context) {
    final couleur = actif ? AppColors.success : AppColors.cancelled;

    // Aplat teinté sans contour : le trait doublait la couleur pour rien et
    // alourdissait des listes qui portent une pastille par ligne.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        actif ? labelActif : labelInactif,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
          color: couleur,
        ),
      ),
    );
  }
}
