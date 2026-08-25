import 'package:get/get.dart';

import '../../../../data/models/tenant_model.dart';
import '../../../../data/repositories/tenant_repository.dart';

/// Liste des entreprises clientes, vue super-administrateur.
class TenantsController extends GetxController {
  final TenantRepository _repo = TenantRepository();

  final tenants = <TenantModel>[].obs;
  final chargement = true.obs;
  final recherche = ''.obs;

  /// Un tenant n'est jamais supprimé : le filtre sert à retrouver
  /// rapidement les entreprises encore actives dans une longue liste.
  final masquerInactifs = false.obs;

  @override
  void onInit() {
    super.onInit();
    tenants.bindStream(
      _repo.watchAll().map((liste) {
        chargement.value = false;
        return liste;
      }),
    );
  }

  List<TenantModel> get resultats {
    final q = recherche.value.trim().toLowerCase();
    return tenants.where((t) {
      if (masquerInactifs.value && !t.active) return false;
      if (q.isEmpty) return true;
      return t.nom.toLowerCase().contains(q) ||
          (t.adresse ?? '').toLowerCase().contains(q) ||
          (t.telephone ?? '').contains(q);
    }).toList();
  }

  int get nbActifs => tenants.where((t) => t.active).length;

  Future<void> basculerActivation(TenantModel tenant) async {
    await _repo.setActive(tenant.id, !tenant.active);
  }
}
