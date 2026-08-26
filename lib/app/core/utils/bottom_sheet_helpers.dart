import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Hauteur maximale des feuilles à liste (`DraggableScrollableSheet`), en
/// fraction de l'espace offert par la route — clavier déjà déduit. On laisse
/// volontairement de la marge en haut : l'utilisateur doit continuer à voir
/// d'où il vient.
///
/// Les feuilles de saisie, dont la hauteur suit le contenu, passent par
/// [hauteurMaxSheet].
const double kBottomSheetMaxHeightRatio = 0.85;

/// Padding bas d'un sheet contenant un champ de saisie.
///
/// **Le clavier n'entre pas dans ce padding.** La route de Get enveloppe déjà
/// la feuille dans un `Padding(bottom: viewInsets.bottom)` — contrairement au
/// `showModalBottomSheet` de Flutter, où l'application doit s'en charger. Le
/// réserver ici le compterait deux fois : la feuille grandissait de toute la
/// hauteur du clavier et débordait par le haut de l'écran.
///
/// Reste la barre de gestes, qui n'a plus lieu d'être réservée quand le
/// clavier la recouvre.
double paddingBasSheet(BuildContext context, {double extra = 20}) {
  final mq = MediaQuery.of(context);
  if (mq.viewInsets.bottom > 0) return extra;
  return mq.viewPadding.bottom + extra;
}

/// Hauteur de la barre d'état, lue sur la vue et non sur le `MediaQuery`.
///
/// La route d'un sheet retire le padding haut du `MediaQuery` (la feuille est
/// collée en bas, elle n'est censée jamais approcher l'encoche) : à
/// l'intérieur, `viewPadding.top` vaut 0. Seule la vue sait encore.
double _hauteurBarreEtat(BuildContext context) {
  final vue = View.of(context);
  return vue.viewPadding.top / vue.devicePixelRatio;
}

/// Marge laissée entre le haut d'un sheet et la barre d'état.
///
/// Un sheet qui touche le haut de l'écran ne se lit plus comme un sheet : on
/// ne voit plus d'où l'on vient, et le geste de fermeture devient le seul
/// repère.
const double kMargeHautSheet = 32;

/// Hauteur maximale d'un sheet de saisie.
///
/// L'espace réellement offert par la route est l'écran moins le clavier ; on
/// en retire encore la barre d'état et [kMargeHautSheet] pour que la feuille
/// s'arrête franchement en dessous.
double hauteurMaxSheet(BuildContext context) {
  final mq = MediaQuery.of(context);
  final disponible = mq.size.height - mq.viewInsets.bottom;
  final plafond = disponible - _hauteurBarreEtat(context) - kMargeHautSheet;
  // Écran minuscule ou clavier démesuré : mieux vaut une feuille haute
  // qu'une feuille vide.
  return plafond > disponible / 2 ? plafond : disponible / 2;
}

/// Cadre commun des sheets de saisie : fond arrondi, hauteur plafonnée sous
/// la barre d'état, contenu défilable.
///
/// C'est le plafond qui compte : sans lui, une feuille dimensionnée sur son
/// contenu monte jusqu'en haut de l'écran dès que le clavier s'ouvre. Ici
/// elle s'arrête sous la barre d'état et c'est le défilement qui absorbe le
/// reste.
class CadreSheet extends StatelessWidget {
  const CadreSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 0),
  });

  /// Contenu du sheet. Une `Column` en `MainAxisSize.min` : c'est le cadre
  /// qui fournit le défilement.
  final Widget child;

  /// Marges intérieures. Le bas est ajouté par le cadre — clavier ouvert ou
  /// barre de gestes sinon.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: hauteurMaxSheet(context)),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          padding: padding + EdgeInsets.only(bottom: paddingBasSheet(context)),
          child: child,
        ),
      ),
    );
  }
}

/// La poignée grise en haut d'un sheet.
class PoigneeSheet extends StatelessWidget {
  const PoigneeSheet({
    super.key,
    this.marge = const EdgeInsets.only(bottom: 16),
  });

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
                    color:
                        couleurSousTitre ??
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
