import 'package:get/get.dart';

import '../controllers/splash_controller.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    // `Get.put` et non `Get.lazyPut` : SplashView n'accède jamais à son
    // contrôleur (elle n'affiche qu'un logo et un loader), donc un lazyPut
    // ne serait jamais résolu — `onReady()` ne partirait pas et l'écran
    // resterait bloqué sur le loader.
    Get.put(SplashController());
  }
}
