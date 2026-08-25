import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:fastura/app/core/constants/app_constants.dart';

import 'package:fastura/app/core/services/facture_pdf_service.dart';
import 'package:fastura/app/core/services/recu_pdf_service.dart';
import 'package:fastura/app/data/models/facture_model.dart';
import 'package:fastura/app/data/models/format_impression.dart';
import 'package:fastura/app/data/models/paiement_model.dart';
import 'package:fastura/app/data/models/tenant_model.dart';

/// Le moteur PDF lève dès qu'un contenu déborde d'une page de hauteur finie.
/// Un A5 fait la moitié d'un A4 : ce test est là pour que le jour où une
/// colonne ou une taille de police change, le débordement se voie ici et pas
/// au comptoir, imprimante en main.
/// Nombre de pages du document, lu dans l'objet `/Pages` du PDF.
///
/// Le moteur ne lève pas quand un contenu déborde d'une page de hauteur
/// finie : il le **rogne**. Compter les pages est le seul moyen de vérifier
/// qu'une longue facture a bien continué au lieu d'être coupée.
int nbPages(Uint8List octets) {
  final m = RegExp(r'/Count (\d+)').firstMatch(latin1.decode(octets));
  return m == null ? 0 : int.parse(m.group(1)!);
}

void main() {
  // Les dates des documents sont formatées en fr_FR ; sans ces données de
  // locale, `DateFormat` lève avant même le rendu.
  setUpAll(() => initializeDateFormatting(AppConstants.defaultLocale));

  TenantModel tenant(FormatImpression format) => TenantModel(
    id: 't1',
    nom: 'Établissement Kéïta & Frères',
    adresse: 'Quartier Almamya, commune de Kaloum, Conakry',
    telephone: '+224 620 00 00 00',
    email: 'contact@keita-freres.gn',
    devise: 'GNF',
    tauxTva: 18,
    tvaActive: true,
    formatImpression: format,
  );

  FactureModel facture({int nbLignes = 12, bool annulee = false}) =>
      FactureModel(
        id: 'f1',
        numero: 'FA-2026-00042',
        date: DateTime(2026, 8, 25),
        clientId: 'c1',
        clientNom: 'Société Générale de Distribution du Fouta',
        tenantId: 't1',
        creeParId: 'u1',
        creeParNom: 'Mamadou Diallo',
        tauxTva: 18,
        devise: 'GNF',
        note: 'Livraison prévue le 30/08, bon de commande BC-2026-118.',
        montantPaye: 150000,
        annulee: annulee,
        lignes: [
          for (var i = 0; i < nbLignes; i++)
            LigneFacture(
              articleId: 'a$i',
              // Une ligne sur deux porte l'ancien code du catalogue : les
              // deux rendus, avec et sans, doivent tenir dans la page.
              code: i.isEven ? 'ART-${(i + 1).toString().padLeft(3, '0')}' : '',
              designation: 'Sac de riz parfumé importé 50 kg, lot ${i + 1}',
              unite: 'sac',
              prixUnitaire: 425000 + i * 1500,
              quantite: 3 + i % 4,
            ),
        ],
      );

  group('Facture', () {
    for (final format in FormatImpression.values) {
      test('se rend en ${format.name} sans déborder', () async {
        final octets = await FacturePdfService.construire(
          facture: facture(),
          tenant: tenant(format),
        );
        expect(octets, isNotEmpty);
      });
    }

    test('le bandeau d\'annulation ne fait pas déborder l\'A5', () async {
      final octets = await FacturePdfService.construire(
        facture: facture(annulee: true),
        tenant: tenant(FormatImpression.a5),
      );
      expect(octets, isNotEmpty);
    });

    test('une facture courte tient sur une page A4', () async {
      final octets = await FacturePdfService.construire(
        facture: facture(nbLignes: 3),
        tenant: tenant(FormatImpression.a4),
      );
      expect(nbPages(octets), 1);
    });

    test('une facture longue continue au lieu d\'être rognée', () async {
      for (final format in [FormatImpression.a4, FormatImpression.a5]) {
        final octets = await FacturePdfService.construire(
          facture: facture(nbLignes: 40),
          tenant: tenant(format),
        );
        expect(nbPages(octets), greaterThan(1), reason: format.name);
      }
    });
  });

  PaiementModel paiement({int nbImputations = 8}) => PaiementModel(
    id: 'p1',
    date: DateTime(2026, 8, 25),
    clientId: 'c1',
    clientNom: 'Société Générale de Distribution du Fouta',
    montant: 100000 * (nbImputations + 1),
    mode: ModePaiement.especes,
    tenantId: 't1',
    creeParId: 'u1',
    creeParNom: 'Mamadou Diallo',
    note: 'Versement partiel, reçu n° 118.',
    imputations: [
      for (var i = 0; i < nbImputations; i++)
        ImputationPaiement(
          factureId: 'f$i',
          factureNumero: 'FA-2026-000${(i + 10)}',
          montant: 100000,
        ),
    ],
  );

  group('Reçu', () {
    test(
      'un lettrage de cinquante factures continue au lieu d\'être rogné',
      () async {
        final octets = await RecuPdfService.construire(
          paiement: paiement(nbImputations: 50),
          tenant: tenant(FormatImpression.a5),
          soldeApres: -100000,
        );
        expect(nbPages(octets), greaterThan(1));
      },
    );

    for (final format in FormatImpression.values) {
      test('se rend en ${format.name} sans déborder', () async {
        final octets = await RecuPdfService.construire(
          paiement: paiement(),
          tenant: tenant(format),
          soldeApres: -100000,
        );
        expect(octets, isNotEmpty);
      });
    }
  });
}
