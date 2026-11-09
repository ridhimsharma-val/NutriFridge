/// Configuration loader for Supabase credentials.
/// Reads values injected at compile time via `--dart-define-from-file=supabase.dev.json`.
class SupabaseConfig {
  static const String _defaultUrl = 'https://kmwagsheagttauoqbzom.supabase.co';
  static const String _defaultPublishableKey = 'sb_publishable_VulEz4DcZc5K7dEMZHSceQ_AA8pI4r-';

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: _defaultUrl);
  static const String supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: _defaultPublishableKey);

  /// Returns true if valid configuration has been injected.
  static bool get isConfigured {
    if (supabaseUrl.trim().isEmpty || supabasePublishableKey.trim().isEmpty) {
      return false;
    }
    // Reject dummy template values
    if (supabaseUrl.contains('your-project') ||
        supabasePublishableKey.contains('your-publishable-key') ||
        supabasePublishableKey.trim() == 'YOUR_SUPABASE_PUBLISHABLE_KEY') {
      return false;
    }
    return true;
  }

  /// Returns a descriptive error message if configuration is missing or invalid.
  static String? get configurationError {
    if (supabaseUrl.trim().isEmpty && supabasePublishableKey.trim().isEmpty) {
      return 'Missing Supabase credentials.\n\n'
          'Please run the app with build-time configuration:\n'
          'flutter run --dart-define-from-file=supabase.dev.json\n\n'
          'Ensure supabase.dev.json contains SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.';
    }
    if (supabaseUrl.trim().isEmpty) {
      return 'SUPABASE_URL is missing in build-time configuration.';
    }
    if (supabasePublishableKey.trim().isEmpty ||
        supabasePublishableKey.trim() == 'YOUR_SUPABASE_PUBLISHABLE_KEY' ||
        supabasePublishableKey.contains('your-publishable-key')) {
      return 'SUPABASE_PUBLISHABLE_KEY is not configured.\n'
          'Please set your real publishable/anon key in supabase.dev.json.';
    }
    return null;
  }
}
