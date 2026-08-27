import 'dart:async';

import 'package:flutter/widgets.dart';

/// Neutralise les appuis sur le contenu du tiroir pendant son ouverture
/// (246 ms côté framework).
///
/// Pendant le glissement, `DrawerController` place le tiroir dans un
/// `Align(widthFactor: animation.value)` aligné sur son bord droit : seule la
/// bande déjà visible reçoit les appuis, mais elle les reçoit *entièrement*,
/// et elle affiche la partie droite du tiroir collée au bord gauche de
/// l'écran. Un appui qui arrive à cet instant en haut à gauche — exactement
/// là où se trouve le bouton qui vient d'ouvrir le tiroir — atterrit donc sur
/// le contenu et peut activer une entrée que personne n'a visée.
///
/// Le symptôme se voit surtout sur tablette (écran plus grand, animation
/// perçue plus lente, double appui sur le bouton fréquent).
///
/// Le sous-arbre du tiroir est reconstruit à chaque ouverture — il est retiré
/// dès que l'animation retombe à zéro — donc `initState`, et le minuteur avec
/// lui, repartent bien à chaque fois.
///
/// Repris de gongore_App, où le cas s'est produit en clientèle.
class DrawerOpenGuard extends StatefulWidget {
  const DrawerOpenGuard({super.key, required this.child});

  final Widget child;

  @override
  State<DrawerOpenGuard> createState() => _DrawerOpenGuardState();
}

class _DrawerOpenGuardState extends State<DrawerOpenGuard> {
  /// Marge au-dessus des 246 ms de l'animation d'ouverture.
  static const _duree = Duration(milliseconds: 320);

  bool _ignore = true;
  Timer? _minuteur;

  @override
  void initState() {
    super.initState();
    _minuteur = Timer(_duree, () {
      if (mounted) setState(() => _ignore = false);
    });
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `AbsorbPointer` et non `IgnorePointer` : l'appui parasite doit être
    // consommé, sinon il traverse jusqu'au voile qui referme le tiroir.
    return AbsorbPointer(absorbing: _ignore, child: widget.child);
  }
}
