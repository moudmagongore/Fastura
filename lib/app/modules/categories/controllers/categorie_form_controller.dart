import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/categorie_model.dart';
import '../../../data/repositories/categorie_repository.dart';

class CategorieFormController extends GetxController {
  final CategorieRepository _repo = CategorieRepository();

  final formKey = GlobalKey<FormState>();
  final libelleCtrl = TextEditingController();

  final enregistrement = false.obs;
  final erreur = RxnString();

  late final String tenantId;
  CategorieModel? _existante;

  bool get estEdition => _existante != null;
  String get titre => estEdition ? 'Modifier la catégorie' : 'Nouvelle catégorie';

  @override
  void onInit() {
    super.onInit();
    tenantId = SessionController.to.requireTenantId;
    final arg = Get.arguments;
    if (arg is CategorieModel) {
      _existante = arg;
      libelleCtrl.text = arg.libelle;
    }
  }

  @override
  void onClose() {
    libelleCtrl.dispose();
    super.onClose();
  }

  String? validerLibelle(String? v) => Validators.requis(v, champ: 'Le libellé');

  Future<void> enregistrer() async {
    erreur.value = null;
    if (!(formKey.currentState?.validate() ?? false)) return;

    enregistrement.value = true;
    try {
      final libelle = libelleCtrl.text.trim();

      if (estEdition) {
        await _repo.update(_existante!.copyWith(libelle: libelle));
      } else {
        await _repo.create(
          CategorieModel(
            id: '',
            libelle: libelle,
            tenantId: tenantId,
          ),
        );
      }

      Get.back();
      Get.snackbar(
        'Enregistré',
        estEdition
            ? 'La catégorie « $libelle » a été mise à jour.'
            : 'La catégorie « $libelle » a été créée.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      erreur.value = 'Enregistrement impossible : $e';
    } finally {
      enregistrement.value = false;
    }
  }
}
