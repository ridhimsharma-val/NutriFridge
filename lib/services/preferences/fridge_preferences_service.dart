import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/supabase_client.dart';
import '../../screens/fridge/models/fridge_preferences.dart';
import '../auth/auth_service.dart';

/// Database service for persisting user's fridge personalization preferences in `public.fridge_preferences`.
class FridgePreferencesService {
  final SupabaseClient? _customClient;
  final AuthService? _customAuthService;

  FridgePreferencesService({
    SupabaseClient? client,
    AuthService? authService,
  })  : _customClient = client,
        _customAuthService = authService;

  static final FridgePreferencesService instance = FridgePreferencesService();

  SupabaseClient get _client {
    if (_customClient != null) return _customClient;
    return SupabaseManager.client;
  }

  AuthService get _authService => _customAuthService ?? AuthService.instance;

  String? get _currentUserId => _authService.currentUser?.id;

  /// Fetches saved fridge preferences for the user.
  Future<FridgePreferences?> fetchPreferences({String? userId}) async {
    final effectiveUserId = userId ?? _currentUserId;
    if (effectiveUserId == null) return null;

    try {
      final data = await _client
          .from('fridge_preferences')
          .select()
          .eq('user_id', effectiveUserId)
          .maybeSingle();

      if (data == null) return null;
      return mapRowToPreferences(data);
    } catch (_) {
      return null;
    }
  }

  /// Persists fridge preferences for the current user.
  Future<FridgePreferences> savePreferences(
    FridgePreferences preferences, {
    String? userId,
  }) async {
    final effectiveUserId = userId ?? _currentUserId;
    if (effectiveUserId == null) {
      throw StateError('Cannot save fridge preferences: User is not authenticated.');
    }

    final row = <String, dynamic>{
      'user_id': effectiveUserId,
      'exterior_color': preferences.exteriorColor.name,
      'freezer_position': preferences.freezerPosition.name,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final response = await _client
        .from('fridge_preferences')
        .upsert(row, onConflict: 'user_id')
        .select()
        .single();

    return mapRowToPreferences(response);
  }

  /// Serializes [FridgePreferences] to a database row map.
  static Map<String, dynamic> toPreferencesMap(
    FridgePreferences preferences, {
    String? userId,
  }) {
    final map = <String, dynamic>{
      'exterior_color': preferences.exteriorColor.name,
      'freezer_position': preferences.freezerPosition.name,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (userId != null) {
      map['user_id'] = userId;
    }
    return map;
  }

  /// Deserializes a database record map into [FridgePreferences].
  static FridgePreferences mapRowToPreferences(Map<String, dynamic> row) {
    final colorStr = row['exterior_color']?.toString() ?? 'midnightNavy';
    final freezerStr = row['freezer_position']?.toString() ?? 'top';

    final color = FridgeColorFinish.values.firstWhere(
      (e) => e.name == colorStr,
      orElse: () => FridgeColorFinish.midnightNavy,
    );

    final position = FreezerPosition.values.firstWhere(
      (e) => e.name == freezerStr,
      orElse: () => FreezerPosition.top,
    );

    return FridgePreferences(
      exteriorColor: color,
      freezerPosition: position,
    );
  }

  /// Alias for mapRowToPreferences.
  static FridgePreferences fromPreferencesMap(Map<String, dynamic> row) =>
      mapRowToPreferences(row);
}
