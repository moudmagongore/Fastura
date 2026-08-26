import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/depense_model.dart';
import '../../../data/models/nature_depense_model.dart';
import '../../../data/repositories/depense_repository.dart';
import '../../../data/repositories/facture_repository.dart';
import '../../../data/repositories/nature_depense_repository.dart';

/// Saisie d'une dépense.
///
/// Une dépense ne se modifie pas après coup : comme une facture, elle se
/// corrige par annulation puis nouvelle saisie. Ce contrôleur ne sert donc
/// qu'à la création.
class DepenseFormController extends GetxController {
  final DepenseRepository _repo = DepenseRepository();
  final NatureDepenseRepository _naturesRepo = NatureDepenseRepository();

  final formKey = GlobalKey<FormState>();
  final montantCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();

  final natures = <NatureDepenseModel>[].obs;
  final natureId = RxnString();
  final date = DateTime.now().obs;

  final chargement = true.obs;
  final enregistrement = false.obs;
  final erreur = RxnString();

  late final String tenantId;

  @override
  void onInit() {
    super.onInit();
    tenantId = SessionController.to.requireTenantId;
    natures.bindStream(
      _naturesRepo.watchByTenant(tenantId, actifsSeulement: true).map((liste) {
        chargement.value = false;
        return liste;
      }),
    );
  }

  @override
  void onClose() {
    montantCtrl.dispose();
    descriptionCtrl.dispose();
    super.onClose();
  }

  String get devise => SessionController.to.devise;

  /// Aucune nature active : la saisie est impossible tant que
  /// l'administrateur n'a pas défini sa nomenclature (CDC §7).
  bool get aucuneNature => !chargement.value && natures.isEmpty;

  bool get peutGererNatures => SessionController.to.peutGererReferentiels;

  String? validerMontant(String? v) => Validators.montant(v);

  Future<void> choisirDate(BuildContext context) async {
    final choisie = await showDatePicker(
      context: context,
      initialDate: date.value,
      firstDate: DateTime(date.value.year - 2),
      lastDate: DateTime.now(),
    );
    if (choisie != null) date.value = choisie;
  }

  Future<void> enregistrer() async {
    erreur.value = null;

    final nature = natures.firstWhereOrNull((n) => n.id == natureId.value);
    if (nature == null) {
      erreur.value = 'Choisissez une nature de dépense.';
      return;
    }
    if (!(formKey.currentState?.validate() ?? false)) return;

    final utilisateur = SessionController.to.user.value;
    if (utilisateur == null) {
      erreur.value = 'Session expirée. Reconnectez-vous.';
      return;
    }

    enregistrement.value = true;
    try {
      final description = descriptionCtrl.text.trim();
      final depense = await _repo.creer(
        tenantId: tenantId,
        natureId: nature.id,
        natureLibelle: nature.libelle,
        montant: Validators.parseMontant(montantCtrl.text)!,
        date: date.value,
        creeParId: utilisateur.id,
        creeParNom: utilisateur.nom,
        description: description.isEmpty ? null : description,
      );

      Get.back<DepenseModel>(result: depense);
      Get.snackbar(
        'Dépense enregistrée',
        '${nature.libelle} — ${montantCtrl.text.trim()} $devise',
        snackPosition: SnackPosition.TOP,
      );
    } on FacturationException catch (e) {
      erreur.value = e.message;
    } catch (e) {
      erreur.value = 'Enregistrement impossible : $e';
    } finally {
      enregistrement.value = false;
    }
  }
}
