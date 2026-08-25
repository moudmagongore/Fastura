import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/utils/format_helpers.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/statut_chip.dart';
import '../../../../data/models/tenant_model.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/tenants_controller.dart';

class TenantsListView extends GetView<TenantsController> {
  const TenantsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entreprises'),
        actions: [
          Obx(
            () => IconButton(
              tooltip: controller.masquerInactifs.value
                  ? 'Afficher les inactives'
                  : 'Masquer les inactives',
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
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(AppRoutes.superAdminTenantForm),
        icon: const Icon(Icons.add),
        label: const Text('Entreprise'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => controller.recherche.value = v,
              decoration: const InputDecoration(
                hintText: 'Rechercher une entreprise…',
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
                  '${controller.nbActifs} active(s) sur '
                  '${controller.tenants.length}',
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
                  icone: Icons.apartment_outlined,
                  titre: controller.tenants.isEmpty
                      ? 'Aucune entreprise'
                      : 'Aucun résultat',
                  description: controller.tenants.isEmpty
                      ? 'Créez la première entreprise cliente de Fastura.'
                      : 'Aucune entreprise ne correspond à cette recherche.',
                  action: controller.tenants.isEmpty
                      ? ElevatedButton.icon(
                          onPressed: () =>
                              Get.toNamed(AppRoutes.superAdminTenantForm),
                          icon: const Icon(Icons.add),
                          label: const Text('Créer une entreprise'),
                        )
                      : null,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: liste.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _TenantCard(
                  tenant: liste[i],
                  onModifier: () => Get.toNamed(
                    AppRoutes.superAdminTenantForm,
                    arguments: liste[i],
                  ),
                  onBasculer: () => _confirmerBascule(liste[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmerBascule(TenantModel t) async {
    final desactivation = t.active;
    final ok = await confirmer(
      titre: desactivation ? 'Suspendre l\'accès' : 'Réactiver l\'entreprise',
      message: desactivation
          ? '${t.nom} ne pourra plus se connecter. Ses données et son '
              'historique de facturation sont conservés.'
          : 'Les utilisateurs de ${t.nom} pourront à nouveau se connecter.',
      libelleConfirmer: desactivation ? 'Suspendre' : 'Réactiver',
      destructif: desactivation,
    );
    if (ok) await controller.basculerActivation(t);
  }
}

class _TenantCard extends StatelessWidget {
  const _TenantCard({
    required this.tenant,
    required this.onModifier,
    required this.onBasculer,
  });

  final TenantModel tenant;
  final VoidCallback onModifier;
  final VoidCallback onBasculer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onModifier,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tenant.nom,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text(context),
                      ),
                    ),
                  ),
                  StatutChip(
                    actif: tenant.active,
                    labelInactif: 'Suspendue',
                  ),
                ],
              ),
              if ((tenant.adresse ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.place_outlined,
                        size: 14, color: AppColors.textMuted(context)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        tenant.adresse!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Tag(texte: tenant.devise, icone: Icons.payments_outlined),
                  _Tag(
                    texte: tenant.tvaActive
                        ? 'TVA ${Formats.pourcentage(tenant.tauxTva)}'
                        : 'Sans TVA',
                    icone: Icons.percent,
                  ),
                  _Tag(
                    texte: tenant.formatImpression.name.toUpperCase(),
                    icone: Icons.print_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onBasculer,
                  style: TextButton.styleFrom(
                    foregroundColor:
                        tenant.active ? AppColors.danger : AppColors.success,
                  ),
                  icon: Icon(
                    tenant.active ? Icons.block : Icons.check_circle_outline,
                    size: 18,
                  ),
                  label: Text(tenant.active ? 'Suspendre' : 'Réactiver'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.texte, required this.icone});

  final String texte;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.background(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 13, color: AppColors.textMuted(context)),
          const SizedBox(width: 5),
          Text(
            texte,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }
}
