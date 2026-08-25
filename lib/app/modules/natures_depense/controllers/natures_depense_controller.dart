import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/models/nature_depense_model.dart';
import '../../../data/repositories/nature_depense_repository.dart';

class NaturesDepenseController extends GetxController {
  final NatureDepenseRepository _repo = NatureDepenseRepository();

  final natures = <NatureDepenseModel>[].obs;
  final chargement = true.obs;
  final recherche = ''.obs;
  final masquerInactives = false.obs;

  late final String tenantId;

  @override
  void onInit() {
    super.onInit();
    tenantId = SessionController.to.requireTenantId;
    natures.bindStream(
      _repo.watchByTenant(tenantId).map((liste) {
        chargement.value = false;
        return liste;
      }),
    );
  }

  List<NatureDepenseModel> get resultats {
    final q = recherche.value.trim().toLowerCase();
    return natures.where((n) {
      if (masquerInactives.value && !n.active) return false;
      if (q.isEmpty) return true;
      return n.libelle.toLowerCase().contains(q);
    }).toList();
  }

  int get nbActives => natures.where((n) => n.active).length;

  /// Bascule le statut d'une nature.
  ///
  /// Aucune cascade à annoncer, contrairement aux catégories d'articles :
  /// les dépenses déjà saisies restent telles quelles. On dit tout de même
  /// combien elles sont, pour que l'administrateur sache qu'il ferme une
  /// rubrique déjà mouvementée.
  Future<void> basculerActivation(NatureDepenseModel n) async {
    final nb = n.active
        ? await _repo.compterDepenses(n.id, tenantId: tenantId)
        : 0;

    final ok = await confirmer(
      titre: n.active ? 'Désactiver la nature' : 'Réactiver la nature',
      message: n.active
          ? '« ${n.libelle} » ne sera plus proposée à la saisie d\'une '
                'dépense.'
                '${nb == 0 ? '' : ' Les $nb dépense(s) déjà enregistrées sous '
                          'cette nature restent dans l\'historique et dans les '
                          'totaux.'}'
          : '« ${n.libelle} » sera de nouveau proposée à la saisie.',
      libelleConfirmer: n.active ? 'Désactiver' : 'Réactiver',
      destructif: n.active,
    );
    if (!ok) return;

    try {
      await _repo.setActive(n.id, !n.active);
    } catch (e) {
      Get.snackbar(
        'Action impossible',
        'Modification impossible : $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
