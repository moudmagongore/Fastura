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
                  onModifier: () => _ouvrirFormulaire(user: liste[i]),
                  onBasculer: () => controller.basculerActivation(liste[i]),
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
    required this.onModifier,
    required this.onBasculer,
  });

  final UserModel user;
  final bool cestMoi;
  final VoidCallback onModifier;
  final VoidCallback onBasculer;

  @override
  Widget build(BuildContext context) {
    final couleurRole = user.role.isAdmin
        ? AppColors.brandPrimary
        : AppColors.brandAccent;

    return Card(
      child: InkWell(
        onTap: onModifier,
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
                  Container(
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
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: couleurRole,
                      ),
                    ),
                  ),
                  if ((user.telephone ?? '').isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: AppColors.textMuted(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      user.telephone!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: cestMoi ? null : onBasculer,
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
