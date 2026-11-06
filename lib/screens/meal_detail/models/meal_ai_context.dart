/// Structured meal context passed when transitioning from Meal Detail to AI Assistant.
class MealAiContext {
  final String mealId;
  final String mealTitle;
  final String mealDescription;
  final String mealType;
  final String nutritionSummary;
  final String servingSize;
  final List<String> requiredIngredients;
  final Map<String, String> availableFridgeQuantities;
  final List<String> missingIngredients;
  final List<String> preparationSteps;
  final List<String> recommendationReasons;

  const MealAiContext({
    required this.mealId,
    required this.mealTitle,
    this.mealDescription = '',
    required this.mealType,
    required this.nutritionSummary,
    this.servingSize = '1 serving',
    required this.requiredIngredients,
    required this.availableFridgeQuantities,
    required this.missingIngredients,
    this.preparationSteps = const [],
    this.recommendationReasons = const [],
  });

  Map<String, dynamic> toJson() => {
        'mealId': mealId,
        'mealTitle': mealTitle,
        'mealDescription': mealDescription,
        'mealType': mealType,
        'nutritionSummary': nutritionSummary,
        'servingSize': servingSize,
        'requiredIngredients': requiredIngredients,
        'availableFridgeQuantities': availableFridgeQuantities,
        'missingIngredients': missingIngredients,
        'preparationSteps': preparationSteps,
        'recommendationReasons': recommendationReasons,
      };
}
