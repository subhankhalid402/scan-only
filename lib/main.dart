import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme_controller.dart';
import 'services/app_local_storage.dart';
import 'services/supabase_service.dart';
import 'theme.dart';
import 'screens/splash_screen.dart';
import 'widgets/app_lifecycle_lock.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await AppLocalStorage.init();
  await AppThemeController.init();
  await SupabaseService.init(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: '',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: '',
    ),
  );

  const channel = MethodChannel('scanonly/openwith');
  String? initialSharedFile;
  try {
    initialSharedFile = await channel.invokeMethod<String>('getInitialSharedFile');
  } catch (_) {}

  runApp(ScanOnlyApp(initialSharedFile: initialSharedFile));
}

class ScanOnlyApp extends StatelessWidget {
  final String? initialSharedFile;
  const ScanOnlyApp({super.key, this.initialSharedFile});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.themeMode,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'ScanOnly',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          home: SplashScreen(initialSharedFile: initialSharedFile),
          builder: (context, child) {
            return AppLifecycleLock(
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
