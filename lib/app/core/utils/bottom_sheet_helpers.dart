import 'dart:io' show Platform;

import 'package:flutter/material.dart';

/// Hauteur maximale d'un bottom sheet, en fraction de l'écran.
///
/// On laisse volontairement de la marge en haut : l'utilisateur doit
/// continuer à voir d'où il vient, et le sheet ne doit pas déborder quand le
/// clavier s'ouvre.
const double kBottomSheetMaxHeightRatio = 0.85;

/// `SafeArea(top: false)` appliqué **uniquement sur Android**.
///
/// Sur Android la barre de gestes masque le bas du contenu sans padding ; sur
/// iOS le moteur de bottom sheet gère déjà le home-indicator, et l'ajouter y
/// créerait une double marge.
Widget androidOnlySafeArea(Widget child) {
  if (Platform.isAndroid) {
    return SafeArea(top: false, child: child);
  }
  return child;
}

/// Padding bas d'un sheet contenant un champ de saisie.
///
/// Prend le clavier quand il est ouvert, la barre de gestes sinon : sans ça,
/// le bouton de validation se retrouve sous le clavier.
double paddingBasSheet(BuildContext context, {double extra = 20}) {
  final mq = MediaQuery.of(context);
  final clavier = mq.viewInsets.bottom;
  return (clavier > 0 ? clavier : mq.viewPadding.bottom) + extra;
}

/// Hauteur maximale disponible, clavier déduit.
double hauteurMaxSheet(BuildContext context) {
  final mq = MediaQuery.of(context);
  return (mq.size.height - mq.viewInsets.bottom) * kBottomSheetMaxHeightRatio;
}

/// La poignée grise en haut d'un sheet.
class PoigneeSheet extends StatelessWidget {
  const PoigneeSheet({super.key, this.marge = const EdgeInsets.only(bottom: 16)});

  final EdgeInsets marge;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        margin: marge,
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// En-tête de sheet : pastille colorée, titre, sous-titre, bouton fermer.
class EnteteSheet extends StatelessWidget {
  const EnteteSheet({
    super.key,
    required this.icone,
    required this.titre,
    required this.couleur,
    this.sousTitre,
    this.couleurSousTitre,
  });

  final IconData icone;
  final String titre;
  final Color couleur;
  final String? sousTitre;
  final Color? couleurSousTitre;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icone, color: couleur),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                titre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (sousTitre != null)
                Text(
                  sousTitre!,
                  style: TextStyle(
                    fontSize: 12,
                    color: couleurSousTitre ??
                        Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}
