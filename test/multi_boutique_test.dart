import 'dart:async';

import 'package:fastura/app/core/utils/stream_helpers.dart';
import 'package:fastura/app/data/models/user_model.dart';
import 'package:fastura/app/data/models/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

/// Affectation d'un même administrateur à plusieurs boutiques.
///
/// Deux points de rupture possibles, tous deux invisibles à l'écran tant
/// qu'on ne teste pas : la lecture d'un document ancien, qui ne porte pas
/// encore `tenantIds`, et la fusion des deux requêtes qui remplacent le OU
/// que Firestore ne sait pas faire.
void main() {
  group('UserModel.tenantIds', () {
    test('un document ancien se lit comme un compte mono-boutique', () {
      final u = UserModel.fromMap({
        'nom': 'Aïssatou Barry',
        'email': 'a@b.c',
        'role': 'admin',
        'tenantId': 'boutique-1',
      }, 'uid-1');

      expect(u.tenantIds, ['boutique-1']);
      expect(u.appartientA('boutique-1'), isTrue);
      expect(u.estMultiBoutique, isFalse);
    });

    test('la boutique d\'origine passe toujours en tête, sans doublon', () {
      final u = UserModel.fromMap({
        'nom': 'Mamadou Diallo',
        'email': 'm@d.c',
        'role': 'admin',
        'tenantId': 'boutique-1',
        'tenantIds': ['boutique-2', 'boutique-1', 'boutique-2'],
      }, 'uid-2');

      expect(u.tenantIds, ['boutique-1', 'boutique-2']);
      expect(u.boutiquesAffectees, ['boutique-2']);
      expect(u.estMultiBoutique, isTrue);
    });

    test('le super-administrateur n\'a aucune boutique', () {
      final u = UserModel(
        id: 'uid-3',
        nom: 'Addvalis',
        email: 's@a.c',
        role: UserRole.superAdmin,
      );

      expect(u.tenantIds, isEmpty);
      expect(u.appartientA('boutique-1'), isFalse);
    });

    test('toMap réécrit la liste complète', () {
      final u = UserModel(
        id: 'uid-4',
        nom: 'Fatou',
        email: 'f@a.c',
        role: UserRole.admin,
        tenantId: 'boutique-1',
        tenantIds: const ['boutique-2'],
      );

      expect(u.toMap()['tenantIds'], ['boutique-1', 'boutique-2']);
    });
  });

  group('fusionnerListes', () {
    test('dédoublonne les deux requêtes et trie le résultat', () async {
      final a = StreamController<List<String>>();
      final b = StreamController<List<String>>();

      final vues = <List<String>>[];
      final sub = fusionnerListes<String>(
        [a.stream, b.stream],
        cle: (s) => s,
        tri: (x, y) => x.compareTo(y),
      ).listen(vues.add);

      // Une seule source a répondu : la liste s'affiche déjà, sans attendre
      // la seconde requête.
      a.add(['Zoé', 'Amadou']);
      await Future<void>.delayed(Duration.zero);
      expect(vues.last, ['Amadou', 'Zoé']);

      // L'administrateur affecté remonte par la seconde requête, et celui
      // que les deux remontent n'apparaît qu'une fois.
      b.add(['Amadou', 'Binta']);
      await Future<void>.delayed(Duration.zero);
      expect(vues.last, ['Amadou', 'Binta', 'Zoé']);

      // Une source qui se vide retire ses éléments, pas ceux de l'autre.
      a.add(const []);
      await Future<void>.delayed(Duration.zero);
      expect(vues.last, ['Amadou', 'Binta']);

      await sub.cancel();
      await a.close();
      await b.close();
    });

    test('source unique : le flux passe tel quel', () async {
      final a = StreamController<List<String>>();
      final vues = <List<String>>[];
      final sub = fusionnerListes<String>(
        [a.stream],
        cle: (s) => s,
        tri: (x, y) => x.compareTo(y),
      ).listen(vues.add);

      // Ni tri ni recopie : le cas courant — un compte mono-boutique —
      // reste la requête d'origine.
      a.add(['Zoé', 'Amadou']);
      await Future<void>.delayed(Duration.zero);
      expect(vues.last, ['Zoé', 'Amadou']);

      await sub.cancel();
      await a.close();
    });
  });
}
