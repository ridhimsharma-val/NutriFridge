import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/screens/ai_assistant/ai_assistant_screen.dart';
import 'package:nutrifridge/screens/ai_assistant/services/ai_assistant_service.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/screens/home/services/meal_recommendation_service.dart';

void main() {
  setUp(() {
    AiAssistantService.mockHandler = null;
    AiAssistantService.resetSession();
    FridgeCategoryRepository.seedSampleDataForTesting();
    MealRecommendationService.reset();
  });

  tearDown(() {
    AiAssistantService.mockHandler = null;
  });

  group('NutriFridge AI Assistant Connection & Normalization Tests', () {
    test('1. Normalization handles direct JSON responses', () async {
      AiAssistantService.mockHandler = (req) async => {
        'ok': true,
        'action': 'add_inventory_items',
        'assistantMessage': 'Added 5 apples to fridge.',
        'inventoryItems': [
          {'name': 'Apple', 'quantity': 5, 'unit': 'pieces', 'category': 'Fruits'}
        ],
        'requiresConfirmation': true,
      };

      final res = await AiAssistantService.sendRequest(message: 'add 5 apples to fridge');
      expect(res['action'], equals('add_inventory_items'));
      expect(res['assistantMessage'], equals('Added 5 apples to fridge.'));
      expect((res['inventoryItems'] as List).length, equals(1));
    });

    test('2. Normalization handles wrapped body responses', () async {
      AiAssistantService.mockHandler = (req) async => {
        'body': {
          'ok': true,
          'action': 'add_inventory_items',
          'assistantMessage': 'Added 2 bananas.',
          'items': [
            {'name': 'Banana', 'quantity': 2, 'unit': 'pieces'}
          ]
        }
      };

      final res = await AiAssistantService.sendRequest(message: 'add 2 bananas');
      expect(res['action'], equals('add_inventory_items'));
      expect(res['assistantMessage'], equals('Added 2 bananas.'));
      expect(res['inventoryItems'], isNotNull);
      expect((res['inventoryItems'] as List).first['name'], equals('Banana'));
    });

    test('3. Normalization handles string-encoded output / raw JSON output', () async {
      AiAssistantService.mockHandler = (req) async => {
        'output': jsonEncode({
          'ok': true,
          'action': 'log_meal',
          'assistantMessage': 'Logged breakfast oats.',
          'meal': {'name': 'Oatmeal'}
        })
      };

      final res = await AiAssistantService.sendRequest(message: 'I had oatmeal');
      expect(res['action'], equals('log_meal'));
      expect(res['assistantMessage'], equals('Logged breakfast oats.'));
      expect(res['meal'], isNotNull);
    });

    test('4. Granular error reporting for HTTP status codes', () async {
      AiAssistantService.mockHandler = (req) async => {
        'success': false,
        'action': 'error',
        'assistantMessage': 'NutriFridge AI service is temporarily experiencing high load (Status 502). Please tap retry in a moment.',
        'error': 'Remote server returned status 502',
      };

      final res = await AiAssistantService.sendRequest(message: 'hello');
      expect(res['action'], equals('error'));
      expect(res['assistantMessage'], contains('502'));
    });

    testWidgets('5. Retry does not duplicate user message and cleans up error bubble', (tester) async {
      int requestCount = 0;
      AiAssistantService.mockHandler = (req) async {
        requestCount++;
        if (requestCount == 1) {
          // First attempt fails
          return {
            'success': false,
            'action': 'error',
            'assistantMessage': 'NutriFridge AI took longer than expected to respond. Please tap retry.',
            'error': 'TimeoutException',
          };
        } else {
          // Second attempt succeeds
          return {
            'ok': true,
            'action': 'assistant_reply',
            'assistantMessage': 'Hello! How can I help you today?',
          };
        }
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiAssistantScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter user message
      final inputFinder = find.byType(TextField);
      expect(inputFinder, findsOneWidget);
      await tester.enterText(inputFinder, 'add 5 apples to fridge');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      // Should show user message and error message with retry button
      expect(find.text('add 5 apples to fridge'), findsOneWidget);
      expect(find.textContaining('NutriFridge AI took longer than expected'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Tap Retry
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Crucial: The user message must still only appear ONCE, not duplicated!
      expect(find.text('add 5 apples to fridge'), findsOneWidget);
      // The error message must be removed, replaced by success reply
      expect(find.textContaining('NutriFridge AI took longer than expected'), findsNothing);
      expect(find.text('Hello! How can I help you today?'), findsOneWidget);
    });

    testWidgets('6. Send button is guarded and disabled while request is in flight', (tester) async {
      final completer = Completer<Map<String, dynamic>>();
      AiAssistantService.mockHandler = (req) => completer.future;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiAssistantScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, 'test in flight');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump(); // Start send

      // In flight: circular progress indicator is shown
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // Attempt to send another message while in-flight
      await tester.enterText(inputFinder, 'second attempt');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();

      // Complete the first request
      completer.complete({
        'ok': true,
        'action': 'assistant_reply',
        'assistantMessage': 'First reply done.',
      });
      await tester.pumpAndSettle();

      // Second attempt was ignored because the previous was in flight
      expect(find.text('test in flight'), findsOneWidget);
      expect(find.text('First reply done.'), findsOneWidget);
    });

    test('7. MealRecommendationService handles 400 from un-updated backend by falling back to auto', () async {
      int requestCount = 0;
      final List<String> receivedActionHints = [];

      AiAssistantService.mockHandler = (req) async {
        requestCount++;
        final hint = req['actionHint'] as String;
        receivedActionHints.add(hint);

        if (hint == 'meal_recommendation') {
          // Simulate older deployed n8n workflow returning 400 INVALID_ACTION_HINT
          return {
            'success': false,
            'action': 'error',
            'assistantMessage': 'NutriFridge AI request could not be completed (Status 400). Please tap retry.',
            'error': 'Remote server returned status 400: INVALID_ACTION_HINT',
          };
        } else {
          // Fallback with actionHint: auto succeeds
          return {
            'ok': true,
            'action': 'assistant_reply',
            'assistantMessage': 'Recommended a fresh vegetable pasta for dinner.',
          };
        }
      };

      // Reset service state
      MealRecommendationService.reset();

      final rec = await MealRecommendationService.fetchRecommendation(
        forceRefresh: true,
        time: DateTime(2026, 11, 4, 20, 0), // Dinner
      );

      // Verify that meal_recommendation was attempted first, then auto was used as fallback
      expect(receivedActionHints, contains('meal_recommendation'));
      expect(receivedActionHints, contains('auto'));
      expect(requestCount, equals(2));
      expect(rec, isNotNull);
      expect(MealRecommendationService.currentStatus, equals(RecommendationStatus.loaded));
    });

    test('8. Structured meal_recommendation response parses properly', () async {
      AiAssistantService.mockHandler = (req) async => {
        'ok': true,
        'action': 'meal_recommendation',
        'meal': {
          'id': 'rec_paneer_bowl_custom',
          'name': 'Paneer Rice Bowl',
          'mealType': 'lunch',
          'description': 'A nutritious meal using paneer and rice from your fridge.',
          'calories': 520,
          'proteinG': 24,
          'carbsG': 62,
          'fatG': 18,
          'nutritionIsEstimate': true,
          'preparationTimeMinutes': 20,
          'ingredients': ['Paneer', 'Rice', 'Capsicum'],
          'missingIngredients': ['Spices'],
          'reason': 'Uses ingredients from your fridge.',
          'imageKey': 'paneer_rice_bowl'
        }
      };

      MealRecommendationService.reset();

      final rec = await MealRecommendationService.fetchRecommendation(
        forceRefresh: true,
        time: DateTime(2026, 11, 4, 13, 0), // Lunch
      );

      expect(rec, isNotNull);
      expect(rec!.title, equals('Paneer Rice Bowl'));
      expect(rec.calories, equals(520));
      expect(rec.proteinGrams, equals(24));
      expect(rec.carbsGrams, equals(62));
      expect(rec.fatGrams, equals(18));
      expect(rec.prepTimeMinutes, equals(20));
      expect(rec.requiredIngredients, contains('Paneer'));
      expect(rec.missingIngredients, contains('Spices'));
      expect(MealRecommendationService.currentStatus, equals(RecommendationStatus.loaded));
    });

    test('9. Empty fridge inventory shows empty-state without calling n8n backend', () async {
      bool backendWasCalled = false;
      AiAssistantService.mockHandler = (req) async {
        backendWasCalled = true;
        return {'ok': true};
      };

      // Clear inventory
      FridgeCategoryRepository.reset();
      MealRecommendationService.reset();

      final rec = await MealRecommendationService.fetchRecommendation(forceRefresh: true);

      expect(rec, isNull);
      expect(backendWasCalled, isFalse);
      expect(MealRecommendationService.currentStatus, equals(RecommendationStatus.empty));

      // Restore inventory
      FridgeCategoryRepository.seedSampleDataForTesting();
    });
  });
}
