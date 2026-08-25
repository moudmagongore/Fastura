import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_keys.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/paiement_model.dart';

/// Lecture des règlements.
///
/// La **création** d'un règlement n'est pas ici : un paiement encaissé au
/// moment de la facturation est écrit dans la transaction de la facture
/// (voir [FactureRepository.creer]), et le menu de paiement dédié avec son
/// lettrage FIFO arrive dans un second temps.
class PaiementRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col => _fs.paiements;

  Stream<List<PaiementModel>> watchByTenant(
    String tenantId, {
    int limite = 200,
    DateTime? depuis,
  }) {
    if (tenantId.isEmpty) return Stream.value(const <PaiementModel>[]);
    Query<Map<String, dynamic>> q =
        _col.where(FirestoreKeys.fieldTenantId, isEqualTo: tenantId);
    if (depuis != null) {
      q = q.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(depuis));
    }
    return q
        .orderBy('date', descending: true)
        .limit(limite)
        .snapshots()
        .ignorePermissionDenied()
        .map((snap) => snap.docs.map(PaiementModel.fromFirestore).toList());
  }

  /// Règlements d'un client, du plus récent au plus ancien.
  Stream<List<PaiementModel>> watchByClient(
    String clientId, {
    required String tenantId,
    int limite = 100,
  }) {
    if (clientId.isEmpty || tenantId.isEmpty) {
      return Stream.value(const <PaiementModel>[]);
    }
    return _col
        .where(FirestoreKeys.fieldTenantId, isEqualTo: tenantId)
        .where('clientId', isEqualTo: clientId)
        .orderBy('date', descending: true)
        .limit(limite)
        .snapshots()
        .ignorePermissionDenied()
        .map((snap) => snap.docs.map(PaiementModel.fromFirestore).toList());
  }

  Future<PaiementModel?> getById(String id) async {
    if (id.isEmpty) return null;
    final doc = await _col.doc(id).get();
    return doc.exists ? PaiementModel.fromFirestore(doc) : null;
  }
}
