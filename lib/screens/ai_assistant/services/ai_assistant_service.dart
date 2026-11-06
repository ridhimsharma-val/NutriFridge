import 'dart:async';
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

  /// Current pending quick-action intent (e.g. 'log_meal', 'add_groceries', 'recipe_ideas')
  static String? activeQuickActionIntent;

  /// Resets the conversation session back to the clean introductory welcome message
  static void resetSession() {
    activeQuickActionIntent = null;
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
    Map<String, dynamic>? extraPayload,
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
      'message': message,
      'imageBase64': imageBase64,
      'mimeType': mimeType,
      'conversationHistory': conversationHistory,
      'inventoryContext': getInventoryContext(),
      'userPreferences': getProfilePreferences(),
      'todayNutrition': getNutritionContext(),
      'locale': 'en-IN',
      ...?extraPayload,
      'actionHint': actionHint,
    };

    if (mockHandler != null) {
      final mockResult = await mockHandler!(payload);
      return _normalizeResponse(mockResult);
    }

    final stopwatch = Stopwatch()..start();
    http.Response response;

    try {
      response = await http
          .post(
            Uri.parse(webhookUrl),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException catch (e) {
      stopwatch.stop();
      debugPrint('[AiAssistantService] Request timed out after ${stopwatch.elapsedMilliseconds}ms: $e');
      return {
        'success': false,
        'action': 'error',
        'assistantMessage':
            'NutriFridge AI took longer than expected to respond. Please tap retry.',
        'error': 'TimeoutException: Request exceeded 60s (${stopwatch.elapsedMilliseconds}ms)',
        'requiresConfirmation': false,
      };
    } on http.ClientException catch (e) {
      stopwatch.stop();
      debugPrint('[AiAssistantService] Client / CORS / Network error after ${stopwatch.elapsedMilliseconds}ms: $e');
      return {
        'success': false,
        'action': 'error',
        'assistantMessage':
            'Unable to connect to NutriFridge AI. Please check your internet connection and tap retry.',
        'error': 'ClientException: $e',
        'requiresConfirmation': false,
      };
    } catch (e) {
      stopwatch.stop();
      debugPrint('[AiAssistantService] Unexpected network error after ${stopwatch.elapsedMilliseconds}ms: $e');
      return {
        'success': false,
        'action': 'error',
        'assistantMessage':
            'Unable to reach NutriFridge AI. Please check your internet connection and tap retry.',
        'error': e.toString(),
        'requiresConfirmation': false,
      };
    }

    stopwatch.stop();
    debugPrint('[AiAssistantService] HTTP ${response.statusCode} in ${stopwatch.elapsedMilliseconds}ms');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        final Map<String, dynamic> data = _normalizeResponse(decoded);
        return data;
      } catch (e) {
        debugPrint('[AiAssistantService] Failed to parse n8n JSON response: $e\nRaw body: ${response.body}');
        return {
          'success': false,
          'action': 'error',
          'assistantMessage':
              'Received an invalid response format from NutriFridge AI. Please tap retry.',
          'error': 'JSON parse error: $e',
          'requiresConfirmation': false,
        };
      }
    } else if (response.statusCode >= 500) {
      debugPrint('[AiAssistantService] n8n server error ${response.statusCode}: ${response.body}');
      return {
        'success': false,
        'action': 'error',
        'assistantMessage':
            'NutriFridge AI is temporarily experiencing high load (Status ${response.statusCode}). Please tap retry in a moment.',
        'error': 'Remote server returned status ${response.statusCode}',
        'requiresConfirmation': false,
      };
    } else {
      debugPrint('[AiAssistantService] n8n client error ${response.statusCode}: ${response.body}');
      return {
        'success': false,
        'action': 'error',
        'assistantMessage':
            'NutriFridge AI request could not be completed (Status ${response.statusCode}). Please tap retry.',
        'error': 'Remote server returned status ${response.statusCode}',
        'requiresConfirmation': false,
      };
    }
  }

  /// Normalizes variations of n8n response structures (direct JSON, wrapped in body/data/output, or string-encoded)
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

      return map;
    }

    return {
      'ok': true,
      'action': 'assistant_reply',
      'assistantMessage': decoded?.toString() ?? '',
    };
  }

  /// Requests the AI to estimate nutrition for a given meal name using the existing AI backend.
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
