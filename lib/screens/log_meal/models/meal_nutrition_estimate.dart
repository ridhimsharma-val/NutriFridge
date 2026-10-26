import 'detected_food_item.dart';

/// Estimated nutrition data for a logged meal.
/// Contains macro and micronutrient values structured so that
/// real nutrition API results can replace the prototype estimates in the future.
class MealNutritionEstimate {
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final double fiberGrams;
  final double sugarsGrams;
  final int sodiumMg;
  final int potassiumMg;

  const MealNutritionEstimate({
    this.calories = 520,
    this.proteinGrams = 24,
    this.carbsGrams = 62,
    this.fatGrams = 18,
    this.fiberGrams = 6.2,
    this.sugarsGrams = 4.5,
    this.sodiumMg = 380,
    this.potassiumMg = 410,
  });

  /// Dynamically estimates nutritional values based on the ingredients list and their portions.
  static MealNutritionEstimate fromIngredients(List<DetectedFoodItem> items) {
    if (items.isEmpty) {
      return const MealNutritionEstimate(
        calories: 0,
        proteinGrams: 0,
        carbsGrams: 0,
        fatGrams: 0,
        fiberGrams: 0,
        sugarsGrams: 0,
        sodiumMg: 0,
        potassiumMg: 0,
      );
    }

    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    double totalFiber = 0;
    double totalSugars = 0;
    double totalSodium = 0;
    double totalPotassium = 0;

    for (final item in items) {
      final cleanName = item.name.toLowerCase().trim();
      final double amount = item.amount > 0 ? item.amount : 0;
      final String unit = item.unit.toLowerCase().trim();

      // Multiplier relative to reference 100g (or 1 piece)
      double factor;
      if (unit == 'g' || unit == 'ml') {
        factor = amount / 100.0;
      } else if (unit == 'cup' || unit == 'bowl') {
        factor = (amount * 200.0) / 100.0;
      } else if (unit == 'tbsp') {
        factor = (amount * 15.0) / 100.0;
      } else {
        // pieces or default
        factor = amount;
      }

      // Nutrient profiles per 100g or per piece
      // [calories, protein, carbs, fat, fiber, sugars, sodium, potassium]
      List<double> profile;
      if (cleanName.contains('paneer')) {
        profile = [265, 18, 4, 15, 0.0, 1.0, 200, 100];
      } else if (cleanName.contains('rice')) {
        profile = [130, 2.67, 30, 0.33, 0.4, 0.13, 33.3, 40];
      } else if (cleanName.contains('veg') || cleanName.contains('vegetable') || cleanName.contains('salad')) {
        profile = [75, 2.5, 16.25, 3.125, 7.0, 4.125, 162.5, 312.5];
      } else if (cleanName.contains('chicken')) {
        profile = [165, 31, 0, 3.6, 0.0, 0.0, 74, 256];
      } else if (cleanName.contains('fish')) {
        profile = [120, 22, 0, 3.0, 0.0, 0.0, 60, 300];
      } else if (cleanName.contains('egg')) {
        profile = [70, 6, 0.6, 5.0, 0.0, 0.6, 70, 65];
      } else if (cleanName.contains('apple')) {
        profile = [52, 0.3, 14, 0.2, 2.4, 10.0, 1, 107];
      } else if (cleanName.contains('milk') || cleanName.contains('curd') || cleanName.contains('yogurt')) {
        profile = [60, 3.5, 4.8, 3.3, 0.0, 4.8, 50, 150];
      } else if (cleanName.contains('bread') || cleanName.contains('roti')) {
        profile = [130, 4.5, 25, 1.8, 1.5, 2.0, 220, 60];
      } else if (cleanName.contains('carrot')) {
        profile = [41, 0.9, 10, 0.2, 2.8, 4.7, 69, 320];
      } else if (cleanName.contains('broccoli')) {
        profile = [34, 2.8, 7, 0.4, 2.6, 1.7, 33, 316];
      } else {
        // Generic food fallback
        profile = [100, 3.0, 15, 3.0, 1.5, 2.0, 80, 120];
      }

      totalCalories += profile[0] * factor;
      totalProtein += profile[1] * factor;
      totalCarbs += profile[2] * factor;
      totalFat += profile[3] * factor;
      totalFiber += profile[4] * factor;
      totalSugars += profile[5] * factor;
      totalSodium += profile[6] * factor;
      totalPotassium += profile[7] * factor;
    }

    return MealNutritionEstimate(
      calories: totalCalories.round(),
      proteinGrams: totalProtein.round(),
      carbsGrams: totalCarbs.round(),
      fatGrams: totalFat.round(),
      fiberGrams: double.parse(totalFiber.toStringAsFixed(1)),
      sugarsGrams: double.parse(totalSugars.toStringAsFixed(1)),
      sodiumMg: totalSodium.round(),
      potassiumMg: totalPotassium.round(),
    );
  }

  MealNutritionEstimate copyWith({
    int? calories,
    int? proteinGrams,
    int? carbsGrams,
    int? fatGrams,
    double? fiberGrams,
    double? sugarsGrams,
    int? sodiumMg,
    int? potassiumMg,
  }) {
    return MealNutritionEstimate(
      calories: calories ?? this.calories,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      carbsGrams: carbsGrams ?? this.carbsGrams,
      fatGrams: fatGrams ?? this.fatGrams,
      fiberGrams: fiberGrams ?? this.fiberGrams,
      sugarsGrams: sugarsGrams ?? this.sugarsGrams,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      potassiumMg: potassiumMg ?? this.potassiumMg,
    );
  }
}
