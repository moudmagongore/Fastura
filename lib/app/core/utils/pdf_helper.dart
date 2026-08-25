import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:printing/printing.dart';

import '../../theme/app_colors.dart';
import 'bottom_sheet_helpers.dart';

/// Propose d'imprimer ou de partager un document déjà généré.
///
/// Les deux usages coexistent sur le terrain : l'imprimante quand elle est
/// là, le partage WhatsApp quand elle ne l'est pas — c'est souvent ainsi que
/// la facture parvient au client.
Future<void> imprimerOuPartager({
  required Uint8List document,
  required String nomFichier,
  required String titre,
}) async {
  await Get.bottomSheet<void>(
    Builder(
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, paddingBasSheet(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PoigneeSheet(),
            EnteteSheet(
              icone: Icons.print_rounded,
              couleur: AppColors.brandPrimary,
              titre: titre,
              sousTitre: 'Imprimer ou envoyer au client',
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () async {
                Get.back();
                await Printing.layoutPdf(
                  onLayout: (_) async => document,
                  name: nomFichier,
                );
              },
              icon: const Icon(Icons.print_rounded),
              label: const Text('Imprimer'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                Get.back();
                await Printing.sharePdf(
                  bytes: document,
                  filename: '$nomFichier.pdf',
                );
              },
              icon: const Icon(Icons.share_outlined),
              label: const Text('Partager le PDF'),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    ),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
}

/// Exécute [generer] en affichant un voile d'attente, puis propose
/// l'impression. Toute erreur est remontée telle quelle : un tirage qui
/// échoue en silence laisse l'utilisateur attendre un papier qui ne vient
/// pas.
Future<void> genererPuisImprimer({
  required Future<Uint8List> Function() generer,
  required String nomFichier,
  required String titre,
}) async {
  Get.dialog(
    const Center(child: CircularProgressIndicator()),
    barrierDismissible: false,
  );
  try {
    final document = await generer();
    if (Get.isDialogOpen ?? false) Get.back();
    await imprimerOuPartager(
      document: document,
      nomFichier: nomFichier,
      titre: titre,
    );
  } catch (e) {
    if (Get.isDialogOpen ?? false) Get.back();
    Get.snackbar(
      'Impression impossible',
      '$e',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 5),
    );
  }
}
