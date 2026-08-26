import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/validators.dart';
import '../../../../data/models/format_impression.dart';
import '../../../../data/models/tenant_model.dart';
import '../../../../data/repositories/tenant_repository.dart';

/// Création et modification d'une entreprise, par le super-administrateur.
/// Le tenant passé en argument de route (`Get.arguments`) déclenche le mode
/// édition ; son absence, le mode création.
class TenantFormController extends GetxController {
  final TenantRepository _repo = TenantRepository();

  final formKey = GlobalKey<FormState>();

  final nomCtrl = TextEditingController();
  final adresseCtrl = TextEditingController();
  final telephoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final deviseCtrl = TextEditingController(text: AppConstants.defaultDevise);
  final tauxTvaCtrl = TextEditingController(
    text: AppConstants.defaultTauxTva.toString(),
  );
  final prefixeCtrl = TextEditingController(text: 'FA');

  final tvaActive = false.obs;
  final format = FormatImpression.a4.obs;
  final enregistrement = false.obs;

  TenantModel? _existant;

  bool get estEdition => _existant != null;
  String get titre =>
      estEdition ? 'Modifier l\'entreprise' : 'Nouvelle entreprise';

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    if (arg is TenantModel) {
      _existant = arg;
      nomCtrl.text = arg.nom;
      adresseCtrl.text = arg.adresse ?? '';
      telephoneCtrl.text = arg.telephone ?? '';
      emailCtrl.text = arg.email ?? '';
      deviseCtrl.text = arg.devise;
      tauxTvaCtrl.text = arg.tauxTva.toString();
      prefixeCtrl.text = arg.prefixeFacture;
      tvaActive.value = arg.tvaActive;
      format.value = arg.formatImpression;
    }
  }

  @override
  void onClose() {
    nomCtrl.dispose();
    adresseCtrl.dispose();
    telephoneCtrl.dispose();
    emailCtrl.dispose();
    deviseCtrl.dispose();
    tauxTvaCtrl.dispose();
    prefixeCtrl.dispose();
    super.onClose();
  }

  String? validerNom(String? v) =>
      Validators.requis(v, champ: 'Le nom de l\'entreprise');

  String? validerDevise(String? v) => Validators.requis(v, champ: 'La devise');

  String? validerTauxTva(String? v) {
    if (!tvaActive.value) return null;
    final taux = Validators.parseMontant(v);
    if (taux == null) return 'Taux invalide';
    if (taux < 0 || taux > 100) return 'Le taux doit être entre 0 et 100';
    return null;
  }

  Future<void> enregistrer() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    enregistrement.value = true;
    try {
      final base =
          _existant ?? TenantModel(id: '', nom: '', createdAt: DateTime.now());

      final tenant = base.copyWith(
        nom: nomCtrl.text.trim(),
        adresse: adresseCtrl.text.trim(),
        telephone: telephoneCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        devise: deviseCtrl.text.trim().toUpperCase(),
        tvaActive: tvaActive.value,
        tauxTva: Validators.parseMontant(tauxTvaCtrl.text) ?? 0,
        formatImpression: format.value,
        prefixeFacture: prefixeCtrl.text.trim().toUpperCase(),
      );

      if (estEdition) {
        await _repo.update(tenant);
      } else {
        await _repo.create(tenant);
      }

      Get.back();
      Get.snackbar(
        'Enregistré',
        estEdition
            ? 'Les informations de ${tenant.nom} ont été mises à jour.'
            : '${tenant.nom} a été créée.',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Enregistrement impossible : $e',
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      enregistrement.value = false;
    }
  }
}
