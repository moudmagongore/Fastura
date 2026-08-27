import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/statut_chip.dart';
import '../../../data/models/user_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../controllers/users_controller.dart';
import '../users_args.dart';

class UsersListView extends GetView<UsersController> {
  const UsersListView({super.key});

  @override
  Widget build(BuildContext context) {
    final vueSuperAdmin = controller.vueSuperAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Text(vueSuperAdmin ? controller.nomTenant! : 'Utilisateurs'),
        actions: [
          if (vueSuperAdmin)
            IconButton(
              tooltip: 'Affecter un administrateur existant',
              icon: const Icon(Icons.group_add_outlined),
              onPressed: controller.affecterAdminExistant,
            ),
          Obx(
            () => IconButton(
              tooltip: controller.masquerInactifs.value
                  ? 'Afficher les inactifs'
                  : 'Masquer les inactifs',
              icon: Icon(
                controller.masquerInactifs.value
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined,
              ),
              onPressed: () => controller.masquerInactifs.toggle(),
            ),
          ),
        ],
      ),
      // Le super-administrateur arrive ici depuis une entreprise : il navigue
      // en arrière, il n'a pas de menu latéral sur cet écran.
      drawer: vueSuperAdmin ? null : const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ouvrirFormulaire(),
        icon: const Icon(Icons.person_add_alt),
        label: Text(vueSuperAdmin ? 'Administrateur' : 'Utilisateur'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => controller.recherche.value = v,
              decoration: const InputDecoration(
                hintText: 'Rechercher un utilisateur…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Obx(
            () => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${controller.nbActifs} actif(s) sur '
                  '${controller.utilisateurs.length}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted(context),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.chargement.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final liste = controller.resultats;
              if (liste.isEmpty) {
                return EmptyState(
                  icone: Icons.manage_accounts_outlined,
                  titre: controller.utilisateurs.isEmpty
                      ? 'Aucun utilisateur'
                      : 'Aucun résultat',
                  description: controller.utilisateurs.isEmpty
                      ? (vueSuperAdmin
                            ? 'Créez l\'administrateur de cette entreprise pour '
                                  'qu\'elle puisse commencer à travailler.'
                            : 'Créez les comptes de vos collaborateurs.')
                      : 'Aucun utilisateur ne correspond à cette recherche.',
                  action: controller.utilisateurs.isEmpty
                      ? ElevatedButton.icon(
                          onPressed: () => _ouvrirFormulaire(),
                          icon: const Icon(Icons.person_add_alt),
                          label: Text(
                            vueSuperAdmin
                                ? 'Créer l\'administrateur'
                                : 'Créer un utilisateur',
                          ),
                        )
                      : null,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: liste.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _UserCard(
                  user: liste[i],
                  cestMoi: controller.estMoi(liste[i]),
                  // Affecté ici par le super-administrateur : sa boutique
                  // d'origine est ailleurs.
                  affecte: controller.estAffecte(liste[i]),
                  modifiable: controller.peutModifier(liste[i]),
                  onModifier: () => _ouvrirFormulaire(user: liste[i]),
                  onBasculer: () => controller.basculerActivation(liste[i]),
                  onRetirer: vueSuperAdmin && controller.estAffecte(liste[i])
                      ? () => controller.retirerAffectation(liste[i])
                      : null,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _ouvrirFormulaire({UserModel? user}) {
    final vueSuperAdmin = controller.vueSuperAdmin;
    Get.toNamed(
      vueSuperAdmin ? AppRoutes.superAdminTenantUserForm : AppRoutes.userForm,
      arguments: UserFormArgs(
        tenantId: controller.tenantId,
        user: user,
        // Le super-administrateur ne crée que l'administrateur initial ;
        // les vendeurs sont ensuite gérés par le tenant lui-même.
        forcerAdmin: vueSuperAdmin && user == null,
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.cestMoi,
    required this.affecte,
    required this.modifiable,
    required this.onModifier,
    required this.onBasculer,
    this.onRetirer,
  });

  final UserModel user;
  final bool cestMoi;

  /// Le compte vient d'une autre boutique : il administre celle-ci en plus
  /// de la sienne.
  final bool affecte;

  /// Faux pour un compte multi-boutiques vu depuis l'une d'elles : le
  /// modifier depuis ici toucherait aussi les autres.
  final bool modifiable;

  final VoidCallback onModifier;
  final VoidCallback onBasculer;

  /// Retire l'affectation à la boutique consultée. Nul quand il n'y a rien
  /// à retirer — compte d'origine, ou vue d'un administrateur de boutique.
  final VoidCallback? onRetirer;

  @override
  Widget build(BuildContext context) {
    final couleurRole = user.role.isAdmin
        ? AppColors.brandPrimary
        : AppColors.brandAccent;

    return Card(
      child: InkWell(
        onTap: modifiable ? onModifier : null,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: couleurRole.withValues(alpha: 0.15),
                    child: Text(
                      user.initiales,
                      style: TextStyle(
                        color: couleurRole,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.nom,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text(context),
                                ),
                              ),
                            ),
                            if (cestMoi) ...[
                              const SizedBox(width: 6),
                              Text(
                                '(vous)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted(context),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatutChip(actif: user.active),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: couleurRole.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              user.role.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: couleurRole,
                              ),
                            ),
                          ),
                        ),
                        if (affecte || user.estMultiBoutique) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: _PastilleBoutiques(
                              texte: affecte
                                  ? 'Affecté'
                                  : '${user.tenantIds.length} boutiques',
                            ),
                          ),
                        ],
                        if ((user.telephone ?? '').isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: AppColors.textMuted(context),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              user.telephone!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textMuted(context),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Sur une affectation, c'est le rattachement qu'on défait,
                  // pas le compte qu'on ferme : le désactiver le
                  // déconnecterait aussi de sa boutique d'origine.
                  if (onRetirer != null)
                    TextButton(
                      onPressed: onRetirer,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                      child: const Text('Retirer'),
                    )
                  else
                    TextButton(
                      onPressed: cestMoi || !modifiable ? null : onBasculer,
                      style: TextButton.styleFrom(
                        foregroundColor: user.active
                            ? AppColors.danger
                            : AppColors.success,
                      ),
                      child: Text(user.active ? 'Désactiver' : 'Réactiver'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastille discrète des comptes qui servent plus d'une boutique.
class _PastilleBoutiques extends StatelessWidget {
  const _PastilleBoutiques({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.brandAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.storefront_outlined,
            size: 13,
            color: AppColors.brandAccent,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              texte,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.brandAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
