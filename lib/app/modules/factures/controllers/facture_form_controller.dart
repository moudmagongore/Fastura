import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/article_model.dart';
import '../../../data/models/categorie_model.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/facture_model.dart';
import '../../../data/models/paiement_model.dart';
import '../../../data/repositories/article_repository.dart';
import '../../../data/repositories/categorie_repository.dart';
import '../../../data/repositories/client_repository.dart';
import '../../../data/repositories/facture_repository.dart';
import '../../../routes/app_routes.dart';

/// Saisie d'une facture.
///
/// Une facture n'est jamais modifiée après émission : c'est une pièce
/// comptable numérotée. Ce contrôleur ne sert donc qu'à la création ; la
/// correction d'une erreur passe par l'annulation, réservée à
/// l'administrateur, puis par une nouvelle facture.
class FactureFormController extends GetxController {
  final FactureRepository _repo = FactureRepository();
  final ClientRepository _clientRepo = ClientRepository();
  final ArticleRepository _articleRepo = ArticleRepository();
  final CategorieRepository _categorieRepo = CategorieRepository();

  /// Seuls les clients et articles **actifs** sont proposés : un élément
  /// désactivé disparaît des listes de sélection mais reste lisible dans
  /// l'historique déjà émis (CDC §2).
  final clients = <ClientModel>[].obs;

  /// Catalogue complet, actifs et inactifs confondus.
  ///
  /// On lit tout puis on filtre côté application, au lieu de laisser
  /// Firestore filtrer sur `active`. Ça permet de distinguer deux
  /// situations que le vendeur vit très différemment : un catalogue vide
  /// (rien n'a jamais été saisi) et un catalogue entièrement désactivé
  /// (souvent la cascade d'une catégorie fermée). Sans cette distinction,
  /// l'écran affiche la même liste vide dans les deux cas et personne ne
  /// comprend quoi faire. Le surcoût est nul : un catalogue tient en
  /// quelques dizaines de documents.
  final catalogue = <ArticleModel>[].obs;

  /// Catégories actives du tenant, pour filtrer le sélecteur d'articles.
  final categories = <CategorieModel>[].obs;

  final client = Rxn<ClientModel>();
  final lignes = <LigneFacture>[].obs;
  final date = DateTime.now().obs;

  final paiementCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  /// Identité du client de passage, facultative et réservée au client
  /// divers : de quoi nommer l'acheteur sur la facture sans lui ouvrir une
  /// fiche. Voir `FactureModel.clientNomLibre`.
  final clientLibreNomCtrl = TextEditingController();
  final clientLibreTelCtrl = TextEditingController();
  final modePaiement = ModePaiement.especes.obs;

  final enregistrement = false.obs;
  final erreur = RxnString();

  late final String tenantId;

  @override
  void onInit() {
    super.onInit();
    final session = SessionController.to;
    tenantId = session.requireTenantId;

    clients.bindStream(
      _clientRepo.watchByTenant(tenantId, actifsSeulement: true).map((liste) {
        _assurerClientDivers(liste);
        return liste;
      }),
    );

    catalogue.bindStream(_articleRepo.watchByTenant(tenantId));
    // Les catégories servent au filtre du sélecteur d'articles et à situer
    // chaque article dans la liste : deux boutiques vendent volontiers deux
    // « Sac 50 kg » différents, la catégorie les départage.
    categories.bindStream(
      _categorieRepo.watchByTenant(tenantId, actifsSeulement: true),
    );
  }

  /// Matérialisation du client de passage déjà tentée : une seule fois par
  /// écran, quel que soit le nombre de fois où le flux réémet.
  bool _diversTente = false;

  /// Présélectionne le client divers, et le crée s'il n'existe pas encore.
  ///
  /// Présélection : la majorité des ventes sont comptant, autant épargner un
  /// geste au vendeur.
  void _assurerClientDivers(List<ClientModel> liste) {
    for (final c in liste) {
      if (c.estDivers) {
        client.value ??= c;
        return;
      }
    }
    _creerClientDivers();
  }

  /// Crée le client divers de la boutique s'il manque.
  ///
  /// Il n'existe pas à la création de l'entreprise — le super-administrateur
  /// n'a aucun droit d'écriture sur les données métier — et c'était jusqu'ici
  /// la liste des clients qui le matérialisait. Mais on peut facturer sans
  /// jamais l'ouvrir : la première vente d'une boutique neuve tombait alors
  /// sur un sélecteur vide, sans le support de vente comptant qui devrait
  /// toujours être là.
  ///
  /// `assurerClientDivers` relit avant d'écrire : un premier instantané
  /// arrivé du cache, encore vide, ne crée pas de doublon.
  Future<void> _creerClientDivers() async {
    if (_diversTente) return;
    _diversTente = true;
    try {
      final divers = await _clientRepo.assurerClientDivers(tenantId);
      // Le flux le rapatriera de lui-même, mais la facture en cours n'a pas
      // à attendre l'aller-retour pour avoir un client.
      client.value ??= divers;
    } catch (e) {
      erreur.value =
          'Le client de passage n\'a pas pu être créé ($e). Choisissez un '
          'client dans la liste ou créez-en un.';
    }
  }

  @override
  void onClose() {
    paiementCtrl.dispose();
    noteCtrl.dispose();
    clientLibreNomCtrl.dispose();
    clientLibreTelCtrl.dispose();
    super.onClose();
  }

  String? get _noteOuNull {
    final t = noteCtrl.text.trim();
    return t.isEmpty ? null : t;
  }

  /// Vrai dès qu'une mention a été saisie : sert à signaler la présence
  /// d'une note depuis la barre du bas, la feuille étant refermée.
  bool get aUneNote => noteCtrl.text.trim().isNotEmpty;

  /// Le client sélectionné est-il le client divers ? Lui seul ouvre la
  /// saisie d'une identité de passage.
  bool get estClientDivers => client.value?.estDivers ?? false;

  String? get _nomLibreOuNull {
    if (!estClientDivers) return null;
    final t = clientLibreNomCtrl.text.trim();
    return t.isEmpty ? null : t;
  }

  String? get _telLibreOuNull {
    if (!estClientDivers) return null;
    final t = clientLibreTelCtrl.text.trim();
    return t.isEmpty ? null : t;
  }

  /// Résumé affiché sous la barre client : « Jean Camara · 622 00 00 00 ».
  String get identiteDePassage {
    final nom = clientLibreNomCtrl.text.trim();
    final tel = clientLibreTelCtrl.text.trim();
    if (nom.isEmpty && tel.isEmpty) return '';
    if (nom.isEmpty) return tel;
    if (tel.isEmpty) return nom;
    return '$nom · $tel';
  }

  /// Articles proposables à la facturation.
  List<ArticleModel> get articles => catalogue.where((a) => a.active).toList();

  /// Catégories à proposer en filtre : seulement celles qui ont au moins un
  /// article actif. Un onglet qui n'ouvre sur rien n'est qu'un piège.
  List<CategorieModel> get categoriesDuCatalogue {
    final utilisees = articles.map((a) => a.categorieId).toSet();
    return categories.where((c) => utilisees.contains(c.id)).toList();
  }

  /// Vrai quand le prix de la ligne a été négocié au comptoir, c'est-à-dire
  /// qu'il s'écarte de celui du catalogue. Sert à signaler visuellement les
  /// lignes remisées.
  bool prixNegocie(LigneFacture l) {
    for (final a in catalogue) {
      if (a.id == l.articleId) return a.prixVente != l.prixUnitaire;
    }
    return false;
  }

  /// Vrai quand aucun article n'a jamais été saisi.
  bool get catalogueVide => catalogue.isEmpty;

  /// Vrai quand le catalogue existe mais que tout y est désactivé — le cas
  /// typique après la fermeture d'une catégorie, qui désactive ses articles
  /// en cascade.
  bool get toutDesactive => catalogue.isNotEmpty && articles.isEmpty;

  // -------------------------------------------------------------- montants

  String get devise => SessionController.to.devise;
  double get tauxTva => SessionController.to.tauxTva;
  bool get tvaActive => SessionController.to.tvaActive;

  double get montantHT =>
      lignes.fold<double>(0, (somme, l) => somme + l.montant);

  double get montantTva => montantHT * tauxTva / 100;

  double get montantTotal => montantHT + montantTva;

  /// Le client de passage ne se crédite pas.
  ///
  /// Il n'a pas de fiche : aucun compte à débiter, aucun numéro à rappeler,
  /// personne à relancer. Une dette inscrite là ne se recouvre jamais et
  /// gonfle un solde anonyme que plus rien ne rattache à un acheteur. Pour
  /// vendre à crédit, il faut une fiche client — celle du fichier, ou une
  /// nouvelle, créée d'un bouton depuis le sélecteur.
  bool get creditPossible => !estClientDivers;

  /// Règlement immédiat. Pour le client de passage, c'est toujours la
  /// totalité : le champ de saisie n'est même pas proposé.
  double get paiementImmediat {
    if (!creditPossible) return montantTotal;
    return Validators.parseMontant(paiementCtrl.text) ?? 0;
  }

  /// Positif : le client reste devoir. Négatif : il a annoncé plus que le
  /// total, ce que la facturation refuse — le surplus se saisit depuis le
  /// menu de paiement, où il devient une avance.
  double get resteDu {
    final reste = montantTotal - paiementImmediat;
    return reste.abs() < 0.005 ? 0 : reste;
  }

  bool get tropPercu => resteDu < 0;

  bool get pretAEnregistrer => lignes.isNotEmpty && client.value != null;

  // --------------------------------------------------------------- lignes

  /// Ajoute un article, ou cumule la quantité s'il est déjà sur la facture —
  /// deux lignes du même article au même prix n'apporteraient rien et
  /// alourdiraient l'impression.
  void ajouterArticle(ArticleModel a, {double quantite = 1}) {
    final index = lignes.indexWhere(
      (l) => l.articleId == a.id && l.prixUnitaire == a.prixVente,
    );
    if (index >= 0) {
      final l = lignes[index];
      lignes[index] = l.copyWith(quantite: l.quantite + quantite);
    } else {
      lignes.add(
        LigneFacture(
          articleId: a.id,
          designation: a.designation,
          unite: a.unite,
          prixUnitaire: a.prixVente,
          quantite: quantite,
        ),
      );
    }
    erreur.value = null;
  }

  void modifierQuantite(int index, double quantite) {
    if (index < 0 || index >= lignes.length) return;
    if (quantite <= 0) {
      lignes.removeAt(index);
      return;
    }
    lignes[index] = lignes[index].copyWith(quantite: quantite);
  }

  void modifierPrix(int index, double prix) {
    if (index < 0 || index >= lignes.length || prix <= 0) return;
    lignes[index] = lignes[index].copyWith(prixUnitaire: prix);
  }

  void retirerLigne(int index) {
    if (index < 0 || index >= lignes.length) return;
    lignes.removeAt(index);
  }

  void viderLignes() => lignes.clear();

  void choisirClient(ClientModel c) {
    client.value = c;
    erreur.value = null;
    // Un client du fichier a son propre nom : l'identité de passage saisie
    // avant n'a plus lieu d'être, et la garder l'imprimerait à sa place.
    if (!c.estDivers) {
      clientLibreNomCtrl.clear();
      clientLibreTelCtrl.clear();
    } else {
      // Un montant partiel saisi pour un client du fichier n'a plus cours :
      // la vente au comptoir se règle en entier. Le laisser reviendrait à le
      // réappliquer si on repasse sur un client à compte.
      paiementCtrl.clear();
    }
    update();
  }

  Future<void> choisirDate(BuildContext context) async {
    final choisie = await showDatePicker(
      context: context,
      initialDate: date.value,
      firstDate: DateTime(date.value.year - 1),
      // Une facture ne s'émet pas dans le futur.
      lastDate: DateTime.now(),
    );
    if (choisie != null) date.value = choisie;
  }

  /// Solde immédiatement la facture : raccourci du cas le plus fréquent,
  /// la vente comptant.
  void reglerTout() {
    paiementCtrl.text = montantTotal == montantTotal.roundToDouble()
        ? montantTotal.toStringAsFixed(0)
        : montantTotal.toStringAsFixed(2);
    update();
  }

  // ---------------------------------------------------------- persistance

  Future<void> enregistrer() async {
    erreur.value = null;

    final c = client.value;
    if (c == null) {
      erreur.value = 'Choisissez un client.';
      return;
    }
    if (lignes.isEmpty) {
      erreur.value = 'Ajoutez au moins un article.';
      return;
    }

    final regle = paiementImmediat;
    if (regle - montantTotal > 0.005) {
      erreur.value = 'Le montant réglé dépasse le total de la facture.';
      return;
    }

    final session = SessionController.to;
    final utilisateur = session.user.value;
    if (utilisateur == null) {
      erreur.value = 'Session expirée. Reconnectez-vous.';
      return;
    }

    enregistrement.value = true;
    try {
      final persistee = await _repo.creer(
        FactureModel(
          id: '',
          numero: '',
          date: date.value,
          clientId: c.id,
          clientNom: c.nom,
          clientNomLibre: _nomLibreOuNull,
          clientTelephoneLibre: _telLibreOuNull,
          lignes: List<LigneFacture>.from(lignes),
          // Taux et devise sont figés à l'émission : la facture doit rester
          // identique à ce qui a été remis au client, même si le tenant
          // change de paramètres ensuite.
          tauxTva: tauxTva,
          devise: devise,
          note: _noteOuNull,
          tenantId: tenantId,
          creeParId: utilisateur.id,
          creeParNom: utilisateur.nom,
        ),
        prefixe: session.tenant.value?.prefixeFacture ?? 'FA',
        paiementImmediat: regle,
        modePaiement: modePaiement.value,
      );

      // La fiche s'ouvre, et rien de plus : le tirage part du bouton
      // « Imprimer », quand on le décide. L'aperçu qui surgissait tout seul
      // était à refermer à chaque vente, y compris les nombreuses où le
      // client ne veut pas de papier.
      Get.offNamed(AppRoutes.factureDetail, arguments: persistee);
      Get.snackbar(
        'Facture ${persistee.numero}',
        persistee.estSoldee
            ? 'Émise et soldée.'
            : 'Émise. Reste à encaisser sur le compte de ${c.nom}.',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 4),
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
