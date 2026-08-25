import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../constants/firestore_keys.dart';

/// Point d'accès unique à Firestore : expose des références typées vers les
/// collections. Les repositories passent par ici, jamais par
/// `FirebaseFirestore.instance` directement.
///
/// C'est aussi la couture prévue pour la bascule vers Spring/Laravel :
/// seuls ce service et les repositories seront réécrits, pas les écrans.
class FirestoreService extends GetxService {
  static FirestoreService get to => Get.find();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  FirebaseFirestore get db => _db;

  CollectionReference<Map<String, dynamic>> get tenants =>
      _db.collection(FirestoreKeys.tenants);

  CollectionReference<Map<String, dynamic>> get users =>
      _db.collection(FirestoreKeys.users);

  CollectionReference<Map<String, dynamic>> get categories =>
      _db.collection(FirestoreKeys.categories);

  CollectionReference<Map<String, dynamic>> get articles =>
      _db.collection(FirestoreKeys.articles);

  CollectionReference<Map<String, dynamic>> get clients =>
      _db.collection(FirestoreKeys.clients);

  CollectionReference<Map<String, dynamic>> get factures =>
      _db.collection(FirestoreKeys.factures);

  CollectionReference<Map<String, dynamic>> get paiements =>
      _db.collection(FirestoreKeys.paiements);

  CollectionReference<Map<String, dynamic>> get naturesDepense =>
      _db.collection(FirestoreKeys.naturesDepense);

  CollectionReference<Map<String, dynamic>> get depenses =>
      _db.collection(FirestoreKeys.depenses);

  /// Compteurs de numérotation séquentielle. Doc-id = tenantId.
  CollectionReference<Map<String, dynamic>> get counters =>
      _db.collection(FirestoreKeys.counters);
}
