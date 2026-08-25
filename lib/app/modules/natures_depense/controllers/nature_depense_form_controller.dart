import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/nature_depense_model.dart';
import '../../../data/repositories/nature_depense_repository.dart';

class NatureDepenseFormController extends GetxController {
  final NatureDepenseRepository _repo = NatureDepenseRepository();

  final formKey = GlobalKey<FormState>();
  final libelleCtrl = TextEditingController();

  final enregistrement = false.obs;
  final erreur = RxnString();

  late final String tenantId;
  NatureDepenseModel? _existante;

  bool get estEdition => _existante != null;
  String get titre =>
      estEdition ? 'Modifier la nature' : 'Nouvelle nature de dépense';

  @override
  void onInit() {
    super.onInit();
    tenantId = SessionController.to.requireTenantId;
    final arg = Get.arguments;
    if (arg is NatureDepenseModel) {
      _existante = arg;
      libelleCtrl.text = arg.libelle;
    }
  }

  @override
  void onClose() {
    libelleCtrl.dispose();
    super.onClose();
  }

  String? validerLibelle(String? v) =>
      Validators.requis(v, champ: 'Le libellé');

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
          NatureDepenseModel(id: '', libelle: libelle, tenantId: tenantId),
        );
      }

      Get.back();
      Get.snackbar(
        'Enregistré',
        estEdition
            ? 'La nature « $libelle » a été mise à jour.'
            : 'La nature « $libelle » a été créée.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      erreur.value = 'Enregistrement impossible : $e';
    } finally {
      enregistrement.value = false;
    }
  }
}
