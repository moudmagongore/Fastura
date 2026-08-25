import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/widgets/message_banner.dart';
import '../../../theme/app_colors.dart';
import '../controllers/mot_de_passe_oublie_controller.dart';

class MotDePasseOublieView extends GetView<MotDePasseOublieController> {
  const MotDePasseOublieView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Obx(
                () => controller.envoye.value
                    ? _Confirmation(email: controller.emailCtrl.text.trim())
                    : _Formulaire(controller: controller),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Formulaire extends StatelessWidget {
  const _Formulaire({required this.controller});

  final MotDePasseOublieController controller;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: controller.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Saisissez l\'email de votre compte. Vous recevrez un lien pour '
            'définir un nouveau mot de passe.',
            style: TextStyle(color: AppColors.textMuted(context)),
          ),
          const SizedBox(height: 24),
          Obx(() {
            final message = controller.erreur.value;
            if (message == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: MessageBanner.erreur(message),
            );
          }),
          TextFormField(
            controller: controller.emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.alternate_email),
            ),
            validator: controller.validerEmail,
          ),
          const SizedBox(height: 24),
          Obx(
            () => ElevatedButton(
              onPressed:
                  controller.isLoading.value ? null : controller.envoyer,
              child: controller.isLoading.value
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text('Envoyer le lien'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Confirmation extends StatelessWidget {
  const _Confirmation({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.mark_email_read_outlined,
            size: 64, color: AppColors.brandAccent),
        const SizedBox(height: 20),
        Text(
          'Si un compte existe pour $email, un lien de réinitialisation '
          'vient d\'y être envoyé.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.text(context)),
        ),
        const SizedBox(height: 8),
        Text(
          'Pensez à vérifier vos courriers indésirables.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textMuted(context)),
        ),
        const SizedBox(height: 28),
        OutlinedButton(
          onPressed: Get.back,
          child: const Text('Retour à la connexion'),
        ),
      ],
    );
  }
}
