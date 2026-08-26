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
    CadreSheet(
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
  _poserVoile();
  try {
    final document = await generer();
    _retirerVoile();
    await imprimerOuPartager(
      document: document,
      nomFichier: nomFichier,
      titre: titre,
    );
  } catch (e) {
    _retirerVoile();
    Get.snackbar(
      'Impression impossible',
      '$e',
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 5),
    );
  } finally {
    // Filet : le voile ne doit survivre à aucun chemin de sortie.
    _retirerVoile();
  }
}

/// Voile d'attente de la génération du PDF.
///
/// Posé dans l'**overlay** et non dans la pile de routes : `Get.dialog` se
/// referme par `Get.back()`, qui dépile *la route du dessus* — pas forcément
/// la sienne. Juste après l'émission d'une facture, le snackbar « Facture
/// FA-… émise » est encore à l'écran et `Get.isDialogOpen` répond faux : le
/// voile n'était alors jamais retiré. La feuille d'impression s'ouvrait
/// par-dessus, et la refermer laissait l'écran bloqué derrière une barrière
/// non renvoyable.
OverlayEntry? _voile;

void _poserVoile() {
  // `Get.overlayContext` est le contexte de l'overlay lui-même : y appeler
  // `Overlay.of` cherche un overlay *au-dessus* et ne trouve rien. On passe
  // donc par le navigateur racine de GetMaterialApp.
  final overlay = Get.key.currentState?.overlay;
  if (_voile != null || overlay == null) return;

  final entree = OverlayEntry(
    builder: (_) => const Stack(
      children: [
        // `ModalBarrier` et non un simple fond coloré : il faut absorber les
        // appuis, sinon on peut relancer le tirage pendant qu'il tourne.
        ModalBarrier(dismissible: false, color: Colors.black38),
        Center(child: CircularProgressIndicator()),
      ],
    ),
  );
  _voile = entree;
  overlay.insert(entree);
}

void _retirerVoile() {
  _voile?.remove();
  _voile = null;
}
