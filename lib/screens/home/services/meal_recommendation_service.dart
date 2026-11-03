import '../../../models/nutrition_data.dart';
import '../../fridge/models/category_item.dart';
import '../../profile/models/user_profile_data.dart';

/// Supported meal time slots for dynamic recommendations.
enum MealTimeSlot {
  breakfast,
  lunch,
  snack,
  dinner;

  String get displayName {
    switch (this) {
      case MealTimeSlot.breakfast:
        return 'Breakfast';
      case MealTimeSlot.lunch:
        return 'Lunch';
      case MealTimeSlot.snack:
        return 'Snack';
      case MealTimeSlot.dinner:
        return 'Dinner';
    }
  }

  String get badgeLabel => displayName.toUpperCase();
}

/// Definition of a recipe available for inventory-aware dynamic recommendations.
class MealRecipeDefinition {
  final String id;
  final String title;
  final List<MealTimeSlot> suitableSlots;
  final String imageUrl;
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final int prepTimeMinutes;
  final List<String> requiredIngredients;
  final List<String> optionalPantryIngredients;
  final bool isVegetarian;
  final bool isVegan;
  final List<String> allergens;
  final List<String> searchKeywords;

  const MealRecipeDefinition({
    required this.id,
    required this.title,
    required this.suitableSlots,
    required this.imageUrl,
    required this.calories,
    required this.proteinGrams,
    this.carbsGrams = 45,
    this.fatGrams = 15,
    this.prepTimeMinutes = 15,
    required this.requiredIngredients,
    this.optionalPantryIngredients = const [],
    this.isVegetarian = true,
    this.isVegan = false,
    this.allergens = const [],
    this.searchKeywords = const [],
  });
}

/// Dynamic, time-aware and inventory-aware meal recommendation service.
class MealRecommendationService {
  /// Testable clock provider allowing controlled time injection in tests.
  static DateTime Function() currentTimeProvider = DateTime.now;

  /// Resets clock provider to system wall clock.
  static void resetClock() {
    currentTimeProvider = DateTime.now;
  }

  /// Determines the relevant meal time slot for a given timestamp.
  /// Sensible windows:
  /// - Morning (05:00 - 10:59): Breakfast
  /// - Afternoon (11:00 - 15:59): Lunch
  /// - Evening (16:00 - 18:59): Snack
  /// - Night & Late-night (19:00 - 04:59): Dinner
  static MealTimeSlot getMealTimeSlot([DateTime? time]) {
    final dt = time ?? currentTimeProvider();
    final hour = dt.hour;
    if (hour >= 5 && hour < 11) {
      return MealTimeSlot.breakfast;
    } else if (hour >= 11 && hour < 16) {
      return MealTimeSlot.lunch;
    } else if (hour >= 16 && hour < 19) {
      return MealTimeSlot.snack;
    } else {
      return MealTimeSlot.dinner;
    }
  }

  /// Alias for test readability
  static MealTimeSlot determineMealSlot([DateTime? time]) => getMealTimeSlot(time);

  /// Master catalog of supported recipes with nutrition, imagery and dietary tags.
  static const List<MealRecipeDefinition> recipeCatalog = [
    // --- BREAKFAST ---
    MealRecipeDefinition(
      id: 'rec_banana_smoothie',
      title: 'Banana Oat Smoothie',
      suitableSlots: [MealTimeSlot.breakfast, MealTimeSlot.snack],
      imageUrl: 'assets/images/foods/banana.jpg',
      calories: 320,
      proteinGrams: 12,
      carbsGrams: 58,
      fatGrams: 6,
      prepTimeMinutes: 5,
      requiredIngredients: ['Banana', 'Milk'],
      optionalPantryIngredients: ['Almonds', 'Honey'],
      isVegetarian: true,
      isVegan: false,
      allergens: ['dairy', 'nuts'],
      searchKeywords: ['banana', 'milk', 'smoothie', 'oat'],
    ),
    MealRecipeDefinition(
      id: 'rec_scrambled_eggs',
      title: 'Scrambled Eggs & Toast',
      suitableSlots: [MealTimeSlot.breakfast],
      imageUrl: 'assets/images/foods/eggs.jpg',
      calories: 360,
      proteinGrams: 22,
      carbsGrams: 26,
      fatGrams: 16,
      prepTimeMinutes: 10,
      requiredIngredients: ['Eggs', 'Bread', 'Butter'],
      optionalPantryIngredients: ['Tomato', 'Milk'],
      isVegetarian: false,
      isVegan: false,
      allergens: ['eggs', 'gluten', 'dairy'],
      searchKeywords: ['eggs', 'bread', 'butter', 'egg', 'toast'],
    ),
    MealRecipeDefinition(
      id: 'rec_pb_banana_toast',
      title: 'Peanut Butter Banana Toast',
      suitableSlots: [MealTimeSlot.breakfast, MealTimeSlot.snack],
      imageUrl: 'assets/images/foods/peanut_butter.jpg',
      calories: 340,
      proteinGrams: 14,
      carbsGrams: 48,
      fatGrams: 12,
      prepTimeMinutes: 5,
      requiredIngredients: ['Banana', 'Bread', 'Peanut Butter'],
      optionalPantryIngredients: ['Honey'],
      isVegetarian: true,
      isVegan: true,
      allergens: ['gluten', 'nuts', 'peanuts'],
      searchKeywords: ['banana', 'bread', 'peanut butter', 'toast'],
    ),
    MealRecipeDefinition(
      id: 'rec_fruit_yogurt_bowl',
      title: 'Fruit & Yogurt Bowl',
      suitableSlots: [MealTimeSlot.breakfast, MealTimeSlot.snack],
      imageUrl: 'assets/images/foods/curd.png',
      calories: 280,
      proteinGrams: 15,
      carbsGrams: 44,
      fatGrams: 5,
      prepTimeMinutes: 5,
      requiredIngredients: ['Curd', 'Apple', 'Banana'],
      optionalPantryIngredients: ['Almonds', 'Honey', 'Grapes'],
      isVegetarian: true,
      isVegan: false,
      allergens: ['dairy', 'nuts'],
      searchKeywords: ['curd', 'yogurt', 'apple', 'banana', 'fruits'],
    ),
    MealRecipeDefinition(
      id: 'rec_apple_oatmeal',
      title: 'Apple Cinnamon Oatmeal',
      suitableSlots: [MealTimeSlot.breakfast],
      imageUrl: 'assets/images/foods/apple.jpg',
      calories: 310,
      proteinGrams: 11,
      carbsGrams: 56,
      fatGrams: 5,
      prepTimeMinutes: 8,
      requiredIngredients: ['Apple', 'Milk'],
      optionalPantryIngredients: ['Honey', 'Almonds'],
      isVegetarian: true,
      isVegan: false,
      allergens: ['dairy', 'nuts'],
      searchKeywords: ['apple', 'milk', 'oatmeal'],
    ),

    // --- LUNCH ---
    MealRecipeDefinition(
      id: 'rec_paneer_rice_bowl',
      title: 'Paneer Rice Bowl',
      suitableSlots: [MealTimeSlot.lunch, MealTimeSlot.dinner],
      imageUrl: 'assets/images/paneer_rice_bowl.jpg',
      calories: 520,
      proteinGrams: 24,
      carbsGrams: 62,
      fatGrams: 18,
      prepTimeMinutes: 20,
      requiredIngredients: ['Paneer', 'Rice', 'Capsicum', 'Onion'],
      optionalPantryIngredients: ['Tomato'],
      isVegetarian: true,
      isVegan: false,
      allergens: ['dairy'],
      searchKeywords: ['paneer', 'rice', 'capsicum', 'onion'],
    ),
    MealRecipeDefinition(
      id: 'rec_dal_rice',
      title: 'Comfort Dal Rice',
      suitableSlots: [MealTimeSlot.lunch, MealTimeSlot.dinner],
      imageUrl: 'assets/images/foods/dal_rice.jpg',
      calories: 420,
      proteinGrams: 18,
      carbsGrams: 72,
      fatGrams: 8,
      prepTimeMinutes: 25,
      requiredIngredients: ['Rice', 'Dal', 'Tomato', 'Onion'],
      optionalPantryIngredients: ['Butter'],
      isVegetarian: true,
      isVegan: true,
      allergens: [],
      searchKeywords: ['rice', 'dal', 'tomato', 'onion'],
    ),
    MealRecipeDefinition(
      id: 'rec_grilled_chicken_salad',
      title: 'Grilled Chicken Salad',
      suitableSlots: [MealTimeSlot.lunch, MealTimeSlot.dinner],
      imageUrl: 'assets/images/foods/chicken.jpg',
      calories: 380,
      proteinGrams: 36,
      carbsGrams: 14,
      fatGrams: 12,
      prepTimeMinutes: 15,
      requiredIngredients: ['Chicken', 'Tomato', 'Capsicum', 'Broccoli'],
      optionalPantryIngredients: ['Lemon'],
      isVegetarian: false,
      isVegan: false,
      allergens: [],
      searchKeywords: ['chicken', 'tomato', 'capsicum', 'broccoli', 'salad'],
    ),
    MealRecipeDefinition(
      id: 'rec_paneer_curry',
      title: 'Paneer Capsicum Curry',
      suitableSlots: [MealTimeSlot.lunch, MealTimeSlot.dinner],
      imageUrl: 'assets/images/foods/paneer_curry.jpg',
      calories: 460,
      proteinGrams: 22,
      carbsGrams: 20,
      fatGrams: 28,
      prepTimeMinutes: 20,
      requiredIngredients: ['Paneer', 'Capsicum', 'Tomato', 'Onion'],
      optionalPantryIngredients: ['Butter'],
      isVegetarian: true,
      isVegan: false,
      allergens: ['dairy'],
      searchKeywords: ['paneer', 'capsicum', 'curry'],
    ),

    // --- SNACK ---
    MealRecipeDefinition(
      id: 'rec_pb_apple_slices',
      title: 'Peanut Butter Apple Slices',
      suitableSlots: [MealTimeSlot.snack],
      imageUrl: 'assets/images/foods/peanut_butter.jpg',
      calories: 220,
      proteinGrams: 8,
      carbsGrams: 28,
      fatGrams: 10,
      prepTimeMinutes: 3,
      requiredIngredients: ['Apple', 'Peanut Butter'],
      optionalPantryIngredients: ['Honey', 'Almonds'],
      isVegetarian: true,
      isVegan: true,
      allergens: ['nuts', 'peanuts'],
      searchKeywords: ['apple', 'peanut butter'],
    ),
    MealRecipeDefinition(
      id: 'rec_fresh_fruit_medley',
      title: 'Fresh Fruit Medley',
      suitableSlots: [MealTimeSlot.snack, MealTimeSlot.breakfast],
      imageUrl: 'assets/images/foods/apple.jpg',
      calories: 180,
      proteinGrams: 3,
      carbsGrams: 42,
      fatGrams: 1,
      prepTimeMinutes: 5,
      requiredIngredients: ['Apple', 'Banana', 'Orange', 'Grapes'],
      optionalPantryIngredients: ['Honey'],
      isVegetarian: true,
      isVegan: true,
      allergens: [],
      searchKeywords: ['apple', 'banana', 'orange', 'grapes', 'fruit'],
    ),
    MealRecipeDefinition(
      id: 'rec_energy_dry_fruits',
      title: 'Nut & Dry Fruit Energy Mix',
      suitableSlots: [MealTimeSlot.snack],
      imageUrl: 'assets/images/foods/dry_fruits_mix.jpg',
      calories: 260,
      proteinGrams: 9,
      carbsGrams: 24,
      fatGrams: 16,
      prepTimeMinutes: 2,
      requiredIngredients: ['Almonds', 'Cashews', 'Raisins'],
      optionalPantryIngredients: ['Chocolate'],
      isVegetarian: true,
      isVegan: true,
      allergens: ['nuts'],
      searchKeywords: ['almonds', 'cashews', 'raisins', 'nuts'],
    ),

    // --- DINNER ---
    MealRecipeDefinition(
      id: 'rec_veg_pasta',
      title: 'Hearty Vegetable Pasta',
      suitableSlots: [MealTimeSlot.dinner, MealTimeSlot.lunch],
      imageUrl: 'assets/images/foods/pasta.jpg',
      calories: 480,
      proteinGrams: 16,
      carbsGrams: 76,
      fatGrams: 12,
      prepTimeMinutes: 20,
      requiredIngredients: ['Pasta', 'Tomato', 'Broccoli', 'Capsicum'],
      optionalPantryIngredients: ['Paneer', 'Butter'],
      isVegetarian: true,
      isVegan: false,
      allergens: ['gluten', 'dairy'],
      searchKeywords: ['pasta', 'tomato', 'broccoli', 'capsicum'],
    ),
    MealRecipeDefinition(
      id: 'rec_pan_seared_fish',
      title: 'Pan-Seared Fish with Greens',
      suitableSlots: [MealTimeSlot.dinner],
      imageUrl: 'assets/images/foods/fish.jpg',
      calories: 390,
      proteinGrams: 38,
      carbsGrams: 10,
      fatGrams: 14,
      prepTimeMinutes: 18,
      requiredIngredients: ['Fish', 'Broccoli', 'Carrot'],
      optionalPantryIngredients: ['Butter', 'Lemon'],
      isVegetarian: false,
      isVegan: false,
      allergens: ['seafood', 'fish'],
      searchKeywords: ['fish', 'broccoli', 'carrot'],
    ),
    MealRecipeDefinition(
      id: 'rec_stir_fry_paneer',
      title: 'Stir-Fried Veggies & Paneer',
      suitableSlots: [MealTimeSlot.dinner, MealTimeSlot.lunch],
      imageUrl: 'assets/images/foods/paneer_curry.jpg',
      calories: 360,
      proteinGrams: 20,
      carbsGrams: 16,
      fatGrams: 22,
      prepTimeMinutes: 15,
      requiredIngredients: ['Paneer', 'Broccoli', 'Carrot', 'Capsicum'],
      optionalPantryIngredients: ['Butter'],
      isVegetarian: true,
      isVegan: false,
      allergens: ['dairy'],
      searchKeywords: ['paneer', 'broccoli', 'carrot', 'capsicum'],
    ),
  ];

  /// Dynamically computes the best meal recommendation from current inventory,
  /// current meal slot, and user dietary preferences.
  /// Returns null if the fridge inventory is empty or no valid recommendation exists.
  static RecipeRecommendation? getRecommendation({DateTime? time}) {
    // 1. Strict empty-inventory guard: Never fabricate recommendations for an empty fridge
    if (FridgeCategoryRepository.totalFridgeItems == 0) {
      return null;
    }

    final slot = getMealTimeSlot(time);
    final profile = MockDataRepository.profile;

    // 2. Filter candidates based on dietary preferences, allergies and restrictions
    final List<MealRecipeDefinition> slotCandidates = [];
    final List<MealRecipeDefinition> otherCandidates = [];

    for (final recipe in recipeCatalog) {
      if (!_isDietaryCompliant(recipe, profile)) {
        continue;
      }
      if (recipe.suitableSlots.contains(slot)) {
        slotCandidates.add(recipe);
      } else {
        otherCandidates.add(recipe);
      }
    }

    // 3. Score and select the best candidate from slotCandidates (or otherCandidates as fallback)
    final candidateToUse = slotCandidates.isNotEmpty ? slotCandidates : otherCandidates;

    MealRecipeDefinition? bestRecipe;
    List<CategoryFoodItem> bestAvailableItems = [];
    List<String> bestMissingItems = [];
    int highestScore = -1;

    for (final recipe in candidateToUse) {
      final List<CategoryFoodItem> availableItems = [];
      final List<String> missingItems = [];

      for (final ing in recipe.requiredIngredients) {
        final found = FridgeCategoryRepository.findItemByName(ing);
        if (found != null) {
          availableItems.add(found);
        } else {
          missingItems.add(ing);
        }
      }

      // Must have at least 1 actual fridge ingredient in inventory
      if (availableItems.isEmpty) continue;

      int score = availableItems.length * 10;

      // Bonus for expiring-soon items (consume soon)
      for (final item in availableItems) {
        if (item.expiryDays >= 0 && item.expiryDays <= 3) {
          score += 6;
        }
      }

      // Bonus if target slot matches exactly
      if (recipe.suitableSlots.contains(slot)) {
        score += 8;
      }

      if (score > highestScore) {
        highestScore = score;
        bestRecipe = recipe;
        bestAvailableItems = availableItems;
        bestMissingItems = missingItems;
      }
    }

    if (bestRecipe == null) {
      return null;
    }

    // 4. Construct match reasons and dynamic explanation
    final reasons = <String>[];
    reasons.add('Uses ${bestAvailableItems.length} items from your fridge');

    final expiring = bestAvailableItems.where((it) => it.expiryDays >= 0 && it.expiryDays <= 3).firstOrNull;
    if (expiring != null) {
      reasons.add('Uses ${expiring.name} (expires in ${expiring.expiryDays}d)');
    } else {
      reasons.add("Helps complete today's ${slot.displayName.toLowerCase()} goal");
    }

    final availableNames = bestAvailableItems.map((e) => e.name).toList();

    return RecipeRecommendation(
      title: bestRecipe.title,
      calories: bestRecipe.calories,
      proteinGrams: bestRecipe.proteinGrams,
      carbsGrams: bestRecipe.carbsGrams,
      fatGrams: bestRecipe.fatGrams,
      prepTimeMinutes: bestRecipe.prepTimeMinutes,
      fridgeItemsUsed: bestAvailableItems.length,
      mealType: slot.badgeLabel,
      tag: slot.badgeLabel,
      imageUrl: bestRecipe.imageUrl,
      matchReasons: reasons,
      requiredIngredients: bestRecipe.requiredIngredients,
      missingIngredients: bestMissingItems,
      explanation:
          'Suggested for ${slot.displayName} based on ${availableNames.join(', ')} available in your fridge.',
    );
  }

  /// Verifies if a recipe complies with the user's dietary preferences, allergies and restrictions.
  static bool _isDietaryCompliant(MealRecipeDefinition recipe, UserProfileData profile) {
    // 1. Dietary Preference check (Vegetarian / Vegan)
    final pref = profile.dietaryPreference?.trim().toLowerCase();
    if (pref != null && pref.isNotEmpty) {
      if (pref.contains('vegan') && !recipe.isVegan) {
        return false;
      }
      if (pref.contains('vegetarian') && !recipe.isVegetarian) {
        return false;
      }
    }

    // 2. Allergies check (case-insensitive substring match)
    for (final allergy in profile.allergies) {
      final aLower = allergy.trim().toLowerCase();
      if (aLower.isEmpty) continue;
      for (final recipeAllergen in recipe.allergens) {
        if (recipeAllergen.contains(aLower) || aLower.contains(recipeAllergen)) {
          return false;
        }
      }
      for (final ing in recipe.requiredIngredients) {
        if (ing.toLowerCase().contains(aLower) || aLower.contains(ing.toLowerCase())) {
          return false;
        }
      }
    }

    // 3. Avoided foods check
    for (final avoided in profile.avoidedFoods) {
      final avLower = avoided.trim().toLowerCase();
      if (avLower.isEmpty) continue;
      for (final ing in recipe.requiredIngredients) {
        if (ing.toLowerCase().contains(avLower) || avLower.contains(ing.toLowerCase())) {
          return false;
        }
      }
    }

    // 4. Custom restrictions check
    for (final custom in profile.customRestrictions) {
      final cLower = custom.trim().toLowerCase();
      if (cLower.isEmpty) continue;
      for (final ing in recipe.requiredIngredients) {
        if (ing.toLowerCase().contains(cLower) || cLower.contains(ing.toLowerCase())) {
          return false;
        }
      }
    }

    return true;
  }
}
