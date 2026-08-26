import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fastura/app/core/utils/pdf_helper.dart';

/// Le voile d'attente du tirage ne doit survivre à aucun chemin de sortie :
/// tant qu'il est là, sa barrière avale les appuis et l'écran est bloqué.
///
/// **Ce qui n'est pas couvert** : le chemin nominal, où la feuille
/// « Imprimer ou partager » s'ouvre par-dessus. Il demande un snackbar à
/// l'écran — c'est là que le bug se produisait — et le snackbar de GetX ne
/// stabilise jamais l'arbre : `pumpAndSettle` ne rend pas la main, et
/// `Get.back()` y dépile le mauvais élément. Le tenir sous test bloquait la
/// suite entière. Ce chemin se vérifie à la main : émettre une facture,
/// fermer la feuille d'impression, et pouvoir encore toucher l'écran.
void main() {
  tearDown(Get.reset);

  testWidgets('génération en échec : le voile tombe et rend la main', (
    tester,
  ) async {
    var appuis = 0;
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => appuis++,
              child: const Text('Bouton de la fiche'),
            ),
          ),
        ),
      ),
    );

    await genererPuisImprimer(
      generer: () async => throw Exception('police introuvable'),
      nomFichier: 'Facture-FA-2026-0001',
      titre: 'Facture FA-2026-0001',
    );
    await tester.pump();

    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'le voile doit tomber même quand la génération échoue',
    );

    // La preuve que plus rien n'absorbe les appuis : l'écran répond.
    await tester.tap(find.text('Bouton de la fiche'));
    await tester.pump();
    expect(appuis, 1, reason: 'l\'écran est resté bloqué derrière le voile');

    Get.closeAllSnackbars();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  });
}
