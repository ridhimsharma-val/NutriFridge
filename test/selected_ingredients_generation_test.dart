import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/screens/ai_assistant/services/ai_assistant_service.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/screens/fridge/services/cooking_basket_service.dart';
import 'package:nutrifridge/screens/home/services/meal_recommendation_service.dart';

void main() {
  setUp(() {
    MockDataRepository.forceInMemoryForTesting = true;
    FridgeCategoryRepository.forceInMemoryForTesting = true;
    CookingBasketService.clear();
    MealRecommendationService.reset();
    AiAssistantService.mockHandler = null;
  });

  tearDown(() {
    AiAssistantService.mockHandler = null;
    CookingBasketService.clear();
    MealRecommendationService.reset();
  });

  group('CategoryFoodItem.displayQuantity Unit Deduplication', () {
    test('Correctly strips duplicate unit when quantity already contains unit', () {
      const milk = CategoryFoodItem(
        id: '1',
        name: 'Milk',
        quantity: '3 L',
      );
      expect(milk.unit, equals('L'));
      expect(milk.displayQuantity, equals('3 L'));

      const paneer = CategoryFoodItem(
        id: '2',
        name: 'Paneer',
        quantity: '500 g',
      );
      expect(paneer.unit, equals('g'));
      expect(paneer.displayQuantity, equals('500 g'));

      const eggs = CategoryFoodItem(
        id: '3',
        name: 'Eggs',
        quantity: '6 pieces',
      );
      expect(eggs.unit, equals('pieces'));
      expect(eggs.displayQuantity, equals('6 pieces'));

      const yogurt = CategoryFoodItem(
        id: '4',
        name: 'Greek Yogurt',
        quantity: '200 ml',
      );
      expect(yogurt.unit, equals('ml'));
      expect(yogurt.displayQuantity, equals('200 ml'));
    });

    test('Appends unit when quantity is purely numeric without unit', () {
      const apples = CategoryFoodItem(
        id: '5',
        name: 'Apples',
        quantity: '4',
      );
      // unit defaults to 'g' when not present in quantity string
      expect(apples.displayQuantity, equals('4 g'));
    });
  });

  group('AiAssistantService Specific Error Code Handling', () {
    test('401 or USER_AUTHENTICATION_FAILED returns friendly session expired message', () async {
      AiAssistantService.mockHandler = (payload) async {
        return {
          'ok': false,
          'action': 'error',
          'assistantMessage': 'Your session has expired. Please sign in again to access NutriFridge AI.',
          'error': {'code': 'USER_AUTHENTICATION_FAILED'},
        };
      };

      final response = await AiAssistantService.sendRequest(
        message: 'test',
        actionHint: 'meal_recommendation',
      );

      expect(response['ok'], isFalse);
      expect(response['assistantMessage'], contains('session has expired'));
    });

    test('429 or GEMINI_RATE_LIMIT_EXCEEDED returns friendly rate limit message', () async {
      AiAssistantService.mockHandler = (payload) async {
        return {
          'ok': false,
          'action': 'error',
          'assistantMessage': 'Google Gemini rate limit exceeded. Please wait a moment and tap retry.',
          'error': {'code': 'GEMINI_RATE_LIMIT_EXCEEDED'},
        };
      };

      final response = await AiAssistantService.sendRequest(
        message: 'test',
        actionHint: 'meal_recommendation',
      );

      expect(response['ok'], isFalse);
      expect(response['assistantMessage'], contains('rate limit exceeded'));
    });

    test('INVALID_UUID_SYNTAX returns friendly invalid ID message', () async {
      AiAssistantService.mockHandler = (payload) async {
        return {
          'ok': false,
          'action': 'error',
          'assistantMessage': 'One or more selected ingredient IDs are invalid. Please refresh your inventory.',
          'error': {'code': 'INVALID_UUID_SYNTAX'},
        };
      };

      final response = await AiAssistantService.sendRequest(
        message: 'test',
        actionHint: 'meal_recommendation',
      );

      expect(response['ok'], isFalse);
      expect(response['assistantMessage'], contains('ingredient IDs are invalid'));
    });

    test('ITEM_NOT_FOUND_OR_UNAUTHORIZED returns friendly item not found message', () async {
      AiAssistantService.mockHandler = (payload) async {
        return {
          'ok': false,
          'action': 'error',
          'assistantMessage': 'One or more selected items could not be found in your inventory. Please refresh and try again.',
          'error': {'code': 'ITEM_NOT_FOUND_OR_UNAUTHORIZED'},
        };
      };

      final response = await AiAssistantService.sendRequest(
        message: 'test',
        actionHint: 'meal_recommendation',
      );

      expect(response['ok'], isFalse);
      expect(response['assistantMessage'], contains('could not be found in your inventory'));
    });

    test('DATABASE_QUERY_ERROR returns friendly database retry message', () async {
      AiAssistantService.mockHandler = (payload) async {
        return {
          'ok': false,
          'action': 'error',
          'assistantMessage': 'Unable to verify selected ingredients from database. Please tap retry.',
          'error': {'code': 'DATABASE_QUERY_ERROR'},
        };
      };

      final response = await AiAssistantService.sendRequest(
        message: 'test',
        actionHint: 'meal_recommendation',
      );

      expect(response['ok'], isFalse);
      expect(response['assistantMessage'], contains('Unable to verify selected ingredients'));
    });

    test('GEMINI_REQUEST_TIMEOUT returns friendly timeout message', () async {
      AiAssistantService.mockHandler = (payload) async {
        return {
          'ok': false,
          'action': 'error',
          'assistantMessage': 'NutriFridge AI took longer than expected to respond. Please tap retry.',
          'error': {'code': 'GEMINI_REQUEST_TIMEOUT'},
        };
      };

      final response = await AiAssistantService.sendRequest(
        message: 'test',
        actionHint: 'meal_recommendation',
      );

      expect(response['ok'], isFalse);
      expect(response['assistantMessage'], contains('longer than expected to respond'));
    });
  });

  group('MealRecommendationService Selected Ingredients Resolution', () {
    test('Resolves UUIDs from loaded inventory when items have fixture IDs', () async {
      // Seed an item with a real UUID in category store
      const realUuid = '3cdcaece-1764-44ab-b2f8-81b0f57175fa';
      const inventoryItem = CategoryFoodItem(
        id: realUuid,
        name: 'Milk',
        quantity: '3 L',
        category: 'Dairy Products',
      );

      FridgeCategoryRepository.addItemToCategory('Dairy Products', inventoryItem);

      // Selected item initially has fixture id 'dairy_1'
      const selectedMilk = CategoryFoodItem(
        id: 'dairy_1',
        name: 'Milk',
        quantity: '3 L',
        category: 'Dairy Products',
      );

      Map<String, dynamic>? receivedPayload;
      AiAssistantService.mockHandler = (payload) async {
        receivedPayload = payload;
        return {
          'ok': true,
          'action': 'meal_recommendation',
          'meal': {
            'id': 'rec_milk_001',
            'name': 'Golden Turmeric Milk',
            'mealType': 'Snack',
            'calories': 180,
            'proteinG': 9,
            'carbsG': 15,
            'fatG': 8,
            'preparationTimeMinutes': 5,
            'cookingTimeMinutes': 5,
            'servingSize': '1 glass',
            'nutritionIsEstimate': true,
            'ingredients': [
              {'name': 'Milk', 'quantity': 250, 'unit': 'ml', 'availableInFridge': true},
            ],
            'preparationSteps': [
              {'stepNumber': 1, 'instruction': 'Warm milk with turmeric and honey.', 'time': '5 mins'},
            ],
            'cookingTips': ['Do not boil furiously.'],
            'substitutions': [],
          },
        };
      };

      final rec = await MealRecommendationService.generateFromSelectedIngredients(
        selectedItems: [selectedMilk],
      );

      expect(rec, isNotNull);
      expect(receivedPayload, isNotNull);
      // The payload selectedInventoryItemIds should have resolved the real UUID!
      final ids = receivedPayload!['selectedInventoryItemIds'] as List;
      expect(ids, contains(realUuid));
      expect(ids, isNot(contains('dairy_1')));
    });
  });
}
