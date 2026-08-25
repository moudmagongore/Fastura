import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

/// Enveloppe Firebase Authentication. Ne connaît ni les rôles ni les
/// tenants : la session métier (profil, tenant, droits) est portée par
/// `SessionController`, qui écoute [authStateChanges].
class AuthService extends GetxService {
  static AuthService get to => Get.find();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;
  bool get isAuthenticated => _auth.currentUser != null;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => _auth.signOut();

  /// Traduit les codes d'erreur Firebase en messages affichables.
  /// `invalid-credential` couvre à la fois un email inconnu et un mauvais
  /// mot de passe depuis que Firebase a fusionné les deux cas : on reste
  /// volontairement vague pour ne pas révéler l'existence d'un compte.
  static String messageErreur(Object error) {
    if (error is! FirebaseAuthException) {
      return 'Une erreur est survenue. Réessayez.';
    }
    return switch (error.code) {
      'invalid-email' => 'Format d\'email invalide.',
      'user-disabled' => 'Ce compte a été désactivé.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' =>
        'Email ou mot de passe incorrect.',
      'too-many-requests' =>
        'Trop de tentatives. Réessayez dans quelques minutes.',
      'network-request-failed' =>
        'Pas de connexion. Fastura nécessite Internet.',
      _ => 'Connexion impossible (${error.code}).',
    };
  }
}
