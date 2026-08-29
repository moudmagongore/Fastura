import 'dart:async';

import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../core/utils/filtre_periode.dart';
import '../../../data/models/paiement_model.dart';
import '../../../data/repositories/paiement_repository.dart';

class PaiementsController extends GetxController {
  final PaiementRepository _repo = PaiementRepository();

  final paiements = <PaiementModel>[].obs;
  final chargement = true.obs;
  final recherche = ''.obs;
  final masquerAnnules = true.obs;

  /// Période affichée. « Toutes » par défaut, comme le journal des
  /// factures : on y cherche un règlement ancien aussi souvent qu'on y fait
  /// le point du mois.
  late final FiltrePeriode periode = FiltrePeriode(onChangement: _ecouter);

  StreamSubscription<List<PaiementModel>>? _sub;

  late final String tenantId;

  @override
  void onInit() {
    super.onInit();
    tenantId = SessionController.to.requireTenantId;
    _ecouter();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  void _ecouter() {
    _sub?.cancel();
    chargement.value = true;
    _sub = _repo
        .watchByTenant(tenantId, depuis: periode.debut, jusqua: periode.fin)
        .listen((liste) {
          paiements.assignAll(liste);
          chargement.value = false;
        });
  }

  String get devise => SessionController.to.devise;

  List<PaiementModel> get resultats {
    final q = recherche.value.trim().toLowerCase();
    return paiements.where((p) {
      if (masquerAnnules.value && p.annule) return false;
      if (q.isEmpty) return true;
      return p.clientNom.toLowerCase().contains(q) ||
          p.imputations.any((i) => i.factureNumero.toLowerCase().contains(q));
    }).toList();
  }

  /// Total encaissé sur la période affichée, annulations exclues.
  double get totalEncaisse => paiements
      .where((p) => !p.annule)
      .fold<double>(0, (somme, p) => somme + p.montant);
}
