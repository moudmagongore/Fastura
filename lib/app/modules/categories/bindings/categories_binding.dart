import 'package:get/get.dart';

import '../controllers/categorie_form_controller.dart';
import '../controllers/categories_controller.dart';

class CategoriesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => CategoriesController());
  }
}

class CategorieFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => CategorieFormController());
  }
}
