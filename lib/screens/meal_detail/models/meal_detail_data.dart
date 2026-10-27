import '../../../models/nutrition_data.dart';
import '../../fridge/models/category_item.dart';

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
  });

  /// Derives detailed meal information from the dashboard [RecipeRecommendation],
  /// cross-referencing [FridgeCategoryRepository] for real-time inventory tracking.
  factory MealDetailInfo.fromRecommendation(RecipeRecommendation rec) {
    // 1. Check Paneer in fridge inventory
    final paneerItem = FridgeCategoryRepository.findItemByName('Paneer', exact: true);
    final paneerIngredient = MealIngredientItem(
      name: 'Paneer',
      recipeQuantity: '150 g diced',
      availability: paneerItem != null
          ? IngredientAvailability.available
          : IngredientAvailability.notTracked,
      statusLabel: paneerItem != null
          ? 'In fridge · ${paneerItem.quantity}'
          : 'Not in fridge',
    );

    // 2. Check Rice (Pantry staple / leftover rice)
    final riceItem = FridgeCategoryRepository.findItemByName('Rice', exact: true);
    final riceIngredient = MealIngredientItem(
      name: 'Rice',
      recipeQuantity: '1 cooked bowl',
      availability: riceItem != null
          ? IngredientAvailability.available
          : IngredientAvailability.partial,
      statusLabel: riceItem != null
          ? 'In fridge · ${riceItem.quantity}'
          : 'Available in pantry',
    );

    // 3. Check Capsicum in fridge inventory
    final capsicumItem = FridgeCategoryRepository.findItemByName('Capsicum', exact: true);
    final capsicumIngredient = MealIngredientItem(
      name: 'Capsicum',
      recipeQuantity: '1 sliced',
      availability: capsicumItem != null
          ? IngredientAvailability.available
          : IngredientAvailability.notTracked,
      statusLabel: capsicumItem != null
          ? 'In fridge · ${capsicumItem.quantity}'
          : 'Not in fridge',
    );

    // 4. Check Onion in fridge inventory
    final onionItem = FridgeCategoryRepository.findItemByName('Onion', exact: true);
    final onionIngredient = MealIngredientItem(
      name: 'Onion',
      recipeQuantity: '1 medium chopped',
      availability: onionItem != null
          ? IngredientAvailability.available
          : IngredientAvailability.notTracked,
      statusLabel: onionItem != null
          ? 'In fridge · ${onionItem.quantity}'
          : 'Not in fridge',
    );

    final resolvedIngredients = [
      paneerIngredient,
      riceIngredient,
      capsicumIngredient,
      onionIngredient,
    ];

    return MealDetailInfo(
      name: rec.title,
      tag: rec.tag.isNotEmpty ? rec.tag : 'Picked for your fridge',
      imageUrl: rec.imageUrl,
      calories: rec.calories,
      proteinGrams: rec.proteinGrams,
      carbsGrams: 62,
      fatGrams: 18,
      prepTimeMinutes: 20,
      whyReasons: [
        'Uses ${rec.fridgeItemsUsed > 0 ? rec.fridgeItemsUsed : 4} ingredients from your fridge',
        "Helps support today's protein goal",
      ],
      ingredients: resolvedIngredients,
    );
  }
}
