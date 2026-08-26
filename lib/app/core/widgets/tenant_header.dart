import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../services/session_controller.dart';
import '../utils/format_helpers.dart';

/// Carte de rappel des paramètres de l'entreprise courante : devise, TVA,
/// format d'impression. Sert de repère à l'utilisateur avant de facturer,
/// et de vérification visuelle que la session est bien scopée au bon tenant.
class TenantHeader extends StatelessWidget {
  const TenantHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final tenant = SessionController.to.tenant.value;
      if (tenant == null) return const SizedBox.shrink();

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          // Barres de titre devenues claires, cette carte est le seul aplat
          // de marque de l'écran : elle porte l'identité à elle seule.
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.brandPrimaryLight, AppColors.brandPrimary],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tenant.nom,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                height: 1.15,
              ),
            ),
            if ((tenant.adresse ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                tenant.adresse!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _Pastille(icone: Icons.payments_outlined, texte: tenant.devise),
                _Pastille(
                  icone: Icons.percent,
                  texte: tenant.tvaActive
                      ? 'TVA ${Formats.pourcentage(tenant.tauxTva)}'
                      : 'Sans TVA',
                ),
                _Pastille(
                  icone: Icons.print_outlined,
                  texte: tenant.formatImpression.name.toUpperCase(),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille({required this.icone, required this.texte});

  final IconData icone;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            texte,
            style: const TextStyle(color: Colors.white, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
