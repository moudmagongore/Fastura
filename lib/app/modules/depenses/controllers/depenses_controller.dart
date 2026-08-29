import 'dart:async';

import 'package:get/get.dart';

import '../../../core/services/depenses_pdf_service.dart';
import '../../../core/services/session_controller.dart';
import '../../../core/utils/filtre_periode.dart';
import '../../../core/utils/pdf_helper.dart';
import '../../../data/models/depense_model.dart';
import '../../../data/models/nature_depense_model.dart';
import '../../../data/repositories/depense_repository.dart';
import '../../../data/repositories/nature_depense_repository.dart';

class DepensesController extends GetxController {
  final DepenseRepository _repo = DepenseRepository();
  final NatureDepenseRepository _naturesRepo = NatureDepenseRepository();

  final depenses = <DepenseModel>[].obs;
  final natures = <NatureDepenseModel>[].obs;

  final chargement = true.obs;
  final recherche = ''.obs;
  final masquerAnnulees = true.obs;
  final filtreNatureId = ''.obs;

  /// Sans borne à l'ouverture, comme les journaux des factures et des
  /// paiements : c'est l'utilisateur qui pose ses dates. Le plafond de
  /// lecture du repository contient le volume tant qu'il n'en pose pas.
  late final FiltrePeriode periode = FiltrePeriode(onChangement: _ecouter);

  StreamSubscription<List<DepenseModel>>? _sub;

  late final String tenantId;

  @override
  void onInit() {
    super.onInit();
    tenantId = SessionController.to.requireTenantId;
    natures.bindStream(_naturesRepo.watchByTenant(tenantId));
    _ecouter();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  String get devise => SessionController.to.devise;

  // ------------------------------------------------------------- période

  /// Nulles tant qu'aucune borne n'est posée.
  DateTime? get debut => periode.debut;
  DateTime? get fin => periode.fin;

  String get libellePeriode => periode.libelle;

  void _ecouter() {
    _sub?.cancel();
    chargement.value = true;
    _sub = _repo.watchByTenant(tenantId, debut: debut, fin: fin).listen((
      liste,
    ) {
      depenses.assignAll(liste);
      chargement.value = false;
    });
  }

  // ------------------------------------------------------------- filtres

  /// Libellé courant de la nature, à défaut celui recopié à la saisie : une
  /// nature renommée doit s'afficher sous son nom d'aujourd'hui, mais une
  /// dépense dont la nature a disparu du référentiel ne doit pas devenir
  /// anonyme.
  String libelleNature(DepenseModel d) {
    final courante = natures.firstWhereOrNull((n) => n.id == d.natureId);
    return courante?.libelle ?? d.natureLibelle;
  }

  List<NatureDepenseModel> get naturesFiltrables {
    // Une nature fermée reste proposée au filtre tant qu'elle porte des
    // dépenses de la période : sinon on ne pourrait plus les isoler.
    final utilisees = depenses.map((d) => d.natureId).toSet();
    return natures.where((n) => n.active || utilisees.contains(n.id)).toList();
  }

  List<DepenseModel> get resultats {
    final q = recherche.value.trim().toLowerCase();
    final nature = filtreNatureId.value;
    return depenses.where((d) {
      if (masquerAnnulees.value && d.annulee) return false;
      if (nature.isNotEmpty && d.natureId != nature) return false;
      if (q.isEmpty) return true;
      return libelleNature(d).toLowerCase().contains(q) ||
          (d.description ?? '').toLowerCase().contains(q) ||
          d.creeParNom.toLowerCase().contains(q);
    }).toList();
  }

  /// Total de ce qui est affiché, annulations exclues : une dépense annulée
  /// reste visible mais ne pèse plus rien.
  double get total => resultats
      .where((d) => !d.annulee)
      .fold<double>(0, (somme, d) => somme + d.montant);

  /// Répartition par nature, la plus lourde d'abord.
  List<TotalNature> get repartition {
    final parNature = <String, TotalNature>{};
    for (final d in resultats.where((d) => !d.annulee)) {
      final courant = parNature[d.natureId];
      parNature[d.natureId] = TotalNature(
        natureId: d.natureId,
        libelle: libelleNature(d),
        montant: (courant?.montant ?? 0) + d.montant,
        nombre: (courant?.nombre ?? 0) + 1,
      );
    }
    final liste = parNature.values.toList()
      ..sort((a, b) => b.montant.compareTo(a.montant));
    return liste;
  }

  /// Récapitulatif imprimable de la période (CDC §7).
  Future<void> imprimerRecapitulatif() async {
    final tenant = SessionController.to.tenant.value;
    if (tenant == null) return;

    final lignes = resultats.where((d) => !d.annulee).toList();
    if (lignes.isEmpty) {
      Get.snackbar(
        'Rien à imprimer',
        'Aucune dépense sur la période sélectionnée.',
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    // Sans borne posée, le document annonce la période qu'il couvre
    // réellement — celle des dépenses listées. Un récapitulatif sans dates
    // ne se classe pas.
    final dates = lignes.map((d) => d.date).toList()..sort();

    await genererPuisImprimer(
      generer: () async => DepensesPdfService.construire(
        tenant: tenant,
        depenses: lignes,
        repartition: repartition,
        debut: debut ?? dates.first,
        fin: fin ?? dates.last,
        total: total,
      ),
      nomFichier: 'Depenses-${tenant.nom}',
      titre: 'Récapitulatif des dépenses',
    );
  }
}
