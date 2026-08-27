import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:fastura/app/core/constants/app_constants.dart';
import 'package:fastura/app/core/services/facture_pdf_service.dart';
import 'package:fastura/app/data/models/facture_model.dart';
import 'package:fastura/app/data/models/format_impression.dart';
import 'package:fastura/app/data/models/tenant_model.dart';

/// Écrit une facture de démonstration dans `build/`, pour regarder le rendu —
/// le pied de page en particulier, qui porte la signature de l'éditeur.
///
/// **Ce n'est pas un test** — il vit sous `tool/`, `flutter test` ne le
/// ramasse pas :
///
/// ```sh
/// flutter test tool/apercu_facture.dart
/// sips -s format png build/apercu-facture-a5.pdf --out build/apercu-facture-a5.png
/// ```
void main() {
  setUpAll(() => initializeDateFormatting(AppConstants.defaultLocale));

  final tenant = TenantModel(
    id: 't1',
    nom: 'Établissement Kéïta & Frères',
    adresse: 'Quartier Almamya, Kaloum, Conakry',
    telephone: '+224 620 00 00 00',
    devise: 'GNF',
    tauxTva: 18,
    tvaActive: true,
    formatImpression: FormatImpression.a5,
  );

  final facture = FactureModel(
    id: 'f1',
    numero: 'FA-2026-00042',
    date: DateTime(2026, 8, 25),
    clientId: 'c1',
    clientNom: 'Boutique Camara',
    tenantId: 't1',
    creeParId: 'u1',
    creeParNom: 'Mamadou Diallo',
    tauxTva: 18,
    devise: 'GNF',
    montantPaye: 150000,
    lignes: const [
      LigneFacture(
        articleId: 'a1',
        designation: 'Sac de riz parfumé importé 50 kg',
        categorieLibelle: 'Céréales',
        unite: 'sac',
        prixUnitaire: 425000,
        quantite: 3,
      ),
      LigneFacture(
        articleId: 'a2',
        designation: 'Bidon d\'huile 20 L',
        categorieLibelle: 'Huiles et condiments',
        unite: 'bidon',
        prixUnitaire: 310000,
        quantite: 2,
      ),
    ],
  );

  for (final format in FormatImpression.values) {
    test('écrit une facture ${format.name} dans build/', () async {
      final octets = await FacturePdfService.construire(
        facture: facture,
        tenant: tenant.copyWith(formatImpression: format),
      );
      Directory('build').createSync(recursive: true);
      File('build/apercu-facture-${format.name}.pdf').writeAsBytesSync(octets);
      expect(octets, isNotEmpty);
    });
  }
}
