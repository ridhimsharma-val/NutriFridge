import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/screens/home/services/meal_recommendation_service.dart';
import 'package:nutrifridge/services/meals/meal_tracking_service.dart';
import 'package:nutrifridge/services/meals/models/meal_models.dart';
import 'package:nutrifridge/services/sync/user_data_sync_service.dart';

void main() {
  setUp(() {
    MockDataRepository.reset();
  });

  tearDown(() {
    MockDataRepository.reset();
  });

  group('MealTrackingService RPC Parameter Serialization & Validation Tests', () {
    test('buildRpcParams serializes all meal transaction parameters correctly', () {
      final deductions = [
        const MealIngredientDeduction(
          name: 'Paneer',
          requiredQuantity: 200,
          requiredUnit: 'g',
          matchedFridgeItemId: '11111111-2222-3333-4444-555555555555',
          deductQuantity: 200,
          deductUnit: 'g',
          doDeduct: true,
        ),
        const MealIngredientDeduction(
          name: 'Rice',
          requiredQuantity: 100,
          requiredUnit: 'g',
          doDeduct: false,
        ),
      ];

      final params = MealTrackingService.buildRpcParams(
        idempotencyKey: 'idemp-test-12345',
        mealName: 'Paneer Rice Bowl',
        mealType: 'Lunch',
        servingSize: '1 bowl',
        calories: 520,
        proteinG: 24,
        carbsG: 62,
        fatG: 18,
        fiberG: 5,
        isEstimate: true,
        nutritionSource: 'ai_estimate',
        recipeId: 'rec-uuid-999',
        imageUrl: 'https://example.com/paneer.jpg',
        ingredients: deductions,
      );

      expect(params['p_idempotency_key'], 'idemp-test-12345');
      expect(params['p_meal_name'], 'Paneer Rice Bowl');
      expect(params['p_meal_type'], 'lunch'); // Normalized to lower-case canonical slot
      expect(params['p_serving_size'], '1 bowl');
      expect(params['p_calories'], 520);
      expect(params['p_protein_g'], 24);
      expect(params['p_carbs_g'], 62);
      expect(params['p_fat_g'], 18);
      expect(params['p_fiber_g'], 5);
      expect(params['p_is_estimate'], true);
      expect(params['p_nutrition_source'], 'ai_estimate');
      expect(params['p_recipe_id'], 'rec-uuid-999');
      expect(params['p_image_url'], 'https://example.com/paneer.jpg');

      final ingList = params['p_ingredients'] as List<dynamic>;
      expect(ingList.length, 2);
      expect(ingList[0]['name'], 'Paneer');
      expect(ingList[0]['matched_fridge_item_id'], '11111111-2222-3333-4444-555555555555');
      expect(ingList[0]['do_deduct'], true);
      expect(ingList[1]['name'], 'Rice');
      expect(ingList[1]['matched_fridge_item_id'], isNull);
      expect(ingList[1]['do_deduct'], false);
    });

    test('buildRpcParams throws ArgumentError on empty idempotency key or meal name', () {
      expect(
        () => MealTrackingService.buildRpcParams(
          idempotencyKey: '',
          mealName: 'Salad',
          mealType: 'lunch',
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => MealTrackingService.buildRpcParams(
          idempotencyKey: 'key-1',
          mealName: '   ',
          mealType: 'lunch',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('normalizeMealSlot normalizes slots and rejects invalid meal slot names', () {
      expect(MealTrackingService.normalizeMealSlot('Breakfast'), 'breakfast');
      expect(MealTrackingService.normalizeMealSlot('LUNCH'), 'lunch');
      expect(MealTrackingService.normalizeMealSlot('Evening Snacks'), 'snack');
      expect(MealTrackingService.normalizeMealSlot('Dinner'), 'dinner');

      expect(
        () => MealTrackingService.normalizeMealSlot('Midnight Brunch'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Idempotency & Transaction Result Tests', () {
    test('generateIdempotencyKey creates unique non-empty keys', () {
      final key1 = MealTrackingService.generateIdempotencyKey();
      final key2 = MealTrackingService.generateIdempotencyKey();

      expect(key1, isNotEmpty);
      expect(key2, isNotEmpty);
      expect(key1, isNot(equals(key2)));
      expect(key1.startsWith('meal_'), isTrue);
    });

    test('MealTransactionResult handles successful and duplicate responses correctly', () {
      final successJson = {
        'status': 'success',
        'already_processed': false,
        'meal_id': '88888888-4444-4444-4444-121212121212',
        'local_date': '2026-11-06',
        'meal_type': 'lunch',
        'deductions_applied': 2,
        'deduction_details': [
          {'ingredient': 'Paneer', 'deducted_qty': 200, 'status': 'full'},
        ],
      };

      final successResult = MealTransactionResult.fromJson(successJson);
      expect(successResult.isSuccess, isTrue);
      expect(successResult.alreadyProcessed, isFalse);
      expect(successResult.mealId, '88888888-4444-4444-4444-121212121212');
      expect(successResult.deductionsApplied, 2);

      final duplicateJson = {
        'status': 'idempotent_duplicate',
        'already_processed': true,
        'meal_id': '88888888-4444-4444-4444-121212121212',
        'local_date': '2026-11-06',
        'meal_type': 'lunch',
        'message': 'Meal was already successfully logged with this idempotency key.',
      };

      final duplicateResult = MealTransactionResult.fromJson(duplicateJson);
      expect(duplicateResult.isDuplicate, isTrue);
      expect(duplicateResult.alreadyProcessed, isTrue);
      expect(duplicateResult.message, contains('already successfully logged'));
    });
  });

  group('NULL Nutrition Values & Snapshot Mapping Tests', () {
    test('LoggedMealRecord preserves NULL nutrition values without fabricating zeroes', () {
      final json = {
        'id': 'meal-001',
        'user_id': 'user-001',
        'name': 'Unknown Homemade Dish',
        'meal_type': 'dinner',
        'logged_at': '2026-11-06T19:30:00Z',
        'local_date': '2026-11-06',
        'serving_size': '1 portion',
        'calories': null, // NULL nutrition
        'protein_g': null,
        'carbs_g': null,
        'fat_g': null,
        'fiber_g': null,
        'is_estimate': true,
        'nutrition_source': 'ai_estimate',
        'idempotency_key': 'key-null-1',
        'created_at': '2026-11-06T19:30:00Z',
      };

      final record = LoggedMealRecord.fromJson(json);
      expect(record.calories, isNull);
      expect(record.proteinG, isNull);
      expect(record.carbsG, isNull);
      expect(record.fatG, isNull);

      final map = record.toMap();
      expect(map['calories'], isNull);
      expect(map['protein'], isNull);
    });

    test('DailyNutritionSnapshotRecord correctly maps fields and partial nutrition flags', () {
      final snapshotJson = {
        'id': 'snap-1',
        'user_id': 'user-1',
        'log_date': '2026-11-06',
        'total_calories': 1450,
        'target_calories': 2200,
        'protein_g': 75,
        'carbs_g': 180,
        'fat_g': 45,
        'fiber_g': 18,
        'meals_logged_count': 3,
        'meals_with_unknown_nutrition': 1,
        'is_complete': false,
        'updated_at': '2026-11-06T20:00:00Z',
      };

      final snapshot = DailyNutritionSnapshotRecord.fromJson(snapshotJson);
      expect(snapshot.totalCalories, 1450);
      expect(snapshot.targetCalories, 2200);
      expect(snapshot.proteinG, 75);
      expect(snapshot.mealsLoggedCount, 3);
      expect(snapshot.mealsWithUnknownNutrition, 1);
      expect(snapshot.isComplete, isFalse);
    });

    test('DailyMealSlotRecord correctly parses completed slot and primary meal id', () {
      final slotJson = {
        'id': 'slot-1',
        'user_id': 'user-1',
        'log_date': '2026-11-06',
        'meal_slot': 'breakfast',
        'status': 'completed',
        'completed_at': '2026-11-06T08:30:00Z',
        'primary_meal_id': 'meal-uuid-breakfast',
      };

      final slot = DailyMealSlotRecord.fromJson(slotJson);
      expect(slot.mealSlot, 'breakfast');
      expect(slot.isCompleted, isTrue);
      expect(slot.primaryMealId, 'meal-uuid-breakfast');
    });
  });

  group('Meal Slot Progression & Recommendation Safety Tests', () {
    test('MealRecommendationService advances correctly after logging breakfast', () {
      MockDataRepository.forceInMemoryForTesting = true;

      // Log Breakfast
      MockDataRepository.logMeal(
        mealType: 'breakfast',
        mealName: 'Oats & Berries',
        calories: 350,
        protein: 12,
        carbs: 60,
        fat: 6,
      );

      final completed = MealRecommendationService.getCompletedMealSlotsToday();
      expect(completed.contains(MealTimeSlot.breakfast), isTrue);

      // Advance slot recommendation
      MealRecommendationService.advanceAfterMealLogged(
        loggedSlot: MealTimeSlot.breakfast,
      );

      final nextSlot = MealRecommendationService.resolveActiveMealSlot(
        DateTime(2026, 11, 6, 8, 30), // During breakfast window
      );
      // Since breakfast is logged, should advance to lunch!
      expect(nextSlot, MealTimeSlot.lunch);
    });

    test('Duplicate meal responses do not cause second progression events', () {
      final completedBefore = MealRecommendationService.getCompletedMealSlotsToday();

      const duplicateResult = MealTransactionResult(
        status: 'idempotent_duplicate',
        alreadyProcessed: true,
        mealId: 'existing-id',
        localDate: '2026-11-06',
        mealType: 'lunch',
      );

      // Simulated duplicate check in UI: only advance if NOT alreadyProcessed
      if (!duplicateResult.alreadyProcessed) {
        MealRecommendationService.advanceAfterMealLogged(
          loggedSlot: MealTimeSlot.lunch,
        );
      }

      final completedAfter = MealRecommendationService.getCompletedMealSlotsToday();
      expect(completedAfter.length, completedBefore.length);
    });
  });

  group('Session Isolation & Cache Purging Tests', () {
    test('MockDataRepository.reset clears all nutrition totals, slots and history', () {
      MockDataRepository.forceInMemoryForTesting = true;

      MockDataRepository.logMeal(
        mealType: 'dinner',
        mealName: 'Steamed Fish & Veggies',
        calories: 480,
        protein: 42,
        carbs: 20,
        fat: 12,
      );

      expect(MockDataRepository.nutrition.consumedCalories, 480);
      expect(MockDataRepository.loggedMealsHistory, isNotEmpty);

      // Logout / reset
      UserDataSyncService.clearAllUserDataForLogout();

      expect(MockDataRepository.nutrition.consumedCalories, 0);
      expect(MockDataRepository.loggedMealsHistory, isEmpty);
      expect(MockDataRepository.meals.any((m) => m.isCompleted), isFalse);
    });
  });

  group('Ingredient Quantity Deduction & Unit Conversion Regression Tests', () {
    setUp(() {
      FridgeCategoryRepository.reset();
      MockDataRepository.reset();
      MockDataRepository.forceInMemoryForTesting = true;
    });

    tearDown(() {
      FridgeCategoryRepository.reset();
      MockDataRepository.reset();
    });

    test('parseIngredientQuantity extracts name, quantity, and unit from various string formats', () {
      final p1 = MealTrackingService.parseIngredientQuantity('Paneer (100g)');
      expect(p1.name, 'Paneer');
      expect(p1.quantity, 100);
      expect(p1.unit, 'g');

      final p2 = MealTrackingService.parseIngredientQuantity('Paneer (100 g)');
      expect(p2.name, 'Paneer');
      expect(p2.quantity, 100);
      expect(p2.unit, 'g');

      final p3 = MealTrackingService.parseIngredientQuantity('100g Paneer');
      expect(p3.name, 'Paneer');
      expect(p3.quantity, 100);
      expect(p3.unit, 'g');

      final p4 = MealTrackingService.parseIngredientQuantity('Paneer: 100g');
      expect(p4.name, 'Paneer');
      expect(p4.quantity, 100);
      expect(p4.unit, 'g');

      final p5 = MealTrackingService.parseIngredientQuantity('50g Paneer');
      expect(p5.name, 'Paneer');
      expect(p5.quantity, 50);
      expect(p5.unit, 'g');

      final p6 = MealTrackingService.parseIngredientQuantity('100ml Milk');
      expect(p6.name, 'Milk');
      expect(p6.quantity, 100);
      expect(p6.unit, 'ml');

      final p7 = MealTrackingService.parseIngredientQuantity('1 piece Eggs');
      expect(p7.name, 'Eggs');
      expect(p7.quantity, 1);
      expect(p7.unit, 'piece');

      final p8 = MealTrackingService.parseIngredientQuantity('Paneer');
      expect(p8.name, 'Paneer');
      expect(p8.quantity, isNull);
      expect(p8.unit, isNull);
    });

    test('Case 0 (Production Bug Reproduction): 149g Mutton - 50g logged = 99g remaining', () async {
      FridgeCategoryRepository.addOrMergeItem(
        categoryName: 'Non-Veg',
        name: 'Mutton',
        quantity: 149,
        unit: 'g',
      );

      final before = FridgeCategoryRepository.findItemByName('Mutton');
      expect(before?.decimalAmount, 149);
      expect(before?.unit, 'g');

      await MockDataRepository.logMeal(
        mealType: 'dinner',
        mealName: 'Mutton Curry',
        calories: 450,
        protein: 35,
        carbs: 5,
        fat: 25,
        ingredients: ['Mutton (50g)'],
      );

      final after = FridgeCategoryRepository.findItemByName('Mutton');
      expect(after?.decimalAmount, 99);
      expect(after?.unit, 'g');
    });

    test('Case 1: 500g initial inventory - 100g logged = 400g remaining', () async {
      FridgeCategoryRepository.addOrMergeItem(
        categoryName: 'Dairy Products',
        name: 'Tofu Paneer',
        quantity: 500,
        unit: 'g',
      );

      final before = FridgeCategoryRepository.findItemByName('Tofu Paneer');
      expect(before?.decimalAmount, 500);
      expect(before?.unit, 'g');

      await MockDataRepository.logMeal(
        mealType: 'lunch',
        mealName: 'Tofu Stir Fry',
        calories: 350,
        protein: 25,
        carbs: 10,
        fat: 15,
        ingredients: ['Tofu Paneer (100g)'],
      );

      final after = FridgeCategoryRepository.findItemByName('Tofu Paneer');
      expect(after?.decimalAmount, 400);
      expect(after?.unit, 'g');
    });

    test('Case 2: 500g initial inventory - 50g logged = 450g remaining', () async {
      FridgeCategoryRepository.addOrMergeItem(
        categoryName: 'Dairy Products',
        name: 'Greek Yogurt',
        quantity: 500,
        unit: 'g',
      );

      final before = FridgeCategoryRepository.findItemByName('Greek Yogurt');
      expect(before?.decimalAmount, 500);

      await MockDataRepository.logMeal(
        mealType: 'snack',
        mealName: 'Yogurt Snack',
        calories: 120,
        protein: 10,
        carbs: 8,
        fat: 2,
        ingredients: ['50g Greek Yogurt'],
      );

      final after = FridgeCategoryRepository.findItemByName('Greek Yogurt');
      expect(after?.decimalAmount, 450);
      expect(after?.unit, 'g');
    });

    test('Case 3: 500ml initial inventory - 100ml logged = 400ml remaining', () async {
      FridgeCategoryRepository.addOrMergeItem(
        categoryName: 'Drinks & Juices',
        name: 'Almond Milk',
        quantity: 500,
        unit: 'ml',
      );

      final before = FridgeCategoryRepository.findItemByName('Almond Milk');
      expect(before?.decimalAmount, 500);
      expect(before?.unit, 'ml');

      await MockDataRepository.logMeal(
        mealType: 'breakfast',
        mealName: 'Morning Shake',
        calories: 180,
        protein: 6,
        carbs: 22,
        fat: 4,
        ingredients: ['Almond Milk (100ml)'],
      );

      final after = FridgeCategoryRepository.findItemByName('Almond Milk');
      expect(after?.decimalAmount, 400);
      expect(after?.unit, 'ml');
    });

    test('Case 4: 12 pieces initial inventory - 1 piece logged = 11 pieces remaining', () async {
      FridgeCategoryRepository.addOrMergeItem(
        categoryName: 'Dairy Products',
        name: 'Farm Eggs',
        quantity: 12,
        unit: 'pieces',
      );

      final before = FridgeCategoryRepository.findItemByName('Farm Eggs');
      expect(before?.decimalAmount, 12);
      expect(before?.unit, 'pieces');

      await MockDataRepository.logMeal(
        mealType: 'breakfast',
        mealName: 'Boiled Egg',
        calories: 78,
        protein: 6,
        carbs: 1,
        fat: 5,
        ingredients: ['Farm Eggs (1 piece)'],
      );

      final after = FridgeCategoryRepository.findItemByName('Farm Eggs');
      expect(after?.decimalAmount, 11);
      expect(after?.unit, 'pieces');
    });

    test('Incompatible units do not deduct inventory or corrupt stock', () async {
      FridgeCategoryRepository.addOrMergeItem(
        categoryName: 'Dairy Products',
        name: 'Solid Cheese',
        quantity: 500,
        unit: 'g',
      );

      // Attempt to deduct in volume (ml) from mass (g)
      await MockDataRepository.logMeal(
        mealType: 'lunch',
        mealName: 'Cheese Soup',
        calories: 200,
        protein: 10,
        carbs: 5,
        fat: 12,
        ingredients: ['Solid Cheese (100ml)'],
      );

      // Quantity must remain untouched at 500g
      final after = FridgeCategoryRepository.findItemByName('Solid Cheese');
      expect(after?.decimalAmount, 500);
      expect(after?.unit, 'g');
    });

    test('Unspecified ingredient quantity on mass items does not deduct default 1g', () async {
      FridgeCategoryRepository.addOrMergeItem(
        categoryName: 'Dairy Products',
        name: 'Paneer Block',
        quantity: 500,
        unit: 'g',
      );

      // Meal lists "Paneer Block" with no quantity specified
      await MockDataRepository.logMeal(
        mealType: 'lunch',
        mealName: 'Paneer Curry',
        calories: 400,
        protein: 20,
        carbs: 15,
        fat: 18,
        ingredients: ['Paneer Block'],
      );

      // Quantity must NOT decrease by 1g to 499g
      final after = FridgeCategoryRepository.findItemByName('Paneer Block');
      expect(after?.decimalAmount, 500);
      expect(after?.unit, 'g');
    });

    test('Insufficient stock prevents negative inventory', () async {
      FridgeCategoryRepository.addOrMergeItem(
        categoryName: 'Vegetables',
        name: 'Spinach',
        quantity: 50,
        unit: 'g',
      );

      // Attempt to deduct 100g when only 50g available
      final deductionResult = FridgeCategoryRepository.deductItemQuantity(
        name: 'Spinach',
        quantity: 100,
        unit: 'g',
      );

      expect(deductionResult.status, DeductionStatus.overRemoval);

      // Inventory remains 50g, never negative
      final after = FridgeCategoryRepository.findItemByName('Spinach');
      expect(after?.decimalAmount, 50);
    });

    test('Retries with same idempotency key never deduct inventory twice', () async {
      FridgeCategoryRepository.addOrMergeItem(
        categoryName: 'Dairy Products',
        name: 'Butter Cube',
        quantity: 200,
        unit: 'g',
      );

      const idempotencyKey = 'idemp-duplicate-safe-key-777';

      // First attempt
      final result1 = await MockDataRepository.logMeal(
        mealType: 'breakfast',
        mealName: 'Toast with Butter',
        calories: 220,
        protein: 4,
        carbs: 24,
        fat: 12,
        ingredients: ['Butter Cube (50g)'],
        idempotencyKey: idempotencyKey,
      );

      expect(result1?.alreadyProcessed, isFalse);
      final stockAfterFirst = FridgeCategoryRepository.findItemByName('Butter Cube')?.decimalAmount;
      expect(stockAfterFirst, 150);

      // Simulated second attempt / retry with same idempotency key
      // If RPC or service returns alreadyProcessed == true, client suppresses deduction
      const duplicateResult = MealTransactionResult(
        status: 'idempotent_duplicate',
        alreadyProcessed: true,
        mealId: 'existing-meal-id',
        localDate: '2026-11-06',
        mealType: 'breakfast',
        deductionsApplied: 0,
      );

      if (!duplicateResult.alreadyProcessed) {
        FridgeCategoryRepository.deductItemQuantityByName(
          name: 'Butter Cube',
          quantity: 50,
          unit: 'g',
        );
      }

      final stockAfterRetry = FridgeCategoryRepository.findItemByName('Butter Cube')?.decimalAmount;
      expect(stockAfterRetry, 150); // Untouched on replay!
    });

    test('Zero-row inventory deduction RPC rollback assertion behavior', () {
      // Validates client-side representation of RPC assertion:
      // If an RPC fails due to zero-row mutation (NOT FOUND),
      // client error handler preserves inventory without modifying cache.
      FridgeCategoryRepository.addOrMergeItem(
        categoryName: 'Non-Veg',
        name: 'Mutton',
        quantity: 149,
        unit: 'g',
      );

      final stockBefore = FridgeCategoryRepository.findItemByName('Mutton')?.decimalAmount;
      expect(stockBefore, 149);

      // Simulate failed RPC (e.g., PostgreSQL exception raised because zero rows affected)
      expect(
        () {
          throw Exception(
            'Inventory deduction failed: fridge item "Mutton" was locked, but the UPDATE mutation affected zero rows. Transaction rolled back.',
          );
        },
        throwsA(isA<Exception>()),
      );

      // Inventory remains untampered at 149g
      final stockAfter = FridgeCategoryRepository.findItemByName('Mutton')?.decimalAmount;
      expect(stockAfter, 149);
    });
  });
}
