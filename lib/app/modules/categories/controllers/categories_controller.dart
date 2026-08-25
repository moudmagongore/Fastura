import 'package:flutter/material.dart';
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

  /// Bascule le statut d'une catégorie.
  ///
  /// À la **désactivation**, la cascade est automatique et on annonce combien
  /// d'articles elle emporte, pour que l'administrateur mesure la portée de
  /// son geste.
  ///
  /// À la **réactivation**, la cascade est proposée mais jamais imposée : un
  /// article fermé pour rupture définitive n'a pas à rouvrir parce que sa
  /// catégorie rouvre. L'écran pose donc la question au lieu de trancher à
  /// la place de l'administrateur.
  Future<void> basculerActivation(CategorieModel c) async {
    if (c.active) {
      await _desactiver(c);
    } else {
      await _reactiver(c);
    }
  }

  Future<void> _desactiver(CategorieModel c) async {
    final nb = await _repo.compterArticles(
      c.id,
      tenantId: tenantId,
      active: true,
    );

    final ok = await confirmer(
      titre: 'Désactiver la catégorie',
      message: nb == 0
          ? '« ${c.libelle} » n\'apparaîtra plus au moment de facturer.'
          : '« ${c.libelle} » et ses $nb article(s) actif(s) n\'apparaîtront '
              'plus au moment de facturer. Les factures déjà émises ne '
              'changent pas.',
      libelleConfirmer: 'Désactiver',
      destructif: true,
    );
    if (!ok) return;

    await _appliquer(() => _repo.setActive(c.id, false, tenantId: tenantId));
  }

  Future<void> _reactiver(CategorieModel c) async {
    final nbInactifs = await _repo.compterArticles(
      c.id,
      tenantId: tenantId,
      active: false,
    );

    // Sans article fermé, la question ne se pose pas.
    if (nbInactifs == 0) {
      final ok = await confirmer(
        titre: 'Réactiver la catégorie',
        message: '« ${c.libelle} » réapparaîtra dans les listes de sélection.',
        libelleConfirmer: 'Réactiver',
      );
      if (!ok) return;
      await _appliquer(() => _repo.setActive(c.id, true, tenantId: tenantId));
      return;
    }

    final choix = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Réactiver la catégorie'),
        content: Text(
          '« ${c.libelle} » compte $nbInactifs article(s) désactivé(s).\n\n'
          'Voulez-vous les réactiver aussi ? Répondez non si certains ont été '
          'fermés pour une raison qui leur est propre — vous pourrez les '
          'rouvrir un par un depuis le catalogue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Renoncer'),
          ),
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('La catégorie seule'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('Tout réactiver ($nbInactifs)'),
          ),
        ],
      ),
    );
    if (choix == null) return;

    await _appliquer(
      () => _repo.setActive(
        c.id,
        true,
        tenantId: tenantId,
        reactiverArticles: choix,
      ),
    );
  }

  Future<void> _appliquer(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      Get.snackbar(
        'Action impossible',
        'Modification impossible : $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
