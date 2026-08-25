import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/facture_model.dart';
import '../../../data/models/paiement_model.dart';
import '../../../data/repositories/facture_repository.dart';
import '../../../data/repositories/paiement_repository.dart';

/// Projection d'une ligne du lettrage, calculée à l'écran avant validation.
class ApercuImputation {
  const ApercuImputation({required this.facture, required this.montant});

  final FactureModel facture;
  final double montant;

  bool get solde => montant >= facture.resteDu - 0.005;
}

/// Encaissement d'un règlement pour un client donné.
///
/// Le lettrage FIFO est rejoué **à l'écran** pendant la saisie, à titre
/// d'aperçu : le vendeur voit exactement quelles factures son montant va
/// solder avant de valider. Le lettrage qui fait foi reste celui de la
/// transaction, rejoué sur des montants relus — un autre appareil a pu
/// encaisser entre-temps.
class PaiementFormController extends GetxController {
  PaiementFormController({required this.client});

  final ClientModel client;

  final PaiementRepository _repo = PaiementRepository();

  /// Factures à apurer, les plus anciennes d'abord.
  final aApurer = <FactureModel>[].obs;
  final chargement = true.obs;

  final montantCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  final mode = ModePaiement.especes.obs;
  final date = DateTime.now().obs;

  final enregistrement = false.obs;
  final erreur = RxnString();

  late final String tenantId;

  /// Renseigné après un encaissement réussi, pour que la feuille se ferme en
  /// rendant le règlement à l'appelant.
  PaiementModel? resultat;

  @override
  void onInit() {
    super.onInit();
    tenantId = SessionController.to.requireTenantId;

    // Pré-remplit avec la dette en cours : c'est le montant attendu neuf
    // fois sur dix, et il reste modifiable.
    if (client.solde > 0) {
      montantCtrl.text = client.solde == client.solde.roundToDouble()
          ? client.solde.toStringAsFixed(0)
          : client.solde.toStringAsFixed(2);
    }

    _charger();
  }

  @override
  void onClose() {
    montantCtrl.dispose();
    noteCtrl.dispose();
    super.onClose();
  }

  String get devise => SessionController.to.devise;

  Future<void> _charger() async {
    chargement.value = true;
    try {
      aApurer.assignAll(
        await _repo.facturesAApurer(client.id, tenantId: tenantId),
      );
    } catch (e) {
      erreur.value = 'Impossible de lire les factures du client : $e';
    } finally {
      chargement.value = false;
    }
  }

  double get montant => Validators.parseMontant(montantCtrl.text) ?? 0;

  /// Total encore dû par le client sur les factures remontées.
  double get totalAApurer =>
      aApurer.fold<double>(0, (somme, f) => somme + f.resteDu);

  /// Aperçu du lettrage : ce que le montant saisi va solder, dans l'ordre.
  List<ApercuImputation> get apercu {
    final resultat = <ApercuImputation>[];
    var reste = montant;
    for (final f in aApurer) {
      if (reste <= 0.005) break;
      final part = reste >= f.resteDu ? f.resteDu : reste;
      resultat.add(ApercuImputation(facture: f, montant: part));
      reste -= part;
    }
    return resultat;
  }

  /// Part du montant qui ne trouve aucune facture à solder et restera en
  /// avance au crédit du client.
  double get avance {
    final reste = montant - totalAApurer;
    return reste > 0.005 ? reste : 0;
  }

  bool get pretAEnregistrer => montant > 0;

  /// Saisit d'un geste le total de l'ardoise.
  void solderTout() {
    if (totalAApurer <= 0) return;
    montantCtrl.text = totalAApurer == totalAApurer.roundToDouble()
        ? totalAApurer.toStringAsFixed(0)
        : totalAApurer.toStringAsFixed(2);
    update();
  }

  Future<void> choisirDate(BuildContext context) async {
    final choisie = await showDatePicker(
      context: context,
      initialDate: date.value,
      firstDate: DateTime(date.value.year - 1),
      lastDate: DateTime.now(),
      locale: const Locale('fr', 'FR'),
    );
    if (choisie != null) date.value = choisie;
  }

  Future<void> enregistrer() async {
    erreur.value = null;

    if (montant <= 0) {
      erreur.value = 'Saisissez un montant supérieur à 0.';
      return;
    }

    final utilisateur = SessionController.to.user.value;
    if (utilisateur == null) {
      erreur.value = 'Session expirée. Reconnectez-vous.';
      return;
    }

    enregistrement.value = true;
    try {
      final paiement = await _repo.creer(
        tenantId: tenantId,
        clientId: client.id,
        clientNom: client.nom,
        montant: montant,
        mode: mode.value,
        date: date.value,
        creeParId: utilisateur.id,
        creeParNom: utilisateur.nom,
        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );

      resultat = paiement;
      Get.back(result: paiement);
      Get.snackbar(
        'Règlement enregistré',
        paiement.montantEnAvance > 0
            ? '${paiement.imputations.length} facture(s) soldée(s). '
                'Le surplus reste en avance au crédit de ${client.nom}.'
            : '${paiement.imputations.length} facture(s) soldée(s) pour '
                '${client.nom}.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
      );
    } on FacturationException catch (e) {
      erreur.value = e.message;
    } catch (e) {
      erreur.value = 'Enregistrement impossible : $e';
    } finally {
      enregistrement.value = false;
    }
  }
}
