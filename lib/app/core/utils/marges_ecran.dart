import 'package:flutter/material.dart';

/// Marge à réserver au dernier élément d'un contenu défilant : barre
/// d'accueil sur iOS, barre de gestes sur Android.
///
/// À ajouter au padding de la liste plutôt qu'à entourer l'écran d'un
/// `SafeArea` : le fond et le contenu qui défile doivent filer jusqu'au bord
/// de l'écran. Un `SafeArea` bas rétrécit le viewport, et il reste une bande
/// morte en permanence sous la liste — 34 points sur iPhone, sur chaque
/// écran. Seul le contenu **au repos** s'arrête au-dessus de la barre.
///
/// `paddingOf` et non `viewPaddingOf` : clavier ouvert, la barre d'accueil est
/// déjà recouverte et n'a plus à être réservée.
double margeBasse(BuildContext context) => MediaQuery.paddingOf(context).bottom;
