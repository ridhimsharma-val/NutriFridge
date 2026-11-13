import 'package:flutter/foundation.dart';
import '../../meal_detail/models/meal_detail_data.dart';
import 'meal_nutrition_estimate.dart';

/// Structured data passed into the Cinematic Meal Logging & Nutrition Reveal experience.
/// Captures verified nutrition, ingredient details, and metadata from genuine meal logging.
@immutable
class CinematicMealData {
  final String mealName;
  final String? mealType;
  final String? servingSize;
  final String? imageUrl;
  final DateTime loggedAt;
  final int calories;
  final num proteinGrams;
  final num carbsGrams;
  final num fatGrams;
  final num? fiberGrams;
  final num? sugarGrams;
  final num? sodiumMg;
  final num? potassiumMg;
  final List<String> ingredients;
  final Map<String, String> extraNutrients;

  const CinematicMealData({
    required this.mealName,
    this.mealType,
    this.servingSize,
    this.imageUrl,
    required this.loggedAt,
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    this.fiberGrams,
    this.sugarGrams,
    this.sodiumMg,
    this.potassiumMg,
    this.ingredients = const [],
    this.extraNutrients = const {},
  });

  /// Factory constructor from [MealDetailInfo] (Recipe & Meal Detail flow).
  factory CinematicMealData.fromMealDetail({
    required MealDetailInfo meal,
    String? mealType,
    DateTime? loggedAt,
  }) {
    final cleanIngredients = meal.ingredients
        .map((i) => i.name.trim())
        .where((n) => n.isNotEmpty)
        .toList();

    return CinematicMealData(
      mealName: meal.name,
      mealType: mealType ?? meal.mealType ?? (meal.tag.isNotEmpty ? meal.tag : null),
      servingSize: meal.servingSize.isNotEmpty ? meal.servingSize : '1 serving',
      imageUrl: meal.imageUrl.isNotEmpty ? meal.imageUrl : null,
      loggedAt: loggedAt ?? DateTime.now(),
      calories: meal.calories ?? 0,
      proteinGrams: meal.proteinGrams ?? 0,
      carbsGrams: meal.carbsGrams ?? 0,
      fatGrams: meal.fatGrams ?? 0,
      fiberGrams: meal.fiberGrams,
      sugarGrams: null, // Only include if explicitly provided; never fabricate
      sodiumMg: null,
      potassiumMg: null,
      ingredients: cleanIngredients,
    );
  }

  /// Factory constructor from [MealNutritionEstimate] (Camera / Manual Review flow).
  factory CinematicMealData.fromNutritionEstimate({
    required String mealName,
    required MealNutritionEstimate nutrition,
    required List<String> ingredients,
    String? mealType,
    String? servingSize,
    String? imageUrl,
    DateTime? loggedAt,
  }) {
    // Only pass micronutrients if they are non-zero / explicitly set
    return CinematicMealData(
      mealName: mealName,
      mealType: mealType,
      servingSize: servingSize ?? '1 serving',
      imageUrl: (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : null,
      loggedAt: loggedAt ?? DateTime.now(),
      calories: nutrition.calories,
      proteinGrams: nutrition.proteinGrams,
      carbsGrams: nutrition.carbsGrams,
      fatGrams: nutrition.fatGrams,
      fiberGrams: nutrition.fiberGrams > 0 ? nutrition.fiberGrams : null,
      sugarGrams: nutrition.sugarsGrams > 0 ? nutrition.sugarsGrams : null,
      sodiumMg: nutrition.sodiumMg > 0 ? nutrition.sodiumMg : null,
      potassiumMg: nutrition.potassiumMg > 0 ? nutrition.potassiumMg : null,
      ingredients: ingredients,
    );
  }

  /// Factory constructor for AI Assistant meal suggestions.
  factory CinematicMealData.fromAiAssistant({
    required String mealName,
    required Map<dynamic, dynamic> nutritionMap,
    required List<String> ingredients,
    String? mealType,
    String? servingSize,
    String? imageUrl,
    DateTime? loggedAt,
  }) {
    final calories = (nutritionMap['calories'] as num?)?.toInt() ?? 0;
    final protein = (nutritionMap['proteinG'] as num? ??
            nutritionMap['protein'] as num? ??
            nutritionMap['proteinGrams'] as num?) ??
        0;
    final carbs = (nutritionMap['carbsG'] as num? ??
            nutritionMap['carbs'] as num? ??
            nutritionMap['carbsGrams'] as num?) ??
        0;
    final fat = (nutritionMap['fatG'] as num? ??
            nutritionMap['fat'] as num? ??
            nutritionMap['fatGrams'] as num?) ??
        0;

    final rawFiber = nutritionMap['fiberG'] as num? ??
        nutritionMap['fiber'] as num? ??
        nutritionMap['fiberGrams'] as num?;
    final rawSugar = nutritionMap['sugarsG'] as num? ??
        nutritionMap['sugar'] as num? ??
        nutritionMap['sugarsGrams'] as num?;
    final rawSodium = nutritionMap['sodiumMg'] as num? ??
        nutritionMap['sodium'] as num?;
    final rawPotassium = nutritionMap['potassiumMg'] as num? ??
        nutritionMap['potassium'] as num?;

    return CinematicMealData(
      mealName: mealName,
      mealType: mealType,
      servingSize: servingSize ?? '1 serving',
      imageUrl: (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : null,
      loggedAt: loggedAt ?? DateTime.now(),
      calories: calories,
      proteinGrams: protein,
      carbsGrams: carbs,
      fatGrams: fat,
      fiberGrams: (rawFiber != null && rawFiber > 0) ? rawFiber : null,
      sugarGrams: (rawSugar != null && rawSugar > 0) ? rawSugar : null,
      sodiumMg: (rawSodium != null && rawSodium > 0) ? rawSodium : null,
      potassiumMg: (rawPotassium != null && rawPotassium > 0) ? rawPotassium : null,
      ingredients: ingredients,
    );
  }

  /// Formatted logging time (e.g. "1:30 PM" or "Just now")
  String get formattedLoggedTime {
    final now = DateTime.now();
    final diff = now.difference(loggedAt);
    if (diff.inMinutes < 1) {
      return 'Just now';
    }
    final hour = loggedAt.hour;
    final minute = loggedAt.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final standardHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$standardHour:$minute $ampm';
  }
}
