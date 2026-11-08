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

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Validates whether [value] matches standard UUID v4/canonical formatting.
  /// Prevents PostgreSQL 22P02 errors ('invalid input syntax for type uuid')
  /// when synthetic recommendation or item IDs (such as 'rec_1794205815811'
  /// or 'dairy_1') are passed into fields expecting genuine UUIDs.
  static bool isValidUuid(String? value) {
    if (value == null) return false;
    return _uuidRegex.hasMatch(value.trim());
  }

  static const Set<String> _knownUnits = {
    'g', 'gram', 'grams', 'kg', 'kilogram', 'kilograms',
    'ml', 'milliliter', 'milliliters', 'l', 'liter', 'liters', 'litre', 'litres',
    'piece', 'pieces', 'pc', 'pcs', 'slice', 'slices', 'cup', 'cups',
    'tbsp', 'tsp', 'bowl', 'bowls', 'medium', 'item', 'items',
    'serving', 'servings', 'portion', 'portions', 'pack', 'packs',
    'box', 'boxes', 'bottle', 'bottles', 'jar', 'jars', 'can', 'cans', 'tub', 'tubs',
  };

  /// Parses an ingredient string to safely separate the item name, numeric quantity, and unit.
  /// Prevents accidental quantity loss or defaulting to 1 for mass/volume items.
  static ParsedIngredient parseIngredientQuantity(String input) {
    final clean = input.trim();
    if (clean.isEmpty) {
      return const ParsedIngredient(name: '');
    }

    // 1. Parenthesized format: "Paneer (100g)", "Paneer (100 g)", "Milk (100 ml)", "Eggs (1 piece)"
    final parenMatch = RegExp(r'^(.*?)\s*\(\s*([0-9]+(?:\.[0-9]+)?)\s*([a-zA-Z]+)?\s*\)$').firstMatch(clean);
    if (parenMatch != null) {
      final name = parenMatch.group(1)!.trim();
      final qty = num.tryParse(parenMatch.group(2)!);
      final rawUnit = parenMatch.group(3)?.trim();
      return ParsedIngredient(name: name, quantity: qty, unit: rawUnit);
    }

    // 2. Prefix format: "100g Paneer", "100 g Paneer", "100ml Milk", "1 piece Egg", "2 Eggs"
    final prefixMatch = RegExp(r'^\s*([0-9]+(?:\.[0-9]+)?)\s*([a-zA-Z]+)?\s+(?:of\s+)?(.*?)$').firstMatch(clean);
    if (prefixMatch != null) {
      final qty = num.tryParse(prefixMatch.group(1)!);
      final rawWord = prefixMatch.group(2)?.trim();
      final rest = prefixMatch.group(3)!.trim();

      if (rawWord != null && _knownUnits.contains(rawWord.toLowerCase())) {
        return ParsedIngredient(name: rest, quantity: qty, unit: rawWord);
      } else if (rawWord != null) {
        final combinedName = rest.isNotEmpty ? '$rawWord $rest' : rawWord;
        return ParsedIngredient(name: combinedName, quantity: qty, unit: null);
      }
    }

    // 3. Postfix or colon format: "Paneer: 100g", "Paneer - 100 g", "Paneer 100g"
    final postfixMatch = RegExp(r'^(.*?)\s*[:\-–]\s*([0-9]+(?:\.[0-9]+)?)\s*([a-zA-Z]+)?$').firstMatch(clean);
    if (postfixMatch != null) {
      final name = postfixMatch.group(1)!.trim();
      final qty = num.tryParse(postfixMatch.group(2)!);
      final rawUnit = postfixMatch.group(3)?.trim();
      return ParsedIngredient(name: name, quantity: qty, unit: rawUnit);
    }

    // 4. Trailing quantity + unit: "Paneer 100g", "Milk 100ml"
    final trailingMatch = RegExp(r'^(.*?)\s+([0-9]+(?:\.[0-9]+)?)\s*([a-zA-Z]+)$').firstMatch(clean);
    if (trailingMatch != null) {
      final name = trailingMatch.group(1)!.trim();
      final qty = num.tryParse(trailingMatch.group(2)!);
      final rawUnit = trailingMatch.group(3)?.trim();
      if (rawUnit != null && _knownUnits.contains(rawUnit.toLowerCase())) {
        return ParsedIngredient(name: name, quantity: qty, unit: rawUnit);
      }
    }

    // 5. Unspecified quantity
    return ParsedIngredient(name: clean, quantity: null, unit: null);
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

    // Sanitize recipeId: PostgreSQL p_recipe_id column requires a valid UUID.
    // Synthetic recommendation IDs (e.g., 'rec_1794205815811') must NEVER be
    // passed to UUID fields, avoiding error 22P02.
    final validRecipeId = isValidUuid(recipeId) ? recipeId!.trim() : null;

    final sanitizedIngredients = ingredients.map((i) {
      final validMatchedId = isValidUuid(i.matchedFridgeItemId) ? i.matchedFridgeItemId!.trim() : null;
      return i.copyWith(matchedFridgeItemId: validMatchedId).toJson();
    }).toList();

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
      'p_recipe_id': validRecipeId,
      'p_image_url': imageUrl,
      'p_ingredients': sanitizedIngredients,
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

  /// Fetches only genuine meals logged during the current day (in client's local timezone).
  /// Boundaries are calculated locally and converted to UTC:
  /// timestamp >= startOfTodayUtc AND timestamp < startOfTomorrowUtc.
  Future<List<LoggedMealRecord>> fetchTodayMeals({
    String? userId,
    DateTime? clientTime,
  }) async {
    final effectiveUserId = userId ?? _currentUserId;
    if (effectiveUserId == null) return [];

    final now = clientTime ?? DateTime.now();
    final localStartOfToday = DateTime(now.year, now.month, now.day);
    final localStartOfTomorrow = localStartOfToday.add(const Duration(days: 1));

    final utcStart = localStartOfToday.toUtc();
    final utcEnd = localStartOfTomorrow.toUtc();

    try {
      final response = await _client
          .from('meals')
          .select()
          .eq('user_id', effectiveUserId)
          .gte('logged_at', utcStart.toIso8601String())
          .lt('logged_at', utcEnd.toIso8601String())
          .order('logged_at', ascending: true);

      final List<dynamic> rows = response as List<dynamic>;
      return rows
          .map((r) => LoggedMealRecord.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches genuine meals logged during yesterday (in client's local timezone)
  /// for accurate +/- vs yesterday wellness score calculations.
  Future<List<LoggedMealRecord>> fetchYesterdayMeals({
    String? userId,
    DateTime? clientTime,
  }) async {
    final effectiveUserId = userId ?? _currentUserId;
    if (effectiveUserId == null) return [];

    final now = clientTime ?? DateTime.now();
    final localStartOfToday = DateTime(now.year, now.month, now.day);
    final localStartOfYesterday = localStartOfToday.subtract(const Duration(days: 1));

    final utcStart = localStartOfYesterday.toUtc();
    final utcEnd = localStartOfToday.toUtc();

    try {
      final response = await _client
          .from('meals')
          .select()
          .eq('user_id', effectiveUserId)
          .gte('logged_at', utcStart.toIso8601String())
          .lt('logged_at', utcEnd.toIso8601String())
          .order('logged_at', ascending: true);

      final List<dynamic> rows = response as List<dynamic>;
      return rows
          .map((r) => LoggedMealRecord.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches genuine meals logged within a local date range [localStart, localEndExclusive).
  /// Automatically converts boundaries to UTC for database comparison.
  Future<List<LoggedMealRecord>> fetchMealsForDateRange({
    String? userId,
    required DateTime localStart,
    required DateTime localEndExclusive,
  }) async {
    final effectiveUserId = userId ?? _currentUserId;
    if (effectiveUserId == null) return [];

    final utcStart = localStart.toUtc();
    final utcEnd = localEndExclusive.toUtc();

    try {
      final response = await _client
          .from('meals')
          .select()
          .eq('user_id', effectiveUserId)
          .gte('logged_at', utcStart.toIso8601String())
          .lt('logged_at', utcEnd.toIso8601String())
          .order('logged_at', ascending: true);

      final List<dynamic> rows = response as List<dynamic>;
      return rows
          .map((r) => LoggedMealRecord.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
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
