import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../services/app_local_storage.dart';
import '../theme.dart';
import 'home_screen.dart';

/// First-launch intro: value props + privacy. Shown once (see [kOnboardingPrefsKey]).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.replaceRootOnFinish = true});

  /// After finish/skip: replace with [HomeScreen] (first launch). If `false` (e.g. opened from Settings), only [Navigator.pop].
  final bool replaceRootOnFinish;

  static const String kOnboardingPrefsKey = 'onboarding_done_v1';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _index = 0;

  static const _pages = [
    _OnboardPageData(
      icon: Iconsax.camera,
      title: 'Scan anything',
      body:
          'Documents, IDs, receipts, books, whiteboards, and QR codes — with guides for each mode.',
      color: AppColors.gold,
    ),
    _OnboardPageData(
      icon: Iconsax.shield_tick,
      title: 'Your data stays on device',
      body:
          'Scans and PDFs live on your phone—not our servers. No account required. Share only when you choose.',
      color: AppColors.green,
    ),
    _OnboardPageData(
      icon: Iconsax.search_normal,
      title: 'Find text inside scans',
      body:
          'After saving, OCR runs on-device so you can search by filename or words inside your documents.',
      color: Color(0xFF6366F1),
    ),
    _OnboardPageData(
      icon: Iconsax.document_download,
      title: 'One PDF, zero clutter',
      body:
          'Stack pages, tap Save, and bundle everything into a single PDF—ideal for school and work. Optional ZIP backup in Settings.',
      color: Color(0xFFE53935),
    ),
  ];

  Future<void> _finish() async {
    await AppLocalStorage.setBool(OnboardingScreen.kOnboardingPrefsKey, true);
    if (!mounted) return;
    if (widget.replaceRootOnFinish) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _next() {
    if (_index < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1740),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  'Skip',
                  style: GoogleFonts.nunito(
                    color: Colors.white54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: p.color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Icon(p.icon, color: p.color, size: 48),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          p.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          p.body,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index ? AppColors.gold : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.navyDark,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _index == _pages.length - 1 ? 'Get started' : 'Next',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPageData {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const _OnboardPageData({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });
}
