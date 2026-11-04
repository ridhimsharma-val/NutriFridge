import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nutrifridge/screens/ai_assistant/ai_assistant_screen.dart';
import 'package:nutrifridge/screens/ai_assistant/models/ai_message.dart';
import 'package:nutrifridge/screens/ai_assistant/services/ai_assistant_service.dart';

void main() {
  setUp(() {
    AiAssistantService.mockHandler = null;
    AiAssistantService.resetSession();
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
  });
}
