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
}

class MockDataRepository {
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

  static const DailyNutritionData nutrition = DailyNutritionData(
    consumedCalories: 1620,
    targetCalories: 2200,
    protein: MacroNutrient(name: 'Protein', amountGrams: 72, targetGrams: 90),
    carbs: MacroNutrient(name: 'Carbs', amountGrams: 210, targetGrams: 260),
    fat: MacroNutrient(name: 'Fat', amountGrams: 62, targetGrams: 70),
  );

  static const List<MealItem> meals = [
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
}
