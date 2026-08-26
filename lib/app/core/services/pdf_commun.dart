import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../constants/app_constants.dart';
import '../../data/models/format_impression.dart';
import '../../data/models/tenant_model.dart';

/// Briques partagées par les documents imprimés : format de page, palette,
/// en-tête d'entreprise, pied de page.
///
/// Les polices intégrées (Helvetica) suffisent : leur encodage WinAnsi
/// couvre tous les accents français. Embarquer une police TTF alourdirait
/// l'application et l'obligerait à la télécharger au premier tirage.
abstract class PdfCommun {
  PdfCommun._();

  static const PdfColor bleuPetrole = PdfColor.fromInt(0xFF1F4E5F);
  static const PdfColor vert = PdfColor.fromInt(0xFF2E7D6E);
  static const PdfColor gris = PdfColor.fromInt(0xFF6B7785);
  static const PdfColor grisClair = PdfColor.fromInt(0xFFF0F3F5);
  static const PdfColor rouge = PdfColor.fromInt(0xFFC0392B);

  /// Largeur de rouleau du format ticket.
  static const double largeurTicket =
      FormatImpression.ticketLargeurMm * PdfPageFormat.mm;

  /// Format de page correspondant au réglage du tenant.
  ///
  /// Le ticket a une hauteur **infinie** : le moteur PDF découpe alors la
  /// page à la hauteur réelle du contenu, ce qu'attend une imprimante
  /// thermique à rouleau continu. Lui imposer une hauteur fixe ferait
  /// avancer du papier vierge après chaque reçu.
  static PdfPageFormat format(FormatImpression f) {
    return switch (f) {
      FormatImpression.a4 => PdfPageFormat.a4.copyWith(
        marginLeft: 32,
        marginRight: 32,
        marginTop: 32,
        marginBottom: 32,
      ),
      FormatImpression.a5 => PdfPageFormat.a5.copyWith(
        marginLeft: 22,
        marginRight: 22,
        marginTop: 22,
        marginBottom: 22,
      ),
      FormatImpression.ticket => PdfPageFormat(
        largeurTicket,
        double.infinity,
        marginLeft: 6,
        marginRight: 6,
        marginTop: 8,
        marginBottom: 8,
      ),
    };
  }

  static bool estTicket(FormatImpression f) => f == FormatImpression.ticket;

  /// Étend un widget à toute la largeur utile.
  ///
  /// `MultiPage` ne contraint pas la largeur de ses enfants : un `Text`
  /// centré s'y ajuste à sa propre ligne et retombe donc à gauche. Le
  /// centrage n'a de sens que sur une boîte pleine largeur.
  static pw.Widget pleineLargeur(pw.Widget enfant) =>
      pw.SizedBox(width: double.infinity, child: enfant);

  /// Échelle typographique. Elle suit la largeur utile de la page, pas le
  /// goût : garder les tailles de l'A4 sur un A5 deux fois plus étroit
  /// déborderait le tableau des lignes.
  static double taille(FormatImpression f, double base) {
    return switch (f) {
      FormatImpression.ticket => base * 0.82,
      FormatImpression.a5 => base * 0.88,
      FormatImpression.a4 => base,
    };
  }

  /// Largeur du bloc des totaux, à droite de la note. Une valeur fixe
  /// mangerait la moitié d'un A5 ; elle est donnée en part de la largeur
  /// utile de la page.
  static double largeurBlocTotaux(FormatImpression f) {
    return switch (f) {
      FormatImpression.a5 => 150,
      _ => 200,
    };
  }

  /// Charge le logo du tenant. Renvoie `null` si absent ou inaccessible :
  /// une facture doit sortir même quand le réseau flanche au moment du
  /// tirage.
  static Future<pw.MemoryImage?> chargerLogo(TenantModel tenant) async {
    final url = tenant.logoUrl;
    if (url == null || url.isEmpty) return null;
    try {
      return await networkImage(url) as pw.MemoryImage?;
    } catch (e) {
      debugPrint('Logo indisponible pour l\'impression : $e');
      return null;
    }
  }

  /// En-tête : logo et adresse du tenant, exigés par le CDC §6.
  ///
  /// Sans logo, le nom de l'entreprise le remplace en gros — un en-tête vide
  /// ferait une facture anonyme.
  static pw.Widget enTete({
    required TenantModel tenant,
    required FormatImpression format,
    pw.MemoryImage? logo,
  }) {
    final ticket = estTicket(format);
    double t(double base) => taille(format, base);

    final identite = pw.Column(
      crossAxisAlignment: ticket
          ? pw.CrossAxisAlignment.center
          : pw.CrossAxisAlignment.start,
      children: [
        if (logo != null)
          pw.Container(
            height: ticket ? 34 : t(46),
            margin: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),
        pw.Text(
          tenant.nom,
          textAlign: ticket ? pw.TextAlign.center : pw.TextAlign.left,
          style: pw.TextStyle(
            fontSize: t(logo != null ? 12 : 17),
            fontWeight: pw.FontWeight.bold,
            color: bleuPetrole,
          ),
        ),
        if ((tenant.adresse ?? '').isNotEmpty)
          pw.Text(
            tenant.adresse!,
            textAlign: ticket ? pw.TextAlign.center : pw.TextAlign.left,
            style: pw.TextStyle(fontSize: t(9), color: gris),
          ),
        if ((tenant.telephone ?? '').isNotEmpty)
          pw.Text(
            'Tél. ${tenant.telephone}',
            textAlign: ticket ? pw.TextAlign.center : pw.TextAlign.left,
            style: pw.TextStyle(fontSize: t(9), color: gris),
          ),
        if ((tenant.email ?? '').isNotEmpty)
          pw.Text(
            tenant.email!,
            textAlign: ticket ? pw.TextAlign.center : pw.TextAlign.left,
            style: pw.TextStyle(fontSize: t(9), color: gris),
          ),
      ],
    );

    if (ticket) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [identite, pw.SizedBox(height: 6), separateur(format)],
      );
    }
    return identite;
  }

  /// Filet de séparation. En ticket, des tirets : le rendu thermique noie
  /// les traits fins d'un point de haut.
  static pw.Widget separateur(FormatImpression format) {
    if (estTicket(format)) {
      // Nombre de tirets déduit de la largeur utile du rouleau : un compte
      // fixe laisse le filet arrêté au milieu de la page. Le tiret occupe
      // 333/1000 de cadratin en Helvetica.
      final corps = taille(format, 8);
      final tirets = ((largeurTicket - 12) / (corps * 0.333)).floor();
      return pw.Text(
        '-' * tirets,
        maxLines: 1,
        style: pw.TextStyle(fontSize: corps, color: gris),
      );
    }
    return pw.Divider(color: grisClair, thickness: 1);
  }

  /// Ligne « libellé / valeur » alignée aux extrémités.
  static pw.Widget ligne(
    FormatImpression format, {
    required String libelle,
    required String valeur,
    bool gras = false,
    PdfColor? couleur,
    double tailleBase = 10,
  }) {
    final style = pw.TextStyle(
      fontSize: taille(format, gras ? tailleBase + 1 : tailleBase),
      fontWeight: gras ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: couleur ?? (gras ? PdfColors.black : gris),
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(child: pw.Text(libelle, style: style)),
          pw.SizedBox(width: 8),
          pw.Text(valeur, style: style),
        ],
      ),
    );
  }

  /// Bandeau diagonal des documents annulés.
  ///
  /// Une pièce annulée peut avoir été imprimée avant de l'être : la marquer
  /// visiblement évite qu'une copie continue de circuler comme valide.
  static pw.Widget filigraneAnnule(FormatImpression format) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      margin: const pw.EdgeInsets.only(bottom: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: rouge, width: 1),
      ),
      child: pw.Text(
        'DOCUMENT ANNULÉ',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: taille(format, 12),
          fontWeight: pw.FontWeight.bold,
          color: rouge,
        ),
      ),
    );
  }

  /// Pied de page. Les mentions légales additionnelles restent un point
  /// ouvert du cahier des charges (§9) : la place est prête.
  ///
  /// [signature] ajoute les coordonnées de l'éditeur — voir
  /// [signatureEditeur].
  static pw.Widget pied(
    FormatImpression format, {
    String? mentions,
    bool signature = false,
  }) {
    final ticket = estTicket(format);
    return pw.Column(
      // Étiré et non centré : un `Text` centré dans une colonne ajustée à
      // son contenu reste collé à gauche, son `textAlign` n'ayant aucune
      // largeur excédentaire sur laquelle jouer.
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SizedBox(height: ticket ? 8 : 16),
        if (mentions != null && mentions.isNotEmpty)
          pw.Text(
            mentions,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: taille(format, 8), color: gris),
          ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Merci de votre confiance',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: taille(format, 9),
            color: gris,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
        if (signature) signatureEditeur(format),
      ],
    );
  }

  /// Signature de l'éditeur, en tout petit sous le pied.
  ///
  /// Sur le reçu et pas sur la facture : la facture est la pièce commerciale
  /// de l'entreprise, elle ne porte que son en-tête à elle. Le reçu est le
  /// papier que le client emporte, et c'est là qu'un numéro de support a une
  /// chance de servir.
  static pw.Widget signatureEditeur(FormatImpression format) {
    final petit = taille(format, 7);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SizedBox(height: 6),
        pw.Text(
          '${AppConstants.appName} · ${AppConstants.contactEmail}',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: petit, color: gris),
        ),
        pw.Text(
          AppConstants.contactTelephones.join('  ·  '),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: petit, color: gris),
        ),
      ],
    );
  }
}
