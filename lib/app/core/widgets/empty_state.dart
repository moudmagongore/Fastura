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
            Icon(icone, size: 56, color: AppColors.textMuted(context)),
            const SizedBox(height: 18),
            Text(
              titre,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
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
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
