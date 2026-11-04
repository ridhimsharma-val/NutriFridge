import 'package:flutter/foundation.dart';
import '../screens/home/services/meal_recommendation_service.dart';
import '../screens/profile/models/user_profile_data.dart';
import 'notification_data.dart';

class UserProfile {
  final String name;
  final String greeting;
  final String subtitle;

  const UserProfile({
    required this.name,
    required this.greeting,
    required this.subtitle,
  });
}

class RecipeRecommendation {
  final String id;
  final String title;
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final int prepTimeMinutes;
  final int fridgeItemsUsed;
  final String tag;
  final String mealType;
  final String imageUrl;
  final String? imageKey;
  final bool nutritionIsEstimate;
  final List<String> matchReasons;
  final List<String> requiredIngredients;
  final List<String> missingIngredients;
  final String? explanation;

  const RecipeRecommendation({
    this.id = '',
    required this.title,
    required this.calories,
    required this.proteinGrams,
    this.carbsGrams = 62,
    this.fatGrams = 18,
    this.prepTimeMinutes = 20,
    required this.fridgeItemsUsed,
    this.tag = 'Picked for your fridge',
    this.mealType = '',
    required this.imageUrl,
    this.imageKey,
    this.nutritionIsEstimate = true,
    this.matchReasons = const [
      'Uses items from your fridge',
      "Helps complete today's protein goal",
    ],
    this.requiredIngredients = const [],
    this.missingIngredients = const [],
    this.explanation,
  });

  /// Factory constructor to parse structured backend recommendation response
  factory RecipeRecommendation.fromJson(Map<String, dynamic> json) {
    final title = (json['name'] ?? json['title'] ?? 'Chef Special').toString();
    final mealType = (json['mealType'] ?? '').toString();
    final imageKey = json['imageKey']?.toString();
    final imageUrl = MealImageRegistry.resolveImage(
      imageKey: imageKey,
      mealName: title,
      providedUrl: json['imageUrl']?.toString(),
    );

    final List<String> requiredIngs = [];
    final List<String> missingIngs = [];
    int availableCount =
        (json['availableIngredientCount'] as num? ?? json['fridgeItemsUsed'] as num? ?? 0).toInt();

    if (json['ingredients'] is List) {
      for (final item in json['ingredients'] as List) {
        if (item is Map) {
          final name = (item['name'] ?? '').toString();
          if (name.isNotEmpty) requiredIngs.add(name);
          final inFridge = item['availableInFridge'] == true || item['inFridge'] == true;
          if (!inFridge && name.isNotEmpty) {
            missingIngs.add(name);
          }
        } else if (item is String) {
          requiredIngs.add(item);
        }
      }
    }

    if (json['missingIngredients'] is List) {
      for (final m in json['missingIngredients'] as List) {
        final s = m.toString();
        if (!missingIngs.contains(s)) missingIngs.add(s);
      }
    }

    if (availableCount == 0 && requiredIngs.isNotEmpty) {
      availableCount = requiredIngs.length - missingIngs.length;
      if (availableCount < 0) availableCount = 0;
    }

    final List<String> reasons = [];
    if (json['reason'] != null) {
      reasons.add(json['reason'].toString());
    } else if (json['matchReasons'] is List) {
      for (final r in json['matchReasons'] as List) {
        reasons.add(r.toString());
      }
    }
    if (reasons.isEmpty) {
      reasons.add('Uses $availableCount items from your fridge');
      reasons.add("Helps support today's protein goal");
    }

    return RecipeRecommendation(
      id: (json['id'] ?? '').toString(),
      title: title,
      calories: (json['calories'] as num? ?? 450).toInt(),
      proteinGrams: (json['proteinG'] as num? ??
              json['proteinGrams'] as num? ??
              json['protein'] as num? ??
              20)
          .toInt(),
      carbsGrams: (json['carbsG'] as num? ??
              json['carbsGrams'] as num? ??
              json['carbs'] as num? ??
              55)
          .toInt(),
      fatGrams: (json['fatG'] as num? ??
              json['fatGrams'] as num? ??
              json['fat'] as num? ??
              14)
          .toInt(),
      prepTimeMinutes: (json['preparationTimeMinutes'] as num? ??
              json['prepTimeMinutes'] as num? ??
              20)
          .toInt(),
      fridgeItemsUsed: availableCount > 0 ? availableCount : requiredIngs.length,
      mealType: mealType.isNotEmpty ? mealType.toUpperCase() : '',
      tag: mealType.isNotEmpty ? mealType.toUpperCase() : 'Picked for your fridge',
      imageUrl: imageUrl,
      imageKey: imageKey,
      nutritionIsEstimate: json['nutritionIsEstimate'] as bool? ?? true,
      matchReasons: reasons,
      requiredIngredients: requiredIngs,
      missingIngredients: missingIngs,
      explanation: (json['description'] ?? json['explanation'] ?? reasons.firstOrNull)?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': title,
      'mealType': mealType,
      'imageUrl': imageUrl,
      'imageKey': imageKey,
      'calories': calories,
      'proteinG': proteinGrams,
      'carbsG': carbsGrams,
      'fatG': fatGrams,
      'preparationTimeMinutes': prepTimeMinutes,
      'fridgeItemsUsed': fridgeItemsUsed,
      'requiredIngredients': requiredIngredients,
      'missingIngredients': missingIngredients,
      'matchReasons': matchReasons,
      'explanation': explanation,
    };
  }
}

class WellnessScoreData {
  final int currentScore;
  final int previousScore;
  final String statusText;
  final int maxScore;
  final bool hasSufficientData;

  const WellnessScoreData({
    required this.currentScore,
    required this.previousScore,
    required this.statusText,
    this.maxScore = 100,
    this.hasSufficientData = true,
  });

  int get scoreDiff => currentScore - previousScore;
}

class MacroNutrient {
  final String name;
  final int amountGrams;
  final int targetGrams;
  final String unit;

  const MacroNutrient({
    required this.name,
    required this.amountGrams,
    required this.targetGrams,
    this.unit = 'g',
  });

  double get progress => (amountGrams / targetGrams).clamp(0.0, 1.0);

  MacroNutrient copyWith({
    String? name,
    int? amountGrams,
    int? targetGrams,
    String? unit,
  }) {
    return MacroNutrient(
      name: name ?? this.name,
      amountGrams: amountGrams ?? this.amountGrams,
      targetGrams: targetGrams ?? this.targetGrams,
      unit: unit ?? this.unit,
    );
  }
}

class DailyNutritionData {
  final int consumedCalories;
  final int targetCalories;
  final MacroNutrient protein;
  final MacroNutrient carbs;
  final MacroNutrient fat;

  const DailyNutritionData({
    required this.consumedCalories,
    required this.targetCalories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  double get calorieProgress => (consumedCalories / targetCalories).clamp(0.0, 1.0);

  DailyNutritionData copyWith({
    int? consumedCalories,
    int? targetCalories,
    MacroNutrient? protein,
    MacroNutrient? carbs,
    MacroNutrient? fat,
  }) {
    return DailyNutritionData(
      consumedCalories: consumedCalories ?? this.consumedCalories,
      targetCalories: targetCalories ?? this.targetCalories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
    );
  }
}

enum MealStatus { completed, upcoming }

class MealItem {
  final String name;
  final MealStatus status;
  final String? time;
  final String iconEmoji;

  const MealItem({
    required this.name,
    required this.status,
    this.time,
    this.iconEmoji = '',
  });

  bool get isCompleted => status == MealStatus.completed;

  MealItem copyWith({
    String? name,
    MealStatus? status,
    String? time,
    String? iconEmoji,
  }) {
    return MealItem(
      name: name ?? this.name,
      status: status ?? this.status,
      time: time ?? this.time,
      iconEmoji: iconEmoji ?? this.iconEmoji,
    );
  }
}

class MockDataRepository {
  /// ValueNotifier triggering dashboard updates on meal logging
  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  static void _notify() {
    notifier.value++;
  }

  static UserProfile get user => UserProfile(
    name: _currentProfile.displayName.isNotEmpty ? _currentProfile.displayName : 'Food Explorer',
    greeting: _currentProfile.displayName.isNotEmpty
        ? 'Welcome back, ${_currentProfile.displayName} 👋'
        : 'Welcome to NutriFridge 👋',
    subtitle: 'Ready for a healthier day?',
  );

  static RecipeRecommendation? _explicitRecommendation;
  static RecipeRecommendation? get recommendation =>
      _explicitRecommendation ?? _deriveDynamicRecommendation();

  static RecommendationStatus get recommendationStatus {
    if (_explicitRecommendation != null) return RecommendationStatus.loaded;
    return MealRecommendationService.currentStatus;
  }

  static void setRecommendationForTesting(RecipeRecommendation? rec) {
    _explicitRecommendation = rec;
    _notify();
  }

  static RecipeRecommendation? _deriveDynamicRecommendation() {
    return MealRecommendationService.getRecommendation();
  }

  static WellnessScoreData? _explicitWellness;
  static WellnessScoreData? get wellness =>
      _explicitWellness ?? _deriveDynamicWellness();

  static void setWellnessForTesting(WellnessScoreData? w) {
    _explicitWellness = w;
    _notify();
  }

  static WellnessScoreData? _deriveDynamicWellness() {
    if (_loggedMealsHistory.isEmpty) return null;
    final mealsCount = _loggedMealsHistory.length;
    final score = (72 + (mealsCount * 5)).clamp(70, 95);
    final prev = score - 2;
    return WellnessScoreData(
      currentScore: score,
      previousScore: prev,
      statusText: score >= 85 ? 'Great today' : 'Good progress',
      hasSufficientData: true,
    );
  }

  static const DailyNutritionData _initialNutrition = DailyNutritionData(
    consumedCalories: 0,
    targetCalories: 2000,
    protein: MacroNutrient(name: 'Protein', amountGrams: 0, targetGrams: 90),
    carbs: MacroNutrient(name: 'Carbs', amountGrams: 0, targetGrams: 260),
    fat: MacroNutrient(name: 'Fat', amountGrams: 0, targetGrams: 70),
  );

  static DailyNutritionData _currentNutrition = _initialNutrition;
  static List<MealItem> _currentMeals = [];
  static final List<Map<String, dynamic>> _loggedMealsHistory = [];
  static UserProfileData _currentProfile = const UserProfileData(
    displayName: '',
    dietaryPreference: null,
    nutritionGoal: null,
    dailyCalorieTarget: null,
    allergies: {},
    avoidedFoods: {},
    customRestrictions: [],
    mealRemindersEnabled: false,
    expiryAlertsEnabled: false,
  );

  /// Current user profile settings
  static UserProfileData get profile => _currentProfile;

  /// Updates user profile settings and syncs calorie target if modified
  static void updateProfile(UserProfileData updated) {
    _currentProfile = updated;
    if (updated.dailyCalorieTarget != null) {
      _currentNutrition = _currentNutrition.copyWith(
        targetCalories: updated.dailyCalorieTarget!,
      );
    }
    _notify();
  }

  /// Current daily nutrition totals
  static DailyNutritionData get nutrition => _currentNutrition;

  /// Current today's meals list
  static List<MealItem> get meals => List.unmodifiable(_currentMeals);

  /// Mock meal history log
  static List<Map<String, dynamic>> get loggedMealsHistory => List.unmodifiable(_loggedMealsHistory);

  /// Logs a meal into the mock state, updating nutrition progress and meal status.
  static void logMeal({
    required String mealType,
    required String mealName,
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
    List<String>? ingredients,
    DateTime? timestamp,
  }) {
    // 1. Add nutrition totals
    _currentNutrition = _currentNutrition.copyWith(
      consumedCalories: _currentNutrition.consumedCalories + calories,
      protein: _currentNutrition.protein.copyWith(
        amountGrams: _currentNutrition.protein.amountGrams + protein,
      ),
      carbs: _currentNutrition.carbs.copyWith(
        amountGrams: _currentNutrition.carbs.amountGrams + carbs,
      ),
      fat: _currentNutrition.fat.copyWith(
        amountGrams: _currentNutrition.fat.amountGrams + fat,
      ),
    );

    // 2. Format current time
    final timeNow = timestamp ?? DateTime.now();
    final rawHour = timeNow.hour;
    final hour = rawHour > 12 ? rawHour - 12 : (rawHour == 0 ? 12 : rawHour);
    final minute = timeNow.minute.toString().padLeft(2, '0');
    final period = rawHour >= 12 ? 'PM' : 'AM';
    final timeString = '$hour:$minute $period';

    // 3. Update matching meal item in Today's Meals
    final cleanType = mealType.trim().toLowerCase();
    final index = _currentMeals.indexWhere((m) => m.name.toLowerCase() == cleanType);
    if (index != -1) {
      _currentMeals[index] = _currentMeals[index].copyWith(
        status: MealStatus.completed,
        time: timeString,
      );
    } else {
      _currentMeals.add(
        MealItem(
          name: mealType,
          status: MealStatus.completed,
          time: timeString,
        ),
      );
    }

    // 4. Save to history
    _loggedMealsHistory.add({
      'mealType': mealType,
      'mealName': mealName,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'ingredients': ingredients ?? const <String>[],
      'timestamp': timeNow,
    });

    // 5. Post synchronized in-app notification
    NotificationRepository.addNotification(
      title: 'Meal logged',
      description: 'Your $mealType ($mealName) has been added to today\'s nutrition.',
      type: NotificationType.mealLogged,
    );

    _notify();
  }

  /// Seeds sample demo data for specific automated widget test suites
  static void seedSampleDataForTesting() {
    _explicitRecommendation = const RecipeRecommendation(
      title: 'Paneer Rice Bowl',
      calories: 520,
      proteinGrams: 24,
      carbsGrams: 62,
      fatGrams: 18,
      prepTimeMinutes: 20,
      fridgeItemsUsed: 4,
      tag: 'Picked for your fridge',
      imageUrl: 'assets/images/paneer_rice_bowl.jpg',
      matchReasons: [
        'Uses 4 ingredients from your fridge',
        "Helps support today's protein goal",
      ],
      requiredIngredients: ['Paneer', 'Rice', 'Capsicum', 'Onion'],
    );
    _explicitWellness = const WellnessScoreData(
      currentScore: 82,
      previousScore: 78,
      statusText: 'Great today',
      hasSufficientData: true,
    );
    _currentNutrition = const DailyNutritionData(
      consumedCalories: 1620,
      targetCalories: 2200,
      protein: MacroNutrient(name: 'Protein', amountGrams: 72, targetGrams: 90),
      carbs: MacroNutrient(name: 'Carbs', amountGrams: 210, targetGrams: 260),
      fat: MacroNutrient(name: 'Fat', amountGrams: 62, targetGrams: 70),
    );
    _currentMeals = [
      const MealItem(
        name: 'Breakfast',
        status: MealStatus.completed,
        time: '8:30 AM',
        iconEmoji: '🍳',
      ),
      const MealItem(
        name: 'Lunch',
        status: MealStatus.completed,
        time: '1:15 PM',
        iconEmoji: '🥗',
      ),
      const MealItem(
        name: 'Snack',
        status: MealStatus.upcoming,
        time: '4:45 PM',
        iconEmoji: '🍎',
      ),
      const MealItem(
        name: 'Dinner',
        status: MealStatus.upcoming,
        time: '8:00 PM',
        iconEmoji: '🍲',
      ),
    ];
    _currentProfile = const UserProfileData(
      displayName: 'Ridhim',
      dietaryPreference: 'Vegetarian',
      nutritionGoal: 'Balanced eating',
      dailyCalorieTarget: 2200,
      allergies: {},
      avoidedFoods: {},
      customRestrictions: [],
      mealRemindersEnabled: true,
      expiryAlertsEnabled: true,
    );
    _loggedMealsHistory.clear();
    _loggedMealsHistory.addAll([
      {
        'mealType': 'breakfast',
        'mealName': 'Oats & Banana',
        'calories': 380,
        'protein': 14,
        'carbs': 65,
        'fat': 8,
      },
      {
        'mealType': 'lunch',
        'mealName': 'Paneer Rice Bowl',
        'calories': 520,
        'protein': 24,
        'carbs': 62,
        'fat': 18,
      },
    ]);
    _notify();
  }

  static void clearLoggedMealsHistoryForTesting() {
    _loggedMealsHistory.clear();
    _notify();
  }

  /// Resets mock repository to clean initial empty state
  static void reset() {
    _currentNutrition = _initialNutrition;
    _currentMeals = [];
    _loggedMealsHistory.clear();
    _currentProfile = const UserProfileData(
      displayName: '',
      dietaryPreference: null,
      nutritionGoal: null,
      dailyCalorieTarget: null,
      allergies: {},
      avoidedFoods: {},
      customRestrictions: [],
      mealRemindersEnabled: false,
      expiryAlertsEnabled: false,
    );
    _explicitRecommendation = null;
    _explicitWellness = null;
    MealRecommendationService.reset();
    NotificationRepository.reset();
    _notify();
  }
}
