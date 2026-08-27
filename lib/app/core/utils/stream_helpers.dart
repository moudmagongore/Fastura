import 'dart:async';

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

/// Fusionne plusieurs flux de listes en un seul, dédoublonné et trié.
///
/// Firestore ne sait pas répondre en une requête à « les comptes dont
/// `tenantId` vaut X **ou** dont `tenantIds` contient X » : le OU sur deux
/// champs différents n'existe pas. On lance donc les deux requêtes et on
/// recolle les résultats ici.
///
/// Le flux émet dès la première réponse reçue, avec ce qui est connu à cet
/// instant : attendre que toutes les sources aient répondu laisserait la
/// liste en chargement si l'une d'elles ne renvoie jamais rien.
Stream<List<T>> fusionnerListes<T>(
  List<Stream<List<T>>> sources, {
  required String Function(T) cle,
  required int Function(T, T) tri,
}) {
  if (sources.length == 1) return sources.first;

  final derniers = List<List<T>?>.filled(sources.length, null);
  final subs = <StreamSubscription<List<T>>>[];
  late final StreamController<List<T>> ctrl;

  void emettre() {
    final parCle = <String, T>{};
    for (final liste in derniers) {
      for (final e in liste ?? const []) {
        parCle[cle(e)] = e;
      }
    }
    ctrl.add(parCle.values.toList()..sort(tri));
  }

  ctrl = StreamController<List<T>>(
    onListen: () {
      for (var i = 0; i < sources.length; i++) {
        final index = i;
        subs.add(
          sources[i].listen((liste) {
            derniers[index] = liste;
            emettre();
          }, onError: ctrl.addError),
        );
      }
    },
    onCancel: () async {
      for (final s in subs) {
        await s.cancel();
      }
      subs.clear();
    },
  );

  return ctrl.stream;
}
