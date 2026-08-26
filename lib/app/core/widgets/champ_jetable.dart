import 'package:flutter/material.dart';

/// Porte un [TextEditingController] le temps d'une boîte de dialogue ou d'une
/// feuille, et le détruit avec le widget.
///
/// Disposer le contrôleur juste après `await Get.dialog(...)` paraît naturel
/// mais casse : `Get.back()` résout le future immédiatement, alors que la
/// route continue de se construire pendant son animation de fermeture. Le
/// `TextField` retombe alors sur un contrôleur détruit — « A
/// TextEditingController was used after being disposed ». Le laisser vivre
/// dans l'arbre est la seule façon d'en libérer au bon moment.
class ChampJetable extends StatefulWidget {
  const ChampJetable({
    super.key,
    required this.builder,
    this.texteInitial = '',
  });

  final Widget Function(BuildContext context, TextEditingController ctrl)
  builder;

  /// Contenu initial du champ.
  final String texteInitial;

  @override
  State<ChampJetable> createState() => _ChampJetableState();
}

class _ChampJetableState extends State<ChampJetable> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.texteInitial,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _ctrl);
}
