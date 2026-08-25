import 'package:get/get.dart';

import '../controllers/user_form_controller.dart';
import '../controllers/users_controller.dart';

class UsersBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => UsersController());
  }
}

class UserFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => UserFormController());
  }
}
