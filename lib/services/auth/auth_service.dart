import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/supabase_client.dart';
import '../sync/user_data_sync_service.dart';

/// Centralized authentication service for NutriFridge using Supabase Auth.
/// Provides email/password signup, login, password recovery, session restore,
/// and profile retrieval without exposing technical stack traces.
class AuthService {
  final SupabaseClient? _customClient;

  AuthService({SupabaseClient? client}) : _customClient = client;

  /// Default singleton instance accessing the centralized Supabase client.
  static final AuthService instance = AuthService();

  /// Optional override for testing purposes.
  static bool? testAuthenticatedOverride;

  SupabaseClient get _client {
    if (_customClient != null) return _customClient;
    return SupabaseManager.client;
  }

  GoTrueClient get _auth => _client.auth;

  /// Currently authenticated user, or null if unauthenticated.
  User? get currentUser {
    if (testAuthenticatedOverride != null) return null;
    if (!SupabaseManager.isInitialized && _customClient == null) return null;
    return _auth.currentUser;
  }

  /// Current session, or null if not signed in.
  Session? get currentSession {
    if (testAuthenticatedOverride != null) return null;
    if (!SupabaseManager.isInitialized && _customClient == null) return null;
    return _auth.currentSession;
  }

  /// Whether there is an active authenticated session.
  bool get isAuthenticated {
    if (testAuthenticatedOverride != null) return testAuthenticatedOverride!;
    return currentSession != null;
  }

  /// Real-time authentication state change stream.
  Stream<AuthState> get onAuthStateChange {
    if (!SupabaseManager.isInitialized && _customClient == null) {
      return const Stream.empty();
    }
    return _auth.onAuthStateChange;
  }

  /// Registers a new user with email, password, and full name.
  /// User full name is stored in auth metadata under `full_name`, which is picked up
  /// by the PostgreSQL `handle_new_user()` trigger to automatically create profiles,
  /// nutrition_goals, and fridge_preferences.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
        },
      );
      return response;
    } on AuthException catch (e) {
      throw AuthFailure(formatAuthError(e.message));
    } catch (e) {
      throw AuthFailure('An unexpected error occurred during registration. Please try again.');
    }
  }

  /// Authenticates an existing user using email and password.
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      throw AuthFailure(formatAuthError(e.message));
    } catch (e) {
      throw AuthFailure('Unable to connect to the authentication service. Please check your connection.');
    }
  }

  /// Signs out the currently authenticated user.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on AuthException catch (e) {
      throw AuthFailure(formatAuthError(e.message));
    } catch (_) {
      // Allow sign out to succeed locally even on network failure
    } finally {
      UserDataSyncService.clearAllUserDataForLogout();
    }
  }

  /// Sends a password reset email with the deep link redirect URL.
  Future<void> resetPasswordForEmail(
    String email, {
    String redirectTo = 'nutrifridge://auth-callback',
  }) async {
    try {
      await _auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: redirectTo,
      );
    } on AuthException catch (e) {
      throw AuthFailure(formatAuthError(e.message));
    } catch (e) {
      throw AuthFailure('Unable to send password reset email. Please try again.');
    }
  }

  /// Updates the password for the currently authenticated user (used during password recovery).
  Future<UserResponse> updatePassword(String newPassword) async {
    try {
      final response = await _auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return response;
    } on AuthException catch (e) {
      throw AuthFailure(formatAuthError(e.message));
    } catch (e) {
      throw AuthFailure('Failed to update password. Please request a new reset link.');
    }
  }

  /// Retrieves the authenticated user's profile from `public.profiles`.
  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return data;
    } catch (e) {
      return null;
    }
  }

  /// Updates permitted fields in the user's profile.
  Future<void> updateProfile({
    required String userId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      await _client
          .from('profiles')
          .update(updates)
          .eq('id', userId);
    } on PostgrestException catch (e) {
      throw AuthFailure('Could not update profile: ${e.message}');
    } catch (e) {
      throw AuthFailure('An unexpected error occurred while saving profile changes.');
    }
  }

  /// Maps raw technical Supabase errors to clean, user-friendly descriptions.
  static String formatAuthError(String rawMessage) {
    final lower = rawMessage.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials')) {
      return 'Incorrect email or password. Please check your credentials and try again.';
    }
    if (lower.contains('email not confirmed') ||
        lower.contains('email_not_confirmed')) {
      return 'Please verify your email address before signing in. Check your inbox for the confirmation email.';
    }
    if (lower.contains('user already registered') ||
        lower.contains('already_registered')) {
      return 'An account with this email address already exists. Please sign in instead.';
    }
    if (lower.contains('password should be at least')) {
      return 'Password must be at least 8 characters long.';
    }
    if (lower.contains('rate limit') || lower.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (lower.contains('network') || lower.contains('socket') || lower.contains('failed to fetch')) {
      return 'Network connection error. Please check your internet connection.';
    }
    return rawMessage;
  }
}

/// Domain exception for authentication failures with human-readable messaging.
class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);

  @override
  String toString() => message;
}
