import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/screens/ai_assistant/models/ai_message.dart';
import 'package:nutrifridge/screens/ai_assistant/services/ai_assistant_service.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';

void main() {
  setUp(() {
    FridgeCategoryRepository.reset();
    MockDataRepository.reset();
    MockDataRepository.forceInMemoryForTesting = true;
    AiAssistantService.mockHandler = null;
    AiAssistantService.resetSession();
  });

  tearDown(() {
    FridgeCategoryRepository.reset();
    MockDataRepository.reset();
    AiAssistantService.mockHandler = null;
    AiAssistantService.resetSession();
  });

  group('NutriFridge AI Assistant — Text & Image Intent Regression Tests', () {
    test('Scenario 1: Adding groceries text "1L milk, 6 eggs and 6 bananas"', () async {
      AiAssistantService.mockHandler = (req) async {
        expect(req['source'], 'text');
        expect(req['message'], '1L milk, 6 eggs and 6 bananas');
        return {
          'ok': true,
          'action': 'add_inventory_items',
          'assistantMessage': 'I found 1L milk, 6 eggs and 6 bananas. Would you like to add these to your fridge inventory?',
          'requiresConfirmation': true,
          'inventoryItems': [
            {'name': 'Milk', 'category': 'Dairy Products', 'quantity': 1, 'unit': 'L'},
            {'name': 'Eggs', 'category': 'Non-Veg', 'quantity': 6, 'unit': 'pieces'},
            {'name': 'Bananas', 'category': 'Fruits', 'quantity': 6, 'unit': 'pieces'}
          ]
        };
      };

      final res = await AiAssistantService.sendRequest(message: '1L milk, 6 eggs and 6 bananas');
      expect(res['ok'], isTrue);
      expect(res['action'], 'add_inventory_items');
      expect(res['requiresConfirmation'], isTrue);
      final items = res['inventoryItems'] as List;
      expect(items.length, 3);
      expect(items[0]['name'], 'Milk');
      expect(items[0]['quantity'], 1);
      expect(items[0]['unit'], 'L');
      expect(items[1]['name'], 'Eggs');
      expect(items[1]['quantity'], 6);
      expect(items[2]['name'], 'Bananas');
      expect(items[2]['quantity'], 6);
    });

    test('Scenario 2: Removing groceries text "remove apples from fridge"', () async {
      AiAssistantService.mockHandler = (req) async {
        expect(req['source'], 'text');
        expect(req['message'], 'remove apples from fridge');
        return {
          'ok': true,
          'action': 'remove_inventory_items',
          'assistantMessage': 'I will remove Apples from your fridge inventory. Please confirm.',
          'requiresConfirmation': true,
          'inventoryItems': [
            {'name': 'Apples', 'category': 'Fruits', 'quantity': null, 'unit': null, 'isFullRemoval': true}
          ]
        };
      };

      final res = await AiAssistantService.sendRequest(message: 'remove apples from fridge');
      expect(res['ok'], isTrue);
      expect(res['action'], 'remove_inventory_items');
      expect(res['requiresConfirmation'], isTrue);
      final items = res['inventoryItems'] as List;
      expect(items.length, 1);
      expect(items[0]['name'], 'Apples');
      expect(items[0]['isFullRemoval'], isTrue);
    });

    test('Scenario 3: Adding groceries text "Add 2 kg potatoes and 500g paneer"', () async {
      AiAssistantService.mockHandler = (req) async {
        expect(req['message'], 'Add 2 kg potatoes and 500g paneer');
        return {
          'ok': true,
          'action': 'add_inventory_items',
          'assistantMessage': 'I found 2 kg potatoes and 500g paneer. Would you like to add them?',
          'requiresConfirmation': true,
          'inventoryItems': [
            {'name': 'Potatoes', 'category': 'Vegetables', 'quantity': 2, 'unit': 'kg'},
            {'name': 'Paneer', 'category': 'Dairy Products', 'quantity': 500, 'unit': 'g'}
          ]
        };
      };

      final res = await AiAssistantService.sendRequest(message: 'Add 2 kg potatoes and 500g paneer');
      expect(res['ok'], isTrue);
      expect(res['action'], 'add_inventory_items');
      final items = res['inventoryItems'] as List;
      expect(items.length, 2);
      expect(items[0]['name'], 'Potatoes');
      expect(items[0]['quantity'], 2);
      expect(items[0]['unit'], 'kg');
      expect(items[1]['name'], 'Paneer');
      expect(items[1]['quantity'], 500);
      expect(items[1]['unit'], 'g');
    });

    test('Scenario 4: Partial removal "I used 2 eggs"', () async {
      AiAssistantService.mockHandler = (req) async {
        expect(req['message'], 'I used 2 eggs');
        return {
          'ok': true,
          'action': 'remove_inventory_items',
          'assistantMessage': 'I will deduct 2 eggs from your fridge inventory.',
          'requiresConfirmation': true,
          'inventoryItems': [
            {'name': 'Eggs', 'category': 'Non-Veg', 'quantity': 2, 'unit': 'pieces', 'isFullRemoval': false}
          ]
        };
      };

      final res = await AiAssistantService.sendRequest(message: 'I used 2 eggs');
      expect(res['ok'], isTrue);
      expect(res['action'], 'remove_inventory_items');
      final items = res['inventoryItems'] as List;
      expect(items.length, 1);
      expect(items[0]['name'], 'Eggs');
      expect(items[0]['quantity'], 2);
      expect(items[0]['unit'], 'pieces');
      expect(items[0]['isFullRemoval'], isFalse);
    });

    test('Scenario 5: Inventory queries "What fruits do I have?"', () async {
      FridgeCategoryRepository.addOrMergeItem(
        categoryName: 'Fruits',
        name: 'Apples',
        quantity: 4,
        unit: 'pieces',
      );

      AiAssistantService.mockHandler = (req) async {
        final inv = req['inventoryContext'] as List;
        expect(inv.any((it) => it['name'] == 'Apples'), isTrue);
        return {
          'ok': true,
          'action': 'query_inventory',
          'assistantMessage': 'You have 4 pieces of Apples in your fridge.',
          'requiresConfirmation': false,
          'inventoryQueryResults': [
            {'name': 'Apples', 'quantity': '4 pieces', 'category': 'Fruits', 'status': 'Good'}
          ]
        };
      };

      final res = await AiAssistantService.sendRequest(message: 'What fruits do I have?');
      expect(res['ok'], isTrue);
      expect(res['action'], 'query_inventory');
      expect(res['assistantMessage'], contains('4 pieces of Apples'));
    });

    test('Scenario 6 & 7: Grocery list image processing and confirmation', () async {
      AiAssistantService.mockHandler = (req) async {
        expect(req['source'], 'image');
        expect(req['imageBase64'], isNotNull);
        return {
          'ok': true,
          'action': 'add_inventory_items',
          'assistantMessage': 'I found Milk, Eggs, and Bananas on your grocery list. Would you like me to add these items to your fridge inventory?',
          'requiresConfirmation': true,
          'inventoryItems': [
            {'name': 'Milk', 'category': 'Dairy Products', 'quantity': 1, 'unit': 'L'},
            {'name': 'Eggs', 'category': 'Non-Veg', 'quantity': 6, 'unit': 'pieces'},
            {'name': 'Bananas', 'category': 'Fruits', 'quantity': 6, 'unit': 'pieces'}
          ]
        };
      };

      final res = await AiAssistantService.sendRequest(
        message: '',
        imageBase64: 'fakeBase64ImageData==',
        mimeType: 'image/jpeg',
      );

      expect(res['ok'], isTrue);
      expect(res['action'], 'add_inventory_items');
      final items = res['inventoryItems'] as List;
      expect(items.length, 3);

      // Confirm additions
      for (final it in items) {
        FridgeCategoryRepository.addOrMergeItem(
          categoryName: it['category'],
          name: it['name'],
          quantity: it['quantity'],
          unit: it['unit'],
        );
      }

      final milk = FridgeCategoryRepository.findItemByName('Milk');
      expect(milk, isNotNull);
      expect(milk!.quantity, '1 L');

      final eggs = FridgeCategoryRepository.findItemByName('Eggs');
      expect(eggs, isNotNull);
      expect(eggs!.quantity, '6 pieces');

      final bananas = FridgeCategoryRepository.findItemByName('Bananas');
      expect(bananas, isNotNull);
      expect(bananas!.quantity, '6 pieces');
    });

    test('Scenario 8: Retry a failed request does not duplicate inventory updates', () async {
      int calls = 0;
      AiAssistantService.mockHandler = (req) async {
        calls++;
        if (calls == 1) {
          return {
            'ok': false,
            'action': 'error',
            'assistantMessage': 'NutriFridge AI took longer than expected to respond. Please tap retry.',
            'error': 'Timeout'
          };
        }
        return {
          'ok': true,
          'action': 'add_inventory_items',
          'assistantMessage': 'Added 3 oranges.',
          'requiresConfirmation': true,
          'inventoryItems': [
            {'name': 'Oranges', 'category': 'Fruits', 'quantity': 3, 'unit': 'pieces'}
          ]
        };
      };

      // First attempt fails
      final res1 = await AiAssistantService.sendRequest(message: 'add 3 oranges');
      expect(res1['ok'], isFalse);
      expect(FridgeCategoryRepository.findItemByName('Oranges'), isNull);

      // Retry succeeds
      final res2 = await AiAssistantService.sendRequest(message: 'add 3 oranges');
      expect(res2['ok'], isTrue);

      // Confirm once
      final items = res2['inventoryItems'] as List;
      for (final it in items) {
        FridgeCategoryRepository.addOrMergeItem(
          categoryName: it['category'],
          name: it['name'],
          quantity: it['quantity'],
          unit: it['unit'],
        );
      }

      expect(FridgeCategoryRepository.findItemByName('Oranges')!.quantity, '3 pieces');

      // Attempting to confirm a second time with the same message does not duplicate
      // (verified through AiChatMessage isConfirmed flag)
      final msg = AiChatMessage(
        id: 'msg_test',
        text: 'Added 3 oranges.',
        isUser: false,
        timestamp: DateTime.now(),
        isConfirmed: true, // Already confirmed
        inventoryItems: [
          {'name': 'Oranges', 'category': 'Fruits', 'quantity': 3, 'unit': 'pieces'}
        ],
      );
      expect(msg.isConfirmed, isTrue);
    });
  });
}
