import 'package:fastura/app/core/constants/app_constants.dart';
import 'package:fastura/app/data/models/article_model.dart';
import 'package:fastura/app/modules/factures/widgets/selecteurs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

/// La feuille d'ajout d'article marque ce qui est déjà sur la facture.
///
/// On y revient plusieurs fois pour une même vente : sans repère, le même
/// sac de riz est saisi deux fois sans que personne ne s'en aperçoive.
void main() {
  setUpAll(() => initializeDateFormatting(AppConstants.defaultLocale));

  ArticleModel article(String id, String designation) => ArticleModel(
    id: id,
    designation: designation,
    unite: 'sac',
    prixVente: 425000,
    categorieId: 'c1',
    tenantId: 't1',
  );

  Future<void> ouvrir(
    WidgetTester tester, {
    required Map<String, double> dejaAjoutes,
  }) async {
    await tester.pumpWidget(
      GetMaterialApp(home: const Scaffold(body: SizedBox.shrink())),
    );
    choisirArticle(
      [article('a1', 'Riz parfumé 50 kg'), article('a2', 'Huile 20 L')],
      devise: 'GNF',
      dejaAjoutes: dejaAjoutes,
    );
    await tester.pumpAndSettle();
  }

  ListTile ligneDe(WidgetTester tester, String designation) =>
      tester.widget<ListTile>(
        find.ancestor(
          of: find.text(designation),
          matching: find.byType(ListTile),
        ),
      );

  testWidgets('un article au panier porte une coche, et lui seul', (
    tester,
  ) async {
    await ouvrir(tester, dejaAjoutes: {'a1': 3});

    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    // L'autre article n'est pas marqué : la coche ne déborde pas sur la
    // ligne voisine.
    expect(ligneDe(tester, 'Huile 20 L').selected, isFalse);
  });

  testWidgets('un article au panier ne se rajoute pas depuis la feuille', (
    tester,
  ) async {
    await ouvrir(tester, dejaAjoutes: {'a1': 3});

    // Ni activé ni tapable : la quantité se règle dans la liste de la
    // facture, pas en ressélectionnant l'article.
    final deja = ligneDe(tester, 'Riz parfumé 50 kg');
    expect(deja.enabled, isFalse);
    expect(deja.onTap, isNull);

    // La feuille reste ouverte après un appui dessus.
    await tester.tap(find.text('Riz parfumé 50 kg'));
    await tester.pumpAndSettle();
    expect(find.text('Huile 20 L'), findsOneWidget);

    // L'article libre, lui, répond toujours.
    expect(ligneDe(tester, 'Huile 20 L').onTap, isNotNull);
  });

  testWidgets('facture vierge : aucune ligne marquée', (tester) async {
    await ouvrir(tester, dejaAjoutes: const {});

    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
  });
}
