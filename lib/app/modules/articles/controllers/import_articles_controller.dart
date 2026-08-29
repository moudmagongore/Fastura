import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../data/models/article_model.dart';
import '../../../data/models/categorie_model.dart';
import '../../../data/repositories/article_repository.dart';
import '../../../data/repositories/categorie_repository.dart';
import '../import_articles.dart';

/// Import d'articles par collage.
///
/// Saisir un catalogue de plusieurs centaines d'articles un par un
/// représente des milliers de gestes. Ici l'administrateur choisit une
/// catégorie, colle sa liste — depuis un tableur, un message, un cahier
/// recopié — vérifie l'aperçu, et valide.
///
/// **Rien n'est écrit avant l'aperçu.** Le catalogue ne supprime jamais : un
/// import raté ne se rattrape qu'en désactivant les articles un par un.
class ImportArticlesController extends GetxController {
  final ArticleRepository _repo = ArticleRepository();
  final CategorieRepository _categoriesRepo = CategorieRepository();

  final categories = <CategorieModel>[].obs;
  final categorieId = RxnString();

  final texteCtrl = TextEditingController();
  final uniteCtrl = TextEditingController(text: 'pièce');

  final lignes = <LigneImport>[].obs;
  final analysee = false.obs;
  final tronquee = false.obs;
  final analyse = false.obs;
  final enregistrement = false.obs;
  final erreur = RxnString();

  late final String tenantId;

  @override
  void onInit() {
    super.onInit();
    tenantId = SessionController.to.requireTenantId;
    categories.bindStream(
      _categoriesRepo.watchByTenant(tenantId, actifsSeulement: true),
    );
  }

  @override
  void onClose() {
    texteCtrl.dispose();
    uniteCtrl.dispose();
    super.onClose();
  }

  String get devise => SessionController.to.devise;

  CategorieModel? get categorie =>
      categories.firstWhereOrNull((c) => c.id == categorieId.value);

  int get nbRetenues => lignes.where((l) => l.retenue).length;
  int get nbCreables =>
      lignes.where((l) => l.statut == StatutLigne.creable).length;
  int get nbDoublons =>
      lignes.where((l) => l.statut == StatutLigne.doublon).length;
  int get nbErreurs =>
      lignes.where((l) => l.statut == StatutLigne.erreur).length;

  /// Découpe le texte collé et confronte chaque ligne au catalogue.
  Future<void> analyser() async {
    erreur.value = null;
    final cat = categorieId.value;
    if (cat == null || cat.isEmpty) {
      erreur.value = 'Choisissez la catégorie de ces articles.';
      return;
    }
    if (texteCtrl.text.trim().isEmpty) {
      erreur.value = 'Collez votre liste, une ligne par article.';
      return;
    }

    analyse.value = true;
    try {
      final existantes = await _repo.designationsDe(tenantId, cat);
      final resultat = AnalyseImport.analyser(
        texteCtrl.text,
        uniteParDefaut: uniteCtrl.text.trim().isEmpty
            ? 'pièce'
            : uniteCtrl.text.trim(),
        existantes: existantes,
      );
      lignes.assignAll(resultat.lignes);
      tronquee.value = resultat.tronquee;
      analysee.value = true;
      if (resultat.lignes.isEmpty) {
        erreur.value = 'Aucune ligne exploitable dans ce texte.';
        analysee.value = false;
      }
    } catch (e) {
      erreur.value = 'Analyse impossible : $e';
    } finally {
      analyse.value = false;
    }
  }

  /// Retour à la saisie, en conservant le texte : on corrige une ligne et on
  /// relance, on ne recolle pas tout.
  void modifierLaListe() {
    analysee.value = false;
    erreur.value = null;
  }

  void basculer(LigneImport ligne) {
    if (!ligne.modifiable) return;
    ligne.retenue = !ligne.retenue;
    lignes.refresh();
  }

  Future<void> creer() async {
    erreur.value = null;
    final cat = categorieId.value;
    final retenues = lignes.where((l) => l.retenue).toList();
    if (cat == null || retenues.isEmpty) return;

    enregistrement.value = true;
    try {
      final crees = await _repo.creerLot([
        for (final l in retenues)
          ArticleModel(
            id: '',
            categorieId: cat,
            designation: l.designation,
            prixVente: l.prix,
            unite: l.unite,
            tenantId: tenantId,
          ),
      ]);

      Get.back();
      Get.snackbar(
        'Catalogue enrichi',
        '$crees article(s) créé(s) dans ${categorie?.libelle ?? 'la catégorie'}.',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      // Les lots partent l'un après l'autre : un échec en cours de route
      // laisse les précédents créés. Le dire plutôt que de laisser croire
      // que rien n'a été écrit.
      erreur.value =
          'Import interrompu ($e). Une partie des articles a pu être créée : '
          'vérifiez le catalogue avant de recommencer.';
    } finally {
      enregistrement.value = false;
    }
  }
}
