import 'package:get/get.dart';

import '../controllers/client_detail_controller.dart';
import '../controllers/client_form_controller.dart';
import '../controllers/clients_controller.dart';

class ClientsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ClientsController());
  }
}

class ClientFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ClientFormController());
  }
}

class ClientDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ClientDetailController());
  }
}
