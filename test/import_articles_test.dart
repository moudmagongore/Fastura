import 'package:fastura/app/modules/articles/import_articles.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'analyseur du collage. C'est le seul endroit de l'app qui lise du texte
/// écrit ailleurs — tableur, message, cahier recopié — et donc le seul où
/// l'on doive prévoir l'imprévu.
void main() {
  AnalyseImport analyser(
    String texte, {
    Iterable<String> existantes = const [],
  }) => AnalyseImport.analyser(
    texte,
    uniteParDefaut: 'pièce',
    existantes: existantes,
  );

  group('séparateurs', () {
    test('point-virgule, tabulation et barre verticale', () {
      for (final s in [';', '\t', '|']) {
        final a = analyser('Sac de riz 50 kg${s}425000${s}sac');
        expect(a.lignes.single.statut, StatutLigne.creable, reason: s);
        expect(a.lignes.single.designation, 'Sac de riz 50 kg');
        expect(a.lignes.single.prix, 425000);
        expect(a.lignes.single.unite, 'sac');
      }
    });

    test('la virgule ne sépare pas : elle est décimale', () {
      final a = analyser('Ciment;12,5');
      expect(a.lignes.single.prix, 12.5);
    });

    test('unité absente : celle du lot', () {
      expect(analyser('Sucre 1 kg;12500').lignes.single.unite, 'pièce');
    });
  });

  group('prix écrits par un humain', () {
    test('espaces, insécables, devise collée', () {
      expect(AnalyseImport.montant('425 000'), 425000);
      expect(AnalyseImport.montant('425 000'), 425000);
      expect(AnalyseImport.montant('425000 GNF'), 425000);
    });

    test('le point à trois chiffres est un millier, pas une décimale', () {
      expect(AnalyseImport.montant('425.000'), 425000);
      expect(AnalyseImport.montant('425.5'), 425.5);
    });

    test('la virgule l\'emporte comme décimale', () {
      expect(AnalyseImport.montant('12.500,50'), 12500.5);
    });

    test('rien d\'exploitable rend nul plutôt qu\'un prix inventé', () {
      expect(AnalyseImport.montant('à voir'), isNull);
      expect(AnalyseImport.montant(''), isNull);
    });
  });

  group('lignes refusées', () {
    test('sans prix', () {
      final l = analyser('Farine T55').lignes.single;
      expect(l.statut, StatutLigne.erreur);
      expect(l.probleme, 'Prix absent');
      expect(l.retenue, isFalse);
      expect(l.modifiable, isFalse);
    });

    test('prix illisible ou nul', () {
      expect(
        analyser('Farine;à voir').lignes.single.statut,
        StatutLigne.erreur,
      );
      expect(analyser('Farine;0').lignes.single.statut, StatutLigne.erreur);
    });

    test('désignation vide', () {
      expect(analyser(';425000').lignes.single.probleme, 'Désignation vide');
    });

    test('les lignes vides ne comptent pas', () {
      expect(analyser('\n\nSac;100\n\n').lignes, hasLength(1));
    });
  });

  group('doublons', () {
    test('déjà au catalogue : signalé et décoché, mais forçable', () {
      final l = analyser(
        'Sac de riz 50 kg;425000',
        existantes: ['  sac   DE riz 50 KG '],
      ).lignes.single;
      expect(l.statut, StatutLigne.doublon);
      expect(l.probleme, 'Déjà au catalogue');
      expect(l.retenue, isFalse);
      // Le catalogue tolère les homonymes : l'utilisateur peut passer outre.
      expect(l.modifiable, isTrue);
    });

    test('répété dans le collage : la seconde occurrence seulement', () {
      final lignes = analyser('Sac;100\nSac;100').lignes;
      expect(lignes.first.statut, StatutLigne.creable);
      expect(lignes.last.probleme, 'Répété plus haut dans la liste');
    });
  });

  test('espaces multiples réduits, dans la désignation comme dans la clé', () {
    final lignes = analyser('Sac   de    riz;100\nSac de riz;100').lignes;
    expect(lignes.first.designation, 'Sac de riz');
    expect(lignes.last.statut, StatutLigne.doublon);
  });

  test('collage plafonné : le surplus est écarté, et annoncé', () {
    final texte = List.generate(
      AnalyseImport.maxLignes + 10,
      (i) => 'Article $i;100',
    ).join('\n');
    final a = analyser(texte);
    expect(a.lignes, hasLength(AnalyseImport.maxLignes));
    expect(a.tronquee, isTrue);
  });
}
