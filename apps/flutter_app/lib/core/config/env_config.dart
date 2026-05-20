enum Environment { development, staging, production }

class EnvConfig {
  static late Environment _environment;
  static late String _supabaseUrl;
  static late String _supabaseAnonKey;
  static late String _livekitUrl;
  static late String _revenueCatApiKey;
  static late String _sentryDsn;
  static late String _posthogApiKey;

  static Environment get environment => _environment;
  static String get supabaseUrl => _supabaseUrl;
  static String get supabaseAnonKey => _supabaseAnonKey;
  static String get livekitUrl => _livekitUrl;
  static String get revenueCatApiKey => _revenueCatApiKey;
  static String get sentryDsn => _sentryDsn;
  static String get posthogApiKey => _posthogApiKey;

  // Feature flags
  static bool get isDevelopment => _environment == Environment.development;
  static bool get isProduction => _environment == Environment.production;
  static bool get enableVoiceChat => true;
  static bool get enableAds => _environment == Environment.production;
  static bool get enableAnalytics => _environment != Environment.development;

  static void initialize(Environment env) {
    _environment = env;

    switch (env) {
      case Environment.development:
        // Mac LAN IP — confirm with `ipconfig getifaddr en0` each session and
        // override at launch via --dart-define=SUPABASE_URL=http://<ip>:54321
        // if the Mac's IP has changed. Same applies to LIVEKIT_URL.
        _supabaseUrl = const String.fromEnvironment(
          'SUPABASE_URL',
          defaultValue: 'http://192.168.1.11:54321',
        );
        _supabaseAnonKey = 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH';
        _livekitUrl = const String.fromEnvironment(
          'LIVEKIT_URL',
          defaultValue: 'ws://192.168.1.11:7880',
        );
        _revenueCatApiKey = 'your-dev-rc-key';
        _sentryDsn = '';
        _posthogApiKey = '';
        break;
      case Environment.staging:
        // gameplatform-staging (project ref: toqtbqmhxmemixaumljz).
        // Anon key is public-by-design (RLS enforces auth at the row level)
        // so checking it in is intentional.
        _supabaseUrl = 'https://toqtbqmhxmemixaumljz.supabase.co';
        _supabaseAnonKey =
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRvcXRicW1oeG1lbWl4YXVtbGp6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkyMjY5OTQsImV4cCI6MjA5NDgwMjk5NH0.o2G4DioZk-QLLGziGi8CzPR15yx0Gnium_ZDpm1WO0A';
        _livekitUrl = 'wss://your-staging.livekit.cloud';
        _revenueCatApiKey = 'your-staging-rc-key';
        _sentryDsn = 'your-staging-sentry-dsn';
        _posthogApiKey = 'your-staging-posthog-key';
        break;
      case Environment.production:
        // gameplatform-prod (project ref: obtgysfcyenbfouvfixs).
        _supabaseUrl = 'https://obtgysfcyenbfouvfixs.supabase.co';
        _supabaseAnonKey =
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9idGd5c2ZjeWVuYmZvdXZmaXhzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkyMjcyNjEsImV4cCI6MjA5NDgwMzI2MX0.ruuz5-i1oZAnFCiMEC-lW3LL8I9b3DbTWRuGiqqNATY';
        _livekitUrl = 'wss://your-prod.livekit.cloud';
        _revenueCatApiKey = 'your-prod-rc-key';
        _sentryDsn = 'your-prod-sentry-dsn';
        _posthogApiKey = 'your-prod-posthog-key';
        break;
    }
  }
}
