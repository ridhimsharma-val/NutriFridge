import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
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
}
