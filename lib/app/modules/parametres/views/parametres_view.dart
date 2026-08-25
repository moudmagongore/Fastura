import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/message_banner.dart';
import '../../../data/models/format_impression.dart';
import '../../../theme/app_colors.dart';
import '../controllers/parametres_controller.dart';

class ParametresView extends GetView<ParametresController> {
  const ParametresView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        actions: [
          IconButton(
            tooltip: 'Aperçu d\'impression',
            icon: const Icon(Icons.print_outlined),
            onPressed: controller.apercuImpression,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: GetBuilder<ParametresController>(
          builder: (c) {
            if (!c.pret) {
              return const Center(child: CircularProgressIndicator());
            }
            return Form(
              key: c.formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  Obx(() {
                    final message = c.erreur.value;
                    if (message == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: MessageBanner.erreur(message),
                    );
                  }),

                  const _Section('Identité'),
                  TextFormField(
                    controller: c.nomCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nom de l\'entreprise *',
                      prefixIcon: Icon(Icons.apartment_outlined),
                    ),
                    validator: c.validerNom,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: c.adresseCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Adresse',
                      helperText: 'Affichée en en-tête des factures et reçus',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: c.telephoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: c.emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                  ),

                  const _Section('Logo'),
                  _Logo(controller: c),

                  const _Section('Facturation'),
                  TextFormField(
                    controller: c.deviseCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Devise *',
                      helperText: 'Ex : GNF, XOF, EUR',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    validator: c.validerDevise,
                  ),
                  const SizedBox(height: 14),
                  Obx(
                    () => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Assujettie à la TVA'),
                      subtitle: const Text(
                        'Désactivé, les factures sont émises sans TVA.',
                      ),
                      value: c.tvaActive.value,
                      onChanged: (v) => c.tvaActive.value = v,
                    ),
                  ),
                  Obx(
                    () => c.tvaActive.value
                        ? Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: TextFormField(
                              controller: c.tauxTvaCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Taux de TVA (%) *',
                                prefixIcon: Icon(Icons.percent),
                              ),
                              validator: c.validerTauxTva,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: c.prefixeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Préfixe des numéros de facture',
                      helperText: 'Ex : FA → FA-2026-00001',
                      prefixIcon: Icon(Icons.tag),
                    ),
                  ),
                  const SizedBox(height: 16),
                  MessageBanner.info(
                    'Devise, taux de TVA et préfixe s\'appliquent aux '
                    'prochaines factures. Celles déjà émises conservent les '
                    'leurs : une pièce comptable ne se réécrit pas.',
                  ),

                  const _Section('Impression'),
                  Text(
                    'Un seul format est actif pour toute l\'entreprise.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Obx(
                    () => RadioGroup<FormatImpression>(
                      groupValue: c.format.value,
                      onChanged: (v) {
                        if (v != null) c.format.value = v;
                      },
                      child: Column(
                        children: [
                          for (final f in FormatImpression.values)
                            RadioListTile<FormatImpression>(
                              contentPadding: EdgeInsets.zero,
                              title: Text(f.label),
                              value: f,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: c.apercuImpression,
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Aperçu sur une facture spécimen'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'L\'aperçu reprend la saisie en cours, avant même '
                    'd\'enregistrer : c\'est en le regardant qu\'on choisit '
                    'un format.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted(context),
                    ),
                  ),

                  const SizedBox(height: 28),
                  Obx(
                    () => ElevatedButton(
                      onPressed: c.enregistrement.value ? null : c.enregistrer,
                      child: c.enregistrement.value
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Enregistrer'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Le logo est **référencé**, pas téléversé : Firebase Storage n'est pas
/// provisionné sur le projet. L'aperçu vaut vérification — une adresse qui
/// ne charge pas ici ne chargera pas davantage à l'impression.
class _Logo extends StatefulWidget {
  const _Logo({required this.controller});

  final ParametresController controller;

  @override
  State<_Logo> createState() => _LogoState();
}

class _LogoState extends State<_Logo> {
  @override
  Widget build(BuildContext context) {
    final url = widget.controller.logoUrlCtrl.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.controller.logoUrlCtrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Adresse du logo',
            helperText: 'Image accessible en https, affichée en en-tête',
            prefixIcon: Icon(Icons.image_outlined),
          ),
          validator: widget.controller.validerLogoUrl,
          onFieldSubmitted: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Vérifier l\'aperçu'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: 96,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: url.isEmpty
              ? Text(
                  'Sans logo, le nom de l\'entreprise le remplace en gros.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted(context),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(10),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Text(
                      'Image inaccessible : l\'en-tête sortirait sans logo.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 10),
        MessageBanner.info(
          'Le téléversement depuis le téléphone arrivera quand Firebase '
          'Storage sera activé sur le projet. En attendant, collez ici '
          'l\'adresse d\'une image déjà en ligne.',
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.titre);

  final String titre;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Text(
        titre.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.primary(context),
        ),
      ),
    );
  }
}
