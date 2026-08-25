import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/app_colors.dart';

/// Confirmation modale. Retourne `true` si l'utilisateur confirme.
///
/// À utiliser systématiquement pour les actions difficiles à revenir en
/// arrière : déconnexion, désactivation, et plus tard annulation d'une
/// facture, d'un paiement ou d'une dépense.
Future<bool> confirmer({
  required String titre,
  required String message,
  String libelleConfirmer = 'Confirmer',
  String libelleAnnuler = 'Annuler',
  bool destructif = false,
}) async {
  final resultat = await Get.dialog<bool>(
    AlertDialog(
      title: Text(titre),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: Text(libelleAnnuler),
        ),
        TextButton(
          onPressed: () => Get.back(result: true),
          style: TextButton.styleFrom(
            foregroundColor: destructif ? AppColors.danger : null,
          ),
          child: Text(libelleConfirmer),
        ),
      ],
    ),
  );
  return resultat ?? false;
}
