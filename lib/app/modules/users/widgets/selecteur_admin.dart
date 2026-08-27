import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/bottom_sheet_helpers.dart';
import '../../../core/utils/marges_ecran.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../theme/app_colors.dart';

/// Feuille de choix d'un administrateur **déjà existant**, pour l'affecter à
/// une autre boutique.
///
/// Réservée au super-administrateur : elle interroge la collection `users`
/// sans filtre de tenant, ce que les rules n'autorisent qu'à lui.
///
/// Sont écartés les comptes déjà rattachés à la boutique — il n'y a rien à
/// leur ajouter — et les comptes désactivés : affecter quelqu'un qui ne peut
/// pas se connecter ne donnerait à la boutique qu'un administrateur de
/// façade.
Future<UserModel?> choisirAdminExistant({
  required String tenantId,
  required String nomBoutique,
}) {
  return Get.bottomSheet<UserModel>(
    _FeuilleAdmins(tenantId: tenantId, nomBoutique: nomBoutique),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
}

class _FeuilleAdmins extends StatefulWidget {
  const _FeuilleAdmins({required this.tenantId, required this.nomBoutique});

  final String tenantId;
  final String nomBoutique;

  @override
  State<_FeuilleAdmins> createState() => _FeuilleAdminsState();
}

class _FeuilleAdminsState extends State<_FeuilleAdmins> {
  final _repo = UserRepository();
  late final Stream<List<UserModel>> _flux = _repo.watchAdmins();

  String _requete = '';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: kBottomSheetMaxHeightRatio,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.background(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            const PoigneeSheet(marge: EdgeInsets.only(bottom: 6)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Affecter un administrateur',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text(context),
                          ),
                        ),
                        Text(
                          'à ${widget.nomBoutique}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) => setState(() => _requete = v),
                decoration: const InputDecoration(
                  hintText: 'Rechercher par nom ou email…',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<UserModel>>(
                stream: _flux,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final q = _requete.trim().toLowerCase();
                  final resultats = snap.data!
                      .where((u) => u.active && !u.appartientA(widget.tenantId))
                      .where(
                        (u) =>
                            q.isEmpty ||
                            u.nom.toLowerCase().contains(q) ||
                            u.email.toLowerCase().contains(q),
                      )
                      .toList();

                  if (resultats.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          q.isEmpty
                              ? 'Aucun autre administrateur actif sur la '
                                    'plateforme. Créez-en un depuis sa propre '
                                    'boutique avant de l\'affecter ici.'
                              : 'Aucun administrateur ne correspond à cette '
                                    'recherche.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted(context)),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: scrollController,
                    padding: EdgeInsets.only(bottom: margeBasse(context)),
                    itemCount: resultats.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, i) {
                      final u = resultats[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary(
                            context,
                          ).withValues(alpha: 0.15),
                          child: Text(
                            u.initiales,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary(context),
                            ),
                          ),
                        ),
                        title: Text(u.nom),
                        subtitle: Text(
                          u.tenantIds.length > 1
                              ? '${u.email} · ${u.tenantIds.length} boutiques'
                              : u.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Get.back(result: u),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
