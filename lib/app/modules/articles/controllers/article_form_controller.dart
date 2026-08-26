import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/article_model.dart';
import '../../../data/models/categorie_model.dart';
import '../../../data/repositories/article_repository.dart';
import '../../../data/repositories/categorie_repository.dart';

class ArticleFormController extends GetxController {
  final ArticleRepository _repo = ArticleRepository();
  final CategorieRepository _categorieRepo = CategorieRepository();

  final formKey = GlobalKey<FormState>();
  final designationCtrl = TextEditingController();
  final prixCtrl = TextEditingController();
  final uniteCtrl = TextEditingController();

  final categories = <CategorieModel>[].obs;
  final categorieId = RxnString();
  final enregistrement = false.obs;
  final erreur = RxnString();

  late final String tenantId;
  ArticleModel? _existant;

  bool get estEdition => _existant != null;
  String get titre => estEdition ? 'Modifier l\'article' : 'Nouvel article';
  String get devise => SessionController.to.devise;

  @override
  void onInit() {
    super.onInit();
    tenantId = SessionController.to.requireTenantId;

    final arg = Get.arguments;
    if (arg is ArticleModel) {
      _existant = arg;
      designationCtrl.text = arg.designation;
      prixCtrl.text = _formaterPrix(arg.prixVente);
      uniteCtrl.text = arg.unite;
      categorieId.value = arg.categorieId;
    }

    categories.bindStream(_categorieRepo.watchByTenant(tenantId));
  }

  @override
  void onClose() {
    designationCtrl.dispose();
    prixCtrl.dispose();
    uniteCtrl.dispose();
    super.onClose();
  }

  /// Catégories proposées : les actives, plus celle de l'article en cours
  /// d'édition même si elle a été désactivée entre-temps — sinon le
  /// sélecteur afficherait un vide et l'enregistrement échouerait sans
  /// que l'utilisateur comprenne pourquoi.
  List<CategorieModel> get categoriesSelectionnables {
    final courante = categorieId.value;
    return categories.where((c) => c.active || c.id == courante).toList();
  }

  bool get aucuneCategorie => categories.isEmpty;

  String? validerDesignation(String? v) =>
      Validators.requis(v, champ: 'La désignation');
  String? validerPrix(String? v) =>
      Validators.montant(v, champ: 'Le prix de vente');
  String? validerUnite(String? v) => Validators.requis(v, champ: 'L\'unité');

  Future<void> enregistrer() async {
    erreur.value = null;

    final cat = categorieId.value;
    if (cat == null || cat.isEmpty) {
      erreur.value = 'Choisissez une catégorie.';
      return;
    }
    if (!(formKey.currentState?.validate() ?? false)) return;

    enregistrement.value = true;
    try {
      final designation = designationCtrl.text.trim();
      final prix = Validators.parseMontant(prixCtrl.text)!;
      final unite = uniteCtrl.text.trim();

      if (estEdition) {
        await _repo.update(
          _existant!.copyWith(
            categorieId: cat,
            designation: designation,
            prixVente: prix,
            unite: unite,
          ),
        );
      } else {
        await _repo.create(
          ArticleModel(
            id: '',
            categorieId: cat,
            designation: designation,
            prixVente: prix,
            unite: unite,
            tenantId: tenantId,
          ),
        );
      }

      Get.back();
      Get.snackbar(
        'Enregistré',
        estEdition
            ? '« $designation » a été mis à jour.'
            : '« $designation » a été ajouté au catalogue.',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      erreur.value = 'Enregistrement impossible : $e';
    } finally {
      enregistrement.value = false;
    }
  }

  static String _formaterPrix(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
