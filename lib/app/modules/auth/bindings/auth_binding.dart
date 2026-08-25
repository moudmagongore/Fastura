import 'package:get/get.dart';

import '../controllers/login_controller.dart';
import '../controllers/mot_de_passe_oublie_controller.dart';

class LoginBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => LoginController());
  }
}

class MotDePasseOublieBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => MotDePasseOublieController());
  }
}
