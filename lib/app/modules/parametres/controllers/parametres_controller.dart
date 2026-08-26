import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/facture_pdf_service.dart';
import '../../../core/services/session_controller.dart';
import '../../../core/utils/pdf_helper.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/facture_model.dart';
import '../../../data/models/format_impression.dart';
import '../../../data/models/tenant_model.dart';
import '../../../data/repositories/tenant_repository.dart';

/// Paramètres de l'entreprise, modifiables par son administrateur (CDC §7).
///
/// Le super-administrateur crée l'entreprise et fixe sa configuration
/// initiale ; c'est le même document Firestore qui est édité ici, à deux
/// différences près : l'administrateur ne touche jamais au statut
/// actif/inactif, et il ne voit que sa propre entreprise. Les rules
/// verrouillent les deux.
class ParametresController extends GetxController {
  final TenantRepository _repo = TenantRepository();

  final formKey = GlobalKey<FormState>();

  final nomCtrl = TextEditingController();
  final adresseCtrl = TextEditingController();
  final telephoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final logoUrlCtrl = TextEditingController();
  final deviseCtrl = TextEditingController();
  final tauxTvaCtrl = TextEditingController();
  final prefixeCtrl = TextEditingController();

  final tvaActive = false.obs;
  final format = FormatImpression.a4.obs;
  final enregistrement = false.obs;
  final erreur = RxnString();

  /// Recopié à l'ouverture pour dire si le format a bougé sans être encore
  /// enregistré — l'aperçu, lui, travaille toujours sur la saisie en cours.
  TenantModel? _tenant;

  bool get pret => _tenant != null;

  @override
  void onInit() {
    super.onInit();
    _remplir(SessionController.to.tenant.value);
    // Le tenant arrive en stream : si l'écran s'ouvre avant que la session
    // l'ait reçu, les champs resteraient vides.
    ever<TenantModel?>(SessionController.to.tenant, (t) {
      if (_tenant == null) _remplir(t);
    });
  }

  void _remplir(TenantModel? t) {
    if (t == null) return;
    _tenant = t;
    nomCtrl.text = t.nom;
    adresseCtrl.text = t.adresse ?? '';
    telephoneCtrl.text = t.telephone ?? '';
    emailCtrl.text = t.email ?? '';
    logoUrlCtrl.text = t.logoUrl ?? '';
    deviseCtrl.text = t.devise;
    tauxTvaCtrl.text = _formaterTaux(t.tauxTva);
    prefixeCtrl.text = t.prefixeFacture;
    tvaActive.value = t.tvaActive;
    format.value = t.formatImpression;
    update();
  }

  static String _formaterTaux(double taux) =>
      taux == taux.roundToDouble() ? taux.toStringAsFixed(0) : '$taux';

  @override
  void onClose() {
    nomCtrl.dispose();
    adresseCtrl.dispose();
    telephoneCtrl.dispose();
    emailCtrl.dispose();
    logoUrlCtrl.dispose();
    deviseCtrl.dispose();
    tauxTvaCtrl.dispose();
    prefixeCtrl.dispose();
    super.onClose();
  }

  // ---------------------------------------------------------- validation

  String? validerNom(String? v) =>
      Validators.requis(v, champ: 'Le nom de l\'entreprise');

  String? validerDevise(String? v) => Validators.requis(v, champ: 'La devise');

  String? validerTauxTva(String? v) {
    if (!tvaActive.value) return null;
    final taux = Validators.parseMontant(v);
    if (taux == null) return 'Taux invalide';
    if (taux < 0 || taux > 100) return 'Le taux doit être entre 0 et 100';
    return null;
  }

  /// Le logo n'est pas téléversé mais référencé : le champ doit donc porter
  /// une URL atteignable, sinon l'en-tête sort muet sans que personne ne
  /// sache pourquoi.
  String? validerLogoUrl(String? v) {
    final url = (v ?? '').trim();
    if (url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isAbsolute || !uri.scheme.startsWith('http')) {
      return 'Adresse invalide : elle doit commencer par https://';
    }
    return null;
  }

  // ------------------------------------------------------------- aperçu

  /// Entreprise telle qu'elle serait avec la saisie en cours, enregistrée
  /// ou non. C'est ce que l'aperçu doit montrer : on choisit un format en
  /// le regardant, pas en le validant d'abord.
  TenantModel get tenantEnCours {
    final base = _tenant ?? const TenantModel(id: '', nom: '');
    return base.copyWith(
      nom: nomCtrl.text.trim(),
      adresse: adresseCtrl.text.trim(),
      telephone: telephoneCtrl.text.trim(),
      email: emailCtrl.text.trim(),
      logoUrl: logoUrlCtrl.text.trim(),
      devise: deviseCtrl.text.trim().toUpperCase(),
      tvaActive: tvaActive.value,
      tauxTva: Validators.parseMontant(tauxTvaCtrl.text) ?? 0,
      formatImpression: format.value,
      prefixeFacture: prefixeCtrl.text.trim().toUpperCase(),
    );
  }

  /// Facture de démonstration, non enregistrée et non numérotée.
  ///
  /// Le numéro est littéralement « SPÉCIMEN » : un aperçu imprimé traîne, et
  /// il ne doit jamais pouvoir passer pour une pièce comptable.
  FactureModel get _factureSpecimen {
    final t = tenantEnCours;
    return FactureModel(
      id: 'specimen',
      numero: 'SPÉCIMEN',
      date: DateTime.now(),
      clientId: '',
      clientNom: 'Client de démonstration',
      tenantId: t.id,
      creeParId: '',
      creeParNom: SessionController.to.user.value?.nom ?? '',
      devise: t.devise,
      tauxTva: t.tvaActive ? t.tauxTva : 0,
      montantPaye: 0,
      lignes: const [
        LigneFacture(
          articleId: '',
          designation: 'Premier article de démonstration',
          unite: 'pièce',
          prixUnitaire: 25000,
          quantite: 2,
        ),
        LigneFacture(
          articleId: '',
          designation: 'Deuxième article de démonstration',
          unite: 'carton',
          prixUnitaire: 140000,
          quantite: 1,
        ),
        LigneFacture(
          articleId: '',
          designation: 'Prestation de démonstration',
          unite: 'forfait',
          prixUnitaire: 75000,
          quantite: 3,
        ),
      ],
    );
  }

  Future<void> apercuImpression() async {
    await genererPuisImprimer(
      generer: () => FacturePdfService.construire(
        facture: _factureSpecimen,
        tenant: tenantEnCours,
      ),
      nomFichier: 'Specimen-${format.value.name}',
      titre: 'Aperçu — ${format.value.label}',
    );
  }

  // -------------------------------------------------------- enregistrement

  Future<void> enregistrer() async {
    erreur.value = null;
    if (_tenant == null) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    enregistrement.value = true;
    try {
      // `active` n'est jamais touché : il vient du document courant et les
      // rules refusent qu'un administrateur le modifie.
      await _repo.update(tenantEnCours);
      Get.back();
      Get.snackbar(
        'Paramètres enregistrés',
        'Les prochaines factures et reçus utiliseront ces réglages.',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      erreur.value = 'Enregistrement impossible : $e';
    } finally {
      enregistrement.value = false;
    }
  }
}
