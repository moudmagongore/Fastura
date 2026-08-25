import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/client_model.dart';

class ClientRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col => _fs.clients;

  /// Clients du tenant, par ordre alphabétique.
  ///
  /// [actifsSeulement] est ce que consommera la facturation : un client
  /// désactivé n'est plus sélectionnable mais son historique et son solde
  /// restent consultables (cf. CDC §5).
  Stream<List<ClientModel>> watchByTenant(
    String tenantId, {
    bool actifsSeulement = false,
  }) {
    if (tenantId.isEmpty) return Stream.value(const <ClientModel>[]);
    Query<Map<String, dynamic>> q =
        _col.where(FirestoreKeys.fieldTenantId, isEqualTo: tenantId);
    if (actifsSeulement) {
      q = q.where(FirestoreKeys.fieldActive, isEqualTo: true);
    }
    return q.orderBy('nom').snapshots().ignorePermissionDenied().map(
          (snap) => snap.docs.map(ClientModel.fromFirestore).toList(),
        );
  }

  /// Suit un client en particulier : sa fiche doit refléter immédiatement
  /// le solde recalculé par une facture ou un règlement enregistré ailleurs.
  Stream<ClientModel?> watchById(String id) {
    if (id.isEmpty) return Stream.value(null);
    return _col.doc(id).snapshots().ignorePermissionDenied().map(
          (doc) => doc.exists ? ClientModel.fromFirestore(doc) : null,
        );
  }

  Future<ClientModel?> getById(String id) async {
    if (id.isEmpty) return null;
    final doc = await _col.doc(id).get();
    return doc.exists ? ClientModel.fromFirestore(doc) : null;
  }

  Future<String> create(ClientModel c) async {
    final data = c.toMap()..['createdAt'] = FieldValue.serverTimestamp();
    final ref = await _col.add(data);
    return ref.id;
  }

  Future<void> update(ClientModel c) {
    final data = c.toMap()
      ..remove('createdAt')
      // Le solde est la propriété des modules Facturation et Paiements, qui
      // le recalculent en transaction. L'écraser depuis un formulaire de
      // fiche client le désynchroniserait de l'historique réel.
      ..remove('solde')
      ..remove('estDivers');
    return _col.doc(c.id).update(data);
  }

  Future<void> setActive(String id, bool active) {
    return _col.doc(id).update({FirestoreKeys.fieldActive: active});
  }

  /// Garantit l'existence du client divers du tenant et le renvoie.
  ///
  /// Il n'est pas créé à l'ouverture de l'entreprise : le super-administrateur
  /// crée le tenant mais n'a aucun droit d'écriture sur les données métier
  /// (cf. `firestore.rules`). Le premier membre du tenant qui ouvre la liste
  /// des clients le matérialise donc à la volée.
  ///
  /// Deux ouvertures simultanées pourraient en créer deux ; le risque est
  /// théorique — il faudrait deux premières ouvertures à la seconde près —
  /// et un doublon se désactive.
  Future<ClientModel> assurerClientDivers(String tenantId) async {
    final existant = await _col
        .where(FirestoreKeys.fieldTenantId, isEqualTo: tenantId)
        .where('estDivers', isEqualTo: true)
        .limit(1)
        .get();

    if (existant.docs.isNotEmpty) {
      return ClientModel.fromFirestore(existant.docs.first);
    }

    final divers = ClientModel(
      id: '',
      nom: AppConstants.clientDiversNom,
      tenantId: tenantId,
      estDivers: true,
    );
    final id = await create(divers);
    return ClientModel(
      id: id,
      nom: divers.nom,
      tenantId: tenantId,
      estDivers: true,
    );
  }
}
