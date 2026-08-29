import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'format_helpers.dart';

/// Deux dates, « du » et « au », posées par l'utilisateur.
///
/// Les bornes partent **au serveur** : un journal se borne à la source, pas
/// après avoir lu six mois de documents. Elles portent sur le champ `date`,
/// qui sert aussi au tri — aucun index composite à ajouter.
///
/// Le contrôleur qui l'utilise garde la main sur son flux : il passe
/// [onChangement] et rebranche sa requête quand une borne bouge.
class FiltrePeriode {
  FiltrePeriode({
    DateTime? debut,
    DateTime? fin,
    this.effacable = true,
    required this.onChangement,
  }) : _debut = Rxn<DateTime>(debut),
       _fin = Rxn<DateTime>(fin);

  final Rxn<DateTime> _debut;
  final Rxn<DateTime> _fin;

  /// Faux quand le journal doit rester borné en toutes circonstances — le
  /// récapitulatif des dépenses, par exemple, n'a de sens que sur une
  /// période. Le bouton d'effacement disparaît alors.
  final bool effacable;

  /// Appelé après chaque changement de borne, pour rebrancher le flux.
  final VoidCallback onChangement;

  /// Borne basse, au début de la journée choisie. Nulle si l'utilisateur
  /// n'en a pas posé.
  DateTime? get debut {
    final d = _debut.value;
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  /// Borne haute, à la **fin** de la journée choisie : une pièce enregistrée
  /// cet après-midi porte une heure, et une borne à minuit la laisserait
  /// hors de la période.
  DateTime? get fin {
    final f = _fin.value;
    return f == null ? null : DateTime(f.year, f.month, f.day, 23, 59, 59);
  }

  bool get bornee => _debut.value != null || _fin.value != null;

  /// Ce que la liste couvre, en toutes lettres — à afficher près des totaux,
  /// qui n'ont de sens que rapportés à leur période.
  String get libelle {
    final d = debut;
    final f = fin;
    if (d == null && f == null) return 'Tout l\'historique';
    if (d == null) return 'Jusqu\'au ${Formats.date(f!)}';
    if (f == null) return 'Depuis le ${Formats.date(d)}';
    return 'Du ${Formats.date(d)} au ${Formats.date(f)}';
  }

  DateTime get _plancher => DateTime(DateTime.now().year - 3);

  /// Aucune pièce ne s'enregistre dans le futur : le calendrier s'arrête à
  /// aujourd'hui.
  DateTime get _plafond => DateTime.now();

  Future<void> choisirDebut(BuildContext context) async {
    final choisie = await showDatePicker(
      context: context,
      initialDate: _debut.value ?? _fin.value ?? _plafond,
      firstDate: _plancher,
      lastDate: _plafond,
      helpText: 'Début de la période',
    );
    if (choisie == null) return;
    _debut.value = choisie;
    // Une borne basse posée après la borne haute donnerait une liste vide
    // sans que personne ne comprenne pourquoi : on pousse l'autre.
    if (_fin.value != null && choisie.isAfter(_fin.value!)) {
      _fin.value = choisie;
    }
    onChangement();
  }

  Future<void> choisirFin(BuildContext context) async {
    final choisie = await showDatePicker(
      context: context,
      initialDate: _fin.value ?? _plafond,
      firstDate: _debut.value ?? _plancher,
      lastDate: _plafond,
      helpText: 'Fin de la période',
    );
    if (choisie == null) return;
    _fin.value = choisie;
    if (_debut.value != null && choisie.isBefore(_debut.value!)) {
      _debut.value = choisie;
    }
    onChangement();
  }

  /// Retire les deux bornes : le journal remonte de nouveau tout ce que son
  /// plafond de lecture permet.
  void effacer() {
    if (!bornee) return;
    _debut.value = null;
    _fin.value = null;
    onChangement();
  }
}
