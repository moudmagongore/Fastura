import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:fastura/app/core/constants/app_constants.dart';

import 'package:fastura/app/core/services/recu_pdf_service.dart';
import 'package:fastura/app/data/models/format_impression.dart';
import 'package:fastura/app/data/models/paiement_model.dart';
import 'package:fastura/app/data/models/tenant_model.dart';

/// Écrit un reçu de démonstration dans `build/`, pour regarder le rendu.
///
/// **Ce n'est pas un test** — il vit sous `tool/`, `flutter test` ne le
/// ramasse pas :
///
/// ```sh
/// flutter test tool/apercu_recu.dart
/// sips -s format png build/apercu-recu.pdf --out build/apercu-recu.png
/// ```
void main() {
  // Les dates longues du reçu passent par `intl`, qui refuse de formater une
  // locale non initialisée — `main()` s'en charge dans l'app.
  setUpAll(() => initializeDateFormatting(AppConstants.defaultLocale));

  for (final format in [FormatImpression.a5, FormatImpression.ticket]) {
    test('écrit un reçu ${format.name} dans build/', () async {
      final octets = await RecuPdfService.construire(
        paiement: PaiementModel(
          id: 'p1',
          date: DateTime(2026, 8, 26, 14, 32),
          clientId: 'c1',
          clientNom: 'Boutique Camara',
          montant: 450000,
          mode: ModePaiement.especes,
          tenantId: 't1',
          creeParId: 'u1',
          creeParNom: 'Mamadou Diallo',
          imputations: const [
            ImputationPaiement(
              factureId: 'f1',
              factureNumero: 'FA-2026-0141',
              montant: 300000,
            ),
            ImputationPaiement(
              factureId: 'f2',
              factureNumero: 'FA-2026-0142',
              montant: 150000,
            ),
          ],
        ),
        tenant: TenantModel(
          id: 't1',
          nom: 'Établissement Kéïta & Frères',
          adresse: 'Quartier Almamya, Kaloum, Conakry',
          telephone: '+224 620 00 00 00',
          devise: 'GNF',
          tauxTva: 18,
          tvaActive: true,
          formatImpression: format,
        ),
        soldeApres: 0,
      );

      Directory('build').createSync(recursive: true);
      File('build/apercu-recu-${format.name}.pdf').writeAsBytesSync(octets);
      expect(octets, isNotEmpty);
    });
  }
}
