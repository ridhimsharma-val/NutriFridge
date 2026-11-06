import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Centralized manager for the singleton Supabase client.
/// Guarantees that only a single instance is initialized and accessed across the app.
class SupabaseManager {
  static bool _isInitialized = false;

  /// Returns whether Supabase has completed initialization.
  static bool get isInitialized => _isInitialized;

  /// Global single-instance client getter.
  static SupabaseClient get client {
    if (!_isInitialized) {
      throw StateError(
        'SupabaseManager.client accessed before initialization. '
        'Ensure SupabaseManager.initialize() was called before runApp().',
      );
    }
    return Supabase.instance.client;
  }

  /// Initializes the centralized Supabase client using build-time configuration.
  static Future<void> initialize() async {
    if (_isInitialized) return;

    if (!SupabaseConfig.isConfigured) {
      // Configuration is missing or placeholder. Do not attempt network connection.
      return;
    }

    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      publishableKey: SupabaseConfig.supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );

    _isInitialized = true;
  }
}

/// Convenience top-level getter for the centralized Supabase client.
SupabaseClient get supabase => SupabaseManager.client;
