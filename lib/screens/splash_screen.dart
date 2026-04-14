import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_local_storage.dart';
import '../theme.dart';
import 'edit_scan_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'scan_screen.dart';

class SplashScreen extends StatefulWidget {
  final String? initialSharedFile;
  const SplashScreen({super.key, this.initialSharedFile});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();

    // ~1s minimum for branding; prefs load in parallel (was a fixed 2.2s wait every launch).
    Future.microtask(() async {
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      final done =
          AppLocalStorage.getBool(OnboardingScreen.kOnboardingPrefsKey);
      if (!mounted) return;
      if (done) {
        final shared = widget.initialSharedFile;
        if (shared != null && shared.isNotEmpty) {
          final lower = shared.toLowerCase();
          final isImage = lower.endsWith('.jpg') ||
              lower.endsWith('.jpeg') ||
              lower.endsWith('.png') ||
              lower.endsWith('.webp');
          if (isImage) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => EditScanScreen(
                  imagePaths: [shared],
                  scanType: 'gallery',
                ),
              ),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const ScanScreen(scanType: 'gallery'),
              ),
            );
          }
          return;
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.navyDark,
              AppColors.navyMid,
              AppColors.navyLight,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Logo
              ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.28),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.30),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Image.asset(
                        'assets/images/launcher_icon.png',
                        width: 108,
                        height: 108,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // App Name
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'ScanOnly',
                  style: GoogleFonts.nunito(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Tagline
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'Scan. Enhance. Share.',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
              ),

              const SizedBox(height: 60),

              // Loading Indicator
              FadeTransition(
                opacity: _fadeAnimation,
                child: const CircularProgressIndicator(
                  color: AppColors.gold,
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
