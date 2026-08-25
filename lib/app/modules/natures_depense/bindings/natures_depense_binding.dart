import 'package:get/get.dart';

import '../controllers/nature_depense_form_controller.dart';
import '../controllers/natures_depense_controller.dart';

class NaturesDepenseBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => NaturesDepenseController());
  }
}

class NatureDepenseFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => NatureDepenseFormController());
  }
}
