import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:fastura/app/core/utils/bottom_sheet_helpers.dart';

/// Écran logique : 360 × 800, barre d'état de 48, barre de gestes de 16.
const double _hauteurEcran = 800;
const double _barreEtat = 48;
const double _clavier = 300;

void _regler(WidgetTester tester, {required bool clavierOuvert}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(360, _hauteurEcran);
  tester.view.padding = FakeViewPadding(
    top: _barreEtat,
    bottom: clavierOuvert ? 0 : 16,
  );
  tester.view.viewPadding = const FakeViewPadding(top: _barreEtat, bottom: 16);
  tester.view.viewInsets = FakeViewPadding(
    bottom: clavierOuvert ? _clavier : 0,
  );
  addTearDown(tester.view.reset);
}

Future<void> _ouvrir(WidgetTester tester, {required int lignes}) async {
  await tester.pumpWidget(
    GetMaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Get.bottomSheet(
              CadreSheet(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < lignes; i++)
                      const SizedBox(height: 60, child: TextField()),
                  ],
                ),
              ),
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  group('CadreSheet', () {
    testWidgets('clavier fermé, contenu court : la feuille reste basse', (
      tester,
    ) async {
      _regler(tester, clavierOuvert: false);
      await _ouvrir(tester, lignes: 3);

      final r = tester.getRect(find.byType(CadreSheet));
      expect(r.bottom, _hauteurEcran);
      expect(r.top, greaterThan(_hauteurEcran / 2));
    });

    testWidgets('clavier ouvert : la feuille ne passe pas sous la barre '
        'd\'état et s\'arrête au-dessus du clavier', (tester) async {
      _regler(tester, clavierOuvert: true);
      await _ouvrir(tester, lignes: 12);

      final r = tester.getRect(find.byType(CadreSheet));
      expect(
        r.top,
        greaterThanOrEqualTo(_barreEtat),
        reason: 'la feuille déborde sur la barre d\'état',
      );
      expect(
        r.bottom,
        lessThanOrEqualTo(_hauteurEcran - _clavier),
        reason: 'la feuille passe derrière le clavier',
      );
    });

    testWidgets('clavier ouvert : pas de vide sous le dernier champ', (
      tester,
    ) async {
      _regler(tester, clavierOuvert: true);
      await _ouvrir(tester, lignes: 2);

      final feuille = tester.getRect(find.byType(CadreSheet));
      final dernier = tester.getRect(find.byType(TextField).last);
      expect(
        feuille.bottom - dernier.bottom,
        lessThan(80),
        reason:
            'le clavier est réservé deux fois : par la route et par le '
            'padding du cadre',
      );
    });
  });
}
