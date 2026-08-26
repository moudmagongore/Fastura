import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Écran vide d'une liste : icône, message, action facultative.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icone,
    required this.titre,
    this.description,
    this.action,
  });

  final IconData icone;
  final String titre;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Le picto posé dans une pastille : seul au milieu du vide, il
            // faisait plus panne qu'invitation.
            Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted(context),
                shape: BoxShape.circle,
              ),
              child: Icon(icone, size: 34, color: AppColors.textMuted(context)),
            ),
            const SizedBox(height: 20),
            Text(
              titre,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: AppColors.text(context),
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: AppColors.textMuted(context),
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}
