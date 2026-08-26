import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../data/models/depense_model.dart';
import '../../../data/models/facture_model.dart';
import '../../../data/models/paiement_model.dart';
import '../../../data/repositories/depense_repository.dart';
import '../../../data/repositories/facture_repository.dart';
import '../../../data/repositories/paiement_repository.dart';

/// Chiffres de l'accueil : le jour en détail, le mois en résumé.
///
/// Le même contrôleur sert l'administrateur et le vendeur : le cahier des
/// charges donne au vendeur la consultation de tout l'historique (§2), il n'y
/// a donc rien à cloisonner ici. Ce qui les sépare tient aux actions, pas aux
/// chiffres.
///
/// **Un seul jeu de flux, borné au mois.** Le jour s'en déduit par filtrage :
/// il est contenu dans le mois, deux abonnements liraient deux fois les mêmes
/// documents. La borne est posée côté serveur, sur le champ qui sert aussi au
/// tri (`date`) — donc sans index composite supplémentaire. Les deux échelles
/// s'affichent ensemble : au comptoir on regarde sa journée, en fin de mois
/// on regarde le mois, et personne n'a envie de basculer un filtre pour ça.
class AccueilController extends GetxController {
  final FactureRepository _factures = FactureRepository();
  final PaiementRepository _paiements = PaiementRepository();
  final DepenseRepository _depenses = DepenseRepository();

  /// Plafonds de lecture. Firestore facture au document lu, et un mois de
  /// comptoir chargé en produit beaucoup : au-delà, les totaux sont annoncés
  /// comme partiels plutôt que faussés en silence (voir [tronque]).
  static const int _plafondFactures = 400;
  static const int _plafondPaiements = 400;
  static const int _plafondDepenses = 300;

  final facturesMois = <FactureModel>[].obs;
  final paiementsMois = <PaiementModel>[].obs;
  final depensesMois = <DepenseModel>[].obs;

  final chargement = true.obs;

  late final DateTime _debutJour;

  String get devise => SessionController.to.devise;

  @override
  void onInit() {
    super.onInit();

    final maintenant = DateTime.now();
    _debutJour = DateTime(maintenant.year, maintenant.month, maintenant.day);
    final debutMois = DateTime(maintenant.year, maintenant.month);

    final tenantId = SessionController.to.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      chargement.value = false;
      return;
    }

    facturesMois.bindStream(
      _factures.watchByTenant(
        tenantId,
        depuis: debutMois,
        limite: _plafondFactures,
      ),
    );
    paiementsMois.bindStream(
      _paiements.watchByTenant(
        tenantId,
        depuis: debutMois,
        limite: _plafondPaiements,
      ),
    );
    depensesMois.bindStream(
      _depenses.watchByTenant(
        tenantId,
        debut: debutMois,
        limite: _plafondDepenses,
      ),
    );

    // Les trois flux arrivent séparément : on laisse passer la rafale plutôt
    // que de faire clignoter les cartes trois fois.
    debounce<List<FactureModel>>(
      facturesMois,
      (_) => chargement.value = false,
      time: const Duration(milliseconds: 250),
    );
  }

  bool _duJour(DateTime date) => !date.isBefore(_debutJour);

  // ---- Aujourd'hui ----

  /// Factures du jour, annulations exclues : une facture annulée ne compte
  /// plus dans le chiffre d'affaires.
  List<FactureModel> get _facturesJourValides =>
      facturesMois.where((f) => !f.annulee && _duJour(f.date)).toList();

  double get factureJour =>
      _facturesJourValides.fold(0.0, (total, f) => total + f.montantTotal);

  int get nombreFacturesJour => _facturesJourValides.length;

  /// Encaissé : les règlements directs à la facturation comptent ici aussi,
  /// ils donnent lieu au même document de paiement.
  double get encaisseJour => paiementsMois
      .where((p) => !p.annule && _duJour(p.date))
      .fold(0.0, (total, p) => total + p.montant);

  double get depensesJour => depensesMois
      .where((d) => !d.annulee && _duJour(d.date))
      .fold(0.0, (total, d) => total + d.montant);

  // ---- Ce mois-ci ----

  double get factureMois => facturesMois
      .where((f) => !f.annulee)
      .fold(0.0, (total, f) => total + f.montantTotal);

  int get nombreFacturesMois => facturesMois.where((f) => !f.annulee).length;

  double get encaisseMois => paiementsMois
      .where((p) => !p.annule)
      .fold(0.0, (total, p) => total + p.montant);

  double get depensesMoisTotal => depensesMois
      .where((d) => !d.annulee)
      .fold(0.0, (total, d) => total + d.montant);

  // ---- Journal du jour ----

  /// Factures du jour, de la plus récente à la plus ancienne.
  List<FactureModel> get facturesJour =>
      facturesMois.where((f) => _duJour(f.date)).toList();

  /// Les cinq dernières : au-delà, c'est le journal qui prend le relais.
  List<FactureModel> get dernieresFactures => facturesJour.take(5).toList();

  /// Un des flux a touché son plafond : les totaux du mois ne portent alors
  /// que sur ce qui a été lu. Le dire vaut mieux qu'afficher un chiffre faux
  /// avec l'aplomb d'un chiffre juste.
  bool get tronque =>
      facturesMois.length >= _plafondFactures ||
      paiementsMois.length >= _plafondPaiements ||
      depensesMois.length >= _plafondDepenses;
}
