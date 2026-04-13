import 'package:flutter/material.dart';

import 'services/app_local_storage.dart';

/// Live dark/light theme from Settings (Hive + SharedPreferences key `darkMode`).
class AppThemeController {
  AppThemeController._();

  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static Future<void> init() async {
    themeMode.value = AppLocalStorage.getBool('darkMode')
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  static void setDarkMode(bool dark) {
    themeMode.value = dark ? ThemeMode.dark : ThemeMode.light;
  }
}
