import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import '../../data/models/format_impression.dart';
import '../../data/models/paiement_model.dart';
import '../../data/models/tenant_model.dart';
import '../utils/format_helpers.dart';
import 'pdf_commun.dart';

/// Génère le reçu d'un règlement, au format retenu par le tenant.
///
/// Un reçu est plus court qu'une facture : le client veut la preuve du
/// montant versé et savoir ce qu'il lui reste à devoir. Le détail du
/// lettrage y figure — c'est la seule trace qu'il emporte de la répartition
/// automatique sur ses factures.
abstract class RecuPdfService {
  RecuPdfService._();

  static Future<Uint8List> construire({
    required PaiementModel paiement,
    required TenantModel tenant,

    /// Solde du client **après** ce règlement. Passé par l'appelant, qui
    /// seul connaît l'état courant de la fiche.
    double? soldeApres,
  }) async {
    final format = tenant.formatImpression;
    final logo = await PdfCommun.chargerLogo(tenant);
    final document = pw.Document(
      title: 'Reçu ${paiement.clientNom}',
      author: tenant.nom,
    );

    // Un règlement peut solder jusqu'à cinquante factures : le détail du
    // lettrage déborde alors d'une page. Une `Page` de hauteur finie le
    // rognerait sans rien dire, et le client repartirait avec un reçu dont
    // il manque des lignes.
    final elements = _elements(
      paiement: paiement,
      tenant: tenant,
      logo: logo,
      format: format,
      soldeApres: soldeApres,
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
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfCommun.format(format),
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          footer: (context) => _piedPage(paiement, format, context),
          build: (context) => elements,
        ),
      );
    }

    return document.save();
  }

  static List<pw.Widget> _elements({
    required PaiementModel paiement,
    required TenantModel tenant,
    required FormatImpression format,
    required pw.MemoryImage? logo,
    double? soldeApres,
  }) {
    final ticket = PdfCommun.estTicket(format);
    double t(double base) => PdfCommun.taille(format, base);
    final devise = tenant.devise;

    return [
      if (paiement.annule) PdfCommun.filigraneAnnule(format),
      PdfCommun.enTete(tenant: tenant, format: format, logo: logo),
      pw.SizedBox(height: ticket ? 6 : 18),

      PdfCommun.pleineLargeur(
        pw.Text(
          'REÇU DE PAIEMENT',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: t(14),
            fontWeight: pw.FontWeight.bold,
            color: PdfCommun.bleuPetrole,
          ),
        ),
      ),
      PdfCommun.pleineLargeur(
        pw.Text(
          Formats.dateLongue(paiement.date),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: t(9), color: PdfCommun.gris),
        ),
      ),
      pw.SizedBox(height: ticket ? 6 : 16),

      PdfCommun.ligne(
        format,
        libelle: 'Reçu de',
        valeur: paiement.clientNom,
        gras: true,
      ),
      PdfCommun.ligne(
        format,
        libelle: 'Mode de paiement',
        valeur: paiement.mode.label,
      ),
      if ((paiement.note ?? '').isNotEmpty)
        PdfCommun.ligne(format, libelle: 'Référence', valeur: paiement.note!),

      pw.SizedBox(height: ticket ? 6 : 12),
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
              'MONTANT VERSÉ',
              style: pw.TextStyle(
                fontSize: t(9),
                fontWeight: pw.FontWeight.bold,
                color: PdfCommun.gris,
              ),
            ),
            pw.Text(
              Formats.montant(paiement.montant, devise: devise),
              style: pw.TextStyle(
                fontSize: t(15),
                fontWeight: pw.FontWeight.bold,
                color: PdfCommun.vert,
              ),
            ),
          ],
        ),
      ),

      if (paiement.imputations.isNotEmpty) ...[
        pw.SizedBox(height: ticket ? 8 : 14),
        pw.Text(
          'Factures soldées',
          style: pw.TextStyle(
            fontSize: t(9),
            fontWeight: pw.FontWeight.bold,
            color: PdfCommun.gris,
          ),
        ),
        pw.SizedBox(height: 2),
        for (final i in paiement.imputations)
          PdfCommun.ligne(
            format,
            libelle: i.factureNumero,
            valeur: Formats.montant(i.montant),
            tailleBase: 9.5,
          ),
      ],

      if (paiement.montantEnAvance > 0) ...[
        pw.SizedBox(height: 4),
        PdfCommun.ligne(
          format,
          libelle: 'Avance conservée',
          valeur: Formats.montant(paiement.montantEnAvance, devise: devise),
          couleur: PdfCommun.vert,
        ),
      ],

      if (soldeApres != null) ...[
        pw.SizedBox(height: ticket ? 6 : 12),
        PdfCommun.separateur(format),
        pw.SizedBox(height: 4),
        PdfCommun.ligne(
          format,
          libelle: soldeApres > 0
              ? 'Reste dû après ce versement'
              : (soldeApres < 0 ? 'Avance disponible' : 'Compte soldé'),
          valeur: Formats.montant(soldeApres.abs(), devise: devise),
          gras: true,
          couleur: soldeApres > 0 ? PdfCommun.rouge : PdfCommun.vert,
          tailleBase: 11,
        ),
      ],

      // Hors ticket, l'encaisseur passe en pied de page : il doit figurer
      // sur chaque feuille, pas seulement sous la dernière ligne.
      if (ticket) ...[
        pw.SizedBox(height: 8),
        pw.Text(
          'Encaissé par ${paiement.creeParNom}',
          style: pw.TextStyle(fontSize: t(8), color: PdfCommun.gris),
        ),
      ],
      PdfCommun.pied(format),
    ];
  }

  static pw.Widget _piedPage(
    PaiementModel paiement,
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
          pw.Text('Encaissé par ${paiement.creeParNom}', style: style),
          pw.Text(
            'Page ${context.pageNumber}/${context.pagesCount}',
            style: style,
          ),
        ],
      ),
    );
  }
}
