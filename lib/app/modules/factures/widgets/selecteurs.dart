import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/format_helpers.dart';
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
}) {
  return Get.bottomSheet<ClientModel>(
    _FeuilleRecherche<ClientModel>(
      titre: 'Choisir un client',
      indice: 'Rechercher par nom ou téléphone…',
      elements: clients,
      filtre: (c, q) =>
          c.nom.toLowerCase().contains(q) || (c.telephone ?? '').contains(q),
      construire: (context, c) => ListTile(
        leading: CircleAvatar(
          backgroundColor:
              AppColors.primary(context).withValues(alpha: 0.15),
          child: c.estDivers
              ? Icon(Icons.storefront_outlined,
                  size: 20, color: AppColors.primary(context))
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
  });

  final String titre;
  final String indice;
  final List<T> elements;
  final bool Function(T element, String requete) filtre;
  final Widget Function(BuildContext context, T element) construire;

  @override
  State<_FeuilleRecherche<T>> createState() => _FeuilleRechercheState<T>();
}

class _FeuilleRechercheState<T> extends State<_FeuilleRecherche<T>> {
  String _requete = '';

  @override
  Widget build(BuildContext context) {
    final q = _requete.trim().toLowerCase();
    final resultats = q.isEmpty
        ? widget.elements
        : widget.elements.where((e) => widget.filtre(e, q)).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.titre,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text(context),
                  ),
                ),
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
