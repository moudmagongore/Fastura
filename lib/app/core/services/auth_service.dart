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

  /// Rejoue la connexion avec le mot de passe courant.
  ///
  /// Firebase exige une authentification **récente** pour changer un mot de
  /// passe ou une adresse : sans ça, un téléphone laissé déverrouillé
  /// permettrait de s'emparer du compte. Plutôt que d'attendre l'erreur
  /// `requires-recent-login` et de renvoyer l'utilisateur sur l'écran de
  /// connexion, on redemande le mot de passe sur place.
  Future<void> reauthentifier(String motDePasse) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Session expirée.',
      );
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: motDePasse),
    );
  }

  Future<void> changerMotDePasse({
    required String actuel,
    required String nouveau,
  }) async {
    await reauthentifier(actuel);
    await _auth.currentUser!.updatePassword(nouveau);
  }

  /// Envoie un lien de vérification à la **nouvelle** adresse.
  ///
  /// L'adresse de connexion ne change qu'une fois ce lien ouvert : Firebase
  /// ne modifie plus un email sans preuve que son titulaire y a accès. Tant
  /// que le lien dort, la connexion se fait toujours avec l'ancienne
  /// adresse — c'est à dire à l'utilisateur, sinon il se croira enfermé
  /// dehors au prochain démarrage.
  Future<void> demanderChangementEmail({
    required String nouvelEmail,
    required String motDePasse,
  }) async {
    await reauthentifier(motDePasse);
    await _auth.currentUser!.verifyBeforeUpdateEmail(nouvelEmail.trim());
  }

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
      'invalid-credential' => 'Email ou mot de passe incorrect.',
      'too-many-requests' =>
        'Trop de tentatives. Réessayez dans quelques minutes.',
      'weak-password' => 'Mot de passe trop simple : 6 caractères minimum.',
      'email-already-in-use' =>
        'Cette adresse est déjà utilisée par un compte.',
      'requires-recent-login' =>
        'Par sécurité, reconnectez-vous avant de modifier vos identifiants.',
      'operation-not-allowed' =>
        'Changement d\'adresse refusé par la configuration du projet.',
      'network-request-failed' =>
        'Pas de connexion. Fastura nécessite Internet.',
      _ => 'Opération impossible (${error.code}).',
    };
  }
}
