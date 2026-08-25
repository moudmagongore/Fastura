import 'package:get/get.dart';

import '../controllers/facture_detail_controller.dart';
import '../controllers/facture_form_controller.dart';
import '../controllers/factures_controller.dart';

class FacturesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => FacturesController());
  }
}

class FactureFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => FactureFormController());
  }
}

class FactureDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => FactureDetailController());
  }
}
