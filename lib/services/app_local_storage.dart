import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// On-device app preferences: primary copy in **Hive**, mirrored to **SharedPreferences**
/// so values persist reliably across launches. Document library stays in SQLite ([DatabaseService]).
class AppLocalStorage {
  AppLocalStorage._();

  static const _boxName = 'app_kv';
  static Box<dynamic>? _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<dynamic>(_boxName);
    await _pullMissingKeysFromSharedPreferences();
  }

  /// If SharedPreferences has keys Hive does not (e.g. app update), copy them once per key.
  static Future<void> _pullMissingKeysFromSharedPreferences() async {
    final b = _box;
    if (b == null) return;
    final sp = await SharedPreferences.getInstance();
    for (final key in sp.getKeys()) {
      if (b.containsKey(key)) continue;
      final v = sp.get(key);
      if (v != null) await b.put(key, v);
    }
  }

  static Box<dynamic> get _requireBox {
    final b = _box;
    if (b == null) {
      throw StateError('Call AppLocalStorage.init() in main() before runApp.');
    }
    return b;
  }

  static Future<void> setBool(String key, bool value) async {
    await _requireBox.put(key, value);
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(key, value);
  }

  static bool getBool(String key, {bool defaultValue = false}) {
    final v = _requireBox.get(key);
    if (v is bool) return v;
    return defaultValue;
  }

  static Future<void> setString(String key, String value) async {
    await _requireBox.put(key, value);
    final sp = await SharedPreferences.getInstance();
    await sp.setString(key, value);
  }

  static String getString(String key, {String defaultValue = ''}) {
    final v = _requireBox.get(key);
    if (v is String) return v;
    return defaultValue;
  }

  static String? getStringOrNull(String key) {
    final v = _requireBox.get(key);
    if (v is String) return v;
    return null;
  }

  static Future<void> setDouble(String key, double value) async {
    await _requireBox.put(key, value);
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble(key, value);
  }

  static double getDouble(String key, {double defaultValue = 0.0}) {
    final v = _requireBox.get(key);
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return defaultValue;
  }

  static Future<void> setInt(String key, int value) async {
    await _requireBox.put(key, value);
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(key, value);
  }

  static int? getInt(String key) {
    final v = _requireBox.get(key);
    if (v is int) return v;
    if (v is double) return v.round();
    return null;
  }

  static Future<void> remove(String key) async {
    await _requireBox.delete(key);
    final sp = await SharedPreferences.getInstance();
    await sp.remove(key);
  }
}
