/// Environment wiring for the admin console.
///
/// Defaults target the **local** Supabase stack so `flutter run -d chrome`
/// works out of the box against a running `supabase start`. Point at staging
/// (or prod) by overriding the dart-defines:
///
///   flutter run -d chrome \
///     --dart-define=SUPABASE_URL=https://toqtbqmhxmemixaumljz.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=<staging anon key>
///
/// The anon key is public-by-design (RLS + admin-gated edge functions enforce
/// authorization server-side), so shipping a default is safe.
class AdminConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://127.0.0.1:54321',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
  );

  /// Human-readable label for the header, derived from the URL host.
  static String get envLabel {
    if (supabaseUrl.contains('127.0.0.1') || supabaseUrl.contains('localhost')) {
      return 'LOCAL';
    }
    if (supabaseUrl.contains('toqtbqmhxmemixaumljz')) return 'STAGING';
    if (supabaseUrl.contains('obtgysfcyenbfouvfixs')) return 'PRODUCTION';
    return 'CUSTOM';
  }
}
