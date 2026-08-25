import 'package:get/get.dart';

import '../controllers/tenant_form_controller.dart';
import '../controllers/tenants_controller.dart';

class TenantsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => TenantsController());
  }
}

class TenantFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => TenantFormController());
  }
}
