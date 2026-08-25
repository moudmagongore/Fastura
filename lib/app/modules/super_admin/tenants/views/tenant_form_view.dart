import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/message_banner.dart';
import '../../../../data/models/format_impression.dart';
import '../../../../theme/app_colors.dart';
import '../controllers/tenant_form_controller.dart';

class TenantFormView extends GetView<TenantFormController> {
  const TenantFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(controller.titre)),
      body: SafeArea(
        child: Form(
          key: controller.formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              const _Section('Identité'),
              TextFormField(
                controller: controller.nomCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nom de l\'entreprise *',
                  prefixIcon: Icon(Icons.apartment_outlined),
                ),
                validator: controller.validerNom,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller.adresseCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Adresse',
                  helperText: 'Affichée en en-tête des factures et reçus',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller.telephoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller.emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),

              const _Section('Facturation'),
              TextFormField(
                controller: controller.deviseCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Devise *',
                  helperText: 'Ex : GNF, XOF, EUR',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: controller.validerDevise,
              ),
              const SizedBox(height: 14),
              Obx(
                () => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Assujettie à la TVA'),
                  subtitle: const Text(
                    'Désactivé, les factures sont émises sans TVA.',
                  ),
                  value: controller.tvaActive.value,
                  onChanged: (v) => controller.tvaActive.value = v,
                ),
              ),
              Obx(
                () => controller.tvaActive.value
                    ? Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: TextFormField(
                          controller: controller.tauxTvaCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Taux de TVA (%) *',
                            prefixIcon: Icon(Icons.percent),
                          ),
                          validator: controller.validerTauxTva,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller.prefixeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Préfixe des numéros de facture',
                  helperText: 'Ex : FA → FA-2026-00001',
                  prefixIcon: Icon(Icons.tag),
                ),
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
                  groupValue: controller.format.value,
                  onChanged: (v) {
                    if (v != null) controller.format.value = v;
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

              const SizedBox(height: 12),
              MessageBanner.info(
                'L\'administrateur de l\'entreprise pourra ensuite ajuster '
                'ces réglages et son logo depuis son écran Paramètres.',
              ),
              const SizedBox(height: 24),

              Obx(
                () => ElevatedButton(
                  onPressed: controller.enregistrement.value
                      ? null
                      : controller.enregistrer,
                  child: controller.enregistrement.value
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
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
