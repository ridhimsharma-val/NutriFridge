import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../../services/auth/auth_service.dart';
import '../../fridge/models/category_item.dart';
import '../../../models/nutrition_data.dart';
import '../../meal_detail/models/meal_ai_context.dart';
import '../../../../services/ai/supabase_ai_function_client.dart';
import '../models/ai_message.dart';

/// Service connecting the Flutter client to the NutriFridge AI pipeline:
/// Flutter AI Assistant -> Supabase Edge Function (`nutrifridge-ai`) -> n8n Webhook -> Google Gemini.
class AiAssistantService {
  /// Name of the authenticated Supabase Edge Function
  static const String edgeFunctionName = 'nutrifridge-ai';

  /// Client timeout limit of 90 seconds (Duration(seconds: 90)) before returning 'GEMINI_REQUEST_TIMEOUT'.
  static const Duration invocationTimeout = Duration(seconds: 90);

  /// In-memory conversation session history to prevent resetting across screen navigations
  static List<AiChatMessage> sessionMessages = [];

  /// Current pending quick-action intent (e.g. 'log_meal', 'add_groceries', 'recipe_ideas')
  static String? activeQuickActionIntent;

  /// Active meal context ID currently being discussed in the session
  static String? activeMealContextId;

  /// Active structured meal context currently being discussed
  static MealAiContext? activeMealContext;

  /// Resets the conversation session back to the clean introductory welcome message
  static void resetSession() {
    activeQuickActionIntent = null;
    activeMealContextId = null;
    activeMealContext = null;
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

  /// Custom SupabaseClient override for unit testing
  static SupabaseClient? customClient;

  static SupabaseClient get _client {
    if (customClient != null) return customClient!;
    return SupabaseManager.client;
  }

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

  /// Sends an authenticated request to the Supabase Edge Function (`nutrifridge-ai`)
  /// and returns the validated, normalized response map.
  static Future<Map<String, dynamic>> sendRequest({
    required String message,
    String? imageBase64,
    String? mimeType,
    String actionHint = 'auto',
    List<AiChatMessage> history = const [],
    Map<String, dynamic>? extraPayload,
    String? conversationId,
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

    // Normalize actionHint: n8n workflow strictly supports:
    // ['auto', 'add_food_single', 'add_food_multiple', 'receipt_scan', 'log_meal', 'assistant', 'meal_recommendation'].
    // Cooking instructions map to 'assistant' while passing mealContext.
    final String normalizedActionHint = (actionHint == 'cook_recipe' || actionHint == 'recipe_instructions')
        ? 'assistant'
        : actionHint;

    final Map<String, dynamic> payload = {
      'requestId': 'req_${DateTime.now().millisecondsSinceEpoch}',
      'source': source,
      'message': message,
      'imageBase64': imageBase64,
      'mimeType': mimeType,
      'conversationHistory': conversationHistory,
      'inventoryContext': getInventoryContext(),
      'userPreferences': getProfilePreferences(),
      'todayNutrition': getNutritionContext(),
      'locale': 'en-IN',
      'actionHint': normalizedActionHint,
      'conversationId': ?conversationId,
      ...?extraPayload,
    };

    if (payload['actionHint'] == 'cook_recipe' || payload['actionHint'] == 'recipe_instructions') {
      payload['actionHint'] = 'assistant';
    }

    // Fallback for offline widget test environments without mock handler
    if (MockDataRepository.forceInMemoryForTesting &&
        (!AuthService.instance.isAuthenticated || AuthService.instance.currentUser == null) &&
        mockHandler == null &&
        SupabaseAiFunctionClient.mockHandler == null) {
      return _generateTestModeFallback(message, actionHint);
    }

    // Delegate execution to the centralized SupabaseAiFunctionClient
    return await SupabaseAiFunctionClient.invokeAiFunction(
      body: payload,
      functionName: edgeFunctionName,
      customClient: SupabaseManager.isInitialized ? _client : null,
      handlerOverride: mockHandler != null
          ? (b) async {
              final res = await mockHandler!(b);
              return _normalizeResponse(res);
            }
          : null,
    );
  }

  /// Generates a structured response for widget tests when in forced in-memory test mode
  static Map<String, dynamic> _generateTestModeFallback(String message, String actionHint) {
    final lowerMsg = message.toLowerCase();
    if (actionHint == 'cook_recipe' || lowerMsg.contains('cook') || lowerMsg.contains('recipe') || lowerMsg.contains('how to make')) {
      final isEggs = lowerMsg.contains('egg') || lowerMsg.contains('toast');
      final recipeTitle = isEggs ? 'Scrambled Eggs on Toast with Milk' : 'Fresh Vegetable Stir Fry';
      return {
        'ok': true,
        'action': 'cook_recipe',
        'assistantMessage': '''# $recipeTitle
A delicious, wholesome dish prepared with ingredients from your fridge.

### Preparation Details
- **Prep Time:** 5 mins
- **Cooking Time:** 10 mins
- **Serving Size:** 1 serving

### Ingredients
- Eggs: 2 large (Available in fridge)
- Bread: 2 slices (Available in fridge)
- Milk: 30 ml (Available in fridge)
- Olive Oil / Butter: 1 tsp (Available in fridge)
- Salt & Black Pepper: to taste (Available in fridge)

### Step-by-Step Instructions
1. In a small bowl, whisk 2 eggs with 30ml milk and a pinch of salt until smooth and aerated.
2. Heat 1 tsp butter or oil in a non-stick pan over medium-low heat.
3. Pour egg mixture into the pan and let set undisturbed for 15 seconds.
4. Gently push eggs from edges to center using a spatula to form soft, tender curds.
5. Toast bread slices until golden brown; spoon creamy scrambled eggs on top and serve hot.

### Chef's Cooking Tips & Substitutions
- **Tip:** Cook over gentle low heat to ensure fluffy, tender curds without drying out.
- **Substitution:** Water or almond milk can substitute cow milk for equally light eggs.

### Nutrition Information (Approximate)
- **Calories:** 340 kcal
- **Protein:** 19g
- **Carbs:** 26g
- **Fat:** 15g''',
        'requiresConfirmation': false,
        'meal': {
          'name': recipeTitle,
          'mealType': isEggs ? 'breakfast' : 'lunch',
          'description': 'A delicious, wholesome dish prepared with ingredients from your fridge.',
          'calories': 340,
          'proteinG': 19,
          'carbsG': 26,
          'fatG': 15,
          'preparationTimeMinutes': 5,
          'cookingTimeMinutes': 10,
          'servings': '1 serving',
          'ingredients': [
            {'name': 'Eggs', 'quantity': 2, 'unit': 'pieces', 'availableInFridge': true},
            {'name': 'Bread', 'quantity': 2, 'unit': 'slices', 'availableInFridge': true},
            {'name': 'Milk', 'quantity': 30, 'unit': 'ml', 'availableInFridge': true},
          ],
          'missingIngredients': <String>[],
          'preparationSteps': [
            {'stepNumber': 1, 'instruction': 'Whisk 2 eggs with 30ml milk, salt, and pepper in a bowl.', 'time': '1 min'},
            {'stepNumber': 2, 'instruction': 'Heat butter in a skillet over medium-low heat.', 'time': '1 min', 'temperature': 'medium-low'},
            {'stepNumber': 3, 'instruction': 'Pour eggs in and push gently from edges to center to form curds.', 'time': '2 mins'},
            {'stepNumber': 4, 'instruction': 'Toast bread slices until golden; serve scrambled eggs warm over toast.', 'time': '2 mins'}
          ],
          'cookingTips': ['Cook over gentle low heat for soft, creamy texture.'],
          'substitutions': ['Water or plant milk can replace dairy milk.'],
          'nutritionIsEstimate': true,
        },
        'inventoryItems': <Map<String, dynamic>>[],
      };
    }

    if (actionHint == 'meal_recommendation' || lowerMsg.contains('eat')) {
      return {
        'ok': true,
        'action': 'meal_recommendation',
        'assistantMessage': 'Here is a recommended meal based on your current fridge items:',
        'requiresConfirmation': true,
        'meal': {
          'name': 'Fresh Vegetable Stir Fry',
          'mealType': 'lunch',
          'description': 'A quick and nutritious stir fry using ingredients from your fridge.',
          'calories': 350,
          'proteinG': 15,
          'carbsG': 40,
          'fatG': 12,
          'preparationTimeMinutes': 10,
          'cookingTimeMinutes': 10,
          'servings': '1 serving',
          'ingredients': [
            {'name': 'Mixed Vegetables', 'quantity': 200, 'unit': 'g', 'deductionNeedsUserConfirmation': true}
          ],
          'missingIngredients': <String>[],
          'preparationSteps': [
            {'stepNumber': 1, 'instruction': 'Chop vegetables into bite-sized florets and slices.', 'time': '5 mins'},
            {'stepNumber': 2, 'instruction': 'Heat 1 tbsp oil in a wok over high heat.', 'time': '2 mins', 'temperature': 'high'},
            {'stepNumber': 3, 'instruction': 'Stir-fry vegetables rapidly until crisp-tender.', 'time': '3 mins'}
          ],
          'cookingTips': ['Keep heat high for crisp vegetables.'],
          'nutritionIsEstimate': true,
        },
        'inventoryItems': <Map<String, dynamic>>[],
      };
    }

    return {
      'ok': true,
      'action': 'assistant_reply',
      'assistantMessage': 'I can help manage your fridge and suggest healthy recipes. What would you like to do?',
      'requiresConfirmation': false,
      'needsClarification': false,
      'inventoryItems': <Map<String, dynamic>>[],
    };
  }

  /// Normalizes variations of response structures (direct JSON, wrapped in body/data/output, or string-encoded)
  static Map<String, dynamic> _normalizeResponse(dynamic decoded) {
    if (decoded is List) {
      if (decoded.isNotEmpty && decoded.first is Map) {
        return _normalizeResponse(decoded.first);
      }
      return {
        'ok': true,
        'action': 'assistant_reply',
        'assistantMessage': 'Received empty response from assistant.',
      };
    }

    if (decoded is String) {
      final trimmed = decoded.trim();
      if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
          (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
        try {
          final inner = jsonDecode(trimmed);
          return _normalizeResponse(inner);
        } catch (_) {}
      }
      return {
        'ok': true,
        'action': 'assistant_reply',
        'assistantMessage': decoded,
      };
    }

    if (decoded is Map) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);

      // 1. Unwrap nested payload wrappers if present
      if (map.containsKey('responseBody') && map['responseBody'] is Map) {
        return _normalizeResponse(map['responseBody']);
      }
      if (map.containsKey('body') && map['body'] != null) {
        return _normalizeResponse(map['body']);
      }
      if (map.containsKey('data') && map['data'] != null && map['action'] == null) {
        return _normalizeResponse(map['data']);
      }
      if (map.containsKey('output') && map['action'] == null) {
        final out = map['output'];
        if (out is Map || out is List) {
          return _normalizeResponse(out);
        } else if (out is String) {
          final trimmedOut = out.trim();
          if ((trimmedOut.startsWith('{') && trimmedOut.endsWith('}')) ||
              (trimmedOut.startsWith('[') && trimmedOut.endsWith(']'))) {
            try {
              return _normalizeResponse(jsonDecode(trimmedOut));
            } catch (_) {}
          }
          return {
            ...map,
            'ok': true,
            'action': 'assistant_reply',
            'assistantMessage': out,
          };
        }
      }

      // 2. Normalize field names and aliases
      if (map['inventoryItems'] == null && map['items'] is List) {
        map['inventoryItems'] = map['items'];
      }
      if (map['inventoryItems'] == null && map['proposedAdditions'] is List) {
        map['inventoryItems'] = map['proposedAdditions'];
      }
      if (map['assistantMessage'] == null && map['message'] is String) {
        map['assistantMessage'] = map['message'];
      }
      if (map['assistantMessage'] == null && map['reply'] is String) {
        map['assistantMessage'] = map['reply'];
      }
      if (map['assistantMessage'] == null && map['text'] is String) {
        map['assistantMessage'] = map['text'];
      }

      // 3. Normalize action
      if (map['action'] == null) {
        map['action'] = 'assistant_reply';
      }

      // 4. Default ok and success status if not explicitly false
      if (map['action'] != 'error') {
        map.putIfAbsent('ok', () => true);
        map.putIfAbsent('success', () => true);
      } else {
        map.putIfAbsent('ok', () => false);
        map.putIfAbsent('success', () => false);
      }

      return map;
    }

    return {
      'ok': true,
      'action': 'assistant_reply',
      'assistantMessage': decoded?.toString() ?? '',
    };
  }

  /// Requests the AI to estimate nutrition for a given meal name using the AI backend.
  static Future<Map<String, dynamic>?> estimateMealNutrition({
    required String mealName,
    String? mealType,
    List<Map<String, dynamic>> ingredients = const [],
    String? imageBase64,
  }) async {
    final cleanMealName = mealName.trim();
    if (cleanMealName.isEmpty) return null;

    final prompt = 'Estimate nutrition for meal: "$cleanMealName"';
    try {
      final response = await sendRequest(
        message: prompt,
        actionHint: 'log_meal',
        imageBase64: imageBase64,
      );

      // 1. Check if response has meal object with nutrition
      if (response['meal'] != null && response['meal'] is Map) {
        final mealData = response['meal'] as Map;
        final nut = mealData['nutrition'];
        if (nut != null && nut is Map) {
          final cal = (nut['calories'] as num?)?.toInt();
          final prot = (nut['proteinG'] as num? ?? nut['protein'] as num?)?.toInt();
          final carbs = (nut['carbsG'] as num? ?? nut['carbs'] as num?)?.toInt();
          final fat = (nut['fatG'] as num? ?? nut['fat'] as num?)?.toInt();

          if (cal != null && prot != null && carbs != null && fat != null) {
            return {
              'calories': cal,
              'proteinG': prot,
              'carbsG': carbs,
              'fatG': fat,
              'isEstimate': true,
              'isManual': false,
              'estimateNote': nut['estimateNote'] as String? ?? 'Approximate nutrition • Actual values may vary',
            };
          }
        }
      }

      // 2. Check if response has top-level nutrition map
      if (response['nutrition'] != null && response['nutrition'] is Map) {
        final nut = response['nutrition'] as Map;
        final cal = (nut['calories'] as num?)?.toInt();
        final prot = (nut['proteinG'] as num? ?? nut['protein'] as num?)?.toInt();
        final carbs = (nut['carbsG'] as num? ?? nut['carbs'] as num?)?.toInt();
        final fat = (nut['fatG'] as num? ?? nut['fat'] as num?)?.toInt();

        if (cal != null && prot != null && carbs != null && fat != null) {
          return {
            'calories': cal,
            'proteinG': prot,
            'carbsG': carbs,
            'fatG': fat,
            'isEstimate': true,
            'isManual': false,
            'estimateNote': nut['estimateNote'] as String? ?? 'Approximate nutrition • Actual values may vary',
          };
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error estimating meal nutrition: $e');
      return null;
    }
  }
}
