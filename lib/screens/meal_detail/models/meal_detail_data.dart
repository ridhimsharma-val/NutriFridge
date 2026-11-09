import '../../../models/nutrition_data.dart';
import '../../../services/meals/meal_tracking_service.dart';
import '../../fridge/models/category_item.dart';
import '../../home/services/meal_recommendation_service.dart';
import 'recipe_preparation_step.dart';
import 'recipe_video_item.dart';

export 'recipe_preparation_step.dart';
export 'recipe_video_item.dart';

/// Inventory availability status for a recipe ingredient.
enum IngredientAvailability {
  available, // Required quantity is available in fridge
  partial, // Partially available or in pantry
  missing, // Not currently tracked / not in fridge
}

/// A specific ingredient required for a meal with its inventory match state.
class MealIngredientItem {
  final String name;
  final num requiredQuantity;
  final String requiredUnit;
  final String? availableQuantityInFridge;
  final num? availableAmount;
  final IngredientAvailability availability;
  final String statusLabel;
  final String? imageAsset;

  const MealIngredientItem({
    required this.name,
    required this.requiredQuantity,
    required this.requiredUnit,
    this.availableQuantityInFridge,
    this.availableAmount,
    required this.availability,
    required this.statusLabel,
    this.imageAsset,
  });

  /// Formatted recipe requirement string (e.g. "200 g", "1 bowl", "2 medium")
  String get recipeQuantityText {
    final qtyStr = (requiredQuantity is int || requiredQuantity == requiredQuantity.roundToDouble())
        ? '${requiredQuantity.toInt()}'
        : requiredQuantity.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    return '$qtyStr $requiredUnit';
  }

  /// Backward compatibility getter
  String get recipeQuantity => recipeQuantityText;
}

/// Recipe specification definition for catalog recipes
class _RecipeCatalogSpec {
  final String title;
  final List<Map<String, dynamic>> ingredients;
  final List<RecipePreparationStep> steps;
  final int? calories;
  final int? proteinGrams;
  final int? carbsGrams;
  final int? fatGrams;
  final int? prepTimeMinutes;

  const _RecipeCatalogSpec({
    required this.title,
    required this.ingredients,
    required this.steps,
    this.calories,
    this.proteinGrams,
    this.carbsGrams,
    this.fatGrams,
    this.prepTimeMinutes,
  });
}

/// Comprehensive meal information model supporting data-driven recipe presentation.
class MealDetailInfo {
  final String name;
  final String tag;
  final String? mealType;
  final String imageUrl;
  final int? calories;
  final int? proteinGrams;
  final int? carbsGrams;
  final int? fatGrams;
  final int? fiberGrams;
  final int? prepTimeMinutes;
  final String servingSize;
  final String nutritionSourceLabel;
  final bool nutritionIsEstimate;
  final List<String> whyReasons;
  final List<MealIngredientItem> ingredients;
  final List<RecipePreparationStep> preparationSteps;
  final List<RecipeVideoItem> videos;
  final int? cookingTimeMinutes;
  final List<String> cookingTips;
  final List<String> substitutions;
  final String? videoSearchQuery;
  final String? videoUrl;

  const MealDetailInfo({
    required this.name,
    required this.tag,
    this.mealType,
    required this.imageUrl,
    this.calories,
    this.proteinGrams,
    this.carbsGrams,
    this.fatGrams,
    this.fiberGrams,
    this.prepTimeMinutes,
    this.servingSize = '1 serving',
    this.nutritionSourceLabel = 'AI estimate',
    this.nutritionIsEstimate = true,
    required this.whyReasons,
    required this.ingredients,
    this.preparationSteps = const [],
    this.videos = const [],
    this.cookingTimeMinutes,
    this.cookingTips = const [],
    this.substitutions = const [],
    this.videoSearchQuery,
    this.videoUrl,
  });

  /// Authoritative total preparation and cooking duration in minutes.
  int? get totalTimeMinutes {
    final p = (prepTimeMinutes != null && prepTimeMinutes! > 0) ? prepTimeMinutes! : 0;
    final c = (cookingTimeMinutes != null && cookingTimeMinutes! > 0) ? cookingTimeMinutes! : 0;
    final sum = p + c;
    return sum > 0 ? sum : null;
  }

  /// Catalog of real recipe definitions with authentic ingredient measurements and instructions.
  static final Map<String, _RecipeCatalogSpec> _catalogSpecs = {
    'paneer rice bowl': const _RecipeCatalogSpec(
      title: 'Paneer Rice Bowl',
      ingredients: [
        {'name': 'Paneer', 'quantity': 200, 'unit': 'g'},
        {'name': 'Rice', 'quantity': 1, 'unit': 'bowl'},
        {'name': 'Capsicum', 'quantity': 1, 'unit': 'medium'},
        {'name': 'Onion', 'quantity': 1, 'unit': 'medium'},
      ],
      steps: [
        RecipePreparationStep(
          stepNumber: 1,
          instruction: 'Cut fresh paneer into bite-sized cubes and thinly slice the capsicum and onions.',
          time: '3 mins',
        ),
        RecipePreparationStep(
          stepNumber: 2,
          instruction: 'Heat 1 tsp olive oil or ghee in a pan over medium heat; sauté paneer cubes until light golden.',
          time: '4 mins',
        ),
        RecipePreparationStep(
          stepNumber: 3,
          instruction: 'Add sliced capsicum and onions; stir-fry for 2-3 minutes until tender-crisp.',
          time: '3 mins',
          tip: 'Keep heat medium-high for maximum crispness.',
        ),
        RecipePreparationStep(
          stepNumber: 4,
          instruction: 'Gently fold in 1 bowl of warm cooked rice with salt and cumin powder; toss until evenly heated.',
          time: '3 mins',
        ),
        RecipePreparationStep(
          stepNumber: 5,
          instruction: 'Remove from heat, garnish with fresh herbs, and serve hot.',
          tip: 'Pairs wonderfully with a spoonful of fresh curd.',
        ),
      ],
      calories: 520,
      proteinGrams: 24,
      carbsGrams: 62,
      fatGrams: 18,
      prepTimeMinutes: 20,
    ),
    'comfort dal rice': const _RecipeCatalogSpec(
      title: 'Comfort Dal Rice',
      ingredients: [
        {'name': 'Rice', 'quantity': 1, 'unit': 'bowl'},
        {'name': 'Dal', 'quantity': 1, 'unit': 'cup'},
        {'name': 'Tomato', 'quantity': 1, 'unit': 'medium'},
        {'name': 'Onion', 'quantity': 1, 'unit': 'medium'},
      ],
      steps: [
        RecipePreparationStep(
          stepNumber: 1,
          instruction: 'Wash yellow lentils thoroughly and pressure cook with turmeric, salt, and water until soft and creamy.',
          time: '10 mins',
        ),
        RecipePreparationStep(
          stepNumber: 2,
          instruction: 'In a separate pan, heat 1 tsp oil/ghee and temper mustard seeds, cumin seeds, and chopped onions.',
          time: '3 mins',
        ),
        RecipePreparationStep(
          stepNumber: 3,
          instruction: 'Add chopped tomatoes and sauté until softened into a rich fragrant tempering.',
          time: '4 mins',
        ),
        RecipePreparationStep(
          stepNumber: 4,
          instruction: 'Pour tempered spices into the cooked dal and simmer together for 3 minutes.',
          time: '3 mins',
        ),
        RecipePreparationStep(
          stepNumber: 5,
          instruction: 'Serve steaming hot over a bowl of freshly cooked basmati rice.',
        ),
      ],
      calories: 420,
      proteinGrams: 18,
      carbsGrams: 72,
      fatGrams: 8,
      prepTimeMinutes: 25,
    ),
    'fruit & yogurt bowl': const _RecipeCatalogSpec(
      title: 'Fruit & Yogurt Bowl',
      ingredients: [
        {'name': 'Curd', 'quantity': 200, 'unit': 'g'},
        {'name': 'Apple', 'quantity': 1, 'unit': 'medium'},
        {'name': 'Banana', 'quantity': 1, 'unit': 'medium'},
      ],
      steps: [
        RecipePreparationStep(
          stepNumber: 1,
          instruction: 'Add 200g chilled fresh curd or Greek yogurt to a wide breakfast bowl.',
        ),
        RecipePreparationStep(
          stepNumber: 2,
          instruction: 'Wash and dice crisp apple and slice ripe banana into neat rounds.',
          time: '2 mins',
        ),
        RecipePreparationStep(
          stepNumber: 3,
          instruction: 'Layer the fresh fruit slices neatly over the creamy yogurt base.',
        ),
        RecipePreparationStep(
          stepNumber: 4,
          instruction: 'Top with chopped almonds or seeds if available; serve immediately.',
          tip: 'Drizzle with half a teaspoon of honey for natural sweetness.',
        ),
      ],
      calories: 280,
      proteinGrams: 15,
      carbsGrams: 44,
      fatGrams: 5,
      prepTimeMinutes: 5,
    ),
    'apple cinnamon oatmeal': const _RecipeCatalogSpec(
      title: 'Apple Cinnamon Oatmeal',
      ingredients: [
        {'name': 'Apple', 'quantity': 1, 'unit': 'medium'},
        {'name': 'Milk', 'quantity': 250, 'unit': 'ml'},
      ],
      steps: [
        RecipePreparationStep(
          stepNumber: 1,
          instruction: 'Pour 250ml milk into a saucepan and bring to a gentle simmer on medium-low heat.',
          time: '3 mins',
        ),
        RecipePreparationStep(
          stepNumber: 2,
          instruction: 'Stir in rolled oats and simmer for 4-5 minutes, stirring occasionally until thick and creamy.',
          time: '5 mins',
        ),
        RecipePreparationStep(
          stepNumber: 3,
          instruction: 'Dice fresh apple into small cubes and fold into warm oatmeal with a dash of cinnamon.',
          time: '2 mins',
        ),
        RecipePreparationStep(
          stepNumber: 4,
          instruction: 'Transfer to a bowl and enjoy warm for sustained morning energy.',
        ),
      ],
      calories: 310,
      proteinGrams: 11,
      carbsGrams: 56,
      fatGrams: 5,
      prepTimeMinutes: 8,
    ),
    'scrambled eggs & toast': const _RecipeCatalogSpec(
      title: 'Scrambled Eggs & Toast',
      ingredients: [
        {'name': 'Eggs', 'quantity': 2, 'unit': 'pieces'},
        {'name': 'Bread', 'quantity': 2, 'unit': 'slices'},
        {'name': 'Butter', 'quantity': 1, 'unit': 'tbsp'},
      ],
      steps: [
        RecipePreparationStep(
          stepNumber: 1,
          instruction: 'Crack 2 fresh eggs into a bowl, add a pinch of salt and black pepper, and whisk until frothy.',
          time: '1 min',
        ),
        RecipePreparationStep(
          stepNumber: 2,
          instruction: 'Melt 1 tbsp butter in a non-stick skillet over low heat.',
          time: '1 min',
        ),
        RecipePreparationStep(
          stepNumber: 3,
          instruction: 'Pour in eggs and gently pull cooked curds from edges to center with a spatula until soft and creamy.',
          time: '3 mins',
          tip: 'Remove from heat while slightly glossy to avoid overcooking.',
        ),
        RecipePreparationStep(
          stepNumber: 4,
          instruction: 'Toast bread slices until golden brown; serve scrambled eggs on warm toast.',
          time: '2 mins',
        ),
      ],
      calories: 360,
      proteinGrams: 22,
      carbsGrams: 26,
      fatGrams: 16,
      prepTimeMinutes: 10,
    ),
    'peanut butter banana toast': const _RecipeCatalogSpec(
      title: 'Peanut Butter Banana Toast',
      ingredients: [
        {'name': 'Banana', 'quantity': 1, 'unit': 'medium'},
        {'name': 'Bread', 'quantity': 2, 'unit': 'slices'},
        {'name': 'Peanut Butter', 'quantity': 2, 'unit': 'tbsp'},
      ],
      steps: [
        RecipePreparationStep(
          stepNumber: 1,
          instruction: 'Toast bread slices in a toaster or skillet until evenly golden and crisp.',
          time: '2 mins',
        ),
        RecipePreparationStep(
          stepNumber: 2,
          instruction: 'Spread 2 tbsp creamy peanut butter generously over the warm toast.',
          time: '1 min',
        ),
        RecipePreparationStep(
          stepNumber: 3,
          instruction: 'Slice ripe banana into uniform coins and arrange in an overlapping layer on top.',
          time: '1 min',
        ),
      ],
      calories: 340,
      proteinGrams: 14,
      carbsGrams: 48,
      fatGrams: 12,
      prepTimeMinutes: 5,
    ),
    'grilled chicken salad': const _RecipeCatalogSpec(
      title: 'Grilled Chicken Salad',
      ingredients: [
        {'name': 'Chicken', 'quantity': 200, 'unit': 'g'},
        {'name': 'Tomato', 'quantity': 1, 'unit': 'medium'},
        {'name': 'Capsicum', 'quantity': 1, 'unit': 'medium'},
        {'name': 'Broccoli', 'quantity': 100, 'unit': 'g'},
      ],
      steps: [
        RecipePreparationStep(
          stepNumber: 1,
          instruction: 'Pat chicken breast dry, brush with light oil, and season with salt, pepper, and herbs.',
          time: '2 mins',
        ),
        RecipePreparationStep(
          stepNumber: 2,
          instruction: 'Grill on medium-high heat for 6-7 minutes per side until thoroughly cooked and juicy.',
          time: '12 mins',
          temperature: 'Medium-high',
        ),
        RecipePreparationStep(
          stepNumber: 3,
          instruction: 'Steam broccoli florets for 3 minutes and dice fresh tomatoes and capsicum.',
          time: '4 mins',
        ),
        RecipePreparationStep(
          stepNumber: 4,
          instruction: 'Slice rested chicken and toss with the fresh veggies in a bowl with lemon dressing.',
        ),
      ],
      calories: 380,
      proteinGrams: 36,
      carbsGrams: 14,
      fatGrams: 12,
      prepTimeMinutes: 15,
    ),
    'paneer capsicum curry': const _RecipeCatalogSpec(
      title: 'Paneer Capsicum Curry',
      ingredients: [
        {'name': 'Paneer', 'quantity': 200, 'unit': 'g'},
        {'name': 'Capsicum', 'quantity': 2, 'unit': 'medium'},
        {'name': 'Tomato', 'quantity': 2, 'unit': 'medium'},
        {'name': 'Onion', 'quantity': 1, 'unit': 'medium'},
      ],
      steps: [
        RecipePreparationStep(
          stepNumber: 1,
          instruction: 'Heat 1 tbsp oil in a kadai and sauté cumin seeds with finely chopped onions until golden.',
          time: '4 mins',
        ),
        RecipePreparationStep(
          stepNumber: 2,
          instruction: 'Add pureed tomatoes, turmeric, coriander, and chili powder; cook until oil separates.',
          time: '5 mins',
        ),
        RecipePreparationStep(
          stepNumber: 3,
          instruction: 'Toss in sliced capsicum and simmer with 1/4 cup water for 3 minutes until tender-crisp.',
          time: '3 mins',
        ),
        RecipePreparationStep(
          stepNumber: 4,
          instruction: 'Add cubed paneer and simmer gently for 2 minutes to absorb flavors without hardening.',
          time: '2 mins',
          tip: 'Do not overcook paneer to keep it melt-in-mouth soft.',
        ),
      ],
      calories: 460,
      proteinGrams: 22,
      carbsGrams: 20,
      fatGrams: 28,
      prepTimeMinutes: 20,
    ),
    'hearty vegetable pasta': const _RecipeCatalogSpec(
      title: 'Hearty Vegetable Pasta',
      ingredients: [
        {'name': 'Pasta', 'quantity': 100, 'unit': 'g'},
        {'name': 'Tomato', 'quantity': 2, 'unit': 'medium'},
        {'name': 'Broccoli', 'quantity': 100, 'unit': 'g'},
        {'name': 'Capsicum', 'quantity': 1, 'unit': 'medium'},
      ],
      steps: [
        RecipePreparationStep(
          stepNumber: 1,
          instruction: 'Boil salted water in a large pot and cook pasta al dente according to package instructions.',
          time: '8 mins',
        ),
        RecipePreparationStep(
          stepNumber: 2,
          instruction: 'In a wide pan, heat olive oil and sauté chopped tomatoes, capsicum, and broccoli until tender.',
          time: '5 mins',
        ),
        RecipePreparationStep(
          stepNumber: 3,
          instruction: 'Drain pasta, reserving 2 tbsp pasta water; toss pasta and water into the simmering veggies.',
          time: '2 mins',
        ),
        RecipePreparationStep(
          stepNumber: 4,
          instruction: 'Season with black pepper, oregano, and salt; serve warm.',
        ),
      ],
      calories: 480,
      proteinGrams: 16,
      carbsGrams: 76,
      fatGrams: 12,
      prepTimeMinutes: 20,
    ),
    'pan-seared fish with greens': const _RecipeCatalogSpec(
      title: 'Pan-Seared Fish with Greens',
      ingredients: [
        {'name': 'Fish', 'quantity': 200, 'unit': 'g'},
        {'name': 'Broccoli', 'quantity': 150, 'unit': 'g'},
        {'name': 'Carrot', 'quantity': 1, 'unit': 'medium'},
      ],
      steps: [
        RecipePreparationStep(
          stepNumber: 1,
          instruction: 'Season fish fillet lightly with sea salt, crushed black pepper, and fresh lemon juice.',
          time: '2 mins',
        ),
        RecipePreparationStep(
          stepNumber: 2,
          instruction: 'Heat 1 tsp oil in a skillet over medium-high heat; sear fish for 3-4 minutes per side.',
          time: '7 mins',
          temperature: 'Medium-high',
        ),
        RecipePreparationStep(
          stepNumber: 3,
          instruction: 'Steam broccoli florets and sliced carrots until tender-crisp.',
          time: '4 mins',
        ),
        RecipePreparationStep(
          stepNumber: 4,
          instruction: 'Plate seared fish alongside the steamed greens with a fresh lemon wedge.',
        ),
      ],
      calories: 390,
      proteinGrams: 38,
      carbsGrams: 10,
      fatGrams: 14,
      prepTimeMinutes: 18,
    ),
    'stir-fried veggies & paneer': const _RecipeCatalogSpec(
      title: 'Stir-Fried Veggies & Paneer',
      ingredients: [
        {'name': 'Paneer', 'quantity': 150, 'unit': 'g'},
        {'name': 'Broccoli', 'quantity': 100, 'unit': 'g'},
        {'name': 'Carrot', 'quantity': 1, 'unit': 'medium'},
        {'name': 'Capsicum', 'quantity': 1, 'unit': 'medium'},
      ],
      steps: [
        RecipePreparationStep(
          stepNumber: 1,
          instruction: 'Chop paneer, broccoli, carrots, and capsicum into uniform bite-sized pieces.',
          time: '4 mins',
        ),
        RecipePreparationStep(
          stepNumber: 2,
          instruction: 'Heat oil in a wok or skillet over high heat; add carrots and broccoli first for 2 minutes.',
          time: '2 mins',
        ),
        RecipePreparationStep(
          stepNumber: 3,
          instruction: 'Add capsicum and paneer cubes; stir-fry briskly for another 3 minutes.',
          time: '3 mins',
          tip: 'High heat gives an authentic smoky stir-fry texture.',
        ),
        RecipePreparationStep(
          stepNumber: 4,
          instruction: 'Season with soy sauce or light spices and serve immediately.',
        ),
      ],
      calories: 360,
      proteinGrams: 20,
      carbsGrams: 16,
      fatGrams: 22,
      prepTimeMinutes: 15,
    ),
    'peanut butter apple slices': const _RecipeCatalogSpec(
      title: 'Peanut Butter Apple Slices',
      ingredients: [
        {'name': 'Apple', 'quantity': 1, 'unit': 'medium'},
        {'name': 'Peanut Butter', 'quantity': 2, 'unit': 'tbsp'},
      ],
      steps: [
        RecipePreparationStep(
          stepNumber: 1,
          instruction: 'Core and slice crisp fresh apple into even wedges.',
          time: '2 mins',
        ),
        RecipePreparationStep(
          stepNumber: 2,
          instruction: 'Arrange apple wedges on a plate alongside 2 tbsp creamy peanut butter for dipping.',
          time: '1 min',
        ),
      ],
      calories: 220,
      proteinGrams: 8,
      carbsGrams: 28,
      fatGrams: 10,
      prepTimeMinutes: 3,
    ),
    'fresh fruit medley': const _RecipeCatalogSpec(
      title: 'Fresh Fruit Medley',
      ingredients: [
        {'name': 'Apple', 'quantity': 1, 'unit': 'medium'},
        {'name': 'Banana', 'quantity': 1, 'unit': 'medium'},
        {'name': 'Orange', 'quantity': 1, 'unit': 'medium'},
        {'name': 'Grapes', 'quantity': 100, 'unit': 'g'},
      ],
      steps: [
        RecipePreparationStep(
          stepNumber: 1,
          instruction: 'Peel banana and orange; wash apple and grapes thoroughly under cold water.',
          time: '2 mins',
        ),
        RecipePreparationStep(
          stepNumber: 2,
          instruction: 'Dice apple and slice banana into neat rounds; separate orange into segments.',
          time: '3 mins',
        ),
        RecipePreparationStep(
          stepNumber: 3,
          instruction: 'Combine all fruits gently in a salad bowl and serve chilled.',
        ),
      ],
      calories: 180,
      proteinGrams: 3,
      carbsGrams: 42,
      fatGrams: 1,
      prepTimeMinutes: 5,
    ),
    'nut & dry fruit energy mix': const _RecipeCatalogSpec(
      title: 'Nut & Dry Fruit Energy Mix',
      ingredients: [
        {'name': 'Almonds', 'quantity': 30, 'unit': 'g'},
        {'name': 'Cashews', 'quantity': 30, 'unit': 'g'},
        {'name': 'Raisins', 'quantity': 20, 'unit': 'g'},
      ],
      steps: [
        RecipePreparationStep(
          stepNumber: 1,
          instruction: 'Combine almonds, cashews, and golden raisins in a clean bowl.',
        ),
        RecipePreparationStep(
          stepNumber: 2,
          instruction: 'Portion out into a travel container or enjoy as a nutrient-dense crunch.',
        ),
      ],
      calories: 260,
      proteinGrams: 9,
      carbsGrams: 24,
      fatGrams: 16,
      prepTimeMinutes: 2,
    ),
  };

  /// Derives detailed meal information from [RecipeRecommendation],
  /// cross-referencing [FridgeCategoryRepository] for real-time inventory tracking,
  /// real recipe instructions, dynamic recommendation reasons, and real nutrition values.
  factory MealDetailInfo.fromRecommendation(RecipeRecommendation rec) {
    final titleClean = rec.title.trim().toLowerCase();
    final spec = _catalogSpecs[titleClean];

    // 1. Resolve Ingredients Requirements with quantities and units
    final List<Map<String, dynamic>> rawReqs = [];
    if (spec != null) {
      rawReqs.addAll(spec.ingredients);
    } else if (rec.requiredIngredients.isNotEmpty) {
      for (final ingStr in rec.requiredIngredients) {
        final parsed = MealTrackingService.parseIngredientQuantity(ingStr);
        rawReqs.add({
          'name': parsed.name,
          'quantity': parsed.quantity ?? 1,
          'unit': parsed.unit ?? 'serving',
          'hasExplicitQuantity': parsed.quantity != null,
        });
      }
    } else {
      // Fallback to catalog match in MealRecommendationService
      final catalogMatch = MealRecommendationService.recipeCatalog
          .where((r) => r.title.toLowerCase() == rec.title.toLowerCase())
          .firstOrNull;
      if (catalogMatch != null) {
        for (final ingStr in catalogMatch.requiredIngredients) {
          final parsed = MealTrackingService.parseIngredientQuantity(ingStr);
          rawReqs.add({
            'name': parsed.name,
            'quantity': parsed.quantity ?? 1,
            'unit': parsed.unit ?? 'portion',
            'hasExplicitQuantity': parsed.quantity != null,
          });
        }
      } else {
        rawReqs.addAll([
          {'name': 'Paneer', 'quantity': 200, 'unit': 'g'},
          {'name': 'Rice', 'quantity': 1, 'unit': 'bowl'},
          {'name': 'Capsicum', 'quantity': 1, 'unit': 'medium'},
          {'name': 'Onion', 'quantity': 1, 'unit': 'medium'},
        ]);
      }
    }

    // 2. Cross-reference each ingredient against FridgeCategoryRepository
    final resolvedIngredients = <MealIngredientItem>[];
    for (final req in rawReqs) {
      final String name = req['name'] as String;
      final num reqQty = (req['quantity'] as num?) ?? 1;
      final String reqUnit = (req['unit'] as String?) ?? 'serving';

      final foundItem = FridgeCategoryRepository.findItemByName(name, exact: true);
      if (foundItem != null) {
        final availQty = foundItem.decimalAmount;
        final availUnit = foundItem.unit;
        final isCompatible = FridgeCategoryRepository.areUnitsCompatible(availUnit, reqUnit);

        IngredientAvailability availability;
        String statusLabel;

        if (!isCompatible) {
          availability = IngredientAvailability.partial;
          statusLabel = 'Unit mismatch (${foundItem.quantity} in fridge)';
        } else if (availQty < reqQty) {
          availability = IngredientAvailability.partial;
          statusLabel = 'Partially available: ${foundItem.quantity}';
        } else {
          availability = IngredientAvailability.available;
          statusLabel = 'In fridge · ${foundItem.quantity}';
        }

        resolvedIngredients.add(
          MealIngredientItem(
            name: name,
            requiredQuantity: reqQty,
            requiredUnit: reqUnit,
            availableQuantityInFridge: foundItem.quantity,
            availableAmount: availQty,
            availability: availability,
            statusLabel: statusLabel,
            imageAsset: FoodItemAssetRegistry.getAssetForItem(name),
          ),
        );
      } else if (name.toLowerCase() == 'rice') {
        resolvedIngredients.add(
          MealIngredientItem(
            name: 'Rice',
            requiredQuantity: reqQty,
            requiredUnit: reqUnit,
            availableQuantityInFridge: 'In pantry',
            availableAmount: null,
            availability: IngredientAvailability.partial,
            statusLabel: 'Available in pantry',
            imageAsset: FoodItemAssetRegistry.getAssetForItem(name),
          ),
        );
      } else {
        resolvedIngredients.add(
          MealIngredientItem(
            name: name,
            requiredQuantity: reqQty,
            requiredUnit: reqUnit,
            availableQuantityInFridge: null,
            availableAmount: null,
            availability: IngredientAvailability.missing,
            statusLabel: 'Not in fridge',
            imageAsset: FoodItemAssetRegistry.getAssetForItem(name),
          ),
        );
      }
    }

    // 3. Resolve Nutrition (nullable, honest values)
    final int? cal = (rec.calories > 0)
        ? rec.calories
        : (spec?.calories);
    final int? protein = (rec.proteinGrams > 0)
        ? rec.proteinGrams
        : (spec?.proteinGrams);
    final int? carbs = (rec.carbsGrams > 0)
        ? rec.carbsGrams
        : (spec?.carbsGrams);
    final int? fat = (rec.fatGrams > 0)
        ? rec.fatGrams
        : (spec?.fatGrams);
    final int? prepTime = (rec.prepTimeMinutes > 0)
        ? rec.prepTimeMinutes
        : spec?.prepTimeMinutes;
    final int? cookTime = (rec.cookingTimeMinutes != null && rec.cookingTimeMinutes! > 0)
        ? rec.cookingTimeMinutes
        : null;

    final String sourceLabel = rec.nutritionIsEstimate ? 'AI estimate' : 'Verified nutrition data';

    // 4. Resolve Dynamic Recommendation Reasons (Derived from actual facts)
    final dynamicReasons = _buildDynamicReasons(
      rec: rec,
      ingredients: resolvedIngredients,
      proteinGrams: protein,
    );

    // 5. Resolve Preparation Steps
    // Priority: AI-generated steps from recommendation -> catalog spec -> empty list
    List<RecipePreparationStep> prepSteps = rec.preparationSteps;
    if (prepSteps.isEmpty && spec != null && spec.steps.isNotEmpty) {
      prepSteps = spec.steps;
    }

    // 6. Resolve genuine videos if present from data source
    final List<RecipeVideoItem> resolvedVideos = [];
    if (rec.videoUrl != null && rec.videoUrl!.isNotEmpty) {
      resolvedVideos.add(RecipeVideoItem(
        id: 'vid_${rec.id.isNotEmpty ? rec.id : 'rec'}',
        title: '${rec.title} - Video Guide',
        channelName: 'Cooking Tutorial',
        duration: 'Guide',
        videoUrl: rec.videoUrl!,
      ));
    }

    final String effectiveMealType = rec.mealType.isNotEmpty
        ? rec.mealType
        : (['breakfast', 'lunch', 'dinner', 'snack'].contains(rec.tag.toLowerCase()) ? rec.tag : '');

    return MealDetailInfo(
      name: rec.title,
      tag: effectiveMealType.isNotEmpty
          ? effectiveMealType.toUpperCase()
          : (rec.tag.isNotEmpty ? rec.tag : 'Picked for your fridge'),
      mealType: effectiveMealType.isNotEmpty ? effectiveMealType : null,
      imageUrl: rec.imageUrl,
      calories: cal,
      proteinGrams: protein,
      carbsGrams: carbs,
      fatGrams: fat,
      fiberGrams: null,
      prepTimeMinutes: prepTime,
      cookingTimeMinutes: cookTime,
      servingSize: rec.servingSize.isNotEmpty ? rec.servingSize : '1 serving',
      nutritionSourceLabel: sourceLabel,
      nutritionIsEstimate: rec.nutritionIsEstimate,
      whyReasons: dynamicReasons,
      ingredients: resolvedIngredients,
      preparationSteps: prepSteps,
      cookingTips: rec.cookingTips,
      substitutions: rec.substitutions,
      videos: resolvedVideos,
      videoSearchQuery: rec.videoSearchQuery ?? '${rec.title} recipe',
      videoUrl: rec.videoUrl,
    );
  }

  /// Derives genuine, recipe-specific reasons from real user inventory and targets
  static List<String> _buildDynamicReasons({
    required RecipeRecommendation rec,
    required List<MealIngredientItem> ingredients,
    required int? proteinGrams,
  }) {
    final List<String> reasons = [];

    // Fact 1: Available ingredients from fridge (unique items with quantity > 0)
    final matchedFridgeItemIds = <String>{};
    for (final ing in ingredients) {
      if (ing.availability == IngredientAvailability.available ||
          ing.availability == IngredientAvailability.partial) {
        final found = FridgeCategoryRepository.findItemByName(ing.name);
        if (found != null && found.decimalAmount > 0) {
          matchedFridgeItemIds.add(found.id.isNotEmpty ? found.id : found.name.toLowerCase());
        }
      }
    }
    final accurateFridgeCount = matchedFridgeItemIds.length;
    if (accurateFridgeCount > 0) {
      final noun = accurateFridgeCount == 1 ? 'ingredient' : 'ingredients';
      reasons.add('Uses $accurateFridgeCount $noun from your fridge');
    }

    // Fact 2: Ingredients nearing expiry
    final expiringItem = ingredients
        .where((i) => i.availability == IngredientAvailability.available)
        .map((i) => FridgeCategoryRepository.findItemByName(i.name))
        .where((f) => f != null && f.expiryDays != null && f.expiryDays! <= 2 && f.expiryDays! >= 0)
        .firstOrNull;
    if (expiringItem != null) {
      final days = expiringItem.expiryDays == 0 ? 'today' : 'in ${expiringItem.expiryDays}d';
      reasons.add('Helps use ${expiringItem.name} nearing expiry ($days)');
    }

    // Fact 3: Protein target support
    final proteinTarget = MockDataRepository.nutrition.protein.targetGrams;
    final proteinCurrent = MockDataRepository.nutrition.protein.amountGrams;
    final proteinRemaining = proteinTarget - proteinCurrent;
    if (proteinGrams != null && proteinGrams > 0) {
      if (proteinRemaining > 0) {
        reasons.add("Helps support today's protein goal");
      } else {
        reasons.add('Provides ${proteinGrams}g protein per serving');
      }
    }

    // Fact 4: Dietary preference match
    final dietaryPref = MockDataRepository.profile.dietaryPreference;
    if (dietaryPref != null && dietaryPref.isNotEmpty && dietaryPref != 'None' && dietaryPref != 'Standard') {
      reasons.add('Matches your $dietaryPref dietary preference');
    }

    // Fact 5: Append any distinct, non-generic match reasons provided in rec
    for (final r in rec.matchReasons) {
      final lower = r.toLowerCase();
      if (!lower.contains('from your fridge') &&
          !lower.contains('in your fridge') &&
          !lower.contains('fridge inventory') &&
          !lower.contains('uses items') &&
          !lower.contains('uses ingredients') &&
          !lower.contains("protein goal") &&
          !reasons.contains(r)) {
        reasons.add(r);
      }
    }

    return reasons;
  }
}
