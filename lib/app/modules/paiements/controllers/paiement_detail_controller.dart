import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../data/models/paiement_model.dart';
import '../../../data/repositories/facture_repository.dart';
import '../../../data/repositories/paiement_repository.dart';

class PaiementDetailController extends GetxController {
  final PaiementRepository _repo = PaiementRepository();

  final paiement = Rxn<PaiementModel>();
  final introuvable = false.obs;
  final annulationEnCours = false.obs;

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    if (arg is PaiementModel) {
      paiement.value = arg;
      paiement.bindStream(_repo.watchById(arg.id));
    } else if (arg is String && arg.isNotEmpty) {
      paiement.bindStream(_repo.watchById(arg));
    } else {
      introuvable.value = true;
    }
  }

  String get devise => SessionController.to.devise;

  bool get peutAnnuler {
    final p = paiement.value;
    return p != null && !p.annule && SessionController.to.peutAnnuler;
  }

  Future<void> annuler(BuildContext context) async {
    final p = paiement.value;
    if (p == null || p.annule) return;

    final ctrl = TextEditingController();
    final motif = await Get.dialog<String>(
      AlertDialog(
        title: const Text('Annuler le règlement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.imputations.isEmpty
                  ? 'Ce règlement était entièrement en avance. Le solde de '
                      '${p.clientNom} remontera d\'autant.'
                  : 'Les ${p.imputations.length} facture(s) soldée(s) par ce '
                      'règlement redeviendront dues, et le solde de '
                      '${p.clientNom} remontera du montant encaissé.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Motif (facultatif)',
                hintText: 'Ex : erreur de saisie, chèque sans provision',
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
            child: const Text('Annuler le règlement'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (motif == null) return;

    annulationEnCours.value = true;
    try {
      await _repo.annuler(
        p,
        parNom: SessionController.to.user.value?.nom ?? '',
        motif: motif.isEmpty ? null : motif,
      );
      Get.snackbar(
        'Règlement annulé',
        'Le solde de ${p.clientNom} a été mis à jour.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on FacturationException catch (e) {
      Get.snackbar(
        'Annulation impossible',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 6),
      );
    } catch (e) {
      Get.snackbar(
        'Annulation impossible',
        '$e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      annulationEnCours.value = false;
    }
  }
}
