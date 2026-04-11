class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();

  factory SubscriptionService() {
    return _instance;
  }

  SubscriptionService._internal();

  static SubscriptionService get instance => _instance;

  bool _isPremium = false;

  bool isPremium() => _isPremium;

  void setPremium(bool value) {
    _isPremium = value;
  }

  List<Map<String, String>> getSubscriptionPlans() {
    return [
      {
        'name': 'Free',
        'duration': 'Forever',
        'price': 'Free',
      },
      {
        'name': 'Pro',
        'duration': 'Monthly',
        'price': '\$4.99',
      },
      {
        'name': 'Pro',
        'duration': 'Yearly',
        'price': '\$39.99',
      },
    ];
  }
}
