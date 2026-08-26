import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/models/article_model.dart';
import '../../../data/models/categorie_model.dart';
import '../../../data/repositories/article_repository.dart';
import '../../../data/repositories/categorie_repository.dart';

class ArticlesController extends GetxController {
  final ArticleRepository _repo = ArticleRepository();
  final CategorieRepository _categorieRepo = CategorieRepository();

  final articles = <ArticleModel>[].obs;
  final categories = <CategorieModel>[].obs;
  final chargement = true.obs;
  final recherche = ''.obs;
  final masquerInactifs = false.obs;

  /// Vide = toutes catégories confondues.
  final filtreCategorieId = ''.obs;

  late final String tenantId;

  @override
  void onInit() {
    super.onInit();
    tenantId = SessionController.to.requireTenantId;

    // Les catégories sont chargées en parallèle : elles servent au filtre et
    // à afficher le libellé de rattachement sur chaque article, plutôt que
    // de dénormaliser ce libellé dans chaque document.
    categories.bindStream(_categorieRepo.watchByTenant(tenantId));
    articles.bindStream(
      _repo.watchByTenant(tenantId).map((liste) {
        chargement.value = false;
        return liste;
      }),
    );
  }

  CategorieModel? categorieDe(ArticleModel a) {
    for (final c in categories) {
      if (c.id == a.categorieId) return c;
    }
    return null;
  }

  String libelleCategorie(ArticleModel a) =>
      categorieDe(a)?.libelle ?? 'Catégorie supprimée';

  String get devise => SessionController.to.devise;

  List<ArticleModel> get resultats {
    final q = recherche.value.trim().toLowerCase();
    final cat = filtreCategorieId.value;
    return articles.where((a) {
      if (masquerInactifs.value && !a.active) return false;
      if (cat.isNotEmpty && a.categorieId != cat) return false;
      if (q.isEmpty) return true;
      return a.designation.toLowerCase().contains(q);
    }).toList();
  }

  int get nbActifs => articles.where((a) => a.active).length;

  Future<void> basculerActivation(ArticleModel a) async {
    final reactivation = !a.active;

    // Réactiver un article dont la catégorie est fermée le rendrait
    // invisible malgré tout à la facturation : la liste de sélection filtre
    // sur les catégories actives. Autant le dire tout de suite.
    if (reactivation) {
      final cat = categorieDe(a);
      if (cat != null && !cat.active) {
        Get.snackbar(
          'Action impossible',
          'La catégorie « ${cat.libelle} » est désactivée. Réactivez-la '
              'd\'abord, sinon cet article resterait absent des listes.',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 5),
        );
        return;
      }
    }

    final ok = await confirmer(
      titre: reactivation ? 'Réactiver l\'article' : 'Désactiver l\'article',
      message: reactivation
          ? '« ${a.designation} » réapparaîtra dans les listes de sélection.'
          : '« ${a.designation} » n\'apparaîtra plus au moment de facturer. '
                'Les factures déjà émises ne changent pas.',
      libelleConfirmer: reactivation ? 'Réactiver' : 'Désactiver',
      destructif: !reactivation,
    );
    if (!ok) return;

    try {
      await _repo.setActive(a.id, reactivation);
    } catch (e) {
      Get.snackbar(
        'Action impossible',
        'Modification impossible : $e',
        snackPosition: SnackPosition.TOP,
      );
    }
  }
}
