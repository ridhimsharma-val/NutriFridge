import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/supabase_client.dart';
import '../../screens/profile/models/user_profile_data.dart';
import '../auth/auth_service.dart';

/// Database service for synchronizing user profiles and nutrition goals
/// across `public.profiles` and `public.nutrition_goals`.
class ProfileService {
  final SupabaseClient? _customClient;
  final AuthService? _customAuthService;

  ProfileService({
    SupabaseClient? client,
    AuthService? authService,
  })  : _customClient = client,
        _customAuthService = authService;

  static final ProfileService instance = ProfileService();

  SupabaseClient get _client {
    if (_customClient != null) return _customClient;
    return SupabaseManager.client;
  }

  AuthService get _authService => _customAuthService ?? AuthService.instance;

  String? get _currentUserId => _authService.currentUser?.id;

  /// Fetches the user profile merged with their saved nutrition goals.
  Future<UserProfileData?> fetchProfileWithGoals({String? userId}) async {
    final effectiveUserId = userId ?? _currentUserId;
    if (effectiveUserId == null) return null;

    try {
      final profileRow = await _client
          .from('profiles')
          .select()
          .eq('id', effectiveUserId)
          .maybeSingle();

      if (profileRow == null) return null;

      final goalsRow = await _client
          .from('nutrition_goals')
          .select()
          .eq('user_id', effectiveUserId)
          .maybeSingle();

      int? targetCalories;
      if (goalsRow != null && goalsRow['target_calories'] != null) {
        targetCalories = (goalsRow['target_calories'] as num).toInt();
      }

      return mapDatabaseToProfile(profileRow, targetCalories: targetCalories);
    } catch (_) {
      return null;
    }
  }

  /// Serializes a [UserProfileData] into a map suitable for `public.profiles`.
  static Map<String, dynamic> toProfileMap(UserProfileData profile) {
    return <String, dynamic>{
      'display_name': profile.displayName.trim().isNotEmpty
          ? profile.displayName.trim()
          : 'Food Explorer',
      'dietary_preference': profile.dietaryPreference,
      'nutrition_goal': profile.nutritionGoal,
      'allergies': profile.allergies.toList(),
      'avoided_foods': profile.avoidedFoods.toList(),
      'custom_restrictions': profile.customRestrictions,
      'meal_reminders_enabled': profile.mealRemindersEnabled,
      'expiry_alerts_enabled': profile.expiryAlertsEnabled,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Builds a map for `public.nutrition_goals` with valid bounds checking.
  static Map<String, dynamic> toNutritionGoalsMap({
    required int targetCalories,
    int proteinTargetG = 90,
    int carbsTargetG = 260,
    int fatTargetG = 70,
    String? userId,
  }) {
    final clampedCalories = targetCalories.clamp(500, 10000);
    final validProtein = proteinTargetG < 0 ? 0 : proteinTargetG;
    final validCarbs = carbsTargetG < 0 ? 0 : carbsTargetG;
    final validFat = fatTargetG < 0 ? 0 : fatTargetG;

    final map = <String, dynamic>{
      'target_calories': clampedCalories,
      'protein_target_g': validProtein,
      'carbs_target_g': validCarbs,
      'fat_target_g': validFat,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (userId != null) {
      map['user_id'] = userId;
    }
    return map;
  }

  /// Updates permitted fields in `public.profiles` and `public.nutrition_goals`.
  Future<void> saveProfileWithGoals(
    UserProfileData profile, {
    String? userId,
  }) async {
    final effectiveUserId = userId ?? _currentUserId;
    if (effectiveUserId == null) {
      throw StateError('Cannot save profile: User is not authenticated.');
    }

    // 1. Update permitted profile fields in public.profiles
    final profileUpdates = toProfileMap(profile);

    await _client
        .from('profiles')
        .update(profileUpdates)
        .eq('id', effectiveUserId);

    // 2. If calorie target is provided, persist to public.nutrition_goals
    if (profile.dailyCalorieTarget != null) {
      final goalsMap = toNutritionGoalsMap(
        targetCalories: profile.dailyCalorieTarget!,
        userId: effectiveUserId,
      );
      await _client.from('nutrition_goals').upsert(goalsMap, onConflict: 'user_id');
    }
  }

  /// Fetches raw nutrition goals row from `public.nutrition_goals`.
  Future<Map<String, dynamic>?> fetchNutritionGoals({String? userId}) async {
    final effectiveUserId = userId ?? _currentUserId;
    if (effectiveUserId == null) return null;

    try {
      return await _client
          .from('nutrition_goals')
          .select()
          .eq('user_id', effectiveUserId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  /// Saves nutrition goals to `public.nutrition_goals`.
  Future<void> saveNutritionGoals({
    required int targetCalories,
    int proteinTargetG = 90,
    int carbsTargetG = 260,
    int fatTargetG = 70,
    String? userId,
  }) async {
    final effectiveUserId = userId ?? _currentUserId;
    if (effectiveUserId == null) {
      throw StateError('Cannot save nutrition goals: User is not authenticated.');
    }

    final goalsMap = toNutritionGoalsMap(
      targetCalories: targetCalories,
      proteinTargetG: proteinTargetG,
      carbsTargetG: carbsTargetG,
      fatTargetG: fatTargetG,
      userId: effectiveUserId,
    );

    await _client.from('nutrition_goals').upsert(goalsMap, onConflict: 'user_id');
  }

  /// Maps database profile map and target calories to [UserProfileData].
  static UserProfileData mapDatabaseToProfile(
    Map<String, dynamic> row, {
    int? targetCalories,
  }) {
    final allergiesRaw = row['allergies'];
    final avoidedRaw = row['avoided_foods'];
    final customRaw = row['custom_restrictions'];

    Set<String> allergies = {};
    if (allergiesRaw is List) {
      allergies = allergiesRaw.map((e) => e.toString()).toSet();
    }

    Set<String> avoidedFoods = {};
    if (avoidedRaw is List) {
      avoidedFoods = avoidedRaw.map((e) => e.toString()).toSet();
    }

    List<String> customRestrictions = [];
    if (customRaw is List) {
      customRestrictions = customRaw.map((e) => e.toString()).toList();
    }

    return UserProfileData(
      displayName: row['display_name']?.toString() ?? 'Food Explorer',
      dietaryPreference: row['dietary_preference']?.toString(),
      nutritionGoal: row['nutrition_goal']?.toString(),
      dailyCalorieTarget: targetCalories,
      allergies: allergies,
      avoidedFoods: avoidedFoods,
      customRestrictions: customRestrictions,
      mealRemindersEnabled: row['meal_reminders_enabled'] as bool? ?? false,
      expiryAlertsEnabled: row['expiry_alerts_enabled'] as bool? ?? false,
    );
  }
}
