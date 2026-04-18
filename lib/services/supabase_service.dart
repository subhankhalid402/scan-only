import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Optional Supabase bootstrap.
/// If URL/anon key are missing, cloud features stay disabled.
class SupabaseService {
  SupabaseService._();

  static bool _initialized = false;
  static bool _available = false;
  static String? _lastInitError;

  static bool get isAvailable => _available;

  /// Set when initialization fails; useful for cloud backup diagnostics.
  static String? get lastInitError => _lastInitError;

  static SupabaseClient? get client =>
      _available ? Supabase.instance.client : null;

  static Future<void> init({
    required String url,
    required String anonKey,
  }) async {
    if (_initialized) return;
    _initialized = true;

    if (url.isEmpty || anonKey.isEmpty) {
      _available = false;
      _lastInitError = 'Missing URL or anon key.';
      debugPrint('Supabase disabled: missing URL or anon key.');
      return;
    }

    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );
      _available = true;
      _lastInitError = null;
    } catch (e) {
      _available = false;
      _lastInitError = e.toString();
      debugPrint('Supabase init failed: $e');
    }
  }
}
