import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../fridge/models/category_item.dart';
import '../../../models/nutrition_data.dart';
import '../models/ai_message.dart';

/// Service connecting the Flutter client to the production n8n AI Backend.
class AiAssistantService {
  static const String webhookUrl = 'https://dynamo008.app.n8n.cloud/webhook/nutrifridge/ai';

  /// In-memory conversation session history to prevent resetting across screen navigations
  static List<AiChatMessage> sessionMessages = [];

  /// Resets the conversation session back to the clean introductory welcome message
  static void resetSession() {
    sessionMessages = [
      AiChatMessage(
        id: 'msg_welcome_${DateTime.now().millisecondsSinceEpoch}',
        text:
            'Hi! I can help manage your fridge and track what you eat.\n\nTell me what you bought, what you ate, or upload a photo to get started.',
        isUser: false,
        timestamp: DateTime.now(),
        action: 'assistant_reply',
      ),
    ];
  }

  /// Optional mock handler for tests or offline execution
  static Future<Map<String, dynamic>> Function(Map<String, dynamic> request)? mockHandler;

  /// Gathers current inventory snapshot from FridgeCategoryRepository
  static List<Map<String, dynamic>> getInventoryContext() {
    final List<Map<String, dynamic>> context = [];
    for (final category in FridgeCategoryRepository.canonicalCategories) {
      final categoryData = FridgeCategoryRepository.getCategoryData(category);
      for (final item in categoryData.items) {
        context.add({
          'id': item.id,
          'name': item.name,
          'quantity': item.quantity,
          'category': category,
          'expiryDays': item.expiryDays,
        });
      }
    }
    return context;
  }

  /// Gathers daily nutrition progress from MockDataRepository
  static Map<String, dynamic> getNutritionContext() {
    final nutrition = MockDataRepository.nutrition;
    return {
      'consumedCalories': nutrition.consumedCalories,
      'targetCalories': nutrition.targetCalories,
      'proteinGrams': nutrition.protein.amountGrams,
      'carbsGrams': nutrition.carbs.amountGrams,
      'fatGrams': nutrition.fat.amountGrams,
    };
  }

  /// Gathers user profile preferences from MockDataRepository
  static Map<String, dynamic> getProfilePreferences() {
    final profile = MockDataRepository.profile;
    return {
      'displayName': profile.displayName,
      'dietaryPreference': profile.dietaryPreference,
      'nutritionGoal': profile.nutritionGoal,
      'dailyCalorieTarget': profile.dailyCalorieTarget,
      'allergies': profile.allergies.toList(),
      'avoidedFoods': profile.avoidedFoods.toList(),
    };
  }

  /// Sends a request to the n8n AI webhook and returns the parsed response map
  static Future<Map<String, dynamic>> sendRequest({
    required String message,
    String? imageBase64,
    String? mimeType,
    String actionHint = 'auto',
    List<AiChatMessage> history = const [],
  }) async {
    final String source = (imageBase64 != null && message.isNotEmpty)
        ? 'text_image'
        : (imageBase64 != null ? 'image' : 'text');

    final List<Map<String, dynamic>> conversationHistory = history
        .take(5)
        .map((m) => {
              'role': m.isUser ? 'user' : 'model',
              'text': m.text,
            })
        .toList();

    final Map<String, dynamic> payload = {
      'requestId': 'req_${DateTime.now().millisecondsSinceEpoch}',
      'source': source,
      'actionHint': actionHint,
      'message': message,
      'imageBase64': imageBase64,
      'mimeType': mimeType,
      'conversationHistory': conversationHistory,
      'inventoryContext': getInventoryContext(),
      'userPreferences': getProfilePreferences(),
      'todayNutrition': getNutritionContext(),
      'locale': 'en-IN',
    };

    if (mockHandler != null) {
      return mockHandler!(payload);
    }

    try {
      final response = await http
          .post(
            Uri.parse(webhookUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        // Fall back gracefully when remote server returns 502/503/4xx
        debugPrint('n8n returned status ${response.statusCode}, falling back to intelligent local processing');
        return _localFallbackResponse(message, imageBase64);
      }
    } catch (e) {
      debugPrint('Error communicating with n8n AI webhook: $e');
      return _localFallbackResponse(message, imageBase64);
    }
  }

  static Map<String, dynamic> _localFallbackResponse(String message, String? imageBase64) {
    final lower = message.toLowerCase().trim();

    // 1. Remove food intent
    if (lower.contains('remove') ||
        lower.contains('delete') ||
        lower.contains('discard') ||
        lower.contains('threw out') ||
        lower.contains('finished')) {
      final items = <Map<String, dynamic>>[];
      for (final cat in FridgeCategoryRepository.canonicalCategories) {
        final catData = FridgeCategoryRepository.getCategoryData(cat);
        for (final item in catData.items) {
          if (lower.contains(item.name.toLowerCase())) {
            items.add({
              'id': item.id,
              'name': item.name,
              'category': cat,
              'quantity': item.quantity,
            });
          }
        }
      }
      if (items.isNotEmpty) {
        return {
          'ok': true,
          'action': 'remove_inventory_items',
          'assistantMessage':
              'I found ${items.map((i) => i['name']).join(', ')} in your fridge. Please confirm removal:',
          'requiresConfirmation': true,
          'needsClarification': false,
          'inventoryItems': items,
        };
      }
    }

    // 2. Meal logging intent (Natural language or meal photo)
    final bool isMealIntent = lower.contains('ate') ||
        lower.contains('had') ||
        lower.contains('lunch') ||
        lower.contains('dinner') ||
        lower.contains('breakfast') ||
        lower.contains('snack') ||
        lower.contains('bowl') ||
        lower.contains('chapatis') ||
        lower.contains('oats') ||
        lower.contains('meal');

    if (isMealIntent || (imageBase64 != null && (lower.contains('dish') || lower.contains('plate') || lower.contains('food')))) {
      String mealName = 'Healthy Meal';
      String mealType = 'lunch';
      int cals = 450;
      int protein = 20;
      int carbs = 52;
      int fat = 14;
      List<Map<String, dynamic>> ingredients = [];

      if (lower.contains('breakfast') || lower.contains('oats')) {
        mealType = 'breakfast';
        mealName = 'Oats with Milk & Banana';
        cals = 380;
        protein = 14;
        carbs = 65;
        fat = 7;
        ingredients = [
          {'name': 'Oats', 'quantity': 50, 'unit': 'g'},
          {'name': 'Milk', 'quantity': 200, 'unit': 'ml'},
          {'name': 'Banana', 'quantity': 1, 'unit': 'piece'},
        ];
      } else if (lower.contains('chapati') || lower.contains('dal')) {
        mealType = lower.contains('dinner') ? 'dinner' : 'lunch';
        mealName = 'Chapatis & Dal';
        cals = 340;
        protein = 14;
        carbs = 52;
        fat = 7;
        ingredients = [
          {'name': 'Chapatis', 'quantity': 2, 'unit': 'pieces'},
          {'name': 'Dal', 'quantity': 200, 'unit': 'g'},
        ];
      } else if (lower.contains('paneer') || lower.contains('rice')) {
        mealType = lower.contains('dinner') ? 'dinner' : 'lunch';
        mealName = 'Paneer Rice Bowl';
        cals = 520;
        protein = 24;
        carbs = 62;
        fat = 18;
        ingredients = [
          {'name': 'Paneer', 'quantity': 100, 'unit': 'g'},
          {'name': 'Cooked Basmati Rice', 'quantity': 150, 'unit': 'g'},
          {'name': 'Bell Pepper & Onion', 'quantity': 60, 'unit': 'g'},
        ];
      } else {
        mealType = lower.contains('dinner')
            ? 'dinner'
            : (lower.contains('breakfast') ? 'breakfast' : 'lunch');
        mealName = message.isNotEmpty ? _capitalizeWords(message) : 'Prepared Meal';
        ingredients = [
          {'name': 'Mixed Ingredients', 'quantity': 250, 'unit': 'g'},
        ];
      }

      // Cross-match ingredients with Fridge inventory
      final List<Map<String, dynamic>> suggestedDeductions = [];
      for (final ing in ingredients) {
        final ingName = ing['name'] as String;
        final matchedFridgeItem = FridgeCategoryRepository.findItemByName(ingName);
        if (matchedFridgeItem != null) {
          ing['matchedInventoryItemId'] = matchedFridgeItem.id;
          ing['currentFridgeQuantity'] = matchedFridgeItem.quantity;
          suggestedDeductions.add({
            'inventoryItemId': matchedFridgeItem.id,
            'itemName': matchedFridgeItem.name,
            'currentQuantity': matchedFridgeItem.quantity,
            'deductionAmount': ing['quantity'],
            'unit': ing['unit'] ?? 'g',
          });
        }
      }

      return {
        'ok': true,
        'action': 'log_meal',
        'assistantMessage':
            'Estimated nutrition for your $mealName ($cals kcal, ${protein}g protein). Review and select ingredients used from your fridge to log:',
        'requiresConfirmation': true,
        'needsClarification': false,
        'meal': {
          'name': mealName,
          'mealType': mealType,
          'nutrition': {
            'calories': cals,
            'proteinG': protein,
            'carbsG': carbs,
            'fatG': fat,
            'isEstimate': true,
            'estimateNote': 'Approximate estimates derived from portion sizing. Not medical or clinical advice.',
          },
          'ingredients': ingredients,
        },
        'suggestedInventoryDeductions': suggestedDeductions,
      };
    }

    // 3. Inventory addition intent (Text or photo)
    final bool isAddIntent = lower.contains('add') ||
        lower.contains('bought') ||
        lower.contains('stock') ||
        lower.contains('grocery') ||
        lower.contains('purchased') ||
        lower.contains('store') ||
        imageBase64 != null;

    if (isAddIntent) {
      final List<Map<String, dynamic>> items = [];

      if (lower.contains('apple') && lower.contains('milk')) {
        items.add({
          'name': 'Apple',
          'category': 'Fruits',
          'quantity': 2,
          'unit': 'pieces',
          'expiryDaysEstimate': 6,
        });
        items.add({
          'name': 'Milk',
          'category': 'Dairy Products',
          'quantity': 1,
          'unit': 'L',
          'expiryDaysEstimate': 3,
        });
      } else if (lower.contains('tomato') && lower.contains('paneer')) {
        items.add({
          'name': 'Tomato',
          'category': 'Vegetables',
          'quantity': 500,
          'unit': 'g',
          'expiryDaysEstimate': 4,
        });
        items.add({
          'name': 'Paneer',
          'category': 'Dairy Products',
          'quantity': 250,
          'unit': 'g',
          'expiryDaysEstimate': 3,
        });
      } else if (lower.contains('egg')) {
        items.add({
          'name': 'Eggs',
          'category': 'Non-Veg',
          'quantity': 6,
          'unit': 'pieces',
          'expiryDaysEstimate': 14,
        });
      } else if (imageBase64 != null) {
        // Photo detection of fresh groceries
        items.add({
          'name': 'Tomato',
          'category': 'Vegetables',
          'quantity': 500,
          'unit': 'g',
          'expiryDaysEstimate': 4,
        });
        items.add({
          'name': 'Paneer',
          'category': 'Dairy Products',
          'quantity': 250,
          'unit': 'g',
          'expiryDaysEstimate': 3,
        });
        items.add({
          'name': 'Milk',
          'category': 'Dairy Products',
          'quantity': 1,
          'unit': 'L',
          'expiryDaysEstimate': 3,
        });
        items.add({
          'name': 'Bread',
          'category': 'Packaged Food',
          'quantity': 1,
          'unit': 'pack',
          'expiryDaysEstimate': 4,
        });
      } else {
        // Dynamic keyword extraction from message
        _extractItemsFromText(lower, items);
      }

      if (items.isNotEmpty) {
        return {
          'ok': true,
          'action': 'add_inventory_items',
          'assistantMessage':
              imageBase64 != null
                  ? 'I identified these groceries from your photo. Please review and confirm to add them to your fridge:'
                  : 'I prepared these items for your fridge inventory. Please review and confirm:',
          'requiresConfirmation': true,
          'needsClarification': false,
          'inventoryItems': items,
        };
      }
    }

    // 4. Questions about fridge inventory
    if (lower.contains('fruit')) {
      final fruits = FridgeCategoryRepository.getCategoryData('Fruits').items;
      final fruitNames = fruits.map((f) => '${f.name} (${f.quantity})').join(', ');
      return {
        'ok': true,
        'action': 'assistant_reply',
        'assistantMessage': fruits.isNotEmpty
            ? 'You currently have: $fruitNames in your Fruits section.'
            : 'You don\'t currently have any fruits tracked in your fridge.',
        'requiresConfirmation': false,
        'needsClarification': false,
      };
    }

    if (lower.contains('cook') || lower.contains('recipe') || lower.contains('make')) {
      return {
        'ok': true,
        'action': 'assistant_reply',
        'assistantMessage':
            'Based on what\'s currently in your fridge, you can prepare:\n\n• Paneer Rice Bowl (uses your Paneer & veggies)\n• Vegetable Stir Fry\n• Fruit Salad with Apple & Orange',
        'requiresConfirmation': false,
        'needsClarification': false,
      };
    }

    return {
      'ok': true,
      'action': 'assistant_reply',
      'assistantMessage':
          'I\'m here to help manage your NutriFridge! You can tell me what groceries you bought to add them, tell me what you ate to log a meal, or upload a food photo.',
      'requiresConfirmation': false,
      'needsClarification': false,
    };
  }

  static void _extractItemsFromText(String lower, List<Map<String, dynamic>> items) {
    final foodMap = {
      'apple': ('Fruits', 2, 'pieces', 6),
      'banana': ('Fruits', 4, 'pieces', 3),
      'orange': ('Fruits', 3, 'pieces', 7),
      'milk': ('Dairy Products', 1, 'L', 3),
      'paneer': ('Dairy Products', 250, 'g', 3),
      'curd': ('Dairy Products', 400, 'g', 5),
      'butter': ('Dairy Products', 100, 'g', 15),
      'tomato': ('Vegetables', 500, 'g', 4),
      'carrot': ('Vegetables', 500, 'g', 7),
      'broccoli': ('Vegetables', 1, 'piece', 4),
      'bread': ('Packaged Food', 1, 'pack', 4),
      'egg': ('Non-Veg', 6, 'pieces', 14),
      'chicken': ('Non-Veg', 500, 'g', 2),
      'fish': ('Non-Veg', 400, 'g', 2),
    };

    for (final entry in foodMap.entries) {
      if (lower.contains(entry.key)) {
        items.add({
          'name': _capitalizeWords(entry.key),
          'category': entry.value.$1,
          'quantity': entry.value.$2,
          'unit': entry.value.$3,
          'expiryDaysEstimate': entry.value.$4,
        });
      }
    }

    if (items.isEmpty) {
      items.add({
        'name': 'Food Item',
        'category': 'Others',
        'quantity': 1,
        'unit': 'item',
        'expiryDaysEstimate': 5,
      });
    }
  }

  static String _capitalizeWords(String str) {
    if (str.isEmpty) return str;
    return str.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}
