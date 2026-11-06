import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/supabase_client.dart';
import '../auth/auth_service.dart';
import '../inventory/fridge_inventory_repository.dart';
import 'models/meal_models.dart';

/// Central database service for meal logging, daily nutrition tracking,
/// meal slot progression, and meal audit history using Supabase.
///
/// In compliance with architectural rules, all meal logging operations
/// are dispatched exclusively through the transactional PostgreSQL RPC
/// `public.log_meal_transaction(...)`. Direct client table mutations are denied.
class MealTrackingService {
  final SupabaseClient? _customClient;
  final AuthService? _customAuthService;

  MealTrackingService({
    SupabaseClient? client,
    AuthService? authService,
  })  : _customClient = client,
        _customAuthService = authService;

  static final MealTrackingService instance = MealTrackingService();

  SupabaseClient get _client {
    if (_customClient != null) return _customClient;
    return SupabaseManager.client;
  }

  AuthService get _authService => _customAuthService ?? AuthService.instance;

  String? get _currentUserId => _authService.currentUser?.id;

  /// Generates a concurrency-safe, unique idempotency key for meal logging attempts.
  static String generateIdempotencyKey() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(999999);
    return 'meal_${now}_$rand';
  }

  /// Normalizes incoming meal slot string to match database check constraint:
  /// ('breakfast', 'lunch', 'dinner', 'snack').
  static String normalizeMealSlot(String input) {
    final clean = input.trim().toLowerCase();
    if (clean.contains('breakfast')) return 'breakfast';
    if (clean.contains('lunch')) return 'lunch';
    if (clean.contains('dinner')) return 'dinner';
    if (clean.contains('snack')) return 'snack';
    throw ArgumentError(
      'Invalid meal_type: "$input". Allowed values are breakfast, lunch, snack, dinner.',
    );
  }

  /// Serializes and validates RPC parameters matching `public.log_meal_transaction`.
  static Map<String, dynamic> buildRpcParams({
    required String idempotencyKey,
    required String mealName,
    required String mealType,
    String servingSize = '1 serving',
    int? calories,
    int? proteinG,
    int? carbsG,
    int? fatG,
    int? fiberG,
    bool isEstimate = true,
    String nutritionSource = 'ai_estimate',
    String? recipeId,
    String? imageUrl,
    List<MealIngredientDeduction> ingredients = const [],
  }) {
    final trimmedKey = idempotencyKey.trim();
    if (trimmedKey.isEmpty) {
      throw ArgumentError('idempotency_key is required for meal logging');
    }

    final trimmedName = mealName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('meal_name is required and cannot be empty.');
    }

    final cleanSlot = normalizeMealSlot(mealType);

    return <String, dynamic>{
      'p_idempotency_key': trimmedKey,
      'p_meal_name': trimmedName,
      'p_meal_type': cleanSlot,
      'p_serving_size': servingSize.trim().isNotEmpty ? servingSize.trim() : '1 serving',
      'p_calories': calories,
      'p_protein_g': proteinG,
      'p_carbs_g': carbsG,
      'p_fat_g': fatG,
      'p_fiber_g': fiberG,
      'p_is_estimate': isEstimate,
      'p_nutrition_source': nutritionSource,
      'p_recipe_id': recipeId,
      'p_image_url': imageUrl,
      'p_ingredients': ingredients.map((i) => i.toJson()).toList(),
    };
  }

  /// Invokes the atomic PostgreSQL transaction `public.log_meal_transaction`.
  Future<MealTransactionResult> logMealTransaction({
    required String idempotencyKey,
    required String mealName,
    required String mealType,
    String servingSize = '1 serving',
    int? calories,
    int? proteinG,
    int? carbsG,
    int? fatG,
    int? fiberG,
    bool isEstimate = true,
    String nutritionSource = 'ai_estimate',
    String? recipeId,
    String? imageUrl,
    List<MealIngredientDeduction> ingredients = const [],
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('Cannot log meal: User is not authenticated.');
    }

    final params = buildRpcParams(
      idempotencyKey: idempotencyKey,
      mealName: mealName,
      mealType: mealType,
      servingSize: servingSize,
      calories: calories,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      fiberG: fiberG,
      isEstimate: isEstimate,
      nutritionSource: nutritionSource,
      recipeId: recipeId,
      imageUrl: imageUrl,
      ingredients: ingredients,
    );

    final response = await _client.rpc(
      'log_meal_transaction',
      params: params,
    );

    final Map<String, dynamic> resultMap = response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);

    return MealTransactionResult.fromJson(resultMap);
  }

  /// Fetches meal history from `public.meals`, scoped strictly to the authenticated user.
  Future<List<LoggedMealRecord>> fetchMealHistory({
    String? userId,
    DateTime? date,
    String? mealType,
    int limit = 50,
  }) async {
    final effectiveUserId = userId ?? _currentUserId;
    if (effectiveUserId == null) return [];

    var query = _client
        .from('meals')
        .select()
        .eq('user_id', effectiveUserId);

    if (date != null) {
      final dateStr = FridgeInventoryRepository.formatDate(date);
      if (dateStr != null) {
        query = query.eq('local_date', dateStr);
      }
    }

    if (mealType != null && mealType.trim().isNotEmpty) {
      final cleanSlot = normalizeMealSlot(mealType);
      query = query.eq('meal_type', cleanSlot);
    }

    final response = await query
        .order('logged_at', ascending: false)
        .limit(limit);

    final List<dynamic> rows = response as List<dynamic>;
    return rows
        .map((r) => LoggedMealRecord.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Fetches daily nutrition snapshot from `public.daily_nutrition_snapshots`.
  Future<DailyNutritionSnapshotRecord?> fetchDailyNutritionSnapshot({
    String? userId,
    DateTime? date,
  }) async {
    final effectiveUserId = userId ?? _currentUserId;
    if (effectiveUserId == null) return null;

    final targetDate = date ?? DateTime.now();
    final dateStr = FridgeInventoryRepository.formatDate(targetDate)!;

    try {
      final response = await _client
          .from('daily_nutrition_snapshots')
          .select()
          .eq('user_id', effectiveUserId)
          .eq('log_date', dateStr)
          .maybeSingle();

      if (response == null) return null;
      return DailyNutritionSnapshotRecord.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  /// Fetches completed meal slots from `public.daily_meal_slots`.
  Future<List<DailyMealSlotRecord>> fetchDailyMealSlots({
    String? userId,
    DateTime? date,
  }) async {
    final effectiveUserId = userId ?? _currentUserId;
    if (effectiveUserId == null) return [];

    final targetDate = date ?? DateTime.now();
    final dateStr = FridgeInventoryRepository.formatDate(targetDate)!;

    try {
      final response = await _client
          .from('daily_meal_slots')
          .select()
          .eq('user_id', effectiveUserId)
          .eq('log_date', dateStr);

      final List<dynamic> rows = response as List<dynamic>;
      return rows
          .map((r) => DailyMealSlotRecord.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches meal-related notifications from `public.app_notifications`.
  Future<List<AppNotificationRecord>> fetchMealNotifications({
    String? userId,
    int limit = 10,
  }) async {
    final effectiveUserId = userId ?? _currentUserId;
    if (effectiveUserId == null) return [];

    try {
      final response = await _client
          .from('app_notifications')
          .select()
          .eq('user_id', effectiveUserId)
          .eq('type', 'mealLogged')
          .order('created_at', ascending: false)
          .limit(limit);

      final List<dynamic> rows = response as List<dynamic>;
      return rows
          .map((r) => AppNotificationRecord.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
