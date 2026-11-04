import 'package:flutter/foundation.dart';
import '../../../models/nutrition_data.dart';
import '../../ai_assistant/services/ai_assistant_service.dart';
import '../../fridge/models/category_item.dart';
import '../../profile/models/user_profile_data.dart';

/// Supported recommendation lifecycle states.
enum RecommendationStatus {
  empty, // Fridge has zero items
  loading, // Fetching recommendation asynchronously
  loaded, // Valid recommendation available
  noMatch, // Items in fridge, but no reasonable recipe match found
  error, // Backend or network error (retry state)
}

/// Supported meal time slots for dynamic recommendations.
enum MealTimeSlot {
  breakfast,
  lunch,
  snack,
  dinner;

  String get displayName {
    switch (this) {
      case MealTimeSlot.breakfast:
        return 'Breakfast';
      case MealTimeSlot.lunch:
        return 'Lunch';
      case MealTimeSlot.snack:
        return 'Snack';
      case MealTimeSlot.dinner:
        return 'Dinner';
    }
  }

  String get badgeLabel => displayName.toUpperCase();
}

/// Centralized registry mapping recipe identities and meal names to photographic food assets.
class MealImageRegistry {
  static const Map<String, String> _imageMap = {
    'paneer_rice_bowl': 'assets/images/paneer_rice_bowl.jpg',
    'dal_rice': 'assets/images/foods/dal_rice.jpg',
    'vegetable_pulao': 'assets/images/foods/dal_rice.jpg',
    'vegetable_khichdi': 'assets/images/foods/dal_rice.jpg',
    'paneer_curry': 'assets/images/foods/paneer_curry.jpg',
    'paneer_capsicum_curry': 'assets/images/foods/paneer_curry.jpg',
    'stir_fried_veggies': 'assets/images/foods/paneer_curry.jpg',
    'pasta': 'assets/images/foods/pasta.jpg',
    'veggie_pasta': 'assets/images/foods/pasta.jpg',
    'hearty_vegetable_pasta': 'assets/images/foods/pasta.jpg',
    'chicken': 'assets/images/foods/chicken.jpg',
    'grilled_chicken': 'assets/images/foods/chicken.jpg',
    'chicken_salad': 'assets/images/foods/chicken.jpg',
    'fish': 'assets/images/foods/fish.jpg',
    'pan_seared_fish': 'assets/images/foods/fish.jpg',
    'eggs': 'assets/images/foods/eggs.jpg',
    'egg_toast': 'assets/images/foods/eggs.jpg',
    'scrambled_eggs': 'assets/images/foods/eggs.jpg',
    'banana': 'assets/images/foods/banana.jpg',
    'banana_smoothie': 'assets/images/foods/banana.jpg',
    'banana_oat_smoothie': 'assets/images/foods/banana.jpg',
    'oats_banana': 'assets/images/foods/banana.jpg',
    'fruit_bowl': 'assets/images/foods/apple.jpg',
    'apple_slices': 'assets/images/foods/apple.jpg',
    'peanut_butter_apple': 'assets/images/foods/peanut_butter.jpg',
    'vegetable_sandwich': 'assets/images/foods/bread.jpg',
    'toast': 'assets/images/foods/bread.jpg',
    'yogurt_bowl': 'assets/images/foods/curd.png',
    'fruit_yogurt_bowl': 'assets/images/foods/curd.png',
    'energy_mix': 'assets/images/foods/dry_fruits_mix.jpg',
    'nut_dry_fruit_mix': 'assets/images/foods/dry_fruits_mix.jpg',
  };

  static String resolveImage({
    String? imageKey,
    String? mealName,
    String? providedUrl,
  }) {
    if (providedUrl != null && providedUrl.isNotEmpty) {
      if (providedUrl.startsWith('assets/')) return providedUrl;
    }
    if (imageKey != null && imageKey.isNotEmpty) {
      final clean = imageKey.toLowerCase().trim().replaceAll('-', '_');
      if (_imageMap.containsKey(clean)) return _imageMap[clean]!;
      if (clean.startsWith('assets/')) return imageKey;
    }
    final name = (mealName ?? '').toLowerCase();
    if (name.contains('rice') && name.contains('paneer')) return 'assets/images/paneer_rice_bowl.jpg';
    if (name.contains('dal') || name.contains('pulao') || name.contains('khichdi')) {
      return 'assets/images/foods/dal_rice.jpg';
    }
    if (name.contains('curry') || name.contains('stir-fried') || name.contains('paneer')) {
      return 'assets/images/foods/paneer_curry.jpg';
    }
    if (name.contains('pasta')) return 'assets/images/foods/pasta.jpg';
    if (name.contains('chicken')) return 'assets/images/foods/chicken.jpg';
    if (name.contains('fish')) return 'assets/images/foods/fish.jpg';
    if (name.contains('egg') || name.contains('scramble') || name.contains('omelet')) {
      return 'assets/images/foods/eggs.jpg';
    }
    if (name.contains('smoothie') || name.contains('banana') || name.contains('oat')) {
      return 'assets/images/foods/banana.jpg';
    }
    if (name.contains('peanut butter')) return 'assets/images/foods/peanut_butter.jpg';
    if (name.contains('fruit') || name.contains('apple')) return 'assets/images/foods/apple.jpg';
    if (name.contains('sandwich') || name.contains('bread') || name.contains('toast')) {
      return 'assets/images/foods/bread.jpg';
    }
    if (name.contains('yogurt') || name.contains('curd')) return 'assets/images/foods/curd.png';
    if (name.contains('nut') || name.contains('dry fruit')) return 'assets/images/foods/dry_fruits_mix.jpg';
    return 'assets/images/paneer_rice_bowl.jpg';
  }
}

/// Definition of a recipe available for inventory-aware dynamic recommendations.
class MealRecipeDefinition {
  final String id;
  final String title;
  final List<MealTimeSlot> suitableSlots;
  final String imageUrl;
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final int prepTimeMinutes;
  final List<String> requiredIngredients;
  final List<String> optionalPantryIngredients;
  final bool isVegetarian;
  final bool isVegan;
  final List<String> allergens;
  final List<String> searchKeywords;

  const MealRecipeDefinition({
    required this.id,
    required this.title,
    required this.suitableSlots,
    required this.imageUrl,
    required this.calories,
    required this.proteinGrams,
    this.carbsGrams = 45,
    this.fatGrams = 15,
    this.prepTimeMinutes = 15,
    required this.requiredIngredients,
    this.optionalPantryIngredients = const [],
    this.isVegetarian = true,
    this.isVegan = false,
    this.allergens = const [],
    this.searchKeywords = const [],
  });
}

/// Dynamic, time-aware and inventory-aware meal recommendation service.
class MealRecommendationService {
  /// Testable clock provider allowing controlled time injection in tests.
  static DateTime Function() currentTimeProvider = DateTime.now;

  /// Resets clock provider to system wall clock.
  static void resetClock() {
    currentTimeProvider = DateTime.now;
  }

  // --- Reactive State Notifiers ---
  static final ValueNotifier<RecommendationStatus> statusNotifier =
      ValueNotifier<RecommendationStatus>(RecommendationStatus.empty);

  static final ValueNotifier<RecipeRecommendation?> recommendationNotifier =
      ValueNotifier<RecipeRecommendation?>(null);

  static RecommendationStatus _currentStatus = RecommendationStatus.empty;
  static RecommendationStatus get currentStatus => _currentStatus;

  static RecipeRecommendation? _currentRecommendation;
  static RecipeRecommendation? get currentRecommendation => _currentRecommendation;

  static String? _errorMessage;
  static String? get errorMessage => _errorMessage;

  // --- In-flight & Caching State ---
  static bool _isFetching = false;
  static int _fetchCallCount = 0;
  static int get fetchCallCount => _fetchCallCount;

  static MealTimeSlot? _cachedSlot;
  static String? _cachedInventoryFingerprint;
  static String? _cachedProfileFingerprint;

  static bool _inventoryListenerAttached = false;

  /// Attaches listener to FridgeCategoryRepository to invalidate cache and refresh on inventory changes
  static void ensureInitialized() {
    if (!_inventoryListenerAttached) {
      _inventoryListenerAttached = true;
      FridgeCategoryRepository.notifier.addListener(_onInventoryChanged);
    }
  }

  static void _onInventoryChanged() {
    if (FridgeCategoryRepository.totalFridgeItems == 0) {
      _currentRecommendation = null;
      _currentStatus = RecommendationStatus.empty;
      _cachedInventoryFingerprint = null;
      statusNotifier.value = RecommendationStatus.empty;
      recommendationNotifier.value = null;
      return;
    }

    final newFingerprint = _generateInventoryFingerprint();
    if (newFingerprint != _cachedInventoryFingerprint) {
      // Invalidate cache and re-fetch recommendation
      _cachedInventoryFingerprint = null;
      fetchRecommendation();
    }
  }

  /// Determines the relevant meal time slot for a given timestamp.
  /// Configurable windows:
  /// - Morning (05:00 - 10:59): Breakfast
  /// - Afternoon (11:00 - 14:59): Lunch
  /// - Evening / Snacks (15:00 - 18:29): Snack
  /// - Night (18:30 - 22:59): Dinner
  /// - Late-night (23:00 - 04:59): Upcoming Breakfast
  static MealTimeSlot getMealTimeSlot([DateTime? time]) {
    final dt = time ?? currentTimeProvider();
    final totalMinutes = dt.hour * 60 + dt.minute;

    if (totalMinutes >= 300 && totalMinutes < 660) {
      return MealTimeSlot.breakfast;
    } else if (totalMinutes >= 660 && totalMinutes < 900) {
      return MealTimeSlot.lunch;
    } else if (totalMinutes >= 900 && totalMinutes < 1110) {
      return MealTimeSlot.snack;
    } else if (totalMinutes >= 1110 && totalMinutes < 1380) {
      return MealTimeSlot.dinner;
    } else {
      // Late night (23:00–04:59): Recommend upcoming breakfast
      return MealTimeSlot.breakfast;
    }
  }

  /// Alias for test readability
  static MealTimeSlot determineMealSlot([DateTime? time]) => getMealTimeSlot(time);

  /// Checks if given time is in late-night upcoming breakfast window
  static bool isLateNightWindow([DateTime? time]) {
    final dt = time ?? currentTimeProvider();
    final totalMinutes = dt.hour * 60 + dt.minute;
    return totalMinutes < 300 || totalMinutes >= 1380;
  }

  static String _generateInventoryFingerprint() {
    final items = <String>[];
    for (final cat in FridgeCategoryRepository.canonicalCategories) {
      final catData = FridgeCategoryRepository.getCategoryData(cat);
      for (final it in catData.items) {
        items.add('${it.name}_${it.quantity}_${it.expiryDays}');
      }
    }
    items.sort();
    return items.join('|');
  }

  static String _generateProfileFingerprint() {
    final p = MockDataRepository.profile;
    return '${p.dietaryPreference}_${p.nutritionGoal}_${p.allergies.join(',')}_${p.avoidedFoods.join(',')}';
  }

  /// Asynchronously fetches an inventory-aware recommendation from Gemini/n8n backend
  /// or falls back cleanly to local dynamic catalog matching.
  static Future<RecipeRecommendation?> fetchRecommendation({
    bool forceRefresh = false,
    DateTime? time,
  }) async {
    ensureInitialized();

    // 1. Emptiness Check: Fridge contains zero items
    if (FridgeCategoryRepository.totalFridgeItems == 0) {
      _currentRecommendation = null;
      _currentStatus = RecommendationStatus.empty;
      _errorMessage = null;
      _cachedSlot = null;
      _cachedInventoryFingerprint = null;
      _cachedProfileFingerprint = null;
      statusNotifier.value = RecommendationStatus.empty;
      recommendationNotifier.value = null;
      return null;
    }

    final slot = getMealTimeSlot(time);
    final invFingerprint = _generateInventoryFingerprint();
    final profileFingerprint = _generateProfileFingerprint();

    // 2. Cache Validation
    if (!forceRefresh &&
        _currentRecommendation != null &&
        _cachedSlot == slot &&
        _cachedInventoryFingerprint == invFingerprint &&
        _cachedProfileFingerprint == profileFingerprint) {
      _currentStatus = RecommendationStatus.loaded;
      statusNotifier.value = RecommendationStatus.loaded;
      return _currentRecommendation;
    }

    // 3. Prevent duplicate simultaneous in-flight requests (TEST 12)
    if (_isFetching) {
      return _currentRecommendation;
    }

    _isFetching = true;
    _fetchCallCount++;
    _currentStatus = RecommendationStatus.loading;
    statusNotifier.value = RecommendationStatus.loading;

    try {
      final now = time ?? currentTimeProvider();
      final inventoryContext = AiAssistantService.getInventoryContext();
      final userPreferences = AiAssistantService.getProfilePreferences();
      final nutritionContext = AiAssistantService.getNutritionContext();

      final requestPayload = {
        'actionHint': 'meal_recommendation',
        'message': 'Generate a meal recommendation for ${slot.displayName} based on current fridge inventory.',
        'currentMealPeriod': slot.displayName,
        'clientLocalTime': now.toIso8601String(),
        'inventoryContext': inventoryContext,
        'userPreferences': userPreferences,
        'todayNutrition': nutritionContext,
      };

      Map<String, dynamic> response;
      if (AiAssistantService.mockHandler != null) {
        response = await AiAssistantService.mockHandler!(requestPayload);
      } else {
        response = await AiAssistantService.sendRequest(
          message: requestPayload['message'] as String,
          actionHint: 'meal_recommendation',
        );
      }

      // 4. Handle Backend failure (TEST 11)
      if (response['success'] == false ||
          response['ok'] == false ||
          response['action'] == 'error' ||
          (response['error'] != null && response['meal'] == null)) {
        _currentRecommendation = null;
        _currentStatus = RecommendationStatus.error;
        _errorMessage = response['assistantMessage'] as String? ??
            response['error'] as String? ??
            'Unable to reach NutriFridge AI. Please check your connection and tap retry.';
        statusNotifier.value = RecommendationStatus.error;
        recommendationNotifier.value = null;
        _isFetching = false;
        return null;
      }

      // 5. Parse backend structured meal recommendation
      if (response['meal'] != null && response['meal'] is Map) {
        final mealJson = Map<String, dynamic>.from(response['meal'] as Map);
        final rec = RecipeRecommendation.fromJson(mealJson);

        _currentRecommendation = rec;
        _currentStatus = RecommendationStatus.loaded;
        _errorMessage = null;
        _cachedSlot = slot;
        _cachedInventoryFingerprint = invFingerprint;
        _cachedProfileFingerprint = profileFingerprint;
        statusNotifier.value = RecommendationStatus.loaded;
        recommendationNotifier.value = rec;
        _isFetching = false;
        return rec;
      }

      // 6. Handle no match condition
      if (response['action'] == 'no_match' || response['noMatch'] == true) {
        _currentRecommendation = null;
        _currentStatus = RecommendationStatus.noMatch;
        _errorMessage = response['assistantMessage'] as String? ??
            "We couldn't find a suitable meal with your current ingredients.";
        statusNotifier.value = RecommendationStatus.noMatch;
        recommendationNotifier.value = null;
        _isFetching = false;
        return null;
      }

      // 7. Dynamic local catalog fallback (for offline or unhandled mock actions)
      final localRec = _computeLocalRecommendation(slot);
      if (localRec != null) {
        _currentRecommendation = localRec;
        _currentStatus = RecommendationStatus.loaded;
        _errorMessage = null;
        _cachedSlot = slot;
        _cachedInventoryFingerprint = invFingerprint;
        _cachedProfileFingerprint = profileFingerprint;
        statusNotifier.value = RecommendationStatus.loaded;
        recommendationNotifier.value = localRec;
      } else {
        _currentRecommendation = null;
        _currentStatus = RecommendationStatus.noMatch;
        statusNotifier.value = RecommendationStatus.noMatch;
        recommendationNotifier.value = null;
      }
      _isFetching = false;
      return _currentRecommendation;
    } catch (e) {
      _currentStatus = RecommendationStatus.error;
      _errorMessage = 'Unable to reach NutriFridge AI. Please check your connection and tap retry.';
      statusNotifier.value = RecommendationStatus.error;
      _isFetching = false;
      return null;
    }
  }

  /// Synchronous recommendation resolver
  static RecipeRecommendation? getRecommendation({DateTime? time}) {
    ensureInitialized();

    if (FridgeCategoryRepository.totalFridgeItems == 0) {
      _currentStatus = RecommendationStatus.empty;
      return null;
    }

    if (_currentStatus == RecommendationStatus.error ||
        _currentStatus == RecommendationStatus.noMatch) {
      return null;
    }

    if (_currentRecommendation != null) {
      return _currentRecommendation;
    }

    final slot = getMealTimeSlot(time);
    final localRec = _computeLocalRecommendation(slot);
    if (localRec != null) {
      _currentRecommendation = localRec;
      _currentStatus = RecommendationStatus.loaded;
      _cachedSlot = slot;
      _cachedInventoryFingerprint = _generateInventoryFingerprint();
      _cachedProfileFingerprint = _generateProfileFingerprint();
      return localRec;
    }
    return null;
  }

  /// Resets recommendation engine back to initial state (for tests)
  static void reset() {
    _currentRecommendation = null;
    _currentStatus = FridgeCategoryRepository.totalFridgeItems == 0
        ? RecommendationStatus.empty
        : RecommendationStatus.loading;
    _errorMessage = null;
    _isFetching = false;
    _fetchCallCount = 0;
    _cachedSlot = null;
    _cachedInventoryFingerprint = null;
    _cachedProfileFingerprint = null;
    statusNotifier.value = _currentStatus;
    recommendationNotifier.value = null;
    resetClock();
  }

  // --- Dynamic Recipe Catalog & Scorer ---

  static const List<MealRecipeDefinition> recipeCatalog = [
    // --- BREAKFAST ---
    MealRecipeDefinition(
      id: 'rec_banana_smoothie',
      title: 'Banana Oat Smoothie',
      suitableSlots: [MealTimeSlot.breakfast, MealTimeSlot.snack],
      imageUrl: 'assets/images/foods/banana.jpg',
      calories: 320,
      proteinGrams: 12,
      carbsGrams: 58,
      fatGrams: 6,
      prepTimeMinutes: 5,
      requiredIngredients: ['Banana', 'Milk'],
      optionalPantryIngredients: ['Almonds', 'Honey'],
      isVegetarian: true,
      isVegan: false,
      allergens: ['dairy', 'nuts'],
      searchKeywords: ['banana', 'milk', 'smoothie', 'oat'],
    ),
    MealRecipeDefinition(
      id: 'rec_scrambled_eggs',
      title: 'Scrambled Eggs & Toast',
      suitableSlots: [MealTimeSlot.breakfast],
      imageUrl: 'assets/images/foods/eggs.jpg',
      calories: 360,
      proteinGrams: 22,
      carbsGrams: 26,
      fatGrams: 16,
      prepTimeMinutes: 10,
      requiredIngredients: ['Eggs', 'Bread', 'Butter'],
      optionalPantryIngredients: ['Tomato', 'Milk'],
      isVegetarian: false,
      isVegan: false,
      allergens: ['eggs', 'gluten', 'dairy'],
      searchKeywords: ['eggs', 'bread', 'butter', 'egg', 'toast'],
    ),
    MealRecipeDefinition(
      id: 'rec_pb_banana_toast',
      title: 'Peanut Butter Banana Toast',
      suitableSlots: [MealTimeSlot.breakfast, MealTimeSlot.snack],
      imageUrl: 'assets/images/foods/peanut_butter.jpg',
      calories: 340,
      proteinGrams: 14,
      carbsGrams: 48,
      fatGrams: 12,
      prepTimeMinutes: 5,
      requiredIngredients: ['Banana', 'Bread', 'Peanut Butter'],
      optionalPantryIngredients: ['Honey'],
      isVegetarian: true,
      isVegan: true,
      allergens: ['gluten', 'nuts', 'peanuts'],
      searchKeywords: ['banana', 'bread', 'peanut butter', 'toast'],
    ),
    MealRecipeDefinition(
      id: 'rec_fruit_yogurt_bowl',
      title: 'Fruit & Yogurt Bowl',
      suitableSlots: [MealTimeSlot.breakfast, MealTimeSlot.snack],
      imageUrl: 'assets/images/foods/curd.png',
      calories: 280,
      proteinGrams: 15,
      carbsGrams: 44,
      fatGrams: 5,
      prepTimeMinutes: 5,
      requiredIngredients: ['Curd', 'Apple', 'Banana'],
      optionalPantryIngredients: ['Almonds', 'Honey', 'Grapes'],
      isVegetarian: true,
      isVegan: false,
      allergens: ['dairy', 'nuts'],
      searchKeywords: ['curd', 'yogurt', 'apple', 'banana', 'fruits'],
    ),
    MealRecipeDefinition(
      id: 'rec_apple_oatmeal',
      title: 'Apple Cinnamon Oatmeal',
      suitableSlots: [MealTimeSlot.breakfast],
      imageUrl: 'assets/images/foods/apple.jpg',
      calories: 310,
      proteinGrams: 11,
      carbsGrams: 56,
      fatGrams: 5,
      prepTimeMinutes: 8,
      requiredIngredients: ['Apple', 'Milk'],
      optionalPantryIngredients: ['Honey', 'Almonds'],
      isVegetarian: true,
      isVegan: false,
      allergens: ['dairy', 'nuts'],
      searchKeywords: ['apple', 'milk', 'oatmeal'],
    ),

    // --- LUNCH ---
    MealRecipeDefinition(
      id: 'rec_paneer_rice_bowl',
      title: 'Paneer Rice Bowl',
      suitableSlots: [MealTimeSlot.lunch, MealTimeSlot.dinner],
      imageUrl: 'assets/images/paneer_rice_bowl.jpg',
      calories: 520,
      proteinGrams: 24,
      carbsGrams: 62,
      fatGrams: 18,
      prepTimeMinutes: 20,
      requiredIngredients: ['Paneer', 'Rice', 'Capsicum', 'Onion'],
      optionalPantryIngredients: ['Tomato'],
      isVegetarian: true,
      isVegan: false,
      allergens: ['dairy'],
      searchKeywords: ['paneer', 'rice', 'capsicum', 'onion'],
    ),
    MealRecipeDefinition(
      id: 'rec_dal_rice',
      title: 'Comfort Dal Rice',
      suitableSlots: [MealTimeSlot.lunch, MealTimeSlot.dinner],
      imageUrl: 'assets/images/foods/dal_rice.jpg',
      calories: 420,
      proteinGrams: 18,
      carbsGrams: 72,
      fatGrams: 8,
      prepTimeMinutes: 25,
      requiredIngredients: ['Rice', 'Dal', 'Tomato', 'Onion'],
      optionalPantryIngredients: ['Butter'],
      isVegetarian: true,
      isVegan: true,
      allergens: [],
      searchKeywords: ['rice', 'dal', 'tomato', 'onion'],
    ),
    MealRecipeDefinition(
      id: 'rec_grilled_chicken_salad',
      title: 'Grilled Chicken Salad',
      suitableSlots: [MealTimeSlot.lunch, MealTimeSlot.dinner],
      imageUrl: 'assets/images/foods/chicken.jpg',
      calories: 380,
      proteinGrams: 36,
      carbsGrams: 14,
      fatGrams: 12,
      prepTimeMinutes: 15,
      requiredIngredients: ['Chicken', 'Tomato', 'Capsicum', 'Broccoli'],
      optionalPantryIngredients: ['Lemon'],
      isVegetarian: false,
      isVegan: false,
      allergens: [],
      searchKeywords: ['chicken', 'tomato', 'capsicum', 'broccoli', 'salad'],
    ),
    MealRecipeDefinition(
      id: 'rec_paneer_curry',
      title: 'Paneer Capsicum Curry',
      suitableSlots: [MealTimeSlot.lunch, MealTimeSlot.dinner],
      imageUrl: 'assets/images/foods/paneer_curry.jpg',
      calories: 460,
      proteinGrams: 22,
      carbsGrams: 20,
      fatGrams: 28,
      prepTimeMinutes: 20,
      requiredIngredients: ['Paneer', 'Capsicum', 'Tomato', 'Onion'],
      optionalPantryIngredients: ['Butter'],
      isVegetarian: true,
      isVegan: false,
      allergens: ['dairy'],
      searchKeywords: ['paneer', 'capsicum', 'curry'],
    ),

    // --- SNACK ---
    MealRecipeDefinition(
      id: 'rec_pb_apple_slices',
      title: 'Peanut Butter Apple Slices',
      suitableSlots: [MealTimeSlot.snack],
      imageUrl: 'assets/images/foods/peanut_butter.jpg',
      calories: 220,
      proteinGrams: 8,
      carbsGrams: 28,
      fatGrams: 10,
      prepTimeMinutes: 3,
      requiredIngredients: ['Apple', 'Peanut Butter'],
      optionalPantryIngredients: ['Honey', 'Almonds'],
      isVegetarian: true,
      isVegan: true,
      allergens: ['nuts', 'peanuts'],
      searchKeywords: ['apple', 'peanut butter'],
    ),
    MealRecipeDefinition(
      id: 'rec_fresh_fruit_medley',
      title: 'Fresh Fruit Medley',
      suitableSlots: [MealTimeSlot.snack, MealTimeSlot.breakfast],
      imageUrl: 'assets/images/foods/apple.jpg',
      calories: 180,
      proteinGrams: 3,
      carbsGrams: 42,
      fatGrams: 1,
      prepTimeMinutes: 5,
      requiredIngredients: ['Apple', 'Banana', 'Orange', 'Grapes'],
      optionalPantryIngredients: ['Honey'],
      isVegetarian: true,
      isVegan: true,
      allergens: [],
      searchKeywords: ['apple', 'banana', 'orange', 'grapes', 'fruit'],
    ),
    MealRecipeDefinition(
      id: 'rec_energy_dry_fruits',
      title: 'Nut & Dry Fruit Energy Mix',
      suitableSlots: [MealTimeSlot.snack],
      imageUrl: 'assets/images/foods/dry_fruits_mix.jpg',
      calories: 260,
      proteinGrams: 9,
      carbsGrams: 24,
      fatGrams: 16,
      prepTimeMinutes: 2,
      requiredIngredients: ['Almonds', 'Cashews', 'Raisins'],
      optionalPantryIngredients: ['Chocolate'],
      isVegetarian: true,
      isVegan: true,
      allergens: ['nuts'],
      searchKeywords: ['almonds', 'cashews', 'raisins', 'nuts'],
    ),

    // --- DINNER ---
    MealRecipeDefinition(
      id: 'rec_veg_pasta',
      title: 'Hearty Vegetable Pasta',
      suitableSlots: [MealTimeSlot.dinner, MealTimeSlot.lunch],
      imageUrl: 'assets/images/foods/pasta.jpg',
      calories: 480,
      proteinGrams: 16,
      carbsGrams: 76,
      fatGrams: 12,
      prepTimeMinutes: 20,
      requiredIngredients: ['Pasta', 'Tomato', 'Broccoli', 'Capsicum'],
      optionalPantryIngredients: ['Paneer', 'Butter'],
      isVegetarian: true,
      isVegan: false,
      allergens: ['gluten', 'dairy'],
      searchKeywords: ['pasta', 'tomato', 'broccoli', 'capsicum'],
    ),
    MealRecipeDefinition(
      id: 'rec_pan_seared_fish',
      title: 'Pan-Seared Fish with Greens',
      suitableSlots: [MealTimeSlot.dinner],
      imageUrl: 'assets/images/foods/fish.jpg',
      calories: 390,
      proteinGrams: 38,
      carbsGrams: 10,
      fatGrams: 14,
      prepTimeMinutes: 18,
      requiredIngredients: ['Fish', 'Broccoli', 'Carrot'],
      optionalPantryIngredients: ['Butter', 'Lemon'],
      isVegetarian: false,
      isVegan: false,
      allergens: ['seafood', 'fish'],
      searchKeywords: ['fish', 'broccoli', 'carrot'],
    ),
    MealRecipeDefinition(
      id: 'rec_stir_fry_paneer',
      title: 'Stir-Fried Veggies & Paneer',
      suitableSlots: [MealTimeSlot.dinner, MealTimeSlot.lunch],
      imageUrl: 'assets/images/foods/paneer_curry.jpg',
      calories: 360,
      proteinGrams: 20,
      carbsGrams: 16,
      fatGrams: 22,
      prepTimeMinutes: 15,
      requiredIngredients: ['Paneer', 'Broccoli', 'Carrot', 'Capsicum'],
      optionalPantryIngredients: ['Butter'],
      isVegetarian: true,
      isVegan: false,
      allergens: ['dairy'],
      searchKeywords: ['paneer', 'broccoli', 'carrot', 'capsicum'],
    ),
  ];

  static RecipeRecommendation? _computeLocalRecommendation(MealTimeSlot slot) {
    if (FridgeCategoryRepository.totalFridgeItems == 0) return null;

    final profile = MockDataRepository.profile;

    final List<MealRecipeDefinition> slotCandidates = [];
    final List<MealRecipeDefinition> otherCandidates = [];

    for (final recipe in recipeCatalog) {
      if (!_isDietaryCompliant(recipe, profile)) {
        continue;
      }
      if (recipe.suitableSlots.contains(slot)) {
        slotCandidates.add(recipe);
      } else {
        otherCandidates.add(recipe);
      }
    }

    final candidateToUse = slotCandidates.isNotEmpty ? slotCandidates : otherCandidates;

    MealRecipeDefinition? bestRecipe;
    List<CategoryFoodItem> bestAvailableItems = [];
    List<String> bestMissingItems = [];
    int highestScore = -1;

    for (final recipe in candidateToUse) {
      final List<CategoryFoodItem> availableItems = [];
      final List<String> missingItems = [];

      for (final ing in recipe.requiredIngredients) {
        final found = FridgeCategoryRepository.findItemByName(ing);
        if (found != null) {
          availableItems.add(found);
        } else {
          missingItems.add(ing);
        }
      }

      if (availableItems.isEmpty) continue;

      int score = availableItems.length * 10;

      for (final item in availableItems) {
        if (item.expiryDays >= 0 && item.expiryDays <= 3) {
          score += 6;
        }
      }

      if (recipe.suitableSlots.contains(slot)) {
        score += 8;
      }

      if (score > highestScore) {
        highestScore = score;
        bestRecipe = recipe;
        bestAvailableItems = availableItems;
        bestMissingItems = missingItems;
      }
    }

    if (bestRecipe == null) return null;

    final reasons = <String>[];
    reasons.add('Uses ${bestAvailableItems.length} items from your fridge');

    final expiring = bestAvailableItems.where((it) => it.expiryDays >= 0 && it.expiryDays <= 3).firstOrNull;
    if (expiring != null) {
      reasons.add('Uses ${expiring.name} (expires in ${expiring.expiryDays}d)');
    } else {
      reasons.add("Helps complete today's ${slot.displayName.toLowerCase()} goal");
    }

    final availableNames = bestAvailableItems.map((e) => e.name).toList();

    return RecipeRecommendation(
      id: bestRecipe.id,
      title: bestRecipe.title,
      calories: bestRecipe.calories,
      proteinGrams: bestRecipe.proteinGrams,
      carbsGrams: bestRecipe.carbsGrams,
      fatGrams: bestRecipe.fatGrams,
      prepTimeMinutes: bestRecipe.prepTimeMinutes,
      fridgeItemsUsed: bestAvailableItems.length,
      mealType: slot.badgeLabel,
      tag: slot.badgeLabel,
      imageUrl: bestRecipe.imageUrl,
      matchReasons: reasons,
      requiredIngredients: bestRecipe.requiredIngredients,
      missingIngredients: bestMissingItems,
      explanation:
          'Suggested for ${slot.displayName} based on ${availableNames.join(', ')} available in your fridge.',
    );
  }

  static bool _isDietaryCompliant(MealRecipeDefinition recipe, UserProfileData profile) {
    final pref = profile.dietaryPreference?.trim().toLowerCase();
    if (pref != null && pref.isNotEmpty) {
      if (pref.contains('vegan') && !recipe.isVegan) {
        return false;
      }
      if (pref.contains('vegetarian') && !recipe.isVegetarian) {
        return false;
      }
    }

    for (final allergy in profile.allergies) {
      final aLower = allergy.trim().toLowerCase();
      if (aLower.isEmpty) continue;
      for (final recipeAllergen in recipe.allergens) {
        if (recipeAllergen.contains(aLower) || aLower.contains(recipeAllergen)) {
          return false;
        }
      }
      for (final ing in recipe.requiredIngredients) {
        if (ing.toLowerCase().contains(aLower) || aLower.contains(ing.toLowerCase())) {
          return false;
        }
      }
    }

    for (final avoided in profile.avoidedFoods) {
      final avLower = avoided.trim().toLowerCase();
      if (avLower.isEmpty) continue;
      for (final ing in recipe.requiredIngredients) {
        if (ing.toLowerCase().contains(avLower) || avLower.contains(ing.toLowerCase())) {
          return false;
        }
      }
    }

    for (final custom in profile.customRestrictions) {
      final cLower = custom.trim().toLowerCase();
      if (cLower.isEmpty) continue;
      for (final ing in recipe.requiredIngredients) {
        if (ing.toLowerCase().contains(cLower) || cLower.contains(ing.toLowerCase())) {
          return false;
        }
      }
    }

    return true;
  }
}
