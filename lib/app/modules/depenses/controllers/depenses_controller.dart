import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/depenses_pdf_service.dart';
import '../../../core/services/session_controller.dart';
import '../../../core/utils/pdf_helper.dart';
import '../../../data/models/depense_model.dart';
import '../../../data/models/nature_depense_model.dart';
import '../../../data/repositories/depense_repository.dart';
import '../../../data/repositories/nature_depense_repository.dart';

/// Périodes proposées au filtre. Le mois courant par défaut : c'est la
/// maille sur laquelle un commerçant raisonne quand il regarde ses sorties.
enum PeriodeDepense {
  ceMois,
  moisDernier,
  trenteJours,
  personnalisee;

  String get label => switch (this) {
    PeriodeDepense.ceMois => 'Ce mois',
    PeriodeDepense.moisDernier => 'Mois dernier',
    PeriodeDepense.trenteJours => '30 jours',
    PeriodeDepense.personnalisee => 'Période…',
  };
}

class DepensesController extends GetxController {
  final DepenseRepository _repo = DepenseRepository();
  final NatureDepenseRepository _naturesRepo = NatureDepenseRepository();

  final depenses = <DepenseModel>[].obs;
  final natures = <NatureDepenseModel>[].obs;

  final chargement = true.obs;
  final recherche = ''.obs;
  final masquerAnnulees = true.obs;
  final filtreNatureId = ''.obs;

  final periode = PeriodeDepense.ceMois.obs;
  final debutPersonnalise = Rxn<DateTime>();
  final finPersonnalisee = Rxn<DateTime>();

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

  DateTime get debut {
    final maintenant = DateTime.now();
    return switch (periode.value) {
      PeriodeDepense.ceMois => DateTime(maintenant.year, maintenant.month),
      PeriodeDepense.moisDernier => DateTime(
        maintenant.year,
        maintenant.month - 1,
      ),
      PeriodeDepense.trenteJours => DateTime(
        maintenant.year,
        maintenant.month,
        maintenant.day - 29,
      ),
      PeriodeDepense.personnalisee =>
        debutPersonnalise.value ?? DateTime(maintenant.year, maintenant.month),
    };
  }

  DateTime get fin {
    final maintenant = DateTime.now();
    // Toujours la fin de journée : une dépense saisie cet après-midi porte
    // une heure, et une borne à minuit la laisserait hors de la période.
    DateTime finDeJournee(DateTime d) =>
        DateTime(d.year, d.month, d.day, 23, 59, 59);

    return switch (periode.value) {
      PeriodeDepense.moisDernier => finDeJournee(
        DateTime(maintenant.year, maintenant.month, 0),
      ),
      PeriodeDepense.personnalisee => finDeJournee(
        finPersonnalisee.value ?? maintenant,
      ),
      _ => finDeJournee(maintenant),
    };
  }

  String get libellePeriode => switch (periode.value) {
    PeriodeDepense.ceMois => 'Ce mois',
    PeriodeDepense.moisDernier => 'Mois dernier',
    PeriodeDepense.trenteJours => '30 derniers jours',
    PeriodeDepense.personnalisee => 'Période choisie',
  };

  void choisirPeriode(PeriodeDepense p) {
    if (p == periode.value && p != PeriodeDepense.personnalisee) return;
    periode.value = p;
    _ecouter();
  }

  /// Ouvre le sélecteur de plage. Sans choix, la période courante est
  /// conservée : refermer un calendrier ne doit pas vider la liste.
  Future<void> choisirPlage(BuildContext context) async {
    final maintenant = DateTime.now();
    final plage = await showDateRangePicker(
      context: context,
      firstDate: DateTime(maintenant.year - 3),
      lastDate: maintenant,
      initialDateRange: DateTimeRange(start: debut, end: fin),
    );
    if (plage == null) return;
    debutPersonnalise.value = plage.start;
    finPersonnalisee.value = plage.end;
    periode.value = PeriodeDepense.personnalisee;
    _ecouter();
  }

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

    await genererPuisImprimer(
      generer: () async => DepensesPdfService.construire(
        tenant: tenant,
        depenses: lignes,
        repartition: repartition,
        debut: debut,
        fin: fin,
        total: total,
      ),
      nomFichier: 'Depenses-${tenant.nom}',
      titre: 'Récapitulatif des dépenses',
    );
  }
}
