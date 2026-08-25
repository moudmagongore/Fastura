import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/models/categorie_model.dart';
import '../../../data/repositories/categorie_repository.dart';

class CategoriesController extends GetxController {
  final CategorieRepository _repo = CategorieRepository();

  final categories = <CategorieModel>[].obs;
  final chargement = true.obs;
  final recherche = ''.obs;
  final masquerInactives = false.obs;

  late final String tenantId;

  @override
  void onInit() {
    super.onInit();
    tenantId = SessionController.to.requireTenantId;
    categories.bindStream(
      _repo.watchByTenant(tenantId).map((liste) {
        chargement.value = false;
        return liste;
      }),
    );
  }

  List<CategorieModel> get resultats {
    final q = recherche.value.trim().toLowerCase();
    return categories.where((c) {
      if (masquerInactives.value && !c.active) return false;
      if (q.isEmpty) return true;
      return c.libelle.toLowerCase().contains(q) ||
          c.code.toLowerCase().contains(q);
    }).toList();
  }

  int get nbActives => categories.where((c) => c.active).length;

  /// La désactivation propage aux articles de la catégorie : on annonce
  /// combien sont concernés avant de demander confirmation, pour que
  /// l'administrateur mesure la portée de son geste.
  Future<void> basculerActivation(CategorieModel c) async {
    final desactivation = c.active;

    String message;
    if (desactivation) {
      final nb = await _repo.compterArticles(c.id, tenantId: tenantId);
      message = nb == 0
          ? '« ${c.libelle} » n\'apparaîtra plus au moment de facturer.'
          : '« ${c.libelle} » et ses $nb article(s) n\'apparaîtront plus au '
              'moment de facturer. Les factures déjà émises ne changent pas.';
    } else {
      message = '« ${c.libelle} » réapparaîtra dans les listes de sélection. '
          'Ses articles restent désactivés : réactivez ceux dont vous avez '
          'besoin depuis le catalogue.';
    }

    final ok = await confirmer(
      titre: desactivation ? 'Désactiver la catégorie' : 'Réactiver la catégorie',
      message: message,
      libelleConfirmer: desactivation ? 'Désactiver' : 'Réactiver',
      destructif: desactivation,
    );
    if (!ok) return;

    try {
      await _repo.setActive(c.id, !c.active, tenantId: tenantId);
    } catch (e) {
      Get.snackbar(
        'Action impossible',
        'Modification impossible : $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
