/// Structured meal context passed when transitioning from Meal Detail to AI Assistant.
class MealAiContext {
  final String mealId;
  final String mealTitle;
  final String mealDescription;
  final String mealType;
  final String nutritionSummary;
  final String servingSize;
  final int? prepTimeMinutes;
  final int? cookingTimeMinutes;
  final List<String> requiredIngredients;
  final Map<String, String> availableFridgeQuantities;
  final List<String> missingIngredients;
  final List<String> preparationSteps;
  final List<String> cookingTips;
  final List<String> substitutions;
  final List<String> recommendationReasons;

  const MealAiContext({
    required this.mealId,
    required this.mealTitle,
    this.mealDescription = '',
    required this.mealType,
    required this.nutritionSummary,
    this.servingSize = '1 serving',
    this.prepTimeMinutes,
    this.cookingTimeMinutes,
    required this.requiredIngredients,
    required this.availableFridgeQuantities,
    required this.missingIngredients,
    this.preparationSteps = const [],
    this.cookingTips = const [],
    this.substitutions = const [],
    this.recommendationReasons = const [],
  });

  Map<String, dynamic> toJson() => {
        'mealId': mealId,
        'mealTitle': mealTitle,
        'mealDescription': mealDescription,
        'mealType': mealType,
        'nutritionSummary': nutritionSummary,
        'servingSize': servingSize,
        if (prepTimeMinutes != null) 'prepTimeMinutes': prepTimeMinutes,
        if (cookingTimeMinutes != null) 'cookingTimeMinutes': cookingTimeMinutes,
        'requiredIngredients': requiredIngredients,
        'availableFridgeQuantities': availableFridgeQuantities,
        'missingIngredients': missingIngredients,
        'preparationSteps': preparationSteps,
        if (cookingTips.isNotEmpty) 'cookingTips': cookingTips,
        if (substitutions.isNotEmpty) 'substitutions': substitutions,
        'recommendationReasons': recommendationReasons,
      };
}
