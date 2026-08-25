import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../data/models/facture_model.dart';
import '../../../data/repositories/facture_repository.dart';

class FactureDetailController extends GetxController {
  final FactureRepository _repo = FactureRepository();

  final facture = Rxn<FactureModel>();
  final introuvable = false.obs;
  final annulationEnCours = false.obs;

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    if (arg is FactureModel) {
      facture.value = arg;
      // Suivi du document : le statut et le montant réglé évoluent dès
      // qu'un paiement est enregistré, y compris depuis un autre appareil.
      facture.bindStream(_repo.watchById(arg.id));
    } else if (arg is String && arg.isNotEmpty) {
      facture.bindStream(_repo.watchById(arg));
    } else {
      introuvable.value = true;
    }
  }

  String get devise => facture.value?.devise ?? SessionController.to.devise;

  /// Seul l'administrateur annule (CDC §1.3). Le bouton n'apparaît pas pour
  /// le vendeur, et `firestore.rules` refuse l'écriture de toute façon.
  bool get peutAnnuler {
    final f = facture.value;
    return f != null && !f.annulee && SessionController.to.peutAnnuler;
  }

  Future<void> annuler(BuildContext context) async {
    final f = facture.value;
    if (f == null || f.annulee) return;

    final motif = await _demanderMotif(context, f);
    if (motif == null) return;

    annulationEnCours.value = true;
    try {
      await _repo.annuler(
        f,
        parNom: SessionController.to.user.value?.nom ?? '',
        motif: motif.isEmpty ? null : motif,
      );
      Get.snackbar(
        'Facture annulée',
        '${f.numero} ne compte plus dans le solde de ${f.clientNom}.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
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

  /// Demande le motif. Renvoie `null` si l'administrateur renonce.
  ///
  /// Le motif est facultatif mais proposé systématiquement : une annulation
  /// laisse une trace définitive dans l'historique, autant qu'elle soit
  /// explicable des mois plus tard.
  Future<String?> _demanderMotif(BuildContext context, FactureModel f) async {
    final ctrl = TextEditingController();
    final resultat = await Get.dialog<String>(
      AlertDialog(
        title: const Text('Annuler la facture'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${f.numero} sera marquée annulée et sortira du solde de '
              '${f.clientNom}. Elle reste dans l\'historique : la '
              'numérotation ne tolère aucun trou.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Motif (facultatif)',
                hintText: 'Ex : erreur de saisie, commande annulée',
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
            child: const Text('Annuler la facture'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return resultat;
  }
}
