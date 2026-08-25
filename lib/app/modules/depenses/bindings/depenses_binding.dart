import 'package:get/get.dart';

import '../controllers/depense_detail_controller.dart';
import '../controllers/depense_form_controller.dart';
import '../controllers/depenses_controller.dart';

class DepensesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => DepensesController());
  }
}

class DepenseFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => DepenseFormController());
  }
}

class DepenseDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => DepenseDetailController());
  }
}
