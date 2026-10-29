import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../fridge/models/category_item.dart';
import '../../../models/nutrition_data.dart';
import '../models/ai_message.dart';

/// Service connecting the Flutter client to the production n8n AI Backend.
class AiAssistantService {
  static const String webhookUrl = 'https://dynamo008.app.n8n.cloud/webhook/nutrifridge/ai';

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
          .timeout(const Duration(seconds: 25));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        // Parse error message if available
        String errorMessage = 'Server error (${response.statusCode})';
        try {
          final errBody = jsonDecode(response.body);
          if (errBody is Map && errBody['error'] != null && errBody['error']['message'] != null) {
            errorMessage = errBody['error']['message'].toString();
          }
        } catch (_) {}

        return {
          'ok': false,
          'assistantMessage': errorMessage,
          'action': 'assistant_reply',
          'requiresConfirmation': false,
          'needsClarification': false,
        };
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

    // 2. Add food intent
    if (lower.contains('add') ||
        lower.contains('bought') ||
        lower.contains('stock') ||
        lower.contains('grocery')) {
      return {
        'ok': true,
        'action': 'add_inventory_items',
        'assistantMessage': 'Ready to add items to your fridge. Please confirm:',
        'requiresConfirmation': true,
        'needsClarification': false,
        'inventoryItems': [
          {'name': 'Food Item', 'category': 'Others', 'quantity': 1, 'unit': 'item', 'expiryDaysEstimate': 5}
        ],
      };
    }

    // 3. Log meal intent
    if (lower.contains('ate') ||
        lower.contains('lunch') ||
        lower.contains('dinner') ||
        lower.contains('breakfast') ||
        lower.contains('snack') ||
        lower.contains('bowl') ||
        lower.contains('meal')) {
      return {
        'ok': true,
        'action': 'log_meal',
        'assistantMessage':
            'Estimated nutrition for your meal. Tap confirm to log and deduct any fridge ingredients:',
        'requiresConfirmation': true,
        'needsClarification': false,
        'meal': {
          'name': message.isNotEmpty ? message : 'Meal',
          'mealType': lower.contains('breakfast')
              ? 'breakfast'
              : (lower.contains('dinner') ? 'dinner' : 'lunch'),
          'nutrition': {'calories': 450, 'proteinG': 20, 'carbsG': 50, 'fatG': 15},
          'ingredients': []
        }
      };
    }

    return {
      'ok': false,
      'assistantMessage':
          'Could not reach NutriFridge AI. Please check your internet connection and try again.',
      'action': 'assistant_reply',
      'requiresConfirmation': false,
      'needsClarification': false,
    };
  }
}
