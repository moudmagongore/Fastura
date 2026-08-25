import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/widgets/message_banner.dart';
import '../../../data/models/user_role.dart';
import '../../../theme/app_colors.dart';
import '../controllers/user_form_controller.dart';

class UserFormView extends GetView<UserFormController> {
  const UserFormView({super.key});

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
              Obx(() {
                final message = controller.erreur.value;
                if (message == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: MessageBanner.erreur(message),
                );
              }),

              TextFormField(
                controller: controller.nomCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nom complet *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: controller.validerNom,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: controller.emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                // L'email est l'identifiant Firebase Auth : le changer ici ne
                // changerait pas l'identifiant de connexion et créerait une
                // incohérence entre le compte et son profil.
                readOnly: controller.estEdition,
                decoration: InputDecoration(
                  labelText: 'Email *',
                  prefixIcon: const Icon(Icons.alternate_email),
                  helperText: controller.estEdition
                      ? 'L\'email de connexion ne peut pas être modifié'
                      : 'Servira d\'identifiant de connexion',
                ),
                validator: controller.validerEmail,
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

              if (!controller.estEdition) ...[
                const SizedBox(height: 14),
                Obx(
                  () => TextFormField(
                    controller: controller.motDePasseCtrl,
                    obscureText: !controller.motDePasseVisible.value,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe initial *',
                      helperText:
                          'À communiquer à l\'utilisateur. Il pourra le '
                          'changer via « Mot de passe oublié ».',
                      helperMaxLines: 2,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Copier',
                            icon: const Icon(Icons.copy_outlined, size: 20),
                            onPressed: () => _copier(controller
                                .motDePasseCtrl.text),
                          ),
                          IconButton(
                            tooltip: 'Générer un autre mot de passe',
                            icon: const Icon(Icons.autorenew, size: 20),
                            onPressed: controller.regenererMotDePasse,
                          ),
                          IconButton(
                            tooltip: controller.motDePasseVisible.value
                                ? 'Masquer'
                                : 'Afficher',
                            icon: Icon(
                              controller.motDePasseVisible.value
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                            ),
                            onPressed: () =>
                                controller.motDePasseVisible.toggle(),
                          ),
                        ],
                      ),
                    ),
                    validator: controller.validerMotDePasse,
                  ),
                ),
              ],

              const SizedBox(height: 26),
              Text(
                'RÔLE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.primary(context),
                ),
              ),
              const SizedBox(height: 8),

              if (!controller.roleModifiable)
                MessageBanner.info(
                  'Ce compte sera l\'administrateur de l\'entreprise. C\'est '
                  'lui qui créera ensuite ses vendeurs et paramétrera les '
                  'référentiels.',
                )
              else
                Obx(
                  () => RadioGroup<UserRole>(
                    groupValue: controller.role.value,
                    onChanged: (v) {
                      if (v != null) controller.role.value = v;
                    },
                    child: Column(
                      children: [
                        for (final r in UserRole.attribuablesParAdmin)
                          RadioListTile<UserRole>(
                            contentPadding: EdgeInsets.zero,
                            title: Text(r.label),
                            subtitle: Text(
                              r.isAdmin
                                  ? 'Saisit, consulte, annule, et gère les '
                                      'référentiels, les utilisateurs et les '
                                      'paramètres.'
                                  : 'Saisit clients, factures, paiements et '
                                      'dépenses, consulte tout l\'historique, '
                                      'n\'annule rien.',
                              style: const TextStyle(fontSize: 12.5),
                            ),
                            value: r,
                          ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 28),
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
                      : Text(
                          controller.estEdition
                              ? 'Enregistrer'
                              : 'Créer le compte',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copier(String valeur) {
    Clipboard.setData(ClipboardData(text: valeur));
    Get.snackbar(
      'Copié',
      'Le mot de passe est dans le presse-papiers.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }
}
