import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:printing/printing.dart';

import '../../theme/app_colors.dart';

/// Aperçu plein écran d'un document avant tirage.
///
/// Le document se regarde avant de partir sur le papier : un reçu de
/// comptoir se relit d'un coup d'œil, et une facture mal cadrée se voit ici
/// plutôt qu'après trois feuilles gâchées.
///
/// Fond blanc imposé, thème sombre compris : c'est du papier qu'on regarde,
/// et un aperçu sur fond noir ne dit rien de ce qui sortira de l'imprimante.
class ApercuPdf extends StatelessWidget {
  const ApercuPdf({
    super.key,
    required this.document,
    required this.nomFichier,
    required this.titre,
  });

  final Uint8List document;
  final String nomFichier;
  final String titre;

  /// Résolution de rastérisation de l'aperçu.
  ///
  /// Compromis assumé : un ticket 80 mm gagnerait à monter plus haut, mais
  /// la même valeur s'applique à l'A4, où chaque page coûte environ
  /// `largeur × hauteur × dpi²` octets en mémoire — de quoi faire tomber un
  /// téléphone modeste sur un récapitulatif de dépenses un peu long.
  static const double _dpi = 200;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.brandPrimary,
        surfaceTintColor: Colors.white,
        iconTheme: const IconThemeData(color: AppColors.brandPrimary),
        title: Text(
          titre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.brandPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: PdfPreview(
        build: (_) async => document,
        pdfFileName: '$nomFichier.pdf',
        // Le format est arrêté par l'entreprise dans ses paramètres (A4, A5
        // ou ticket) : il ne se rediscute pas au moment du tirage.
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        dpi: _dpi,
        // La barre d'actions du paquet est désactivée : elle porte sa propre
        // élévation Material, qui jure avec des écrans sans ombre. Les deux
        // actions vivent en bas, sous notre contrôle.
        allowPrinting: false,
        allowSharing: false,
        useActions: false,
        scrollViewDecoration: const BoxDecoration(color: Colors.white),
        previewPageMargin: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        pdfPreviewPageDecoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              offset: const Offset(0, 1),
              blurRadius: 6,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Printing.sharePdf(
                      bytes: document,
                      filename: '$nomFichier.pdf',
                    ),
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Partager'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Printing.layoutPdf(
                      onLayout: (_) async => document,
                      name: nomFichier,
                    ),
                    icon: const Icon(Icons.print_rounded, size: 19),
                    label: const Text('Imprimer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Ouvre l'aperçu par-dessus l'écran courant.
  static Future<void> ouvrir({
    required Uint8List document,
    required String nomFichier,
    required String titre,
  }) {
    return Get.to<void>(
          () => ApercuPdf(
            document: document,
            nomFichier: nomFichier,
            titre: titre,
          ),
          routeName: '/apercu-pdf',
          fullscreenDialog: true,
        ) ??
        Future<void>.value();
  }
}
