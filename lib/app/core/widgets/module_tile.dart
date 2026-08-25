import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Tuile d'accès à un module depuis l'accueil.
///
/// [onTap] nul = module pas encore développé : la tuile est grisée et
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

    return Opacity(
      opacity: disponible ? 1 : 0.55,
      child: Material(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: teinte.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icone, color: teinte, size: 22),
                ),
                const SizedBox(height: 14),
                Text(
                  libelle,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text(context),
                  ),
                ),
                if (!disponible)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Bientôt',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
