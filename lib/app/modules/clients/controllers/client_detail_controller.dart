import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/facture_model.dart';
import '../../../data/models/paiement_model.dart';
import '../../../data/repositories/client_repository.dart';
import '../../../data/repositories/facture_repository.dart';
import '../../../data/repositories/paiement_repository.dart';

/// Fiche d'un client : identité, solde, et à terme son historique de
/// factures et de paiements.
class ClientDetailController extends GetxController {
  final ClientRepository _repo = ClientRepository();
  final FactureRepository _factureRepo = FactureRepository();
  final PaiementRepository _paiementRepo = PaiementRepository();

  final client = Rxn<ClientModel>();
  final factures = <FactureModel>[].obs;
  final paiements = <PaiementModel>[].obs;
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

    final tenantId = SessionController.to.requireTenantId;
    factures.bindStream(
      _factureRepo.watchByClient(arg.id, tenantId: tenantId),
    );
    paiements.bindStream(
      _paiementRepo.watchByClient(arg.id, tenantId: tenantId),
    );
  }

  String get devise => SessionController.to.devise;

  /// Factures encore à encaisser, de la plus ancienne à la plus récente —
  /// l'ordre dans lequel le lettrage FIFO les soldera.
  List<FactureModel> get facturesImpayees {
    final liste = factures.where((f) => !f.annulee && f.resteDu > 0).toList();
    liste.sort((a, b) => a.date.compareTo(b.date));
    return liste;
  }
}
