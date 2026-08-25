// GENERATED-PLACEHOLDER
//
// Ce fichier sera **écrasé** par la commande :
//
//     flutterfire configure --project=<id-du-projet-firebase>
//
// Il n'existe que pour que le projet compile avant que le backend Firebase
// ne soit rattaché. Tant qu'il n'a pas été régénéré, le lancement de
// l'application s'arrête au démarrage avec le message ci-dessous, plutôt
// que de partir sur une configuration silencieusement invalide.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
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