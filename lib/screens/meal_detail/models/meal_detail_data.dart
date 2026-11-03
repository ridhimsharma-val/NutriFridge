import '../../../models/nutrition_data.dart';
import '../../fridge/models/category_item.dart';
import '../../home/services/meal_recommendation_service.dart';
import 'recipe_video_item.dart';

/// Inventory availability status for a recipe ingredient.
enum IngredientAvailability {
  available, // In current fridge inventory
  partial, // Partially available or pantry staple
  notTracked, // Not currently tracked in fridge
}

/// A specific ingredient required for a meal with its inventory match state.
class MealIngredientItem {
  final String name;
  final String recipeQuantity;
  final IngredientAvailability availability;
  final String statusLabel;

  const MealIngredientItem({
    required this.name,
    required this.recipeQuantity,
    required this.availability,
    required this.statusLabel,
  });
}

/// Comprehensive meal information model supporting cinematic presentation.
class MealDetailInfo {
  final String name;
  final String tag;
  final String imageUrl;
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final int prepTimeMinutes;
  final List<String> whyReasons;
  final List<MealIngredientItem> ingredients;
  final List<RecipeVideoItem> videos;

  const MealDetailInfo({
    required this.name,
    required this.tag,
    required this.imageUrl,
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.prepTimeMinutes,
    required this.whyReasons,
    required this.ingredients,
    this.videos = const [],
  });

  /// Derives detailed meal information from the dashboard [RecipeRecommendation],
  /// cross-referencing [FridgeCategoryRepository] for real-time inventory tracking.
  factory MealDetailInfo.fromRecommendation(RecipeRecommendation rec) {
    List<String> ingredientsToResolve = rec.requiredIngredients;
    if (ingredientsToResolve.isEmpty) {
      final catalogMatch = MealRecommendationService.recipeCatalog
          .where((r) => r.title.toLowerCase() == rec.title.toLowerCase())
          .firstOrNull;
      if (catalogMatch != null) {
        ingredientsToResolve = catalogMatch.requiredIngredients;
      } else {
        ingredientsToResolve = const ['Paneer', 'Rice', 'Capsicum', 'Onion'];
      }
    }

    final resolvedIngredients = <MealIngredientItem>[];
    for (final ingName in ingredientsToResolve) {
      final foundItem = FridgeCategoryRepository.findItemByName(ingName, exact: true);
      if (foundItem != null) {
        resolvedIngredients.add(
          MealIngredientItem(
            name: ingName,
            recipeQuantity: foundItem.quantity,
            availability: IngredientAvailability.available,
            statusLabel: 'In fridge · ${foundItem.quantity}',
          ),
        );
      } else if (ingName.toLowerCase() == 'rice') {
        resolvedIngredients.add(
          const MealIngredientItem(
            name: 'Rice',
            recipeQuantity: '1 cooked bowl',
            availability: IngredientAvailability.partial,
            statusLabel: 'Available in pantry',
          ),
        );
      } else {
        resolvedIngredients.add(
          MealIngredientItem(
            name: ingName,
            recipeQuantity: '1 medium chopped',
            availability: IngredientAvailability.notTracked,
            statusLabel: 'Not in fridge',
          ),
        );
      }
    }

    final reasons = rec.matchReasons.isNotEmpty
        ? rec.matchReasons
        : [
            'Uses ${rec.fridgeItemsUsed > 0 ? rec.fridgeItemsUsed : 4} ingredients from your fridge',
            "Helps support today's protein goal",
          ];

    return MealDetailInfo(
      name: rec.title,
      tag: rec.tag.isNotEmpty ? rec.tag : 'Picked for your fridge',
      imageUrl: rec.imageUrl,
      calories: rec.calories,
      proteinGrams: rec.proteinGrams,
      carbsGrams: rec.carbsGrams,
      fatGrams: rec.fatGrams,
      prepTimeMinutes: rec.prepTimeMinutes,
      whyReasons: reasons,
      ingredients: resolvedIngredients,
      videos: const [],
    );
  }
}
