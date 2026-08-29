import 'dart:async';

import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../core/utils/filtre_periode.dart';
import '../../../data/models/facture_model.dart';
import '../../../data/repositories/facture_repository.dart';

/// Filtres du journal des factures.
enum FiltreFacture {
  toutes,
  impayees,
  partielles,
  payees,
  annulees;

  String get label => switch (this) {
    FiltreFacture.toutes => 'Toutes',
    FiltreFacture.impayees => 'Impayées',
    FiltreFacture.partielles => 'Partielles',
    FiltreFacture.payees => 'Payées',
    FiltreFacture.annulees => 'Annulées',
  };
}

class FacturesController extends GetxController {
  final FactureRepository _repo = FactureRepository();

  final factures = <FactureModel>[].obs;
  final chargement = true.obs;
  final recherche = ''.obs;
  final filtre = FiltreFacture.toutes.obs;

  /// Période affichée. « Toutes » par défaut : le journal sert autant à
  /// retrouver une vieille facture qu'à faire le point du mois, et une
  /// borne posée d'office la cacherait — la recherche ne porte que sur ce
  /// qui est chargé.
  late final FiltrePeriode periode = FiltrePeriode(onChangement: _ecouter);

  StreamSubscription<List<FactureModel>>? _sub;

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
          factures.assignAll(liste);
          chargement.value = false;
        });
  }

  String get devise => SessionController.to.devise;

  List<FactureModel> get resultats {
    final q = recherche.value.trim().toLowerCase();
    return factures.where((f) {
      switch (filtre.value) {
        case FiltreFacture.toutes:
          break;
        case FiltreFacture.annulees:
          if (!f.annulee) return false;
        case FiltreFacture.impayees:
          if (f.annulee || f.statut != StatutFacture.impayee) return false;
        case FiltreFacture.partielles:
          if (f.annulee || f.statut != StatutFacture.partielle) return false;
        case FiltreFacture.payees:
          if (f.annulee || f.statut != StatutFacture.payee) return false;
      }
      // Les factures annulées ne remontent que via leur propre filtre :
      // elles polluraient le journal courant sans rien y apporter.
      if (filtre.value != FiltreFacture.annulees &&
          filtre.value != FiltreFacture.toutes &&
          f.annulee) {
        return false;
      }
      if (q.isEmpty) return true;
      return f.numero.toLowerCase().contains(q) ||
          f.clientAffiche.toLowerCase().contains(q);
    }).toList();
  }

  /// Total facturé sur la période affichée, annulations exclues.
  double get totalFacture => factures
      .where((f) => !f.annulee)
      .fold<double>(0, (somme, f) => somme + f.montantTotal);

  /// Ce qu'il reste à encaisser sur l'ensemble des factures affichées.
  double get totalResteDu =>
      factures.fold<double>(0, (somme, f) => somme + f.resteDu);
}
