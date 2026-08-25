import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import '../../data/models/depense_model.dart';
import '../../data/models/format_impression.dart';
import '../../data/models/tenant_model.dart';
import '../utils/format_helpers.dart';
import 'pdf_commun.dart';

/// Récapitulatif des dépenses d'une période (CDC §7).
///
/// Deux lectures dans le même document : la **répartition par nature**, qui
/// dit où part l'argent, puis le **détail daté**, qui permet de retrouver une
/// écriture. L'une sans l'autre ne suffit pas — un total par rubrique ne se
/// vérifie pas, une liste de cinquante lignes ne se lit pas.
abstract class DepensesPdfService {
  DepensesPdfService._();

  static Future<Uint8List> construire({
    required TenantModel tenant,
    required List<DepenseModel> depenses,
    required List<TotalNature> repartition,
    required DateTime debut,
    required DateTime fin,
    required double total,
  }) async {
    final format = tenant.formatImpression;
    final logo = await PdfCommun.chargerLogo(tenant);
    final document = pw.Document(
      title: 'Dépenses ${Formats.date(debut)} - ${Formats.date(fin)}',
      author: tenant.nom,
    );

    final elements = _elements(
      tenant: tenant,
      depenses: depenses,
      repartition: repartition,
      debut: debut,
      fin: fin,
      total: total,
      logo: logo,
      format: format,
    );

    if (PdfCommun.estTicket(format)) {
      document.addPage(
        pw.Page(
          pageFormat: PdfCommun.format(format),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: elements,
          ),
        ),
      );
    } else {
      // Un récapitulatif tient rarement sur une page : c'est le document du
      // lot qui déborde le plus naturellement.
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfCommun.format(format),
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          footer: (context) => _piedPage(format, context),
          build: (context) => elements,
        ),
      );
    }

    return document.save();
  }

  static List<pw.Widget> _elements({
    required TenantModel tenant,
    required List<DepenseModel> depenses,
    required List<TotalNature> repartition,
    required DateTime debut,
    required DateTime fin,
    required double total,
    required pw.MemoryImage? logo,
    required FormatImpression format,
  }) {
    final ticket = PdfCommun.estTicket(format);
    double t(double base) => PdfCommun.taille(format, base);
    final devise = tenant.devise;

    return [
      PdfCommun.enTete(tenant: tenant, format: format, logo: logo),
      pw.SizedBox(height: ticket ? 6 : 18),

      PdfCommun.pleineLargeur(
        pw.Text(
          'RÉCAPITULATIF DES DÉPENSES',
          textAlign: ticket ? pw.TextAlign.center : pw.TextAlign.left,
          style: pw.TextStyle(
            fontSize: t(14),
            fontWeight: pw.FontWeight.bold,
            color: PdfCommun.bleuPetrole,
          ),
        ),
      ),
      PdfCommun.pleineLargeur(
        pw.Text(
          'Du ${Formats.date(debut)} au ${Formats.date(fin)}',
          textAlign: ticket ? pw.TextAlign.center : pw.TextAlign.left,
          style: pw.TextStyle(fontSize: t(9.5), color: PdfCommun.gris),
        ),
      ),
      pw.SizedBox(height: ticket ? 6 : 14),

      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: pw.BoxDecoration(
          color: PdfCommun.grisClair,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'TOTAL DES DÉPENSES',
              style: pw.TextStyle(
                fontSize: t(9),
                fontWeight: pw.FontWeight.bold,
                color: PdfCommun.gris,
              ),
            ),
            pw.Text(
              Formats.montant(total, devise: devise),
              style: pw.TextStyle(
                fontSize: t(15),
                fontWeight: pw.FontWeight.bold,
                color: PdfCommun.rouge,
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: ticket ? 8 : 16),

      // ---- Répartition par nature ----
      pw.Text(
        'Par nature',
        style: pw.TextStyle(
          fontSize: t(10),
          fontWeight: pw.FontWeight.bold,
          color: PdfCommun.bleuPetrole,
        ),
      ),
      pw.SizedBox(height: 4),
      for (final r in repartition)
        PdfCommun.ligne(
          format,
          libelle: '${r.libelle}  (${r.nombre})',
          valeur: Formats.montant(r.montant, devise: devise),
          tailleBase: 9.5,
        ),

      pw.SizedBox(height: ticket ? 8 : 16),
      PdfCommun.separateur(format),
      pw.SizedBox(height: ticket ? 4 : 10),

      // ---- Détail ----
      pw.Text(
        'Détail (${depenses.length})',
        style: pw.TextStyle(
          fontSize: t(10),
          fontWeight: pw.FontWeight.bold,
          color: PdfCommun.bleuPetrole,
        ),
      ),
      pw.SizedBox(height: 4),
      if (ticket)
        for (final d in depenses) ...[
          pw.Text(
            '${Formats.date(d.date)}  ${d.natureLibelle}',
            style: pw.TextStyle(fontSize: t(9.5)),
          ),
          PdfCommun.ligne(
            format,
            libelle: d.description ?? '',
            valeur: Formats.montant(d.montant),
            tailleBase: 9.5,
          ),
          pw.SizedBox(height: 2),
        ]
      else
        _tableauDetail(depenses, format),
    ];
  }

  static pw.Widget _tableauDetail(
    List<DepenseModel> depenses,
    FormatImpression format,
  ) {
    double t(double base) => PdfCommun.taille(format, base);

    final enTeteStyle = pw.TextStyle(
      fontSize: t(9),
      fontWeight: pw.FontWeight.bold,
      color: PdfCommun.gris,
    );
    final celluleStyle = pw.TextStyle(fontSize: t(9.5));

    pw.Widget cellule(
      String texte,
      pw.TextStyle style, {
      pw.TextAlign alignement = pw.TextAlign.left,
    }) {
      return pw.Padding(
        padding: pw.EdgeInsets.symmetric(
          vertical: PdfCommun.taille(format, 5),
          horizontal: PdfCommun.taille(format, 6),
        ),
        child: pw.Text(texte, style: style, textAlign: alignement),
      );
    }

    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(1.6),
        1: const pw.FlexColumnWidth(2.4),
        2: const pw.FlexColumnWidth(3.4),
        3: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: PdfCommun.grisClair),
          children: [
            cellule('Date', enTeteStyle),
            cellule('Nature', enTeteStyle),
            cellule('Description', enTeteStyle),
            cellule('Montant', enTeteStyle, alignement: pw.TextAlign.right),
          ],
        ),
        for (final d in depenses)
          pw.TableRow(
            children: [
              cellule(Formats.date(d.date), celluleStyle),
              cellule(d.natureLibelle, celluleStyle),
              cellule(d.description ?? '', celluleStyle),
              cellule(
                Formats.montant(d.montant),
                celluleStyle.copyWith(fontWeight: pw.FontWeight.bold),
                alignement: pw.TextAlign.right,
              ),
            ],
          ),
      ],
    );
  }

  static pw.Widget _piedPage(FormatImpression format, pw.Context context) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6),
      child: PdfCommun.pleineLargeur(
        pw.Text(
          'Page ${context.pageNumber}/${context.pagesCount}',
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(
            fontSize: PdfCommun.taille(format, 8),
            color: PdfCommun.gris,
          ),
        ),
      ),
    );
  }
}
