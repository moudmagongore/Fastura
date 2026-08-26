import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/bottom_sheet_helpers.dart';
import '../../../core/utils/format_helpers.dart';
import '../../../core/utils/marges_ecran.dart';
import '../../../data/models/article_model.dart';
import '../../../data/models/client_model.dart';
import '../../../theme/app_colors.dart';

/// Feuille de sélection d'un client, avec recherche.
///
/// Une feuille plutôt qu'un `DropdownButton` : au-delà d'une dizaine de
/// clients, un menu déroulant devient impraticable au comptoir.
Future<ClientModel?> choisirClient(
  List<ClientModel> clients, {
  ClientModel? selection,
  Future<ClientModel?> Function()? creer,
}) {
  return Get.bottomSheet<ClientModel>(
    _FeuilleRecherche<ClientModel>(
      titre: 'Choisir un client',
      indice: 'Rechercher par nom ou téléphone…',
      elements: clients,
      creer: creer,
      libelleCreer: 'Nouveau',
      iconeCreer: Icons.person_add_alt_1_rounded,
      filtre: (c, q) =>
          c.nom.toLowerCase().contains(q) || (c.telephone ?? '').contains(q),
      construire: (context, c) => ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary(context).withValues(alpha: 0.15),
          child: c.estDivers
              ? Icon(
                  Icons.storefront_outlined,
                  size: 20,
                  color: AppColors.primary(context),
                )
              : Text(
                  c.initiales,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary(context),
                  ),
                ),
        ),
        title: Text(c.nom),
        subtitle: c.solde > 0
            ? Text(
                'Doit ${Formats.montant(c.solde)}',
                style: const TextStyle(color: AppColors.warning),
              )
            : (c.telephone ?? '').isEmpty
            ? null
            : Text(c.telephone!),
        trailing: selection?.id == c.id
            ? Icon(Icons.check, color: AppColors.accent(context))
            : null,
        onTap: () => Get.back(result: c),
      ),
    ),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
}

/// Feuille de sélection d'un article, avec recherche par désignation.
Future<ArticleModel?> choisirArticle(
  List<ArticleModel> articles, {
  required String devise,
}) {
  return Get.bottomSheet<ArticleModel>(
    _FeuilleRecherche<ArticleModel>(
      titre: 'Ajouter un article',
      indice: 'Rechercher un article…',
      elements: articles,
      filtre: (a, q) => a.designation.toLowerCase().contains(q),
      construire: (context, a) => ListTile(
        title: Text(a.designation),
        subtitle: Text(a.unite),
        trailing: Text(
          Formats.montant(a.prixVente, devise: devise),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.accent(context),
          ),
        ),
        onTap: () => Get.back(result: a),
      ),
    ),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
}

class _FeuilleRecherche<T> extends StatefulWidget {
  const _FeuilleRecherche({
    required this.titre,
    required this.indice,
    required this.elements,
    required this.filtre,
    required this.construire,
    this.creer,
    this.libelleCreer,
    this.iconeCreer,
  });

  final String titre;
  final String indice;
  final List<T> elements;
  final bool Function(T element, String requete) filtre;
  final Widget Function(BuildContext context, T element) construire;

  /// Création à la volée. L'élément créé referme la feuille et devient sa
  /// réponse : au comptoir, un client qui n'est pas encore au fichier ne doit
  /// pas obliger à abandonner la facture en cours.
  final Future<T?> Function()? creer;
  final String? libelleCreer;
  final IconData? iconeCreer;

  @override
  State<_FeuilleRecherche<T>> createState() => _FeuilleRechercheState<T>();
}

class _FeuilleRechercheState<T> extends State<_FeuilleRecherche<T>> {
  String _requete = '';

  /// Le formulaire de création s'ouvre **par-dessus** la feuille, jamais à sa
  /// place : la refermer d'abord rendrait `null` à la facture en cours, qui
  /// resterait sans client.
  Future<void> _creer() async {
    final cree = await widget.creer!();
    if (cree != null && mounted) Navigator.of(context).pop(cree);
  }

  @override
  Widget build(BuildContext context) {
    final q = _requete.trim().toLowerCase();
    final resultats = q.isEmpty
        ? widget.elements
        : widget.elements.where((e) => widget.filtre(e, q)).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      // Plafonnée comme les autres feuilles : tirée jusqu'en haut, elle
      // passait sous la barre d'état.
      maxChildSize: kBottomSheetMaxHeightRatio,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.background(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text(context),
                      ),
                    ),
                  ),
                  if (widget.creer != null)
                    TextButton.icon(
                      onPressed: _creer,
                      icon: Icon(
                        widget.iconeCreer ?? Icons.add_rounded,
                        size: 18,
                      ),
                      label: Text(widget.libelleCreer ?? 'Nouveau'),
                    ),
                  // Refermer sans choisir : la poignée seule ne se devine
                  // pas, et le clavier de recherche masque le voile.
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _requete = v),
                decoration: InputDecoration(
                  hintText: widget.indice,
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: resultats.isEmpty
                  ? Center(
                      child: Text(
                        'Aucun résultat',
                        style: TextStyle(color: AppColors.textMuted(context)),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      // La route de la feuille ne réserve que le clavier :
                      // sans ça, le dernier résultat passe sous la barre
                      // d'accueil iOS.
                      padding: EdgeInsets.only(bottom: margeBasse(context)),
                      itemCount: resultats.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (context, i) =>
                          widget.construire(context, resultats[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
