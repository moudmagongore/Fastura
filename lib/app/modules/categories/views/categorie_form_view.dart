import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/widgets/message_banner.dart';
import '../../../core/utils/marges_ecran.dart';
import '../controllers/categorie_form_controller.dart';

class CategorieFormView extends GetView<CategorieFormController> {
  const CategorieFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(controller.titre)),
      body: SafeArea(
        bottom: false,
        child: Form(
          key: controller.formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 32 + margeBasse(context)),
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
                  helperText: 'Ex : Alimentation, Boissons, Prestations',
                  prefixIcon: Icon(Icons.category_outlined),
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
