import 'package:flutter/material.dart';

import 'services/app_local_storage.dart';

/// Theme mode: manual light/dark ([darkMode]) or [ThemeMode.system] when
/// [themeFollowSystemKey] is true (matches Android / device setting).
class AppThemeController {
  AppThemeController._();

  /// When true, [ThemeMode.system] is used; [darkMode] is still saved for when
  /// the user turns this off.
  static const String themeFollowSystemKey = 'themeFollowSystem';

  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static Future<void> init() async {
    if (AppLocalStorage.getBool(themeFollowSystemKey)) {
      themeMode.value = ThemeMode.system;
    } else {
      themeMode.value = AppLocalStorage.getBool('darkMode')
          ? ThemeMode.dark
          : ThemeMode.light;
    }
  }

  /// Persists preference and applies [ThemeMode.system] when [follow] is true.
  static Future<void> setFollowSystemTheme(bool follow) async {
    await AppLocalStorage.setBool(themeFollowSystemKey, follow);
    if (follow) {
      themeMode.value = ThemeMode.system;
    } else {
      themeMode.value = AppLocalStorage.getBool('darkMode')
          ? ThemeMode.dark
          : ThemeMode.light;
    }
  }

  /// Persists [darkMode] and updates the active theme unless system mode is on.
  static Future<void> setDarkMode(bool dark) async {
    await AppLocalStorage.setBool('darkMode', dark);
    if (!AppLocalStorage.getBool(themeFollowSystemKey)) {
      themeMode.value = dark ? ThemeMode.dark : ThemeMode.light;
    }
  }
}
