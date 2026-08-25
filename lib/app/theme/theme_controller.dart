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

  Future<void> toggle() => setMode(
        mode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
      );
}
