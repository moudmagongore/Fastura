import 'package:cloud_firestore/cloud_firestore.dart';

extension IgnorePermissionDenied<T> on Stream<T> {
  /// Absorbe les `permission-denied` transitoires de Firestore.
  ///
  /// Au moment exact de la déconnexion (ou de la désactivation d'un
  /// utilisateur par l'admin), les listeners encore montés reçoivent une
  /// erreur de permission avant d'être disposés. Sans ce filtre, l'écran
  /// affiche une erreur rouge une fraction de seconde avant de basculer sur
  /// le login. Toute autre erreur est bien relayée.
  Stream<T> ignorePermissionDenied() {
    return handleError(
      (Object _) {},
      test: (e) => e is FirebaseException && e.code == 'permission-denied',
    );
  }
}
