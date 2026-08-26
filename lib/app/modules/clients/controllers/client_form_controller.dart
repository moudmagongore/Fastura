import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/client_model.dart';
import '../../../data/repositories/client_repository.dart';

class ClientFormController extends GetxController {
  final ClientRepository _repo = ClientRepository();

  final formKey = GlobalKey<FormState>();
  final nomCtrl = TextEditingController();
  final telephoneCtrl = TextEditingController();
  final adresseCtrl = TextEditingController();

  final enregistrement = false.obs;
  final erreur = RxnString();

  late final String tenantId;
  ClientModel? _existant;

  bool get estEdition => _existant != null;
  bool get estDivers => _existant?.estDivers ?? false;
  String get titre => estEdition ? 'Modifier le client' : 'Nouveau client';

  @override
  void onInit() {
    super.onInit();
    tenantId = SessionController.to.requireTenantId;
    final arg = Get.arguments;
    if (arg is ClientModel) {
      _existant = arg;
      nomCtrl.text = arg.nom;
      telephoneCtrl.text = arg.telephone ?? '';
      adresseCtrl.text = arg.adresse ?? '';
    }
  }

  @override
  void onClose() {
    nomCtrl.dispose();
    telephoneCtrl.dispose();
    adresseCtrl.dispose();
    super.onClose();
  }

  String? validerNom(String? v) => Validators.requis(v, champ: 'Le nom');

  Future<void> enregistrer() async {
    erreur.value = null;
    if (!(formKey.currentState?.validate() ?? false)) return;

    enregistrement.value = true;
    try {
      final nom = nomCtrl.text.trim();

      if (estEdition) {
        // Construction explicite : copyWith retombe sur l'ancienne valeur
        // quand on lui passe null, ce qui empêcherait d'effacer un
        // téléphone ou une adresse déjà saisis.
        final e = _existant!;
        await _repo.update(
          ClientModel(
            id: e.id,
            // Le client divers garde son nom : c'est un repère commun à
            // toute l'équipe, le renommer sèmerait la confusion en caisse.
            nom: e.estDivers ? e.nom : nom,
            telephone: _ouNull(telephoneCtrl.text),
            adresse: _ouNull(adresseCtrl.text),
            solde: e.solde,
            estDivers: e.estDivers,
            tenantId: e.tenantId,
            active: e.active,
            createdAt: e.createdAt,
          ),
        );
        Get.back();
      } else {
        final saisi = ClientModel(
          id: '',
          nom: nom,
          telephone: _ouNull(telephoneCtrl.text),
          adresse: _ouNull(adresseCtrl.text),
          tenantId: tenantId,
        );
        // `copyWith` ne touche pas à l'identifiant — il vient de Firestore et
        // ne se réécrit pas — d'où la reconstruction.
        final cree = ClientModel(
          id: await _repo.create(saisi),
          nom: saisi.nom,
          telephone: saisi.telephone,
          adresse: saisi.adresse,
          tenantId: saisi.tenantId,
        );

        // Le client créé repart à l'écran qui a ouvert ce formulaire : la
        // feuille de choix, à la facturation, le sélectionne sans attendre
        // que le flux Firestore l'ait rapatrié. Les écrans qui n'en ont pas
        // l'usage ignorent simplement le résultat.
        Get.back(result: cree);
      }
      Get.snackbar(
        'Enregistré',
        estEdition
            ? 'La fiche de $nom a été mise à jour.'
            : '$nom a été ajouté à vos clients.',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      erreur.value = 'Enregistrement impossible : $e';
    } finally {
      enregistrement.value = false;
    }
  }

  String? _ouNull(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
}
