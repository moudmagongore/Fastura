import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../core/widgets/champ_jetable.dart';
import '../../../data/models/depense_model.dart';
import '../../../data/repositories/depense_repository.dart';

class DepenseDetailController extends GetxController {
  final DepenseRepository _repo = DepenseRepository();

  final depense = Rxn<DepenseModel>();
  final introuvable = false.obs;
  final annulationEnCours = false.obs;

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    if (arg is DepenseModel) {
      depense.value = arg;
      depense.bindStream(_repo.watchById(arg.id));
    } else if (arg is String && arg.isNotEmpty) {
      depense.bindStream(_repo.watchById(arg));
    } else {
      introuvable.value = true;
    }
  }

  String get devise => SessionController.to.devise;

  bool get peutAnnuler {
    final d = depense.value;
    return d != null && !d.annulee && SessionController.to.peutAnnuler;
  }

  Future<void> annuler() async {
    final d = depense.value;
    if (d == null || d.annulee) return;

    final motif = await Get.dialog<String>(
      ChampJetable(
        builder: (_, ctrl) => AlertDialog(
          title: const Text('Annuler la dépense'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'La dépense restera dans l\'historique, barrée et motivée, '
                'mais sortira des totaux de la période.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Motif (facultatif)',
                  hintText: 'Ex : erreur de montant, doublon de saisie',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Renoncer'),
            ),
            TextButton(
              onPressed: () => Get.back(result: ctrl.text.trim()),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Annuler la dépense'),
            ),
          ],
        ),
      ),
    );
    if (motif == null) return;

    annulationEnCours.value = true;
    try {
      await _repo.annuler(
        d,
        parNom: SessionController.to.user.value?.nom ?? '',
        motif: motif.isEmpty ? null : motif,
      );
      Get.snackbar(
        'Dépense annulée',
        'Elle ne compte plus dans les totaux.',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar(
        'Annulation impossible',
        '$e',
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      annulationEnCours.value = false;
    }
  }
}
