import 'package:flutter/foundation.dart';
import '../screens/profile/models/user_profile_data.dart';

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
  final String title;
  final int calories;
  final int proteinGrams;
  final int fridgeItemsUsed;
  final String tag;
  final String imageUrl;
  final List<String> matchReasons;

  const RecipeRecommendation({
    required this.title,
    required this.calories,
    required this.proteinGrams,
    required this.fridgeItemsUsed,
    this.tag = 'Picked for your fridge',
    required this.imageUrl,
    this.matchReasons = const [
      'Uses 4 items from your fridge',
      "Helps complete today's protein goal",
    ],
  });
}

class WellnessScoreData {
  final int currentScore;
  final int previousScore;
  final String statusText;
  final int maxScore;

  const WellnessScoreData({
    required this.currentScore,
    required this.previousScore,
    required this.statusText,
    this.maxScore = 100,
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

  static const UserProfile user = UserProfile(
    name: 'Ridhim',
    greeting: 'Good Evening, Ridhim 👋',
    subtitle: 'Ready for a healthier day?',
  );

  static const RecipeRecommendation recommendation = RecipeRecommendation(
    title: 'Paneer Rice Bowl',
    calories: 520,
    proteinGrams: 24,
    fridgeItemsUsed: 4,
    tag: 'Picked for your fridge',
    imageUrl: 'assets/images/paneer_rice_bowl.jpg',
  );

  static const WellnessScoreData wellness = WellnessScoreData(
    currentScore: 82,
    previousScore: 78,
    statusText: 'Great today',
  );

  static const DailyNutritionData _initialNutrition = DailyNutritionData(
    consumedCalories: 1620,
    targetCalories: 2200,
    protein: MacroNutrient(name: 'Protein', amountGrams: 72, targetGrams: 90),
    carbs: MacroNutrient(name: 'Carbs', amountGrams: 210, targetGrams: 260),
    fat: MacroNutrient(name: 'Fat', amountGrams: 62, targetGrams: 70),
  );

  static const List<MealItem> _initialMeals = [
    MealItem(
      name: 'Breakfast',
      status: MealStatus.completed,
      time: '8:30 AM',
      iconEmoji: '🍳',
    ),
    MealItem(
      name: 'Lunch',
      status: MealStatus.completed,
      time: '1:15 PM',
      iconEmoji: '🥗',
    ),
    MealItem(
      name: 'Snack',
      status: MealStatus.upcoming,
      time: '4:45 PM',
      iconEmoji: '🍎',
    ),
    MealItem(
      name: 'Dinner',
      status: MealStatus.upcoming,
      time: '8:00 PM',
      iconEmoji: '🍲',
    ),
  ];

  static DailyNutritionData _currentNutrition = _initialNutrition;
  static List<MealItem> _currentMeals = List<MealItem>.from(_initialMeals);
  static final List<Map<String, dynamic>> _loggedMealsHistory = [];
  static UserProfileData _currentProfile = const UserProfileData(
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

    _notify();
  }

  /// Resets mock repository to clean initial state (for tests)
  static void reset() {
    _currentNutrition = _initialNutrition;
    _currentMeals = List<MealItem>.from(_initialMeals);
    _loggedMealsHistory.clear();
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
    _notify();
  }
}
