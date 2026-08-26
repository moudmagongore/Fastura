import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Bandeau d'information contextuel (erreur de connexion, entreprise
/// désactivée, information). Volontairement statique : les retours
/// transitoires passent par un `SnackBar`.
class MessageBanner extends StatelessWidget {
  const MessageBanner({
    super.key,
    required this.message,
    required this.couleur,
    required this.icone,
  });

  factory MessageBanner.erreur(String message) => MessageBanner(
    message: message,
    couleur: AppColors.danger,
    icone: Icons.error_outline,
  );

  factory MessageBanner.info(String message) => MessageBanner(
    message: message,
    couleur: AppColors.brandPrimary,
    icone: Icons.info_outline,
  );

  factory MessageBanner.attention(String message) => MessageBanner(
    message: message,
    couleur: AppColors.warning,
    icone: Icons.warning_amber_outlined,
  );

  final String message;
  final Color couleur;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        // Aplat teinté sans contour : la couleur du texte porte déjà le
        // sens, le trait ne faisait qu'épaissir le bandeau.
        color: couleur.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 20, color: couleur),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: couleur, fontSize: 13.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
