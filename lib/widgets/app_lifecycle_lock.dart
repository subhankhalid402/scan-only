import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../services/biometric_service.dart';
import '../theme.dart';

/// When enabled in Settings, asks for biometric after the app returns from background.
class AppLifecycleLock extends StatefulWidget {
  final Widget child;

  const AppLifecycleLock({super.key, required this.child});

  @override
  State<AppLifecycleLock> createState() => _AppLifecycleLockState();
}

class _AppLifecycleLockState extends State<AppLifecycleLock>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _ready = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pausedAt = DateTime.now();
    }
    if (state == AppLifecycleState.resumed) {
      _maybeLock();
    }
  }

  Future<void> _maybeLock() async {
    if (!_ready) return;
    final enabled = await BiometricService.instance.isBiometricLockEnabled();
    if (!enabled || !mounted) return;
    final t = _pausedAt;
    if (t == null) return;
    if (DateTime.now().difference(t) < const Duration(milliseconds: 600)) {
      return;
    }
    final can = await BiometricService.instance.canUseBiometrics();
    if (!can || !mounted) return;
    setState(() => _locked = true);
  }

  Future<void> _unlock() async {
    final ok = await BiometricService.instance.authenticate();
    if (ok && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_locked)
          Material(
            color: Colors.black.withValues(alpha: 0.92),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Iconsax.lock_1,
                          color: AppColors.gold, size: 56),
                      const SizedBox(height: 20),
                      Text(
                        'ScanOnly is locked',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your scans stay on this device. Unlock to continue.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          color: Colors.white60,
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _unlock,
                          icon: const Icon(Iconsax.finger_scan,
                              color: AppColors.navyDark),
                          label: Text(
                            'Unlock with biometrics',
                            style: GoogleFonts.nunito(
                              color: AppColors.navyDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
