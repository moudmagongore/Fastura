import 'package:get/get.dart';

import '../controllers/article_form_controller.dart';
import '../controllers/articles_controller.dart';

class ArticlesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ArticlesController());
  }
}

class ArticleFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ArticleFormController());
  }
}
