import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../data/models/client_model.dart';
import '../../../data/repositories/client_repository.dart';

/// Fiche d'un client : identité, solde, et à terme son historique de
/// factures et de paiements.
class ClientDetailController extends GetxController {
  final ClientRepository _repo = ClientRepository();

  final client = Rxn<ClientModel>();
  final introuvable = false.obs;

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    if (arg is! ClientModel) {
      introuvable.value = true;
      return;
    }

    // On part de l'objet passé pour afficher immédiatement, puis on suit le
    // document : le solde bouge dès qu'une facture ou un règlement est
    // enregistré, y compris depuis un autre appareil.
    client.value = arg;
    client.bindStream(_repo.watchById(arg.id));
  }

  String get devise => SessionController.to.devise;
}
