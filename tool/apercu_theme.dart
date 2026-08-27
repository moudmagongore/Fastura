import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fastura/app/core/widgets/empty_state.dart';
import 'package:fastura/app/core/widgets/module_tile.dart';
import 'package:fastura/app/core/widgets/statut_chip.dart';
import 'package:fastura/app/core/widgets/message_banner.dart';
import 'package:fastura/app/core/utils/format_helpers.dart';
import 'package:fastura/app/core/widgets/marque_fastura.dart';
import 'package:fastura/app/modules/accueil/widgets/statistiques_accueil.dart';
import 'package:fastura/app/theme/app_colors.dart';
import 'package:fastura/app/theme/app_theme.dart';

/// Planche de contrôle du thème : rend les composants communs en clair et en
/// sombre, et écrit deux images.
///
/// **Ce n'est pas un test** — il vit sous `tool/` et non `test/`, donc
/// `flutter test` ne le ramasse pas. C'est le seul moyen de *voir* le thème
/// sans appareil branché, avant de toucher à [AppTheme] :
///
/// ```sh
/// flutter test tool/apercu_theme.dart --update-goldens
/// open build/apercu-clair.png build/apercu-sombre.png
/// ```
///
/// Les libellés de boutons, de chips et de barre de titre sortent en pavés
/// noirs : leurs styles viennent des thèmes de composants, qui ne passent pas
/// par la `Typography` et n'héritent donc pas de la police chargée ici. Sur
/// appareil, ils prennent la police du système. Seule la mise en page et les
/// couleurs se jugent sur ces images.
Future<void> _chargerPolices() async {
  final racine =
      Platform.environment['FLUTTER_ROOT'] ??
      '${Platform.environment['HOME']}/development/flutter';
  final dossier = Directory('$racine/bin/cache/artifacts/material_fonts');
  if (!dossier.existsSync()) return;

  Future<void> charger(String famille, Map<String, FontWeight> fichiers) async {
    final loader = FontLoader(famille);
    for (final f in fichiers.keys) {
      final fichier = File('${dossier.path}/$f');
      if (fichier.existsSync()) {
        loader.addFont(
          Future.value(fichier.readAsBytesSync().buffer.asByteData()),
        );
      }
    }
    await loader.load();
  }

  await charger('Roboto', {
    'Roboto-Regular.ttf': FontWeight.w400,
    'Roboto-Medium.ttf': FontWeight.w500,
    'Roboto-Bold.ttf': FontWeight.w700,
  });
  await charger('MaterialIcons', {
    'MaterialIcons-Regular.otf': FontWeight.w400,
  });
}

Widget _vitrine(BuildContext context) {
  return Scaffold(
    // La barre des accueils : le bouton du tiroir à gauche, la marque au
    // titre. C'est le seul endroit où les deux teintes du logo se lisent sur
    // le fond de la barre — le cas à vérifier en sombre.
    appBar: AppBar(
      leading: IconButton(
        onPressed: () {},
        icon: const Icon(Icons.menu_rounded),
      ),
      centerTitle: true,
      title: const MarqueFastura(),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () {},
      icon: const Icon(Icons.add),
      label: const Text('Facturer'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const TextField(
          decoration: InputDecoration(
            hintText: 'Rechercher par numéro ou client…',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // `FilterChip` d'abord : c'est celui des filtres de dépenses,
              // le plus exposé au problème de contraste une fois coché.
              FilterChip(
                label: const Text('Avec solde'),
                selected: true,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                onSelected: (_) {},
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Tous'),
                selected: false,
                onSelected: (_) {},
              ),
              const SizedBox(width: 8),
              for (final (libelle, coche) in [
                ('Toutes', true),
                ('Impayées', false),
                ('Partielles', false),
              ]) ...[
                ChoiceChip(
                  label: Text(libelle),
                  selected: coche,
                  onSelected: (_) {},
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Chiffres de l'accueil : le montant le plus long possible, pour
        // vérifier qu'il se réduit au lieu de déborder.
        const TitreSection('Aujourd\'hui'),
        const SizedBox(height: 12),
        CarteStatVedette(
          icone: Icons.trending_up_rounded,
          libelle: 'Facturé aujourd\'hui',
          montant: Formats.montant(128450000, devise: 'GNF'),
          precision: '12 factures',
          couleur: AppColors.brandPrimary,
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: CarteStat(
                  icone: Icons.payments_rounded,
                  libelle: 'Encaissé',
                  valeur: Formats.montant(96200000, devise: 'GNF'),
                  couleur: AppColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CarteStat(
                  icone: Icons.trending_down_rounded,
                  libelle: 'Dépenses',
                  valeur: Formats.montant(1450000, devise: 'GNF'),
                  couleur: AppColors.danger,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const TitreSection('Ce mois-ci'),
        const SizedBox(height: 12),
        CarteResumeMois(
          facture: Formats.montant(1284500000, devise: 'GNF'),
          encaisse: Formats.montant(962000000, devise: 'GNF'),
          depenses: Formats.montant(14500000, devise: 'GNF'),
          nombreFactures: 143,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'FA-2026-0142',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    const StatutChip(actif: true, labelActif: 'Payée'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Boutique Camara',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '26/08/2026 · 4 article(s)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '1 250 000 GNF',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    const StatutChip(actif: false, labelInactif: 'Annulée'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        MessageBanner.attention('Cette facture reste due de 250 000 GNF.'),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: [
            ModuleTile(
              libelle: 'Nouvelle facture',
              icone: Icons.receipt_long_outlined,
              onTap: () {},
            ),
            ModuleTile(
              libelle: 'Paiements',
              icone: Icons.payments_outlined,
              couleur: AppColors.brandAccent,
              onTap: () {},
            ),
            const ModuleTile(
              libelle: 'Relevés',
              icone: Icons.insights_outlined,
            ),
            ModuleTile(
              libelle: 'Dépenses',
              icone: Icons.trending_down,
              couleur: AppColors.danger,
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.check_rounded),
          label: const Text('Valider la facture'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.print_outlined, size: 18),
          label: const Text('Imprimer ou partager'),
        ),
        const SizedBox(height: 24),
        const SizedBox(
          height: 320,
          child: EmptyState(
            icone: Icons.people_outline,
            titre: 'Aucun client',
            description:
                'Les clients que vous enregistrez apparaîtront ici, du plus '
                'récent au plus ancien.',
          ),
        ),
      ],
    ),
  );
}

void main() {
  setUpAll(_chargerPolices);

  for (final (nom, theme) in [
    ('clair', AppTheme.light),
    ('sombre', AppTheme.dark),
  ]) {
    testWidgets('planche de contrôle — thème $nom', (tester) async {
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(780, 3000);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          debugShowCheckedModeBanner: false,
          home: Builder(builder: _vitrine),
        ),
      );
      await tester.pump();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../build/apercu-$nom.png'),
      );
    });
  }
}
