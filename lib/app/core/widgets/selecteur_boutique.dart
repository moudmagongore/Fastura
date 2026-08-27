import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/tenant_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../services/session_controller.dart';
import '../utils/bottom_sheet_helpers.dart';

/// Feuille de bascule entre les boutiques d'un même compte.
///
/// Un administrateur affecté à plusieurs boutiques n'en sert qu'une à la
/// fois : la session entière (facturation, catalogue, dépenses, chiffres de
/// l'accueil) suit celle qui est choisie ici.
Future<void> ouvrirSelecteurBoutique() {
  return Get.bottomSheet<void>(
    const _SelecteurBoutique(),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
}

class _SelecteurBoutique extends StatelessWidget {
  const _SelecteurBoutique();

  @override
  Widget build(BuildContext context) {
    final session = SessionController.to;

    return CadreSheet(
      child: Obx(() {
        final user = session.user.value;
        if (user == null) return const SizedBox.shrink();

        final chargees = {for (final t in session.boutiques) t.id: t};
        final courante = session.tenantId;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PoigneeSheet(),
            EnteteSheet(
              icone: Icons.storefront_outlined,
              titre: 'Changer de boutique',
              couleur: AppColors.primary(context),
              sousTitre: '${user.tenantIds.length} boutiques sur ce compte',
            ),
            const SizedBox(height: 8),
            for (final id in user.tenantIds)
              _LigneBoutique(
                boutique: chargees[id],
                courante: id == courante,
                onTap: () {
                  Navigator.of(context).pop();
                  session.changerBoutique(id);
                },
              ),
            const SizedBox(height: 4),
            Text(
              'Les factures, le catalogue et les chiffres affichés sont ceux '
              'de la boutique servie. Rien ne circule de l\'une à l\'autre.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      }),
    );
  }
}

class _LigneBoutique extends StatelessWidget {
  const _LigneBoutique({
    required this.boutique,
    required this.courante,
    required this.onTap,
  });

  /// Nulle tant que le nom n'est pas revenu de Firestore : la feuille
  /// s'ouvre sans attendre, la ligne se remplit ensuite.
  final TenantModel? boutique;
  final bool courante;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaire = AppColors.primary(context);
    final t = boutique;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: courante
            ? primaire.withValues(alpha: 0.10)
            : AppColors.surfaceMuted(context),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InkWell(
          // Rien à faire sur la boutique déjà servie, et rien à faire non
          // plus tant que son nom n'est pas connu.
          onTap: courante || t == null ? null : onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(
                  courante
                      ? Icons.storefront_rounded
                      : Icons.storefront_outlined,
                  size: 20,
                  color: courante ? primaire : AppColors.textMuted(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t?.nom ?? 'Chargement…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: courante ? primaire : AppColors.text(context),
                        ),
                      ),
                      if ((t?.adresse ?? '').isNotEmpty)
                        Text(
                          t!.adresse!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (courante)
                  Icon(Icons.check_circle_rounded, size: 20, color: primaire)
                else if (t != null && !t.active)
                  Text(
                    'Suspendue',
                    style: TextStyle(fontSize: 12, color: AppColors.danger),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
