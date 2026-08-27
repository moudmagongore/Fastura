// Options Firebase du projet `fastura-c05bf`.
//
// À régénérer plutôt qu'à corriger à la main :
//
//     flutterfire configure --project=fastura-c05bf
//
// Les valeurs doivent rester identiques à celles des fichiers natifs —
// `android/app/google-services.json` et `ios/Runner/GoogleService-Info.plist`.
// Les deux plateformes initialisent déjà l'app Firebase nativement : si les
// options passées depuis Dart ne correspondent pas à celles de l'app
// existante, `Firebase.initializeApp` lève
// `[core/duplicate-app] A Firebase App named "[DEFAULT]" already exists`.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        // Fastura est une application Android et iOS (cf. cahier des
        // charges). Mieux vaut s'arrêter net ailleurs que démarrer sur les
        // options d'une autre plateforme.
        throw UnsupportedError(
          'Fastura n\'est pas configurée pour $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCBrRRaKRRWxI118526xOWtSDY8sUV_m10',
    appId: '1:1010816198129:ios:02abed6153a44e48309050',
    messagingSenderId: '1010816198129',
    projectId: 'fastura-c05bf',
    storageBucket: 'fastura-c05bf.firebasestorage.app',
    iosBundleId: 'com.addvalis.fastura',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDjYCkJrtpFUJ0tHX7Q3jNHDW86l9agjd4',
    appId: '1:1010816198129:android:12c550d4bb650a33309050',
    messagingSenderId: '1010816198129',
    projectId: 'fastura-c05bf',
    storageBucket: 'fastura-c05bf.firebasestorage.app',
  );
}
