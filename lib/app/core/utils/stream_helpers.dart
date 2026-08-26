import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

extension IgnorePermissionDenied<T> on Stream<T> {
  /// Absorbe les `permission-denied` transitoires de Firestore, et rend
  /// visibles toutes les autres erreurs.
  ///
  /// Au moment exact de la déconnexion (ou de la désactivation d'un
  /// utilisateur par l'admin), les listeners encore montés reçoivent une
  /// erreur de permission avant d'être disposés. Sans ce filtre, l'écran
  /// affiche une erreur rouge une fraction de seconde avant de basculer sur
  /// le login.
  ///
  /// Les autres erreurs — index composite manquant en tête — sont journalisées
  /// puis relayées. Les avaler laisserait une liste vide sans le moindre
  /// indice sur la cause, ce qui se diagnostique très mal depuis un
  /// téléphone.
  Stream<T> ignorePermissionDenied({String? contexte}) {
    return handleError((Object e) {
      if (e is FirebaseException && e.code == 'failed-precondition') {
        // Firestore renvoie ce code, avec l'URL de création de l'index,
        // quand une requête combine filtre et tri sans index composite.
        debugPrint(
          'Firestore — index manquant${contexte == null ? '' : ' ($contexte)'} : '
          '${e.message}',
        );
      } else {
        debugPrint(
          'Firestore — erreur${contexte == null ? '' : ' ($contexte)'} : $e',
        );
      }
    }, test: (e) => e is FirebaseException);
  }
}
