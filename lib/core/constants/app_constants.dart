/// App-brede constanten en sleutels.
abstract final class AppConstants {
  static const String appName = 'Bitewise';

  // Edge Function namen (Supabase).
  static const String fnLookupProduct = 'lookup_product';

  // shared_preferences sleutels.
  static const String prefOnboardingComplete = 'onboarding_complete';
  static const String prefSyncEnabled = 'sync_enabled';
  static const String prefAnalyticsEnabled = 'analytics_enabled';
  static const String prefInstallId = 'install_id';
  static const String prefCalculatorProfile = 'calculator_profile';
  static const String prefSnackSwapUseDayContext = 'snackswap_use_day_context';

  // Voedingsstandaarden (per 100 g/ml tenzij anders vermeld).
  static const double defaultServingGrams = 100;
}
