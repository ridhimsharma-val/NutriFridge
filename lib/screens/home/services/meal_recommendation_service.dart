import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../models/nutrition_data.dart';
import '../../../services/meals/meal_tracking_service.dart';
import '../../ai_assistant/services/ai_assistant_service.dart';
import '../../fridge/models/category_item.dart';
import '../../fridge/services/cooking_basket_service.dart';
import '../../meal_detail/models/recipe_preparation_step.dart';
import '../../profile/models/user_profile_data.dart';

export '../../../models/nutrition_data.dart' show RecommendationStatus;

/// Modes for discovering meals in NutriFridge
enum MealDiscoveryMode {
  none, // Initial state: shows two choices ("AI Suggestion" & "Use My Ingredients")
  aiSuggestion, // User selected AI Suggestion: uses full fridge inventory & preferences
  useMyIngredients, // User selected Use My Ingredients: uses only user-selected ingredients
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
  MealRecommendationService._internal() {
    _wireRepositories();
  }

  static final MealRecommendationService _instance = MealRecommendationService._internal();
  static MealRecommendationService get instance => _instance;
  factory MealRecommendationService() => _instance;

  static DateTime Function() _currentTimeProvider = DateTime.now;

  /// Testable clock provider allowing controlled time injection in tests.
  static DateTime Function() get currentTimeProvider => _currentTimeProvider;
  static set currentTimeProvider(DateTime Function() provider) {
    _currentTimeProvider = provider;
    MockDataRepository.currentTimeProvider = provider;
  }

  /// Resets clock provider to system wall clock.
  static void resetClock() {
    _currentTimeProvider = DateTime.now;
    MockDataRepository.resetClock();
  }

  // --- Reactive State Notifiers ---
  static final ValueNotifier<RecommendationStatus> statusNotifier =
      ValueNotifier<RecommendationStatus>(RecommendationStatus.empty);

  static final ValueNotifier<RecipeRecommendation?> recommendationNotifier =
      ValueNotifier<RecipeRecommendation?>(null);

  static final ValueNotifier<bool> isChangingSuggestionNotifier =
      ValueNotifier<bool>(false);

  static final ValueNotifier<MealDiscoveryMode> discoveryModeNotifier =
      ValueNotifier<MealDiscoveryMode>(MealDiscoveryMode.none);

  static MealDiscoveryMode _discoveryMode = MealDiscoveryMode.none;
  static MealDiscoveryMode get discoveryMode => _discoveryMode;

  static void selectDiscoveryMode(MealDiscoveryMode mode, {bool fetch = true}) {
    _discoveryMode = mode;
    discoveryModeNotifier.value = mode;
    if (mode == MealDiscoveryMode.none) {
      _currentRecommendation = null;
      _currentStatus = RecommendationStatus.empty;
      _errorMessage = null;
      _alternativeMessage = null;
      _isFetching = false;
      _activeFetchFuture = null;
      recommendationNotifier.value = null;
      statusNotifier.value = RecommendationStatus.empty;
      MockDataRepository.setRecommendationForTesting(null);
    } else if (mode == MealDiscoveryMode.aiSuggestion && fetch) {
      fetchRecommendation(forceRefresh: true);
    }
  }

  static RecommendationStatus _currentStatus = RecommendationStatus.empty;
  static RecommendationStatus get currentStatus => _currentStatus;

  static RecipeRecommendation? _currentRecommendation;
  static RecipeRecommendation? get currentRecommendation => _currentRecommendation;

  static String? _errorMessage;
  static String? get errorMessage => _errorMessage;

  static String? _alternativeMessage;
  static String? get alternativeMessage => _alternativeMessage;

  static bool _isChangingSuggestion = false;
  static bool get isChangingSuggestion => _isChangingSuggestion;

  // --- In-flight & Caching State ---
  static bool _isFetching = false;
  static Future<RecipeRecommendation?>? _activeFetchFuture;
  static int _fetchCallCount = 0;
  static int get fetchCallCount => _fetchCallCount;

  static int _currentRequestId = 0;

  static MealTimeSlot? _cachedSlot;
  static String? _cachedInventoryFingerprint;
  static String? _cachedProfileFingerprint;

  static final Set<String> _rejectedRecipeIds = <String>{};
  static Set<String> get rejectedRecipeIds => Set.unmodifiable(_rejectedRecipeIds);

  static final Set<MealTimeSlot> _sessionCompletedSlots = <MealTimeSlot>{};
  static int _lastLoggedMealsCount = 0;
  static Set<MealTimeSlot> _lastCompletedSlots = {};

  static bool _listenersAttached = false;
  static bool _isInitialized = false;
  static Future<void>? _initFuture;

  /// Indicates whether the service has been initialized
  static bool get isInitialized => _isInitialized;

  /// Static initialization hook. Safe to call repeatedly; avoids duplicate
  /// simultaneous requests and handles initialization errors gracefully.
  static Future<void> ensureInitialized() => _instance.init();

  /// Alias for ensureInitialized
  static Future<void> initialize() => _instance.init();

  /// Instance method for initialization
  Future<void> init() async {
    _wireRepositories();
    if (_isInitialized) return;
    if (_initFuture != null) {
      await _initFuture;
      return;
    }

    _initFuture = _performInitialization();
    try {
      await _initFuture;
    } finally {
      _initFuture = null;
    }
  }

  /// Instance alias matching ensureInitialized
  Future<void> ensureInitializedInstance() => init();

  Future<void> _performInitialization() async {
    try {
      _wireRepositories();
      if (!_listenersAttached) {
        _listenersAttached = true;
        FridgeCategoryRepository.notifier.addListener(_onInventoryChanged);
        MockDataRepository.notifier.addListener(_onMockDataChanged);
      }
      _isInitialized = true;
    } catch (e, st) {
      debugPrint('Error during MealRecommendationService initialization: $e\n$st');
      _isInitialized = false;
      _listenersAttached = false;
    }
  }

  static void _wireRepositories() {
    MockDataRepository.recommendationProvider = () {
      if (_discoveryMode == MealDiscoveryMode.none) return null;
      if (_currentRecommendation != null) return _currentRecommendation;
      if (_currentStatus == RecommendationStatus.loading ||
          _currentStatus == RecommendationStatus.error ||
          _currentStatus == RecommendationStatus.noMatch) {
        return null;
      }
      return getRecommendation();
    };
    MockDataRepository.recommendationStatusProvider = () {
      if (_discoveryMode == MealDiscoveryMode.none) return RecommendationStatus.empty;
      return currentStatus;
    };
    MockDataRepository.onResetRecommendation = () => reset();
  }

  static void _onInventoryChanged() {
    if (FridgeCategoryRepository.totalFridgeItems == 0) {
      _currentRecommendation = null;
      _currentStatus = RecommendationStatus.empty;
      _cachedInventoryFingerprint = null;
      _alternativeMessage = null;
      statusNotifier.value = RecommendationStatus.empty;
      recommendationNotifier.value = null;
      return;
    }

    final newFingerprint = _generateInventoryFingerprint();
    if (newFingerprint != _cachedInventoryFingerprint) {
      // Invalidate cache and re-fetch recommendation if a mode is active
      _cachedInventoryFingerprint = null;
      _alternativeMessage = null;
      if (_discoveryMode != MealDiscoveryMode.none) {
        fetchRecommendation(forceRefresh: true);
      }
    }
  }

  static void _onMockDataChanged() {
    if (FridgeCategoryRepository.totalFridgeItems == 0) return;

    final currentHistory = MockDataRepository.loggedMealsHistory;
    final currentCompleted = getCompletedMealSlotsToday();

    // 1. Profile change check
    final newProfileFingerprint = _generateProfileFingerprint();
    final profileChanged = newProfileFingerprint != _cachedProfileFingerprint;

    // 2. Meal logging / slot completion check
    final mealsLoggedChanged = currentHistory.length != _lastLoggedMealsCount ||
        !setEquals(currentCompleted, _lastCompletedSlots);

    if (mealsLoggedChanged) {
      _lastLoggedMealsCount = currentHistory.length;
      _lastCompletedSlots = Set.from(currentCompleted);

      // Invalidate previous recommendation and slot cache
      _currentRecommendation = null;
      _cachedSlot = null;
      _rejectedRecipeIds.clear();
      _alternativeMessage = null;
      recommendationNotifier.value = null;

      // Automatically advance to the next unlogged upcoming slot if a mode is active
      if (_discoveryMode != MealDiscoveryMode.none) {
        fetchRecommendation(forceRefresh: true);
      }
      return;
    }

    if (profileChanged) {
      _cachedProfileFingerprint = null;
      _rejectedRecipeIds.clear();
      _alternativeMessage = null;
      if (_discoveryMode != MealDiscoveryMode.none) {
        fetchRecommendation(forceRefresh: true);
      }
    }
  }

  /// Parses a string representation of a meal slot name.
  static MealTimeSlot? parseMealSlot(String? name) {
    if (name == null || name.isEmpty) return null;
    final clean = name.trim().toLowerCase();
    if (clean.contains('breakfast')) return MealTimeSlot.breakfast;
    if (clean.contains('lunch')) return MealTimeSlot.lunch;
    if (clean.contains('snack')) return MealTimeSlot.snack;
    if (clean.contains('dinner')) return MealTimeSlot.dinner;
    return null;
  }

  /// Determines which meal slots have already been completed today.
  static Set<MealTimeSlot> getCompletedMealSlotsToday([DateTime? now]) {
    final today = now ?? currentTimeProvider();
    final completed = <MealTimeSlot>{};

    // 1. Inspect MockDataRepository.meals
    for (final meal in MockDataRepository.meals) {
      if (meal.status == MealStatus.completed || meal.isCompleted) {
        final slot = parseMealSlot(meal.name) ?? parseMealSlot(meal.mealType);
        if (slot != null) {
          completed.add(slot);
        }
      }
    }

    // 2. Inspect MockDataRepository.loggedMealsHistory
    for (final entry in MockDataRepository.loggedMealsHistory) {
      final dt = entry['timestamp'];
      bool isToday = true;
      if (dt is DateTime) {
        isToday = dt.year == today.year && dt.month == today.month && dt.day == today.day;
      }
      if (isToday) {
        final type = (entry['mealType'] ?? '').toString();
        final slot = parseMealSlot(type);
        if (slot != null) {
          completed.add(slot);
        }
      }
    }

    // 3. Include any session-marked slots
    completed.addAll(_sessionCompletedSlots);

    return completed;
  }

  /// Determines the raw meal time slot for a given timestamp based on clock windows:
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

  /// Determines the next appropriate unlogged meal slot based on both
  /// current local time and today's completed meal slots.
  /// Progression order: Breakfast -> Lunch -> Snacks -> Dinner -> tomorrow's Breakfast.
  static MealTimeSlot resolveActiveMealSlot([DateTime? time]) {
    final dt = time ?? currentTimeProvider();
    final completed = getCompletedMealSlotsToday(dt);

    // Late night (23:00 - 04:59) -> upcoming Breakfast
    if (isLateNightWindow(dt)) {
      return MealTimeSlot.breakfast;
    }

    final clockSlot = getMealTimeSlot(dt);

    // If clock slot has NOT yet been completed today, recommend it
    if (!completed.contains(clockSlot)) {
      return clockSlot;
    }

    // Clock slot is already completed today:
    // Advance to the next unlogged upcoming slot today
    const order = [
      MealTimeSlot.breakfast,
      MealTimeSlot.lunch,
      MealTimeSlot.snack,
      MealTimeSlot.dinner,
    ];

    final currentIndex = order.indexOf(clockSlot);
    for (int i = currentIndex + 1; i < order.length; i++) {
      if (!completed.contains(order[i])) {
        return order[i];
      }
    }

    // No suitable remaining slot exists today (e.g. Dinner completed or all completed)
    // -> Advance to tomorrow's Breakfast
    return MealTimeSlot.breakfast;
  }

  /// Alias for resolveActiveMealSlot
  static MealTimeSlot getNextUnloggedMealSlot([DateTime? time]) => resolveActiveMealSlot(time);

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
    MealTimeSlot? targetSlot,
    bool isAlternativeRequest = false,
    Set<String>? excludedRecipeIds,
  }) async {
    ensureInitialized();

    if (_activeFetchFuture != null && !forceRefresh && !isAlternativeRequest) {
      return _activeFetchFuture;
    }

    final future = _performFetchRecommendation(
      forceRefresh: forceRefresh,
      time: time,
      targetSlot: targetSlot,
      isAlternativeRequest: isAlternativeRequest,
      excludedRecipeIds: excludedRecipeIds,
    );

    _activeFetchFuture = future;
    try {
      return await future;
    } finally {
      if (_activeFetchFuture == future) {
        _activeFetchFuture = null;
      }
    }
  }

  static Future<RecipeRecommendation?> _performFetchRecommendation({
    bool forceRefresh = false,
    DateTime? time,
    MealTimeSlot? targetSlot,
    bool isAlternativeRequest = false,
    Set<String>? excludedRecipeIds,
  }) async {
    // 1. Emptiness Check: Fridge contains zero items
    if (FridgeCategoryRepository.totalFridgeItems == 0) {
      _currentRecommendation = null;
      _currentStatus = RecommendationStatus.empty;
      _errorMessage = null;
      _alternativeMessage = null;
      _cachedSlot = null;
      _cachedInventoryFingerprint = null;
      _cachedProfileFingerprint = null;
      statusNotifier.value = RecommendationStatus.empty;
      recommendationNotifier.value = null;
      return null;
    }

    final slot = targetSlot ?? resolveActiveMealSlot(time);
    final invFingerprint = _generateInventoryFingerprint();
    final profileFingerprint = _generateProfileFingerprint();

    // 2. Cache Validation (skip if forceRefresh or alternative request)
    if (!forceRefresh &&
        !isAlternativeRequest &&
        _currentRecommendation != null &&
        _cachedSlot == slot &&
        _cachedInventoryFingerprint == invFingerprint &&
        _cachedProfileFingerprint == profileFingerprint) {
      _currentStatus = RecommendationStatus.loaded;
      statusNotifier.value = RecommendationStatus.loaded;
      return _currentRecommendation;
    }

    _isFetching = true;
    _fetchCallCount++;
    final thisRequestId = ++_currentRequestId;
    _currentStatus = RecommendationStatus.loading;
    statusNotifier.value = RecommendationStatus.loading;

    try {
      final now = time ?? currentTimeProvider();
      final inventoryContext = AiAssistantService.getInventoryContext();
      final userPreferences = AiAssistantService.getProfilePreferences();
      final nutritionContext = AiAssistantService.getNutritionContext();

      final exclusions = excludedRecipeIds ?? _rejectedRecipeIds;
      final completedSlots = getCompletedMealSlotsToday(now);
      final nextSlot = getNextUnloggedMealSlot(now);

      final remainingCalories = (MockDataRepository.nutrition.targetCalories -
              MockDataRepository.nutrition.consumedCalories)
          .clamp(0, 9999);
      final remainingProtein = (MockDataRepository.nutrition.protein.targetGrams -
              MockDataRepository.nutrition.protein.amountGrams)
          .clamp(0, 999);
      final remainingCarbs = (MockDataRepository.nutrition.carbs.targetGrams -
              MockDataRepository.nutrition.carbs.amountGrams)
          .clamp(0, 999);
      final remainingFat = (MockDataRepository.nutrition.fat.targetGrams -
              MockDataRepository.nutrition.fat.amountGrams)
          .clamp(0, 999);

      final requestPayload = {
        'userId': MockDataRepository.profile.displayName.isNotEmpty
            ? MockDataRepository.profile.displayName
            : 'guest_user',
        'actionHint': 'meal_recommendation',
        'message': isAlternativeRequest
            ? 'Suggest an alternative meal recommendation for ${slot.displayName} based on current fridge inventory, excluding previously rejected recipes.'
            : 'Generate a meal recommendation for ${slot.displayName} based on current fridge inventory.',
        'currentMealPeriod': slot.displayName,
        'targetMealSlot': slot.displayName,
        'nextMealSlot': nextSlot.displayName,
        'completedMealSlots': completedSlots.map((s) => s.displayName).toList(),
        'todayLoggedMeals': MockDataRepository.todayLoggedMealsHistory.map((m) {
          final ts = m['timestamp'];
          return {
            'mealType': m['mealType'],
            'mealName': m['mealName'],
            'calories': m['calories'],
            'protein': m['protein'],
            'carbs': m['carbs'],
            'fat': m['fat'],
            'timestamp': ts is DateTime ? ts.toIso8601String() : ts?.toString(),
          };
        }).toList(),
        'clientLocalTime': now.toIso8601String(),
        'inventoryContext': inventoryContext,
        'userPreferences': userPreferences,
        'todayNutrition': nutritionContext,
        'remainingTargets': {
          'calories': remainingCalories,
          'proteinG': remainingProtein,
          'carbsG': remainingCarbs,
          'fatG': remainingFat,
        },
        'excludedRecipeIds': exclusions.toList(),
        'rejectedRecipeIds': exclusions.toList(),
        'isAlternative': isAlternativeRequest,
      };

      Map<String, dynamic> response = await AiAssistantService.sendRequest(
        message: requestPayload['message'] as String,
        actionHint: 'meal_recommendation',
        extraPayload: requestPayload,
      );

      // Discard stale responses if newer request has been triggered
      if (thisRequestId != _currentRequestId) {
        return _currentRecommendation;
      }

      // If n8n backend rejects 'meal_recommendation' with HTTP 400 (e.g. un-updated live deployment),
      // gracefully fall back to actionHint: 'auto' with recommendation context
      if (response['error'] != null &&
          response['error'].toString().contains('400') &&
          response['action'] == 'error') {
        debugPrint(
            '[MealRecommendationService] Live n8n rejected meal_recommendation; falling back to actionHint: auto');
        final fallbackPayload = Map<String, dynamic>.from(requestPayload);
        fallbackPayload['actionHint'] = 'auto';
        response = await AiAssistantService.sendRequest(
          message: requestPayload['message'] as String,
          actionHint: 'auto',
          extraPayload: fallbackPayload,
        );
        if (thisRequestId != _currentRequestId) {
          return _currentRecommendation;
        }
      }

      // 4. Handle Backend failure (TEST 11)
      if (response['success'] == false ||
          response['ok'] == false ||
          response['action'] == 'error' ||
          (response['error'] != null && response['meal'] == null)) {
        if (!isAlternativeRequest) {
          _currentRecommendation = null;
        }
        _currentStatus = RecommendationStatus.error;
        _errorMessage = response['assistantMessage'] as String? ??
            response['error'] as String? ??
            'Unable to reach NutriFridge AI. Please check your connection and tap retry.';
        statusNotifier.value = RecommendationStatus.error;
        if (!isAlternativeRequest) {
          recommendationNotifier.value = null;
        }
        _isFetching = false;
        return null;
      }

      // 5. Parse backend structured meal recommendation
      if (response['meal'] != null && response['meal'] is Map) {
        final mealJson = Map<String, dynamic>.from(response['meal'] as Map);
        final rec = RecipeRecommendation.fromJson(mealJson);

        if (!exclusions.contains(rec.id) && !exclusions.contains(rec.title)) {
          _currentRecommendation = rec;
          _currentStatus = RecommendationStatus.loaded;
          _errorMessage = null;
          _alternativeMessage = null;
          _cachedSlot = slot;
          _cachedInventoryFingerprint = invFingerprint;
          _cachedProfileFingerprint = profileFingerprint;
          statusNotifier.value = RecommendationStatus.loaded;
          recommendationNotifier.value = rec;
          _isFetching = false;
          return rec;
        }
      }

      // 6. Handle explicit no-match condition from backend
      if (response['action'] == 'no_match' || response['noMatch'] == true) {
        if (!isAlternativeRequest) {
          _currentRecommendation = null;
          _currentStatus = RecommendationStatus.noMatch;
          _errorMessage = response['assistantMessage'] as String? ??
              "We couldn't find a suitable meal with your current ingredients.";
          statusNotifier.value = RecommendationStatus.noMatch;
          recommendationNotifier.value = null;
          _isFetching = false;
          return null;
        }
      }

      // 7. Dynamic local catalog fallback (for offline or unhandled mock actions)
      final localRec = _computeLocalRecommendation(
        slot,
        excludedRecipeIds: exclusions,
      );

      if (localRec != null) {
        _currentRecommendation = localRec;
        _currentStatus = RecommendationStatus.loaded;
        _errorMessage = null;
        _alternativeMessage = null;
        _cachedSlot = slot;
        _cachedInventoryFingerprint = invFingerprint;
        _cachedProfileFingerprint = profileFingerprint;
        statusNotifier.value = RecommendationStatus.loaded;
        recommendationNotifier.value = localRec;
      } else {
        if (isAlternativeRequest && _currentRecommendation != null) {
          // Keep current recommendation visible, notify user
          _currentStatus = RecommendationStatus.loaded;
          _alternativeMessage = 'No other suitable suggestion is available right now.';
          statusNotifier.value = RecommendationStatus.loaded;
          recommendationNotifier.value = _currentRecommendation;
        } else {
          _currentRecommendation = null;
          _currentStatus = RecommendationStatus.noMatch;
          statusNotifier.value = RecommendationStatus.noMatch;
          recommendationNotifier.value = null;
        }
      }
      _isFetching = false;
      return _currentRecommendation;
    } catch (e) {
      if (thisRequestId == _currentRequestId) {
        if (!isAlternativeRequest) {
          _currentRecommendation = null;
          _currentStatus = RecommendationStatus.error;
          final errorStr = e.toString().toLowerCase();
          if (errorStr.contains('auth') ||
              errorStr.contains('jwt') ||
              errorStr.contains('unauthorized') ||
              errorStr.contains('401')) {
            _errorMessage =
                'Session expired. Please sign in again to get AI recommendations.';
          } else if (errorStr.contains('timeout') ||
              errorStr.contains('timed out')) {
            _errorMessage = 'AI request timed out. Please tap retry.';
          } else if (errorStr.contains('rate limit') ||
              errorStr.contains('429')) {
            _errorMessage =
                'Too many requests. Please wait a moment and try again.';
          } else if (errorStr.contains('network') ||
              errorStr.contains('socket') ||
              errorStr.contains('clientexception') ||
              errorStr.contains('failed host lookup') ||
              errorStr.contains('connection refused')) {
            _errorMessage =
                'Unable to reach NutriFridge AI. Please check your internet connection and tap retry.';
          } else {
            final cleaned = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
            _errorMessage = cleaned.isNotEmpty
                ? cleaned
                : 'Unable to reach NutriFridge AI. Please check your connection and tap retry.';
          }
          statusNotifier.value = RecommendationStatus.error;
          recommendationNotifier.value = null;
        }
        _isFetching = false;
      }
      return null;
    } finally {
      _isFetching = false;
    }
  }

  /// Requests another valid recommendation for the current meal slot without
  /// logging meals, mutating inventory, altering calories, or completing slots.
  static Future<bool> changeSuggestion({
    void Function(String message)? onMessage,
  }) async {
    ensureInitialized();

    // Prevent duplicate simultaneous requests on rapid taps (TEST F)
    if (_isFetching || _isChangingSuggestion) {
      return false;
    }

    final currentRec = _currentRecommendation;
    if (currentRec == null) {
      return false;
    }

    // 1. Preserve current meal slot
    final slot = _cachedSlot ?? resolveActiveMealSlot();

    // 2. Exclude currently displayed recipe and preserve session rejects
    if (currentRec.id.isNotEmpty) {
      _rejectedRecipeIds.add(currentRec.id);
    }
    _rejectedRecipeIds.add(currentRec.title);

    _isChangingSuggestion = true;
    isChangingSuggestionNotifier.value = true;
    _alternativeMessage = null;

    try {
      final exclusions = Set<String>.from(_rejectedRecipeIds);
      final newRec = await fetchRecommendation(
        forceRefresh: true,
        targetSlot: slot,
        isAlternativeRequest: true,
        excludedRecipeIds: exclusions,
      );

      if (newRec != null &&
          newRec.id != currentRec.id &&
          newRec.title != currentRec.title) {
        _currentRecommendation = newRec;
        _currentStatus = RecommendationStatus.loaded;
        _alternativeMessage = null;
        statusNotifier.value = RecommendationStatus.loaded;
        recommendationNotifier.value = newRec;
        return true;
      } else {
        // Alternative unavailable: keep current recommendation visible!
        _currentRecommendation = currentRec;
        _currentStatus = RecommendationStatus.loaded;
        _alternativeMessage = 'No other suitable suggestion is available right now.';
        statusNotifier.value = RecommendationStatus.loaded;
        recommendationNotifier.value = currentRec;
        onMessage?.call('No other suitable suggestion is available right now.');
        return false;
      }
    } catch (_) {
      _currentRecommendation = currentRec;
      _currentStatus = RecommendationStatus.loaded;
      _alternativeMessage = 'No other suitable suggestion is available right now.';
      statusNotifier.value = RecommendationStatus.loaded;
      recommendationNotifier.value = currentRec;
      onMessage?.call('No other suitable suggestion is available right now.');
      return false;
    } finally {
      _isChangingSuggestion = false;
      isChangingSuggestionNotifier.value = false;
    }
  }

  /// Invalidates the previous recommendation, marks slot completed,
  /// and requests the next unlogged meal slot recommendation.
  static Future<RecipeRecommendation?> advanceAfterMealLogged({
    MealTimeSlot? loggedSlot,
    DateTime? time,
  }) async {
    ensureInitialized();
    if (loggedSlot != null) {
      _sessionCompletedSlots.add(loggedSlot);
    }
    _currentRecommendation = null;
    _cachedSlot = null;
    _cachedInventoryFingerprint = null;
    _rejectedRecipeIds.clear();
    _alternativeMessage = null;
    recommendationNotifier.value = null;

    final nextSlot = resolveActiveMealSlot(time);
    return fetchRecommendation(
      forceRefresh: true,
      targetSlot: nextSlot,
      time: time,
    );
  }

  /// Generates a meal recommendation based strictly on user-selected ingredients
  /// and an optional dish name (Mode B: "Use My Ingredients").
  static Future<RecipeRecommendation?> generateFromSelectedIngredients({
    required List<CategoryFoodItem> selectedItems,
    String? preferredDishName,
    BuildContext? context,
  }) async {
    ensureInitialized();

    if (selectedItems.isEmpty) {
      return null;
    }

    _isFetching = true;
    CookingBasketService.isGeneratingNotifier.value = true;
    CookingBasketService.generationErrorNotifier.value = null;

    final now = _currentTimeProvider();
    final slot = resolveActiveMealSlot(now);

    final validUuidIds = selectedItems
        .where((i) => MealTrackingService.isValidUuid(i.id))
        .map((i) => i.id)
        .toList();
    final itemIds = validUuidIds.isNotEmpty
        ? validUuidIds
        : selectedItems.map((i) => i.id).toList();

    final requestPayload = {
      'userId': MockDataRepository.profile.displayName.isNotEmpty
          ? MockDataRepository.profile.displayName
          : 'guest_user',
      'actionHint': 'meal_recommendation',
      'recipeMode': 'selected_ingredients',
      'selectedInventoryItemIds': itemIds,
      'preferredDishName': preferredDishName,
      'message': (preferredDishName != null && preferredDishName.trim().isNotEmpty)
          ? 'Create a recipe for ${preferredDishName.trim()} using these selected ingredients from my fridge: ${selectedItems.map((i) => i.name).join(", ")}.'
          : 'Create a recipe using primarily these selected ingredients from my fridge: ${selectedItems.map((i) => i.name).join(", ")}.',
      'currentMealPeriod': slot.displayName,
      'targetMealSlot': slot.displayName,
      'inventoryContext': selectedItems.map((i) => {
        'id': i.id,
        'name': i.name,
        'category': i.category,
        'quantity': i.quantity,
        'unit': i.unit,
        'expiryDays': i.expiryDays,
      }).toList(),
      'userPreferences': {
        'dietaryPreference': MockDataRepository.profile.dietaryPreference,
        'allergies': MockDataRepository.profile.allergies,
        'avoidedFoods': MockDataRepository.profile.avoidedFoods,
      },
      'todayNutrition': MockDataRepository.nutrition,
      'clientLocalTime': now.toIso8601String(),
    };

    try {
      final response = await AiAssistantService.sendRequest(
        message: requestPayload['message'] as String,
        actionHint: 'meal_recommendation',
        extraPayload: requestPayload,
      );

      RecipeRecommendation? rec;
      if (response['meal'] != null && response['meal'] is Map) {
        rec = RecipeRecommendation.fromJson(Map<String, dynamic>.from(response['meal'] as Map));
      } else if (response['success'] == true && response['data'] != null && response['data']['meal'] is Map) {
        rec = RecipeRecommendation.fromJson(Map<String, dynamic>.from(response['data']['meal'] as Map));
      }

      // If backend responded with error or empty meal:
      if (rec == null) {
        if (response['action'] == 'error' || response['ok'] == false) {
          final errMsg = response['assistantMessage']?.toString() ??
              response['error']?.toString() ??
              'Unable to generate recipe with selected ingredients.';
          throw Exception(errMsg);
        }

        // Local dynamic synthesis for test/mock offline execution
        rec = _synthesizeRecipeFromSelected(selectedItems, preferredDishName, slot);
      }

      _discoveryMode = MealDiscoveryMode.useMyIngredients;
      discoveryModeNotifier.value = MealDiscoveryMode.useMyIngredients;
      _currentRecommendation = rec;
      _currentStatus = RecommendationStatus.loaded;
      _errorMessage = null;
      _alternativeMessage = null;
      statusNotifier.value = RecommendationStatus.loaded;
      recommendationNotifier.value = rec;
      CookingBasketService.isGeneratingNotifier.value = false;
      return rec;
    } catch (e) {
      debugPrint('[MealRecommendationService] generateFromSelectedIngredients error: $e');
      final cleanMsg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      CookingBasketService.generationErrorNotifier.value = cleanMsg;
      CookingBasketService.isGeneratingNotifier.value = false;
      return null;
    } finally {
      _isFetching = false;
      CookingBasketService.isGeneratingNotifier.value = false;
    }
  }

  static RecipeRecommendation _synthesizeRecipeFromSelected(
    List<CategoryFoodItem> selectedItems,
    String? preferredDishName,
    MealTimeSlot slot,
  ) {
    final title = (preferredDishName != null && preferredDishName.trim().isNotEmpty)
        ? preferredDishName.trim()
        : '${selectedItems.map((i) => i.name).take(2).join(" & ")} Special';

    return RecipeRecommendation(
      id: 'rec_custom_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      mealType: slot.displayName,
      explanation: 'Crafted specially using your selected ingredients: ${selectedItems.map((i) => i.name).join(", ")}.',
      calories: 450,
      proteinGrams: 28,
      carbsGrams: 45,
      fatGrams: 16,
      prepTimeMinutes: 15,
      cookingTimeMinutes: 20,
      servingSize: '1 serving',
      fridgeItemsUsed: selectedItems.length,
      imageUrl: 'assets/images/paneer_rice_bowl.jpg',
      requiredIngredients: selectedItems.map((i) => '${i.name} (${i.quantity} ${i.unit})').toList(),
      missingIngredients: const [],
      preparationSteps: [
        RecipePreparationStep(
          stepNumber: 1,
          instruction: 'Prepare and chop ${selectedItems.map((i) => i.name).take(3).join(", ")} evenly.',
          time: '5 mins',
        ),
        RecipePreparationStep(
          stepNumber: 2,
          instruction: 'Heat a skillet over medium heat with cooking oil or butter.',
          time: '2 mins',
          temperature: 'medium heat',
        ),
        RecipePreparationStep(
          stepNumber: 3,
          instruction: 'Add the primary ingredients and sauté until fragrant and tender.',
          time: '8 mins',
          temperature: 'medium',
          tip: 'Sauté gently to preserve flavor and textures.',
        ),
        RecipePreparationStep(
          stepNumber: 4,
          instruction: 'Season with salt, pepper, and herbs to taste.',
          time: '2 mins',
        ),
        RecipePreparationStep(
          stepNumber: 5,
          instruction: 'Plate warm, garnish with fresh herbs, and serve immediately.',
          time: '1 min',
        ),
      ],
      cookingTips: ['Cook on medium heat to retain moisture and freshness.'],
      substitutions: ['You can substitute olive oil for butter for a lighter preparation.'],
      videoSearchQuery: '$title recipe',
    );
  }

  /// Synchronous recommendation resolver
  static RecipeRecommendation? getRecommendation({DateTime? time, MealTimeSlot? targetSlot}) {
    ensureInitialized();

    if (FridgeCategoryRepository.totalFridgeItems == 0) {
      _currentStatus = RecommendationStatus.empty;
      return null;
    }

    final slot = targetSlot ?? resolveActiveMealSlot(time);
    if (_currentRecommendation != null && _cachedSlot == slot) {
      return _currentRecommendation;
    }

    final localRec = _computeLocalRecommendation(
      slot,
      excludedRecipeIds: _rejectedRecipeIds,
    );
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
    _discoveryMode = MealDiscoveryMode.none;
    discoveryModeNotifier.value = MealDiscoveryMode.none;
    CookingBasketService.clear();
    _currentStatus = RecommendationStatus.empty;
    _errorMessage = null;
    _alternativeMessage = null;
    _isFetching = false;
    _activeFetchFuture = null;
    _isChangingSuggestion = false;
    isChangingSuggestionNotifier.value = false;
    _fetchCallCount = 0;
    _currentRequestId = 0;
    _cachedSlot = null;
    _cachedInventoryFingerprint = null;
    _cachedProfileFingerprint = null;
    _rejectedRecipeIds.clear();
    _sessionCompletedSlots.clear();
    _lastLoggedMealsCount = 0;
    _lastCompletedSlots.clear();
    statusNotifier.value = _currentStatus;
    recommendationNotifier.value = null;
    resetClock();
    _wireRepositories();
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

  static RecipeRecommendation? _computeLocalRecommendation(
    MealTimeSlot slot, {
    Set<String> excludedRecipeIds = const {},
  }) {
    if (FridgeCategoryRepository.totalFridgeItems == 0) return null;

    final profile = MockDataRepository.profile;

    final List<MealRecipeDefinition> slotCandidates = [];
    final List<MealRecipeDefinition> otherCandidates = [];

    for (final recipe in recipeCatalog) {
      if (excludedRecipeIds.contains(recipe.id) ||
          excludedRecipeIds.contains(recipe.title)) {
        continue;
      }
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
        if (item.isExpiringSoon) {
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

    final expiring = bestAvailableItems.where((it) => it.isExpiringSoon).firstOrNull;
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
