import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/models/client_model.dart';
import '../../../data/repositories/client_repository.dart';

class ClientsController extends GetxController {
  final ClientRepository _repo = ClientRepository();

  final clients = <ClientModel>[].obs;
  final chargement = true.obs;
  final recherche = ''.obs;
  final masquerInactifs = false.obs;

  /// Ne montre que les clients à qui il reste quelque chose à encaisser.
  final soldeSeulement = false.obs;

  late final String tenantId;

  @override
  void onInit() {
    super.onInit();
    tenantId = SessionController.to.requireTenantId;

    clients.bindStream(
      _repo.watchByTenant(tenantId).map((liste) {
        chargement.value = false;
        return liste;
      }),
    );

    // Matérialise le client divers si l'entreprise vient d'être ouverte.
    // L'échec n'est pas bloquant : la liste reste utilisable, et la
    // prochaine ouverture réessaiera.
    _repo.assurerClientDivers(tenantId).catchError((_) => const ClientModel(
          id: '',
          nom: '',
          tenantId: '',
        ));
  }

  String get devise => SessionController.to.devise;

  /// Le client divers reste en tête : c'est le plus sollicité, il sert à
  /// toutes les ventes comptant.
  List<ClientModel> get resultats {
    final q = recherche.value.trim().toLowerCase();
    final liste = clients.where((c) {
      if (masquerInactifs.value && !c.active) return false;
      if (soldeSeulement.value && !c.aUneDette) return false;
      if (q.isEmpty) return true;
      return c.nom.toLowerCase().contains(q) ||
          (c.telephone ?? '').contains(q) ||
          (c.adresse ?? '').toLowerCase().contains(q);
    }).toList();

    liste.sort((a, b) {
      if (a.estDivers != b.estDivers) return a.estDivers ? -1 : 1;
      return a.nom.toLowerCase().compareTo(b.nom.toLowerCase());
    });
    return liste;
  }

  int get nbActifs => clients.where((c) => c.active).length;

  /// Total des créances en cours, tous clients confondus.
  double get totalCreances => clients
      .where((c) => c.aUneDette)
      .fold<double>(0, (somme, c) => somme + c.solde);

  Future<void> basculerActivation(ClientModel c) async {
    // Le client divers est le support des ventes comptant : le désactiver
    // priverait la caisse de son interlocuteur par défaut.
    if (c.estDivers) {
      Get.snackbar(
        'Action impossible',
        'Le client divers ne peut pas être désactivé : c\'est lui qui porte '
            'les ventes comptant.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    final desactivation = c.active;

    // Désactiver un client qui doit encore de l'argent le sortirait des
    // listes de facturation alors que sa créance reste à recouvrer.
    final avertissement = desactivation && c.aUneDette
        ? ' Attention : il reste un solde à recouvrer.'
        : '';

    final ok = await confirmer(
      titre: desactivation ? 'Désactiver le client' : 'Réactiver le client',
      message: desactivation
          ? '${c.nom} ne sera plus sélectionnable pour une nouvelle facture. '
              'Son historique et son solde restent consultables.$avertissement'
          : '${c.nom} sera à nouveau sélectionnable à la facturation.',
      libelleConfirmer: desactivation ? 'Désactiver' : 'Réactiver',
      destructif: desactivation,
    );
    if (!ok) return;

    try {
      await _repo.setActive(c.id, !c.active);
    } catch (e) {
      Get.snackbar(
        'Action impossible',
        'Modification impossible : $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
