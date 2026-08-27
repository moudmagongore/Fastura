import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// Persiste le choix clair / sombre / système entre deux lancements.
class ThemeController extends GetxController {
  static ThemeController get to => Get.find();

  static const _key = 'theme_mode';

  final _box = GetStorage();
  final mode = ThemeMode.system.obs;

  @override
  void onInit() {
    super.onInit();
    final saved = _box.read<String>(_key);
    mode.value = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode value) async {
    mode.value = value;
    await _box.write(_key, value.name);
  }

  /// Le thème **réellement affiché**, `ThemeMode.system` résolu par le
  /// réglage de l'appareil.
  ///
  /// Le mode enregistré ne suffit pas à répondre : au premier lancement il
  /// vaut `system`, et sur un téléphone réglé en sombre l'application est
  /// sombre alors que `mode` ne dit ni l'un ni l'autre. L'interrupteur du
  /// tiroir affichait donc « éteint » sur une application manifestement
  /// sombre.
  ///
  /// Lit `mode.value` : l'appel reste donc valable dans un `Obx`.
  bool estSombre(BuildContext context) => switch (mode.value) {
    ThemeMode.dark => true,
    ThemeMode.light => false,
    ThemeMode.system =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark,
  };

  /// Bascule à partir de ce qui est **affiché**, pas de ce qui est
  /// enregistré : depuis `system` sur un appareil sombre, l'ancienne bascule
  /// posait `dark` — le réglage changeait, l'écran non, et le premier appui
  /// semblait sans effet.
  Future<void> basculer(BuildContext context) =>
      setMode(estSombre(context) ? ThemeMode.light : ThemeMode.dark);
}
