import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../firebase_options.dart';

/// Erreur métier remontée à l'écran de création d'un utilisateur.
class CreationCompteException implements Exception {
  const CreationCompteException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Crée des comptes Firebase Auth **sans toucher à la session en cours**.
///
/// `createUserWithEmailAndPassword` connecte automatiquement le compte qu'il
/// vient de créer : appelé sur l'instance principale, il éjecterait
/// l'administrateur au profit du vendeur qu'il est en train d'enregistrer.
/// On passe donc par une seconde instance Firebase, isolée, détruite juste
/// après. C'est la seule façon de faire côté client ; une Cloud Function
/// avec l'Admin SDK serait l'alternative propre le jour où le backend
/// bascule vers Spring ou Laravel.
class UserCreationService {
  static const _nomInstance = 'userCreation';

  /// Crée le compte et renvoie son uid. Le document `users/{uid}` reste à
  /// écrire par l'appelant — voir [UserRepository.createProfile].
  Future<String> creerCompte({
    required String email,
    required String motDePasse,
  }) async {
    final app = await _instanceSecondaire();
    try {
      final auth = FirebaseAuth.instanceFor(app: app);
      final cred = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: motDePasse,
      );
      final uid = cred.user?.uid;
      if (uid == null) {
        throw const CreationCompteException(
          'Le compte n\'a pas pu être créé. Réessayez.',
        );
      }
      // L'instance secondaire est connectée au nouveau compte : on la ferme
      // avant de la détruire, pour ne laisser aucun jeton derrière nous.
      await auth.signOut();
      return uid;
    } on FirebaseAuthException catch (e) {
      throw CreationCompteException(_message(e));
    } finally {
      await app.delete();
    }
  }

  /// Récupère l'instance secondaire, ou la crée. La récupération couvre le
  /// cas d'une tentative précédente interrompue avant le `delete()`.
  Future<FirebaseApp> _instanceSecondaire() async {
    try {
      return Firebase.app(_nomInstance);
    } on FirebaseException {
      return Firebase.initializeApp(
        name: _nomInstance,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  static String _message(FirebaseAuthException e) {
    return switch (e.code) {
      'email-already-in-use' =>
        'Cet email est déjà utilisé par un autre compte.',
      'invalid-email' => 'Format d\'email invalide.',
      'weak-password' => 'Mot de passe trop faible (6 caractères minimum).',
      'operation-not-allowed' =>
        'La création de comptes est désactivée sur ce projet Firebase.',
      'network-request-failed' =>
        'Pas de connexion. Fastura nécessite Internet.',
      _ => 'Création impossible (${e.code}).',
    };
  }

  /// Mot de passe initial lisible au téléphone : pas de caractères
  /// ambigus (I/l/1, O/0) que l'utilisateur retaperait de travers.
  static String genererMotDePasse({int longueur = 10}) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final rnd = Random.secure();
    return List.generate(
      longueur,
      (_) => alphabet[rnd.nextInt(alphabet.length)],
    ).join();
  }
}
