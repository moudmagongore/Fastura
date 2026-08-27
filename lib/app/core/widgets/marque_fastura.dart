import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Le nom de la marque, à la place du titre, sur les deux accueils.
///
/// **Le mot et non l'image** : `Fastura_logo_horizontal.png` est encré en
/// bleu pétrole et en vert sur fond transparent — sur la barre du thème
/// sombre, « Fast » disparaît dans le décor. Le mot, lui, prend la primaire
/// adaptative et reste lisible partout, sans image à décoder ni à cadrer.
///
/// Les deux teintes reprennent le tracé du logo : « Fast » en primaire,
/// « ura » en accent.
class MarqueFastura extends StatelessWidget {
  const MarqueFastura({super.key, this.taille = 21});

  final double taille;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: taille,
      fontWeight: FontWeight.w800,
      // Serré comme le logotype, où les lettres se touchent presque.
      letterSpacing: -0.6,
      height: 1.1,
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Fast',
            style: base.copyWith(color: AppColors.primary(context)),
          ),
          TextSpan(
            text: 'ura',
            style: base.copyWith(color: AppColors.accent(context)),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
