import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Tuile d'accès à un module depuis l'accueil.
///
/// [onTap] nul = module pas encore développé : la tuile est atténuée et
/// marquée « Bientôt ». Les accueils affichent ainsi la feuille de route
/// réelle plutôt qu'une grille qui promet des écrans inexistants.
class ModuleTile extends StatelessWidget {
  const ModuleTile({
    super.key,
    required this.libelle,
    required this.icone,
    this.couleur,
    this.onTap,
  });

  final String libelle;
  final IconData icone;
  final Color? couleur;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disponible = onTap != null;
    final teinte = disponible
        ? (couleur ?? AppColors.primary(context))
        : AppColors.textMuted(context);
    final rayon = BorderRadius.circular(AppTheme.radius);

    return Material(
      color: AppColors.surface(context),
      borderRadius: rayon,
      child: InkWell(
        onTap: onTap,
        borderRadius: rayon,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: rayon,
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Le picto porte la couleur du module ; le reste de la tuile
              // reste neutre, sans quoi une grille de huit vignettes vire au
              // sapin de Noël.
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: teinte.withValues(alpha: disponible ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall + 2),
                ),
                child: Icon(icone, color: teinte, size: 22),
              ),
              const Spacer(),
              Text(
                libelle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                  height: 1.2,
                  color: disponible
                      ? AppColors.text(context)
                      : AppColors.textMuted(context),
                ),
              ),
              if (!disponible)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    'Bientôt',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
