import 'app_local_storage.dart';

/// Subscription service - manages premium state locally.
/// For real in-app purchases, integrate with `in_app_purchase` package.
class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();
  static SubscriptionService get instance => _instance;

  static const _premiumKey = 'is_premium';
  static const _expiryKey = 'premium_expiry';

  /// Returns true if user has active premium subscription.
  bool isPremium() {
    final premium = AppLocalStorage.getBool(_premiumKey);
    if (!premium) return false;

    // Check expiry if set
    final expiryStr = AppLocalStorage.getString(_expiryKey);
    if (expiryStr.isEmpty) return premium;

    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return false;

    // Expired - auto-revoke
    if (DateTime.now().isAfter(expiry)) {
      AppLocalStorage.setBool(_premiumKey, false);
      return false;
    }

    return true;
  }

  /// Activate premium for given duration.
  Future<void> activatePremium({Duration duration = const Duration(days: 30)}) async {
    final expiry = DateTime.now().add(duration);
    await AppLocalStorage.setBool(_premiumKey, true);
    await AppLocalStorage.setString(_expiryKey, expiry.toIso8601String());
  }

  /// Revoke premium.
  Future<void> revokePremium() async {
    await AppLocalStorage.setBool(_premiumKey, false);
    await AppLocalStorage.setString(_expiryKey, '');
  }

  /// Days remaining in subscription (null if not premium).
  int? daysRemaining() {
    if (!isPremium()) return null;
    final expiryStr = AppLocalStorage.getString(_expiryKey);
    if (expiryStr.isEmpty) return null;
    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return null;
    return expiry.difference(DateTime.now()).inDays.clamp(0, 9999);
  }

  List<Map<String, String>> getSubscriptionPlans() {
    return [
      {'name': 'Free', 'duration': 'Forever', 'price': 'Free',
       'features': 'Basic scanning, local storage, PDF export'},
      {'name': 'Pro Monthly', 'duration': 'Monthly', 'price': '\$4.99',
       'features': 'Cloud backup, batch processing, priority support'},
      {'name': 'Pro Yearly', 'duration': 'Yearly', 'price': '\$39.99',
       'features': 'All Pro features + 2 months free'},
    ];
  }
}
