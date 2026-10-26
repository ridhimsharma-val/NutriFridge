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
