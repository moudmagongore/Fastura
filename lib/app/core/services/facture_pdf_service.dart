import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/models/facture_model.dart';
import '../../data/models/format_impression.dart';
import '../../data/models/tenant_model.dart';
import '../utils/format_helpers.dart';
import 'pdf_commun.dart';

/// Génère le PDF d'une facture au format retenu par le tenant.
///
/// Un seul format est actif à la fois pour toute l'entreprise (CDC §6). Le
/// rendu n'est pas une simple mise à l'échelle : un ticket de 80 mm se lit en
/// une colonne, sans tableau, là où l'A4 et l'A5 présentent les lignes en
/// colonnes avec un cartouche client.
abstract class FacturePdfService {
  FacturePdfService._();

  static Future<Uint8List> construire({
    required FactureModel facture,
    required TenantModel tenant,
  }) async {
    final format = tenant.formatImpression;
    final logo = await PdfCommun.chargerLogo(tenant);
    final document = pw.Document(
      title: 'Facture ${facture.numero}',
      author: tenant.nom,
    );

    if (PdfCommun.estTicket(format)) {
      document.addPage(
        pw.Page(
          pageFormat: PdfCommun.format(format),
          build: (context) => _ticket(facture, tenant, logo),
        ),
      );
    } else {
      // MultiPage et non Page : une facture de dix lignes remplit déjà un
      // A5, et une `Page` de hauteur finie **rogne** le débordement sans
      // rien signaler — le pied de facture disparaîtrait en silence.
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfCommun.format(format),
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          header: (context) => context.pageNumber == 1
              ? pw.SizedBox()
              : _bandeauSuite(facture, format),
          footer: (context) => _piedPage(facture, format, context),
          build: (context) => _corps(facture, tenant, logo, format),
        ),
      );
    }

    return document.save();
  }

  // ---------------------------------------------------------------- A4 / A5

  static List<pw.Widget> _corps(
    FactureModel f,
    TenantModel tenant,
    pw.MemoryImage? logo,
    FormatImpression format,
  ) {
    double t(double base) => PdfCommun.taille(format, base);

    return [
      if (f.annulee) PdfCommun.filigraneAnnule(format),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: PdfCommun.enTete(tenant: tenant, format: format, logo: logo),
          ),
          _cartoucheFacture(f, format),
        ],
      ),
      pw.SizedBox(height: 18),
      _cartoucheClient(f, format),
      pw.SizedBox(height: 14),
      _tableauLignes(f, format),
      pw.SizedBox(height: 12),
      pw.Row(
        children: [
          pw.Expanded(
            child: (f.note ?? '').isEmpty
                ? pw.SizedBox()
                : pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Note',
                        style: pw.TextStyle(
                          fontSize: t(9),
                          fontWeight: pw.FontWeight.bold,
                          color: PdfCommun.gris,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        f.note!,
                        style: pw.TextStyle(
                          fontSize: t(9),
                          color: PdfCommun.gris,
                        ),
                      ),
                    ],
                  ),
          ),
          pw.SizedBox(width: 20),
          pw.SizedBox(
            width: PdfCommun.largeurBlocTotaux(format),
            child: _totaux(f, format),
          ),
        ],
      ),
      PdfCommun.pied(format),
    ];
  }

  /// Rappel d'identité en haut des pages suivantes : détachée de la
  /// première, une page de lignes ne dit plus de quelle facture elle vient.
  static pw.Widget _bandeauSuite(FactureModel f, FormatImpression format) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        'Facture ${f.numero} (suite)',
        textAlign: pw.TextAlign.right,
        style: pw.TextStyle(
          fontSize: PdfCommun.taille(format, 9),
          color: PdfCommun.gris,
        ),
      ),
    );
  }

  static pw.Widget _piedPage(
    FactureModel f,
    FormatImpression format,
    pw.Context context,
  ) {
    final style = pw.TextStyle(
      fontSize: PdfCommun.taille(format, 8),
      color: PdfCommun.gris,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Émise par ${f.creeParNom}', style: style),
          pw.Text(
            'Page ${context.pageNumber}/${context.pagesCount}',
            style: style,
          ),
        ],
      ),
    );
  }

  static pw.Widget _cartoucheFacture(FactureModel f, FormatImpression format) {
    double t(double base) => PdfCommun.taille(format, base);

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfCommun.grisClair,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            'FACTURE',
            style: pw.TextStyle(
              fontSize: t(14),
              fontWeight: pw.FontWeight.bold,
              color: PdfCommun.bleuPetrole,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            f.numero,
            style: pw.TextStyle(
              fontSize: t(12),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            Formats.date(f.date),
            style: pw.TextStyle(fontSize: t(9), color: PdfCommun.gris),
          ),
        ],
      ),
    );
  }

  static pw.Widget _cartoucheClient(FactureModel f, FormatImpression format) {
    double t(double base) => PdfCommun.taille(format, base);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfCommun.grisClair, width: 1),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CLIENT',
            style: pw.TextStyle(
              fontSize: t(8),
              fontWeight: pw.FontWeight.bold,
              color: PdfCommun.gris,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            f.clientNom,
            style: pw.TextStyle(
              fontSize: t(12),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tableauLignes(FactureModel f, FormatImpression format) {
    double t(double base) => PdfCommun.taille(format, base);

    final enTeteStyle = pw.TextStyle(
      fontSize: t(9),
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );
    final celluleStyle = pw.TextStyle(fontSize: t(9.5));

    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(4.5),
        1: const pw.FlexColumnWidth(1.4),
        2: const pw.FlexColumnWidth(1.8),
        3: const pw.FlexColumnWidth(1.8),
      },
      children: [
        pw.TableRow(
          // Répété en tête de chaque page : sans ça, une facture qui déborde
          // livre une deuxième page de chiffres sans intitulé de colonne.
          repeat: true,
          decoration: const pw.BoxDecoration(color: PdfCommun.bleuPetrole),
          children: [
            _cellule('Désignation', enTeteStyle, format: format),
            _cellule(
              'Qté',
              enTeteStyle,
              format: format,
              alignement: pw.TextAlign.center,
            ),
            _cellule(
              'P.U.',
              enTeteStyle,
              format: format,
              alignement: pw.TextAlign.right,
            ),
            _cellule(
              'Montant',
              enTeteStyle,
              format: format,
              alignement: pw.TextAlign.right,
            ),
          ],
        ),
        for (var i = 0; i < f.lignes.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isEven ? PdfColors.white : PdfCommun.grisClair,
            ),
            children: [
              // Le code n'existe plus au catalogue : il n'est repris que
              // sur les factures antérieures, qui le portaient sur la copie
              // remise au client.
              _cellule(
                f.lignes[i].code.isEmpty
                    ? f.lignes[i].designation
                    : '${f.lignes[i].designation}\n${f.lignes[i].code}',
                celluleStyle,
                format: format,
              ),
              _cellule(
                '${Formats.montant(f.lignes[i].quantite)} ${f.lignes[i].unite}',
                celluleStyle,
                format: format,
                alignement: pw.TextAlign.center,
              ),
              _cellule(
                Formats.montant(f.lignes[i].prixUnitaire),
                celluleStyle,
                format: format,
                alignement: pw.TextAlign.right,
              ),
              _cellule(
                Formats.montant(f.lignes[i].montant),
                celluleStyle.copyWith(fontWeight: pw.FontWeight.bold),
                format: format,
                alignement: pw.TextAlign.right,
              ),
            ],
          ),
      ],
    );
  }

  static pw.Widget _cellule(
    String texte,
    pw.TextStyle style, {
    required FormatImpression format,
    pw.TextAlign alignement = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(
        vertical: PdfCommun.taille(format, 6),
        horizontal: PdfCommun.taille(format, 8),
      ),
      child: pw.Text(texte, style: style, textAlign: alignement),
    );
  }

  static pw.Widget _totaux(FactureModel f, FormatImpression format) {
    return pw.Column(
      children: [
        if (f.tauxTva > 0) ...[
          PdfCommun.ligne(
            format,
            libelle: 'Montant HT',
            valeur: Formats.montant(f.montantHT, devise: f.devise),
          ),
          PdfCommun.ligne(
            format,
            libelle: 'TVA ${Formats.pourcentage(f.tauxTva)}',
            valeur: Formats.montant(f.montantTva, devise: f.devise),
          ),
        ],
        pw.Divider(color: PdfCommun.grisClair),
        PdfCommun.ligne(
          format,
          libelle: 'TOTAL',
          valeur: Formats.montant(f.montantTotal, devise: f.devise),
          gras: true,
          couleur: PdfCommun.bleuPetrole,
          tailleBase: 12,
        ),
        if (!f.annulee) ...[
          PdfCommun.ligne(
            format,
            libelle: 'Déjà réglé',
            valeur: Formats.montant(f.montantPaye, devise: f.devise),
            couleur: PdfCommun.vert,
          ),
          if (f.resteDu > 0)
            PdfCommun.ligne(
              format,
              libelle: 'Reste à payer',
              valeur: Formats.montant(f.resteDu, devise: f.devise),
              gras: true,
              couleur: PdfCommun.rouge,
            ),
        ],
      ],
    );
  }

  // ----------------------------------------------------------------- Ticket

  /// Rendu une colonne pour imprimante thermique.
  ///
  /// Pas de tableau ni de filets : sur 80 mm de large, quatre colonnes
  /// deviennent illisibles, et le rendu thermique écrase les traits fins.
  /// Chaque ligne occupe donc deux rangs — désignation, puis quantité ×
  /// prix aligné au montant.
  static pw.Widget _ticket(
    FactureModel f,
    TenantModel tenant,
    pw.MemoryImage? logo,
  ) {
    const format = FormatImpression.ticket;
    double t(double base) => PdfCommun.taille(format, base);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (f.annulee) PdfCommun.filigraneAnnule(format),
        PdfCommun.enTete(tenant: tenant, format: format, logo: logo),
        pw.SizedBox(height: 6),
        pw.Text(
          'FACTURE ${f.numero}',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: t(12), fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          Formats.dateHeure(f.date),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: t(9), color: PdfCommun.gris),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Client : ${f.clientNom}',
          style: pw.TextStyle(fontSize: t(10)),
        ),
        pw.SizedBox(height: 4),
        PdfCommun.separateur(format),
        pw.SizedBox(height: 4),
        for (final l in f.lignes) ...[
          pw.Text(
            l.designation,
            style: pw.TextStyle(
              fontSize: t(10),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          PdfCommun.ligne(
            format,
            libelle:
                '${Formats.montant(l.quantite)} ${l.unite} × '
                '${Formats.montant(l.prixUnitaire)}',
            valeur: Formats.montant(l.montant),
            tailleBase: 9.5,
          ),
          pw.SizedBox(height: 2),
        ],
        PdfCommun.separateur(format),
        pw.SizedBox(height: 4),
        if (f.tauxTva > 0) ...[
          PdfCommun.ligne(
            format,
            libelle: 'Montant HT',
            valeur: Formats.montant(f.montantHT),
          ),
          PdfCommun.ligne(
            format,
            libelle: 'TVA ${Formats.pourcentage(f.tauxTva)}',
            valeur: Formats.montant(f.montantTva),
          ),
        ],
        PdfCommun.ligne(
          format,
          libelle: 'TOTAL',
          valeur: Formats.montant(f.montantTotal, devise: f.devise),
          gras: true,
          tailleBase: 12,
        ),
        if (!f.annulee) ...[
          PdfCommun.ligne(
            format,
            libelle: 'Réglé',
            valeur: Formats.montant(f.montantPaye, devise: f.devise),
          ),
          if (f.resteDu > 0)
            PdfCommun.ligne(
              format,
              libelle: 'Reste à payer',
              valeur: Formats.montant(f.resteDu, devise: f.devise),
              gras: true,
            ),
        ],
        if ((f.note ?? '').isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            f.note!,
            style: pw.TextStyle(fontSize: t(9), color: PdfCommun.gris),
          ),
        ],
        pw.SizedBox(height: 4),
        pw.Text(
          'Vendeur : ${f.creeParNom}',
          style: pw.TextStyle(fontSize: t(8), color: PdfCommun.gris),
        ),
        PdfCommun.pied(format),
      ],
    );
  }
}
