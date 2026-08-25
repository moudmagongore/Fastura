import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/widgets/message_banner.dart';
import '../controllers/client_form_controller.dart';

class ClientFormView extends GetView<ClientFormController> {
  const ClientFormView({super.key});

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

              if (controller.estDivers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: MessageBanner.info(
                    'Le client divers porte toutes les ventes comptant. Son '
                    'nom est commun à toute l\'équipe et ne peut pas être '
                    'modifié.',
                  ),
                ),

              TextFormField(
                controller: controller.nomCtrl,
                textCapitalization: TextCapitalization.words,
                readOnly: controller.estDivers,
                decoration: const InputDecoration(
                  labelText: 'Nom *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: controller.validerNom,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: controller.telephoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: controller.adresseCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Adresse',
                  prefixIcon: Icon(Icons.place_outlined),
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
