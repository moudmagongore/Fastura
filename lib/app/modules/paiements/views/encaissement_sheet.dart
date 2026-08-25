import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../core/utils/bottom_sheet_helpers.dart';
import '../../../core/utils/format_helpers.dart';
import '../../../data/models/client_model.dart';
import '../../../data/repositories/client_repository.dart';
import '../../../theme/app_colors.dart';
import 'reglement_sheet.dart';

/// Feuille « Encaisser un règlement » ouverte depuis le journal des
/// paiements ou l'accueil.
///
/// Elle commence par choisir le client, puis enchaîne sur [ReglementSheet].
/// Le filtre « avec créance » est actif par défaut : on encaisse presque
/// toujours quelqu'un qui doit de l'argent, et une liste de clients soldés
/// ne ferait qu'allonger la recherche.
class EncaissementSheet extends StatefulWidget {
  const EncaissementSheet({super.key});

  static Future<void> ouvrir() async {
    await Get.bottomSheet(
      const EncaissementSheet(),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  State<EncaissementSheet> createState() => _EncaissementSheetState();
}

class _EncaissementSheetState extends State<EncaissementSheet> {
  final _repo = ClientRepository();
  final _rechercheCtrl = TextEditingController();
  final _clients = <ClientModel>[].obs;

  bool _avecCreanceSeulement = true;

  @override
  void initState() {
    super.initState();
    _clients.bindStream(
      _repo.watchByTenant(
        SessionController.to.requireTenantId,
        actifsSeulement: true,
      ),
    );
  }

  @override
  void dispose() {
    _rechercheCtrl.dispose();
    _clients.close();
    super.dispose();
  }

  List<ClientModel> get _resultats {
    final q = _rechercheCtrl.text.trim().toLowerCase();
    final liste = _clients.where((c) {
      if (_avecCreanceSeulement && !c.aUneDette) return false;
      if (q.isEmpty) return true;
      return c.nom.toLowerCase().contains(q) ||
          (c.telephone ?? '').contains(q);
    }).toList();

    // Les plus gros débiteurs d'abord : c'est eux qu'on relance.
    liste.sort((a, b) => b.solde.compareTo(a.solde));
    return liste;
  }

  @override
  Widget build(BuildContext context) {
    final devise = SessionController.to.devise;

    return DraggableScrollableSheet(
      initialChildSize: kBottomSheetMaxHeightRatio,
      minChildSize: 0.5,
      maxChildSize: kBottomSheetMaxHeightRatio,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: androidOnlySafeArea(
          Column(
            children: [
              const SizedBox(height: 10),
              const PoigneeSheet(marge: EdgeInsets.only(bottom: 8)),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 8, 6),
                child: EnteteSheet(
                  icone: Icons.payments_rounded,
                  couleur: AppColors.success,
                  titre: 'Encaisser un règlement',
                  sousTitre: 'Choisissez le client qui règle',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _rechercheCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Rechercher un client (nom, téléphone)…',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Avec créance'),
                      selected: _avecCreanceSeulement,
                      onSelected: (v) =>
                          setState(() => _avecCreanceSeulement = v),
                    ),
                    const Spacer(),
                    Obx(() {
                      final total = _clients
                          .where((c) => c.aUneDette)
                          .fold<double>(0, (s, c) => s + c.solde);
                      if (total <= 0) return const SizedBox.shrink();
                      return Text(
                        'À recouvrer : '
                        '${Formats.montant(total, devise: devise)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Obx(() {
                  // Lecture de la liste observable pour que le filtre se
                  // recalcule à chaque changement côté Firestore.
                  _clients.length;
                  final liste = _resultats;

                  if (liste.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          _avecCreanceSeulement
                              ? 'Aucun client n\'a de créance en cours.\n'
                                  'Décochez « Avec créance » pour encaisser '
                                  'une avance.'
                              : 'Aucun client ne correspond à cette recherche.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textMuted(context),
                            height: 1.4,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: liste.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (_, i) => _TuileClient(
                      client: liste[i],
                      devise: devise,
                      onTap: () => _encaisser(liste[i]),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _encaisser(ClientModel c) async {
    // La feuille de choix se referme avant celle de saisie : empiler deux
    // sheets rendrait le retour arrière déroutant.
    Get.back();
    await ReglementSheet.ouvrir(c);
  }
}

class _TuileClient extends StatelessWidget {
  const _TuileClient({
    required this.client,
    required this.devise,
    required this.onTap,
  });

  final ClientModel client;
  final String devise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: AppColors.primary(context).withValues(alpha: 0.15),
        child: client.estDivers
            ? Icon(Icons.storefront_outlined,
                size: 20, color: AppColors.primary(context))
            : Text(
                client.initiales,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary(context),
                ),
              ),
      ),
      title: Text(
        client.nom,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
      ),
      subtitle: (client.telephone ?? '').isEmpty
          ? null
          : Text(client.telephone!, style: const TextStyle(fontSize: 12)),
      trailing: client.solde == 0
          ? null
          : Text(
              client.aUneDette
                  ? Formats.montant(client.solde, devise: devise)
                  : '+ ${Formats.montant(-client.solde, devise: devise)}',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color:
                    client.aUneDette ? AppColors.warning : AppColors.success,
              ),
            ),
    );
  }
}
