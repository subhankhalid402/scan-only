import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Live dark/light theme from Settings (SharedPreferences key `darkMode`).
class AppThemeController {
  AppThemeController._();

  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    themeMode.value =
        p.getBool('darkMode') == true ? ThemeMode.dark : ThemeMode.light;
  }

  static void setDarkMode(bool dark) {
    themeMode.value = dark ? ThemeMode.dark : ThemeMode.light;
  }
}
