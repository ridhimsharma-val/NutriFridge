import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/screens/home/services/meal_recommendation_service.dart';
import 'package:nutrifridge/screens/meal_detail/models/meal_detail_data.dart';
import 'package:nutrifridge/services/meals/meal_tracking_service.dart';
import 'package:nutrifridge/services/meals/models/meal_models.dart';

void main() {
  setUp(() {
    MockDataRepository.reset();
    MockDataRepository.forceInMemoryForTesting = true;
  });

  tearDown(() {
    MockDataRepository.reset();
    MockDataRepository.forceInMemoryForTesting = false;
  });

  group('NutriFridge — Multiple Meal Logging & Meal Slot Classification Regression Tests', () {
    // 1. Logging 3 different meals under Dinner results in 3 meals classified as Dinner
    test('Scenario 1: Logging 3 different meals under Dinner preserves Dinner category for all 3', () async {
      final now = DateTime(2026, 11, 10, 20, 0); // 8:00 PM (Dinner slot)

      // Meal 1
      await MockDataRepository.logMeal(
        mealType: 'Dinner',
        mealName: 'Grilled Salmon & Asparagus',
        calories: 520,
        protein: 42,
        carbs: 12,
        fat: 22,
        timestamp: now,
      );

      // Meal 2
      await MockDataRepository.logMeal(
        mealType: 'Dinner',
        mealName: 'Quinoa Salad',
        calories: 280,
        protein: 8,
        carbs: 45,
        fat: 6,
        timestamp: now.add(const Duration(minutes: 15)),
      );

      // Meal 3
      await MockDataRepository.logMeal(
        mealType: 'Dinner',
        mealName: 'Greek Yogurt Parfait',
        calories: 190,
        protein: 15,
        carbs: 22,
        fat: 4,
        timestamp: now.add(const Duration(minutes: 30)),
      );

      final loggedMeals = MockDataRepository.meals.where((m) => m.isCompleted).toList();
      expect(loggedMeals.length, 3);
      for (final meal in loggedMeals) {
        expect(meal.mealType, 'Dinner');
        expect(meal.isCompleted, isTrue);
      }
      expect(loggedMeals[0].name, 'Grilled Salmon & Asparagus');
      expect(loggedMeals[1].name, 'Quinoa Salad');
      expect(loggedMeals[2].name, 'Greek Yogurt Parfait');

      // Check logged meals history
      final history = MockDataRepository.loggedMealsHistory;
      expect(history.length, 3);
      expect(history.every((h) => h['mealType'].toString().toLowerCase() == 'dinner'), isTrue);
    });

    // 2. Logging 2 meals under Breakfast results in 2 meals classified as Breakfast
    test('Scenario 2: Logging 2 meals under Breakfast preserves Breakfast category for both', () async {
      final now = DateTime(2026, 11, 10, 8, 30); // 8:30 AM (Breakfast slot)

      await MockDataRepository.logMeal(
        mealType: 'Breakfast',
        mealName: 'Scrambled Eggs with Avocado',
        calories: 380,
        protein: 20,
        carbs: 8,
        fat: 28,
        timestamp: now,
      );

      await MockDataRepository.logMeal(
        mealType: 'Breakfast',
        mealName: 'Oatmeal with Blueberries',
        calories: 250,
        protein: 6,
        carbs: 48,
        fat: 3,
        timestamp: now.add(const Duration(minutes: 20)),
      );

      final breakfastMeals = MockDataRepository.meals
          .where((m) => m.isCompleted && m.mealType == 'Breakfast')
          .toList();
      expect(breakfastMeals.length, 2);
      expect(breakfastMeals[0].name, 'Scrambled Eggs with Avocado');
      expect(breakfastMeals[1].name, 'Oatmeal with Blueberries');
    });

    // 3. Logging Breakfast, Lunch, and 3 Dinners results in 5 total meals with their exact categories preserved
    test('Scenario 3: Logging Breakfast, Lunch, and 3 Dinners preserves exact categories for all 5 meals', () async {
      final date = DateTime(2026, 11, 10);

      // Breakfast
      await MockDataRepository.logMeal(
        mealType: 'Breakfast',
        mealName: 'Avocado Toast',
        calories: 320,
        protein: 10,
        carbs: 34,
        fat: 16,
        timestamp: DateTime(date.year, date.month, date.day, 8, 0),
      );

      // Lunch
      await MockDataRepository.logMeal(
        mealType: 'Lunch',
        mealName: 'Chicken Burrito Bowl',
        calories: 650,
        protein: 45,
        carbs: 70,
        fat: 18,
        timestamp: DateTime(date.year, date.month, date.day, 13, 0),
      );

      // Dinner 1
      await MockDataRepository.logMeal(
        mealType: 'Dinner',
        mealName: 'Tofu Stir Fry',
        calories: 420,
        protein: 26,
        carbs: 38,
        fat: 14,
        timestamp: DateTime(date.year, date.month, date.day, 19, 0),
      );

      // Dinner 2
      await MockDataRepository.logMeal(
        mealType: 'Dinner',
        mealName: 'Miso Soup',
        calories: 90,
        protein: 6,
        carbs: 8,
        fat: 3,
        timestamp: DateTime(date.year, date.month, date.day, 19, 30),
      );

      // Dinner 3
      await MockDataRepository.logMeal(
        mealType: 'Dinner',
        mealName: 'Steamed Edamame',
        calories: 120,
        protein: 12,
        carbs: 9,
        fat: 4,
        timestamp: DateTime(date.year, date.month, date.day, 20, 0),
      );

      final logged = MockDataRepository.meals.where((m) => m.isCompleted).toList();
      expect(logged.length, 5);

      final breakfastCount = logged.where((m) => m.mealType == 'Breakfast').length;
      final lunchCount = logged.where((m) => m.mealType == 'Lunch').length;
      final dinnerCount = logged.where((m) => m.mealType == 'Dinner').length;

      expect(breakfastCount, 1);
      expect(lunchCount, 1);
      expect(dinnerCount, 3);
    });

    // 4. Rapid logging or identical timestamps do not cause meals to be reclassified
    test('Scenario 4: Rapid logging with identical timestamps retains original categories', () async {
      final sameTimestamp = DateTime(2026, 11, 10, 20, 45, 0);

      // Two meals submitted at the exact same timestamp
      await MockDataRepository.logMeal(
        mealType: 'Dinner',
        mealName: 'Paneer Butter Masala',
        calories: 480,
        protein: 22,
        carbs: 26,
        fat: 32,
        timestamp: sameTimestamp,
        idempotencyKey: 'rapid_dinner_1',
      );

      await MockDataRepository.logMeal(
        mealType: 'Dinner',
        mealName: 'Garlic Naan',
        calories: 260,
        protein: 7,
        carbs: 45,
        fat: 6,
        timestamp: sameTimestamp,
        idempotencyKey: 'rapid_dinner_2',
      );

      final dinnerMeals = MockDataRepository.meals
          .where((m) => m.isCompleted && m.mealType == 'Dinner')
          .toList();
      expect(dinnerMeals.length, 2);
      expect(dinnerMeals[0].name, 'Paneer Butter Masala');
      expect(dinnerMeals[1].name, 'Garlic Naan');
    });

    // 5. AI-generated meal started from a slot logs into that exact slot
    test('Scenario 5: AI-generated meal created from Dinner slot logs into Dinner', () async {
      const dinnerRec = RecipeRecommendation(
        id: 'rec_dinner_test_001',
        title: 'Rosemary Garlic Roast',
        calories: 550,
        proteinGrams: 38,
        carbsGrams: 28,
        fatGrams: 20,
        fridgeItemsUsed: 3,
        mealType: 'Dinner',
        imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947',
      );

      final mealInfo = MealDetailInfo.fromRecommendation(dinnerRec);
      expect(mealInfo.mealType, 'Dinner');
      expect(mealInfo.tag, 'DINNER');

      final cleanSlot = MealTrackingService.normalizeMealSlot(
        dinnerRec.mealType.isNotEmpty ? dinnerRec.mealType : mealInfo.tag,
      );
      expect(cleanSlot, 'dinner');

      await MockDataRepository.logMeal(
        mealType: cleanSlot,
        mealName: mealInfo.name,
        calories: mealInfo.calories ?? 0,
        protein: mealInfo.proteinGrams ?? 0,
        carbs: mealInfo.carbsGrams ?? 0,
        fat: mealInfo.fatGrams ?? 0,
        timestamp: DateTime(2026, 11, 10, 20, 15),
      );

      final logged = MockDataRepository.meals.where((m) => m.isCompleted).toList();
      expect(logged.last.mealType, 'Dinner');
      expect(logged.last.name, 'Rosemary Garlic Roast');
    });

    // 6. Custom ingredient meal started from a slot logs into that exact slot
    test('Scenario 6: Custom ingredient meal created from Lunch slot logs into Lunch', () async {
      final selectedItems = [
        const CategoryFoodItem(
          id: 'item_egg',
          name: 'Eggs',
          category: 'Dairy & Eggs',
          quantity: '6 pcs',
          expiryDays: 7,
        ),
      ];

      final customRec = await MealRecommendationService.generateFromSelectedIngredients(
        selectedItems: selectedItems,
        preferredDishName: 'Spinach Egg Scramble',
        targetSlot: MealTimeSlot.lunch,
      );

      expect(customRec, isNotNull);
      expect(customRec!.mealType, 'Lunch');

      final mealInfo = MealDetailInfo.fromRecommendation(customRec);
      expect(mealInfo.mealType, 'Lunch');

      final cleanSlot = MealTrackingService.normalizeMealSlot(mealInfo.mealType ?? 'Lunch');
      expect(cleanSlot, 'lunch');

      await MockDataRepository.logMeal(
        mealType: cleanSlot,
        mealName: mealInfo.name,
        calories: mealInfo.calories ?? 0,
        protein: mealInfo.proteinGrams ?? 0,
        carbs: mealInfo.carbsGrams ?? 0,
        fat: mealInfo.fatGrams ?? 0,
        timestamp: DateTime(2026, 11, 10, 13, 10),
      );

      final logged = MockDataRepository.meals.where((m) => m.isCompleted).toList();
      expect(logged.last.mealType, 'Lunch');
      expect(logged.last.name, mealInfo.name);
    });

    // 7. Persistence after app reload/reopen confirms the correct categories are retained
    test('Scenario 7: App reload/history mapping retains exact categories for multiple meals', () {
      final records = [
        LoggedMealRecord.fromJson({
          'id': 'meal_1',
          'user_id': 'test_user_uuid',
          'name': 'Protein Oatmeal',
          'meal_type': 'breakfast',
          'logged_at': '2026-11-10T08:15:00Z',
          'local_date': '2026-11-10',
          'serving_size': '1 bowl',
          'calories': 350,
          'protein_g': 22,
          'carbs_g': 50,
          'fat_g': 6,
          'idempotency_key': 'key_1',
          'created_at': '2026-11-10T08:15:00Z',
        }),
        LoggedMealRecord.fromJson({
          'id': 'meal_2',
          'user_id': 'test_user_uuid',
          'name': 'Grilled Salmon',
          'meal_type': 'dinner',
          'logged_at': '2026-11-10T19:00:00Z',
          'local_date': '2026-11-10',
          'serving_size': '1 fillet',
          'calories': 520,
          'protein_g': 40,
          'carbs_g': 10,
          'fat_g': 24,
          'idempotency_key': 'key_2',
          'created_at': '2026-11-10T19:00:00Z',
        }),
        LoggedMealRecord.fromJson({
          'id': 'meal_3',
          'user_id': 'test_user_uuid',
          'name': 'Roasted Veggies',
          'meal_type': 'dinner',
          'logged_at': '2026-11-10T19:45:00Z',
          'local_date': '2026-11-10',
          'serving_size': '1 plate',
          'calories': 180,
          'protein_g': 5,
          'carbs_g': 24,
          'fat_g': 7,
          'idempotency_key': 'key_3',
          'created_at': '2026-11-10T19:45:00Z',
        }),
      ];

      // Simulate loadFromSupabase mapping logic
      final mappedMeals = records.map((m) {
        final lower = m.mealType.trim().toLowerCase();
        final formattedSlot = lower == 'breakfast'
            ? 'Breakfast'
            : lower == 'lunch'
                ? 'Lunch'
                : lower == 'dinner'
                    ? 'Dinner'
                    : 'Snack';
        return MealItem(
          id: m.id,
          name: m.name,
          mealType: formattedSlot,
          status: MealStatus.completed,
          time: '7:00 PM',
          calories: m.calories ?? 0,
          proteinG: m.proteinG ?? 0,
          carbsG: m.carbsG ?? 0,
          fatG: m.fatG ?? 0,
        );
      }).toList();

      expect(mappedMeals.length, 3);
      expect(mappedMeals[0].mealType, 'Breakfast');
      expect(mappedMeals[1].mealType, 'Dinner');
      expect(mappedMeals[2].mealType, 'Dinner');

      expect(mappedMeals.where((m) => m.mealType == 'Dinner').length, 2);
    });

    // 8. Daily totals sum all meals accurately across duplicate categories
    test('Scenario 8: Daily nutrition totals accurately accumulate all meals across duplicate slots', () async {
      final now = DateTime(2026, 11, 10, 19, 0);

      // Dinner 1: 500 kcal, 40g P, 30g C, 15g F
      await MockDataRepository.logMeal(
        mealType: 'Dinner',
        mealName: 'Dinner Item 1',
        calories: 500,
        protein: 40,
        carbs: 30,
        fat: 15,
        timestamp: now,
      );

      // Dinner 2: 300 kcal, 20g P, 25g C, 10g F
      await MockDataRepository.logMeal(
        mealType: 'Dinner',
        mealName: 'Dinner Item 2',
        calories: 300,
        protein: 20,
        carbs: 25,
        fat: 10,
        timestamp: now.add(const Duration(minutes: 20)),
      );

      // Dinner 3: 200 kcal, 10g P, 15g C, 5g F
      await MockDataRepository.logMeal(
        mealType: 'Dinner',
        mealName: 'Dinner Item 3',
        calories: 200,
        protein: 10,
        carbs: 15,
        fat: 5,
        timestamp: now.add(const Duration(minutes: 40)),
      );

      final nutrition = MockDataRepository.nutrition;
      expect(nutrition.consumedCalories, 1000); // 500 + 300 + 200
      expect(nutrition.protein.amountGrams, 70); // 40 + 20 + 10
      expect(nutrition.carbs.amountGrams, 70); // 30 + 25 + 15
      expect(nutrition.fat.amountGrams, 30); // 15 + 10 + 5
    });
  });
}
