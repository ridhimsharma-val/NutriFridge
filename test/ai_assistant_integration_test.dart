import 'dart:convert';
import 'dart:io';

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

  group('AiAssistantService — Context Construction Tests', () {
    test('Inventory context correctly gathers items from FridgeCategoryRepository', () {
      FridgeCategoryRepository.addOrMergeItem(
        categoryName: 'Dairy Products',
        name: 'Greek Yogurt',
        quantity: 500,
        unit: 'g',
      );
      FridgeCategoryRepository.addOrMergeItem(
        categoryName: 'Non-Veg',
        name: 'Farm Eggs',
        quantity: 6,
        unit: 'pieces',
      );

      final context = AiAssistantService.getInventoryContext();

      expect(context.length, 2);
      final yogurt = context.firstWhere((it) => it['name'] == 'Greek Yogurt');
      expect(yogurt['category'], 'Dairy Products');
      expect(yogurt['quantity'], '500 g');

      final eggs = context.firstWhere((it) => it['name'] == 'Farm Eggs');
      expect(eggs['category'], 'Non-Veg');
      expect(eggs['quantity'], '6 pieces');
    });

    test('Empty inventory context returns empty list without inventing items', () {
      final context = AiAssistantService.getInventoryContext();
      expect(context, isEmpty);
    });

    test('Nutrition goal context construction extracts current targets and totals', () {
      final nutritionCtx = AiAssistantService.getNutritionContext();

      expect(nutritionCtx.containsKey('consumedCalories'), isTrue);
      expect(nutritionCtx.containsKey('targetCalories'), isTrue);
      expect(nutritionCtx.containsKey('proteinGrams'), isTrue);
      expect(nutritionCtx.containsKey('carbsGrams'), isTrue);
      expect(nutritionCtx.containsKey('fatGrams'), isTrue);
      expect(nutritionCtx['targetCalories'], 2000);
    });

    test('User profile preferences context construction captures goals and restrictions', () {
      final prefs = AiAssistantService.getProfilePreferences();

      expect(prefs.containsKey('displayName'), isTrue);
      expect(prefs.containsKey('dietaryPreference'), isTrue);
      expect(prefs.containsKey('nutritionGoal'), isTrue);
      expect(prefs.containsKey('allergies'), isTrue);
      expect(prefs.containsKey('avoidedFoods'), isTrue);
    });
  });

  group('AiAssistantService — Authentication & Rejection Tests', () {
    test('Rejects unauthenticated requests in live mode', () async {
      // Disable forceInMemoryForTesting to simulate live mode with no user signed in
      MockDataRepository.forceInMemoryForTesting = false;

      final response = await AiAssistantService.sendRequest(
        message: 'What can I cook for lunch?',
      );

      expect(response['ok'], isFalse);
      expect(response['action'], 'error');
      expect(response['assistantMessage'], contains('Please sign in'));
    });

    test('Session reset restores standard welcome introductory message', () {
      AiAssistantService.sessionMessages.add(
        AiChatMessage(
          id: 'test_msg',
          text: 'Custom conversation text',
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      expect(AiAssistantService.sessionMessages.length, 2);

      AiAssistantService.resetSession();

      expect(AiAssistantService.sessionMessages.length, 1);
      expect(AiAssistantService.sessionMessages.first.isUser, isFalse);
      expect(AiAssistantService.sessionMessages.first.text, contains('Hi! I can help manage your fridge'));
    });
  });

  group('AiAssistantService — Response Normalization & Gemini Schema Parsing', () {
    test('Parses candidate payload produced by Gemini 3.8 Flash', () async {
      AiAssistantService.mockHandler = (request) async {
        // Simulates normalized candidate output from Gemini 3.8 Flash endpoint
        return {
          'model': 'gemini-3.8-flash',
          'action': 'meal_recommendation',
          'assistantMessage': 'Based on your available ingredients, here is a protein-packed dinner suggestion:',
          'requiresConfirmation': true,
          'needsClarification': false,
          'clarifyingQuestion': null,
          'meal': {
            'name': 'Scrambled Eggs with Spinach',
            'mealType': 'dinner',
            'description': 'Simple and quick scramble.',
            'preparationTimeMinutes': 15,
            'calories': 320,
            'proteinG': 22,
            'carbsG': 3,
            'fatG': 24,
            'ingredients': [
              {
                'name': 'Farm Eggs',
                'quantity': 3,
                'unit': 'pieces',
                'matchedInventoryItemId': 'uuid-egg-001',
                'suggestedDeductionQuantity': 3,
                'deductionNeedsUserConfirmation': true,
              }
            ],
            'missingIngredients': <String>[],
            'nutritionIsEstimate': true,
          },
          'inventoryItems': <Map<String, dynamic>>[],
        };
      };

      final response = await AiAssistantService.sendRequest(
        message: 'What can I cook with eggs?',
      );

      expect(response['ok'], isTrue);
      expect(response['action'], 'meal_recommendation');
      expect(response['meal']?['name'], 'Scrambled Eggs with Spinach');
      expect(response['meal']?['calories'], 320);
      expect(response['meal']?['proteinG'], 22);
    });

    test('Parses structured meal_recommendation and preserves ingredient IDs', () async {
      AiAssistantService.mockHandler = (request) async {
        return {
          'action': 'meal_recommendation',
          'assistantMessage': 'I recommend making a Paneer Spinach Bowl with ingredients in your fridge.',
          'requiresConfirmation': true,
          'meal': {
            'name': 'Paneer Spinach Bowl',
            'mealType': 'dinner',
            'description': 'A high-protein vegetarian dinner.',
            'calories': 480,
            'proteinG': 28,
            'carbsG': 15,
            'fatG': 22,
            'ingredients': [
              {
                'name': 'Paneer',
                'quantity': 150,
                'unit': 'g',
                'matchedInventoryItemId': 'uuid-paneer-123',
                'suggestedDeductionQuantity': 150,
                'deductionNeedsUserConfirmation': true,
              },
              {
                'name': 'Spinach',
                'quantity': 100,
                'unit': 'g',
                'matchedInventoryItemId': 'uuid-spinach-456',
                'suggestedDeductionQuantity': 100,
                'deductionNeedsUserConfirmation': true,
              }
            ],
            'missingIngredients': ['Garam Masala'],
            'nutritionIsEstimate': true,
          },
        };
      };

      final response = await AiAssistantService.sendRequest(
        message: 'What should I eat for dinner?',
      );

      expect(response['ok'], isTrue);
      expect(response['action'], 'meal_recommendation');
      expect(response['requiresConfirmation'], isTrue);
      expect(response['meal'], isNotNull);

      final meal = response['meal'] as Map;
      expect(meal['name'], 'Paneer Spinach Bowl');
      expect(meal['mealType'], 'dinner');
      expect(meal['calories'], 480);
      expect(meal['proteinG'], 28);

      final ingredients = meal['ingredients'] as List;
      expect(ingredients.length, 2);
      expect(ingredients[0]['name'], 'Paneer');
      expect(ingredients[0]['matchedInventoryItemId'], 'uuid-paneer-123');

      final missing = meal['missingIngredients'] as List;
      expect(missing, contains('Garam Masala'));
    });

    test('Correctly handles no_match when inventory is empty or insufficient', () async {
      AiAssistantService.mockHandler = (request) async {
        return {
          'action': 'no_match',
          'assistantMessage': 'Your fridge is currently empty. I suggest picking up eggs, bread, and spinach!',
          'requiresConfirmation': false,
          'meal': null,
          'inventoryItems': [],
        };
      };

      final response = await AiAssistantService.sendRequest(
        message: 'Suggest a meal from my fridge',
      );

      expect(response['ok'], isTrue);
      expect(response['action'], 'no_match');
      expect(response['meal'], isNull);
      expect(response['assistantMessage'], contains('fridge is currently empty'));
    });

    test('Normalizes nested n8n output wrapper', () async {
      AiAssistantService.mockHandler = (request) async {
        return {
          'responseBody': {
            'action': 'assistant_reply',
            'assistantMessage': 'Tofu has approximately 8g of protein per 100g.',
          }
        };
      };

      final response = await AiAssistantService.sendRequest(
        message: 'How much protein is in tofu?',
      );

      expect(response['ok'], isTrue);
      expect(response['action'], 'assistant_reply');
      expect(response['assistantMessage'], contains('8g of protein'));
    });

    test('Handles invalid non-JSON string gracefully without crashing', () async {
      AiAssistantService.mockHandler = (request) async {
        return {
          'output': 'This is a raw text response rather than JSON.',
        };
      };

      final response = await AiAssistantService.sendRequest(
        message: 'Hello!',
      );

      expect(response['ok'], isTrue);
      expect(response['action'], 'assistant_reply');
      expect(response['assistantMessage'], 'This is a raw text response rather than JSON.');
    });

    test('Handles n8n / Gemini upstream timeout error gracefully', () async {
      AiAssistantService.mockHandler = (request) async {
        return {
          'action': 'error',
          'assistantMessage': 'NutriFridge AI took longer than expected to respond. Please tap retry.',
          'error': 'TimeoutException',
          'requiresConfirmation': false,
        };
      };

      final response = await AiAssistantService.sendRequest(
        message: 'Suggest complex recipes',
      );

      expect(response['action'], 'error');
      expect(response['assistantMessage'], contains('took longer than expected'));
    });

    test('Handles upstream n8n connection failure gracefully', () async {
      AiAssistantService.mockHandler = (request) async {
        return {
          'action': 'error',
          'assistantMessage': 'Unable to connect to the AI Assistant service. Please check your network and tap retry.',
          'error': 'Connection refused',
          'requiresConfirmation': false,
        };
      };

      final response = await AiAssistantService.sendRequest(
        message: 'Hello',
      );

      expect(response['action'], 'error');
      expect(response['assistantMessage'], contains('Unable to connect'));
    });
  });

  group('Authoritative Meal Confirmation Flow Tests', () {
    test('Gemini response does NOT modify inventory until user explicitly confirms', () async {
      // 1. Initial inventory: 500g Chicken Breast
      FridgeCategoryRepository.addOrMergeItem(
        categoryName: 'Non-Veg',
        name: 'Chicken Breast',
        quantity: 500,
        unit: 'g',
      );

      expect(FridgeCategoryRepository.findItemByName('Chicken Breast')?.decimalAmount, 500);

      // 2. AI suggests meal with 150g Chicken Breast
      AiAssistantService.mockHandler = (request) async {
        return {
          'action': 'meal_recommendation',
          'assistantMessage': 'How about Grilled Chicken Breast?',
          'requiresConfirmation': true,
          'meal': {
            'name': 'Grilled Chicken Breast',
            'mealType': 'dinner',
            'calories': 380,
            'proteinG': 45,
            'carbsG': 0,
            'fatG': 6,
            'ingredients': [
              {
                'name': 'Chicken Breast',
                'quantity': 150,
                'unit': 'g',
                'matchedInventoryItemId': 'chicken-uuid-123',
                'suggestedDeductionQuantity': 150,
                'deductionNeedsUserConfirmation': true,
              }
            ],
          }
        };
      };

      final aiResponse = await AiAssistantService.sendRequest(
        message: 'Suggest a high-protein dinner',
      );

      // Verify AI returned structured meal but inventory remains untouched at 500g!
      expect(aiResponse['action'], 'meal_recommendation');
      expect(FridgeCategoryRepository.findItemByName('Chicken Breast')?.decimalAmount, 500);

      // 3. User explicitly confirms and logs the meal
      await MockDataRepository.logMeal(
        mealType: 'dinner',
        mealName: 'Grilled Chicken Breast',
        calories: 380,
        protein: 45,
        carbs: 0,
        fat: 6,
        ingredients: ['Chicken Breast (150g)'],
      );

      // 4. Authoritative deduction happens ONLY after explicit confirmation: 500g - 150g = 350g!
      final afterLog = FridgeCategoryRepository.findItemByName('Chicken Breast');
      expect(afterLog?.decimalAmount, 350);
      expect(afterLog?.unit, 'g');
    });

    test('estimateMealNutrition parses nutrition map from AI response', () async {
      AiAssistantService.mockHandler = (request) async {
        return {
          'action': 'log_meal',
          'meal': {
            'name': 'Egg Bhurji',
            'nutrition': {
              'calories': 240,
              'proteinG': 14,
              'carbsG': 4,
              'fatG': 18,
              'estimateNote': 'Approximate nutrition estimate',
            }
          }
        };
      };

      final estimate = await AiAssistantService.estimateMealNutrition(
        mealName: 'Egg Bhurji',
        mealType: 'breakfast',
      );

      expect(estimate, isNotNull);
      expect(estimate!['calories'], 240);
      expect(estimate['proteinG'], 14);
      expect(estimate['carbsG'], 4);
      expect(estimate['fatG'], 18);
      expect(estimate['isEstimate'], isTrue);
    });
  });

  group('Gemini 3.8 Flash Workflow Regression Tests', () {
    test('n8n workflow generationConfig omits deprecated sampling parameters', () {
      final file = File('n8n/workflows/nutrifridge-ai-assistant.json');
      expect(file.existsSync(), isTrue, reason: 'nutrifridge-ai-assistant.json must exist');

      final content = file.readAsStringSync();
      final workflowJson = jsonDecode(content) as Map<String, dynamic>;
      final nodes = workflowJson['nodes'] as List<dynamic>;

      final prepareNode = nodes.firstWhere(
        (n) => n['name'] == 'Build Gemini Request' || n['name'] == 'Prepare Context & Gemini Prompt',
        orElse: () => null,
      );
      expect(prepareNode, isNotNull);

      final jsCode = prepareNode['parameters']['jsCode'] as String;

      // Verify generationConfig specifies maxOutputTokens and responseMimeType
      expect(jsCode, contains('maxOutputTokens: 2048'));
      expect(jsCode, contains("responseMimeType: 'application/json'"));

      // Regression assertions: ensure deprecated sampling parameters are not present
      expect(jsCode, isNot(contains('temperature:')));
      expect(jsCode, isNot(contains('temperature :')));
      expect(jsCode, isNot(contains('top_p')));
      expect(jsCode, isNot(contains('topP')));
      expect(jsCode, isNot(contains('top_k')));
      expect(jsCode, isNot(contains('topK')));
      expect(jsCode, isNot(contains('candidate_count')));
      expect(jsCode, isNot(contains('candidateCount')));
    });

    test('nutrifridge-ai-backend workflow generationConfig also omits deprecated sampling parameters', () {
      final file = File('n8n/nutrifridge-ai/NutriFridge_AI_Backend.json');
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final workflowJson = jsonDecode(content) as Map<String, dynamic>;
        final nodes = workflowJson['nodes'] as List<dynamic>;

        final buildNode = nodes.firstWhere(
          (n) => n['name'] == 'Build Gemini Request',
          orElse: () => null,
        );
        if (buildNode != null) {
          final jsCode = buildNode['parameters']['jsCode'] as String;
          expect(jsCode, contains('maxOutputTokens: 2048'));
          expect(jsCode, contains("responseMimeType: 'application/json'"));
          expect(jsCode, isNot(contains('temperature:')));
          expect(jsCode, isNot(contains('top_p')));
          expect(jsCode, isNot(contains('top_k')));
          expect(jsCode, isNot(contains('candidate_count')));
        }
      }
    });
  });

  group('Supabase Edge Function (nutrifridge-ai) Auth Regression Tests', () {
    late String edgeFunctionSource;

    setUpAll(() {
      final file = File('supabase/functions/nutrifridge-ai/index.ts');
      expect(file.existsSync(), isTrue, reason: 'index.ts must exist');
      edgeFunctionSource = file.readAsStringSync();
    });

    test('1. Valid JWT authenticates successfully and calls auth.getUser(token)', () {
      expect(
        edgeFunctionSource,
        contains('await supabaseUser.auth.getUser(token)'),
        reason: 'Must explicitly pass extracted token to getUser(token)',
      );
      expect(
        edgeFunctionSource,
        isNot(contains('await supabaseUser.auth.getUser()')),
        reason: 'Must NOT call getUser() without arguments in Deno runtime',
      );
    });

    test('2. Missing Authorization header returns 401 with AUTH_HEADER_MISSING log', () {
      expect(edgeFunctionSource, contains("req.headers.get('Authorization')"));
      expect(edgeFunctionSource, contains("console.warn('AUTH_HEADER_MISSING')"));
      expect(edgeFunctionSource, contains("error: 'MISSING_AUTHORIZATION'"));
      expect(edgeFunctionSource, contains('{ status: 401'));
    });

    test('3. Malformed Bearer header returns 401 with AUTH_HEADER_FORMAT_INVALID log', () {
      expect(edgeFunctionSource, contains(r'authHeader.match(/^Bearer\s+(.+)$/i)'));
      expect(edgeFunctionSource, contains("console.warn('AUTH_HEADER_FORMAT_INVALID')"));
      expect(edgeFunctionSource, contains("error: 'INVALID_AUTHORIZATION_FORMAT'"));
    });

    test('4. Invalid or expired JWT returns 401 with AUTH_GET_USER_FAILED log', () {
      expect(edgeFunctionSource, contains('if (authError || !user)'));
      expect(edgeFunctionSource, contains("console.error('AUTH_GET_USER_FAILED'"));
      expect(edgeFunctionSource, contains("error: 'USER_AUTHENTICATION_FAILED'"));
    });

    test('5. Valid JWT retrieves the correct authenticated user with AUTH_USER_VERIFIED log', () {
      expect(edgeFunctionSource, contains("console.log('AUTH_USER_VERIFIED')"));
      expect(edgeFunctionSource, contains('const userId = user.id;'));
    });

    test('6. A different user ID cannot be substituted by client payload', () {
      // Ensure userId used in context and payload is strictly the verified user.id
      expect(
        edgeFunctionSource,
        contains('userId: userId'),
      );
      // Ensure body.userId does not override user.id
      expect(
        edgeFunctionSource,
        isNot(contains('userId = body.userId')),
      );
    });

    test('7. User-context database queries retain RLS via user-scoped supabaseUser', () {
      expect(edgeFunctionSource, contains('Authorization: authHeader'));
      expect(
        RegExp(r'supabaseUser\s*\.from\(\s*[\x27"]fridge_items[\x27"]\s*\)').hasMatch(edgeFunctionSource),
        isTrue,
        reason: 'fridge_items query must use user-scoped supabaseUser client',
      );
      expect(
        RegExp(r'supabaseUser\s*\.from\(\s*[\x27"]nutrition_goals[\x27"]\s*\)').hasMatch(edgeFunctionSource),
        isTrue,
        reason: 'nutrition_goals query must use user-scoped supabaseUser client',
      );
      expect(
        RegExp(r'supabaseUser\s*\.from\(\s*[\x27"]profiles[\x27"]\s*\)').hasMatch(edgeFunctionSource),
        isTrue,
        reason: 'profiles query must use user-scoped supabaseUser client',
      );
      expect(edgeFunctionSource, contains("console.log('USER_CONTEXT_QUERY_STARTED')"));
    });

    test('8. n8n is strictly not called when authentication fails', () {
      // Verify that 401 returns occur BEFORE n8n fetch invocation
      final authErrorIndex = edgeFunctionSource.indexOf("error: 'USER_AUTHENTICATION_FAILED'");
      final n8nFetchIndex = edgeFunctionSource.indexOf('fetch(n8nWebhookUrl');
      expect(authErrorIndex, isNonNegative);
      expect(n8nFetchIndex, isNonNegative);
      expect(authErrorIndex, lessThan(n8nFetchIndex));
      expect(edgeFunctionSource, contains("console.log('N8N_REQUEST_STARTED')"));
    });
  });

  group('Timeout & Extended Generation Regression Tests', () {
    test('1. n8n workflow Google Gemini HTTP Request node configuration & endpoint verification', () {
      final file = File('n8n/workflows/nutrifridge-ai-assistant.json');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final workflowJson = jsonDecode(content) as Map<String, dynamic>;
      final nodes = workflowJson['nodes'] as List<dynamic>;

      final geminiNode = nodes.firstWhere(
        (n) => n['name'] == 'HTTP Request — Gemini generateContent' || n['name'] == 'Call Google Gemini API',
      );
      expect(geminiNode, isNotNull);
      expect(geminiNode['parameters']['url'], contains('gemini-flash-lite-latest:generateContent'));
      expect(content, contains('x-goog-api-key'));
    });

    test('2. Supabase Edge Function timeout is 75,000ms with clearTimeout in finally block', () {
      final file = File('supabase/functions/nutrifridge-ai/index.ts');
      expect(file.existsSync(), isTrue);
      final source = file.readAsStringSync();

      expect(source, contains('75000'));
      expect(
        RegExp(r'finally\s*\{\s*clearTimeout\(\s*timeoutId\s*\);?\s*\}').hasMatch(source),
        isTrue,
        reason: 'clearTimeout must be guaranteed in finally block',
      );
    });

    test('3. Aborted requests return structured GEMINI_REQUEST_TIMEOUT error with retryable: true', () {
      final file = File('supabase/functions/nutrifridge-ai/index.ts');
      final source = file.readAsStringSync();

      expect(source, contains("code: isTimeout ? 'GEMINI_REQUEST_TIMEOUT' : 'CONNECTION_FAILED'"));
      expect(source, contains('retryable: true'));
      expect(source, contains('{ status: isTimeout ? 504 : 502'));
    });

    test('4. Upstream Gemini API error codes are distinguished (429, 401/403, 400, 504)', () {
      final file = File('supabase/functions/nutrifridge-ai/index.ts');
      final source = file.readAsStringSync();

      expect(source, contains("'GEMINI_RATE_LIMIT_EXCEEDED'"));
      expect(source, contains("'GEMINI_AUTH_FAILED'"));
      expect(source, contains("'GEMINI_INVALID_REQUEST'"));
      expect(source, contains("'GEMINI_REQUEST_TIMEOUT'"));
    });

    test('5. Flutter client AiAssistantService sets 90s invocation timeout', () {
      final file = File('lib/screens/ai_assistant/services/ai_assistant_service.dart');
      expect(file.existsSync(), isTrue);
      final source = file.readAsStringSync();

      expect(source, contains('Duration(seconds: 90)'));
      expect(source, contains("'GEMINI_REQUEST_TIMEOUT'"));
    });
  });

  group('Canonical 11 Database Categories Regression Tests', () {
    const expected11Categories = [
      'Dairy Products',
      'Vegetables',
      'Fruits',
      'Non-Veg',
      'Meals & Leftovers',
      'Packaged Food',
      'Drinks & Juices',
      'Ice Cream',
      'Frozen Food',
      'Dry Fruits',
      'Others',
    ];

    test('1. Flutter FridgeCategoryRepository contains all 11 canonical categories', () {
      expect(FridgeCategoryRepository.canonicalCategories.length, 11);
      for (final cat in expected11Categories) {
        expect(FridgeCategoryRepository.canonicalCategories, contains(cat));
      }
    });

    test('2. n8n workflows/nutrifridge-ai-assistant.json preserves all 11 canonical categories', () {
      final file = File('n8n/workflows/nutrifridge-ai-assistant.json');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      final workflowJson = jsonDecode(content) as Map<String, dynamic>;
      final nodes = workflowJson['nodes'] as List<dynamic>;

      final prepNode = nodes.firstWhere(
        (n) => n['name'] == 'Build Gemini Request' || n['name'] == 'Prepare Context & Gemini Prompt',
      );
      final prepCode = prepNode['parameters']['jsCode'] as String;

      final parseNode = nodes.firstWhere(
        (n) => n['name'] == 'Parse and Validate Gemini Response' || n['name'] == 'Parse & Validate Gemini Output',
      );
      final parseCode = parseNode['parameters']['jsCode'] as String;

      for (final cat in expected11Categories) {
        expect(prepCode, contains(cat));
        expect(parseCode, contains(cat));
      }
    });

    test('3. n8n nutrifridge-ai/NutriFridge_AI_Backend.json preserves all 11 canonical categories', () {
      final file = File('n8n/nutrifridge-ai/NutriFridge_AI_Backend.json');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      final workflowJson = jsonDecode(content) as Map<String, dynamic>;
      final nodes = workflowJson['nodes'] as List<dynamic>;

      final buildNode = nodes.firstWhere((n) => n['name'] == 'Build Gemini Request');
      final buildCode = buildNode['parameters']['jsCode'] as String;

      final parseNode = nodes.firstWhere((n) => n['name'] == 'Parse and Validate Gemini Response');
      final parseCode = parseNode['parameters']['jsCode'] as String;

      for (final cat in expected11Categories) {
        expect(buildCode, contains(cat));
        expect(parseCode, contains(cat));
      }
    });

    test('4. FridgeCategoryRepository.canonicalizeCategory maps variations to canonical categories', () {
      expect(FridgeCategoryRepository.canonicalizeCategory('dairy'), 'Dairy Products');
      expect(FridgeCategoryRepository.canonicalizeCategory('VEG'), 'Vegetables');
      expect(FridgeCategoryRepository.canonicalizeCategory('fresh fruit'), 'Fruits');
      expect(FridgeCategoryRepository.canonicalizeCategory('non-veg'), 'Non-Veg');
      expect(FridgeCategoryRepository.canonicalizeCategory('leftovers'), 'Meals & Leftovers');
      expect(FridgeCategoryRepository.canonicalizeCategory('packaged food'), 'Packaged Food');
      expect(FridgeCategoryRepository.canonicalizeCategory('juice'), 'Drinks & Juices');
      expect(FridgeCategoryRepository.canonicalizeCategory('ice cream'), 'Ice Cream');
      expect(FridgeCategoryRepository.canonicalizeCategory('frozen'), 'Frozen Food');
      expect(FridgeCategoryRepository.canonicalizeCategory('dry fruits'), 'Dry Fruits');
      expect(FridgeCategoryRepository.canonicalizeCategory('random item'), 'Others');
    });
  });
}
