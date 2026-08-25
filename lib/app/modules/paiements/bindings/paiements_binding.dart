import 'package:get/get.dart';

import '../controllers/paiement_detail_controller.dart';
import '../controllers/paiement_form_controller.dart';
import '../controllers/paiements_controller.dart';

class PaiementsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => PaiementsController());
  }
}

class PaiementFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => PaiementFormController());
  }
}

class PaiementDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => PaiementDetailController());
  }
}
