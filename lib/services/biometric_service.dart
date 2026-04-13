import 'package:local_auth/local_auth.dart';

import 'app_local_storage.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();

  factory BiometricService() {
    return _instance;
  }

  BiometricService._internal();

  static BiometricService get instance => _instance;

  final _localAuth = LocalAuthentication();

  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access ScanOnly',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  Future<void> enableBiometricLock() async {
    await AppLocalStorage.setBool('biometric_lock_enabled', true);
  }

  Future<void> disableBiometricLock() async {
    await AppLocalStorage.setBool('biometric_lock_enabled', false);
  }

  Future<bool> isBiometricLockEnabled() async {
    return AppLocalStorage.getBool('biometric_lock_enabled');
  }
}
