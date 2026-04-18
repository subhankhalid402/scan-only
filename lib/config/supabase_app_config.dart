/// In-app Supabase credentials (no JSON / dart-define file required).
/// Change these if you point the app at another Supabase project.
class SupabaseAppConfig {
  SupabaseAppConfig._();

  static const String url = 'https://aowgmjiezwydhluigkuc.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFvd2dtamllend5ZGhsdWlna3VjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyMzcwNDYsImV4cCI6MjA5MTgxMzA0Nn0.Ek-gst2tcNLoppK6LHpx8SrVt4gqm1nm07o_mgOmSGw';

  /// Base for `getPublicUrl`-style links without going through the SDK.
  static String get storagePublicObjectBase =>
      '$url/storage/v1/object/public';
}
