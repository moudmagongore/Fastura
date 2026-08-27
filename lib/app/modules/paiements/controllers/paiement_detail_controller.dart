import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/recu_pdf_service.dart';
import '../../../core/services/session_controller.dart';
import '../../../core/utils/pdf_helper.dart';
import '../../../core/widgets/champ_jetable.dart';
import '../../../data/repositories/client_repository.dart';
import '../../../data/models/paiement_model.dart';
import '../../../data/repositories/facture_repository.dart';
import '../../../data/repositories/paiement_repository.dart';

class PaiementDetailController extends GetxController {
  final PaiementRepository _repo = PaiementRepository();
  final ClientRepository _clientRepo = ClientRepository();

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

  /// Génère le reçu au format retenu par l'entreprise puis propose de
  /// l'imprimer ou de le partager.
  ///
  /// Le solde du client est relu au moment du tirage : c'est ce qu'il reste
  /// à devoir *aujourd'hui* qui intéresse le client, pas l'état figé au jour
  /// du versement.
  Future<void> imprimer() async {
    final p = paiement.value;
    final tenant = SessionController.to.tenant.value;
    if (p == null || tenant == null) return;

    await genererPuisImprimer(
      generer: () async {
        final client = await _clientRepo.getById(p.clientId);
        return RecuPdfService.construire(
          paiement: p,
          tenant: tenant,
          soldeApres: client?.solde,
        );
      },
      nomFichier: 'Recu-${p.clientNom}-${p.id}',
      titre: 'Reçu de ${p.clientNom}',
    );
  }

  Future<void> annuler(BuildContext context) async {
    final p = paiement.value;
    if (p == null || p.annule) return;

    final motif = await Get.dialog<String>(
      ChampJetable(
        builder: (_, ctrl) => AlertDialog(
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
      ),
    );
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
        snackPosition: SnackPosition.TOP,
      );
    } on FacturationException catch (e) {
      Get.snackbar(
        'Annulation impossible',
        e.message,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 6),
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
