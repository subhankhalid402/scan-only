import 'dart:io';

/// Ensures [dart_defines.json] exists (for `--dart-define-from-file`).
/// Run from repo root: `dart run tool/ensure_defines.dart`
void main() {
  final target = File('dart_defines.json');
  if (target.existsSync()) return;

  final example = File('dart_defines.example.json');
  if (!example.existsSync()) {
    stderr.writeln('Missing dart_defines.example.json in project root.');
    exitCode = 1;
    return;
  }

  example.copySync(target.path);
  stderr.writeln(
    'Created dart_defines.json from example. '
    'Paste your Supabase URL and anon key, then run the app again.',
  );
}
