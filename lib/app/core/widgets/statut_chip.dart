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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: couleur.withValues(alpha: 0.4)),
      ),
      child: Text(
        actif ? labelActif : labelInactif,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: couleur,
        ),
      ),
    );
  }
}
