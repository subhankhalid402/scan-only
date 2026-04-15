import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'app_local_storage.dart';

class StorageUsageSnapshot {
  final double usedMb;
  final double warningLimitMb;
  final double ratio;

  const StorageUsageSnapshot({
    required this.usedMb,
    required this.warningLimitMb,
    required this.ratio,
  });

  bool get nearLimit => ratio >= 0.85;
}

class StorageMonitorService {
  StorageMonitorService._();
  static final StorageMonitorService instance = StorageMonitorService._();

  static const _limitKey = 'localStorageLimitMb';
  static const _lastWarnAtKey = 'storageWarnLastShownAt';

  double get warningLimitMb =>
      AppLocalStorage.getDouble(_limitKey, defaultValue: 600.0);

  Future<void> setWarningLimitMb(double value) async {
    await AppLocalStorage.setDouble(
      _limitKey,
      value.clamp(200.0, 5000.0),
    );
  }

  Future<StorageUsageSnapshot> getUsage() async {
    final docs = await getApplicationDocumentsDirectory();
    final used = await _dirSizeMb(docs);
    final limit = warningLimitMb;
    final ratio = limit <= 0 ? 0.0 : (used / limit).toDouble();
    return StorageUsageSnapshot(
      usedMb: used,
      warningLimitMb: limit,
      ratio: ratio,
    );
  }

  bool shouldShowWarningNow() {
    final last = AppLocalStorage.getStringOrNull(_lastWarnAtKey);
    if (last == null || last.isEmpty) return true;
    final parsed = DateTime.tryParse(last);
    if (parsed == null) return true;
    return DateTime.now().difference(parsed).inHours >= 24;
  }

  Future<void> markWarningShownNow() async {
    await AppLocalStorage.setString(_lastWarnAtKey, DateTime.now().toIso8601String());
  }

  Future<double> _dirSizeMb(Directory dir) async {
    double total = 0;
    try {
      await for (final f in dir.list(recursive: true)) {
        if (f is File) total += await f.length();
      }
    } catch (_) {}
    return total / (1024 * 1024);
  }
}
