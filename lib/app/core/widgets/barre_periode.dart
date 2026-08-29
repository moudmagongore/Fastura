import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../utils/filtre_periode.dart';
import '../utils/format_helpers.dart';

/// Barre « Du … au … » des journaux.
///
/// Deux dates que l'utilisateur pose lui-même, plutôt que des raccourcis :
/// une clôture, un contrôle, une relance portent sur des bornes précises,
/// rarement sur « ce mois ».
class BarrePeriode extends StatelessWidget {
  const BarrePeriode({super.key, required this.filtre});

  final FiltrePeriode filtre;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: _Borne(
                libelle: 'Du',
                date: filtre.debut,
                onTap: () => filtre.choisirDebut(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Borne(
                libelle: 'Au',
                date: filtre.fin,
                onTap: () => filtre.choisirFin(context),
              ),
            ),
            // Le bouton n'apparaît qu'une fois une borne posée : rien à
            // effacer sur un journal qui montre déjà tout.
            if (filtre.effacable && filtre.bornee) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Effacer la période',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: filtre.effacer,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Borne extends StatelessWidget {
  const _Borne({
    required this.libelle,
    required this.date,
    required this.onTap,
  });

  final String libelle;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pose = date != null;
    final primaire = AppColors.primary(context);

    return Material(
      color: AppColors.surfaceMuted(context),
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(
                Icons.event_outlined,
                size: 17,
                color: pose ? primaire : AppColors.textMuted(context),
              ),
              const SizedBox(width: 8),
              Text(
                '$libelle ',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted(context),
                ),
              ),
              Expanded(
                child: Text(
                  pose ? Formats.date(date!) : '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: pose
                        ? AppColors.text(context)
                        : AppColors.textMuted(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
