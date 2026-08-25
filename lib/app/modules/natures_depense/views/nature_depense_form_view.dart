import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/widgets/message_banner.dart';
import '../controllers/nature_depense_form_controller.dart';

class NatureDepenseFormView extends GetView<NatureDepenseFormController> {
  const NatureDepenseFormView({super.key});

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
                controller: controller.libelleCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Libellé *',
                  helperText: 'Ex : Loyer, Carburant, Fournitures, Salaires',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: controller.validerLibelle,
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
