import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/screens/ai_assistant/ai_assistant_screen.dart';
import 'package:nutrifridge/screens/ai_assistant/services/ai_assistant_service.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/screens/meal_detail/meal_detail_screen.dart';
import 'package:nutrifridge/screens/meal_detail/models/meal_ai_context.dart';
import 'package:nutrifridge/screens/meal_detail/models/meal_detail_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FridgeCategoryRepository.seedSampleDataForTesting();
    MockDataRepository.seedSampleDataForTesting();
    AiAssistantService.mockHandler = null;
    AiAssistantService.resetSession();
  });

  group('RECIPE DETAILS — Model Parsing & Presentation', () {
    test('Complete recipe instructions and metadata are parsed from backend JSON', () {
      final json = {
        'id': 'rec_eggs_toast_123',
        'name': 'Scrambled Eggs on Toast with Milk',
        'mealType': 'breakfast',
        'calories': 340,
        'proteinG': 19,
        'carbsG': 26,
        'fatG': 15,
        'preparationTimeMinutes': 5,
        'cookingTimeMinutes': 5,
        'servingSize': '1 serving',
        'nutritionIsEstimate': true,
        'ingredients': [
          {'name': 'Eggs', 'quantity': 2, 'unit': 'pieces', 'availableInFridge': true},
          {'name': 'Bread', 'quantity': 2, 'unit': 'slices', 'availableInFridge': true},
          {'name': 'Milk', 'quantity': 30, 'unit': 'ml', 'availableInFridge': true},
          {'name': 'Butter', 'quantity': 1, 'unit': 'tsp', 'availableInFridge': false},
        ],
        'missingIngredients': ['Butter'],
        'preparationSteps': [
          {
            'stepNumber': 1,
            'instruction': 'Crack 2 eggs into a bowl, add 30ml milk, salt and black pepper.',
            'time': '1 min',
          },
          {
            'stepNumber': 2,
            'instruction': 'Melt butter in a non-stick skillet over medium-low heat.',
            'time': '1 min',
            'temperature': 'medium-low',
          },
          {
            'stepNumber': 3,
            'instruction': 'Pour eggs in and gently fold until soft curds form.',
            'time': '2 mins',
            'tip': 'Remove while still slightly glossy.',
          },
          {
            'stepNumber': 4,
            'instruction': 'Toast bread slices until golden brown and top with scrambled eggs.',
            'time': '2 mins',
          },
        ],
        'cookingTips': ['Cook on low heat to keep scrambled eggs creamy.'],
        'substitutions': ['Olive oil can substitute butter for cooking.'],
        'videoSearchQuery': 'Scrambled Eggs on Toast recipe tutorial',
      };

      final rec = RecipeRecommendation.fromJson(json);

      expect(rec.title, 'Scrambled Eggs on Toast with Milk');
      expect(rec.calories, 340);
      expect(rec.proteinGrams, 19);
      expect(rec.carbsGrams, 26);
      expect(rec.fatGrams, 15);
      expect(rec.prepTimeMinutes, 5);
      expect(rec.cookingTimeMinutes, 5);
      expect(rec.servingSize, '1 serving');
      expect(rec.missingIngredients, contains('Butter'));
      expect(rec.preparationSteps.length, 4);
      expect(rec.preparationSteps[0].instruction, contains('Crack 2 eggs into a bowl'));
      expect(rec.preparationSteps[1].temperature, 'medium-low');
      expect(rec.preparationSteps[2].tip, 'Remove while still slightly glossy.');
      expect(rec.cookingTips, contains('Cook on low heat to keep scrambled eggs creamy.'));
      expect(rec.substitutions, contains('Olive oil can substitute butter for cooking.'));
      expect(rec.videoSearchQuery, 'Scrambled Eggs on Toast recipe tutorial');
    });

    test('Missing ingredients are identified correctly based on real fridge inventory', () {
      // In sample data, Eggs and Milk exist in fridge, Butter does not
      final rec = RecipeRecommendation(
        id: 'rec_test',
        title: 'Custom Dish',
        calories: 300,
        proteinGrams: 15,
        fridgeItemsUsed: 2,
        imageUrl: 'assets/images/paneer_rice_bowl.jpg',
        requiredIngredients: const ['Milk (250 ml)', 'Dragon Fruit (1 piece)'],
        missingIngredients: const ['Dragon Fruit'],
      );

      final mealInfo = MealDetailInfo.fromRecommendation(rec);

      final milk = mealInfo.ingredients.firstWhere((i) => i.name.toLowerCase() == 'milk');
      expect(milk.availability, IngredientAvailability.available);

      final dragonFruit = mealInfo.ingredients.firstWhere((i) => i.name.toLowerCase().contains('dragon'));
      expect(dragonFruit.availability, IngredientAvailability.missing);
      expect(dragonFruit.statusLabel, 'Not in fridge');
    });

    testWidgets('MealDetailScreen renders preparation steps, times, temperatures, and tips', (WidgetTester tester) async {
      const rec = RecipeRecommendation(
        id: 'rec_eggs_test',
        title: 'Scrambled Eggs on Toast with Milk',
        calories: 340,
        proteinGrams: 19,
        carbsGrams: 26,
        fatGrams: 15,
        prepTimeMinutes: 5,
        cookingTimeMinutes: 5,
        fridgeItemsUsed: 3,
        imageUrl: 'assets/images/paneer_rice_bowl.jpg',
        preparationSteps: [
          RecipePreparationStep(
            stepNumber: 1,
            instruction: 'Whisk eggs with milk and salt.',
            time: '1 min',
          ),
          RecipePreparationStep(
            stepNumber: 2,
            instruction: 'Cook eggs gently in a skillet over low heat.',
            time: '2 mins',
            temperature: 'low heat',
            tip: 'Keep heat low to avoid rubbery eggs.',
          ),
        ],
        cookingTips: ['Serve immediately while warm.'],
        substitutions: ['Use olive oil instead of butter.'],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: MealDetailScreen(recommendation: rec),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Preparation'), findsOneWidget);
      expect(find.text('2 steps'), findsOneWidget);
      expect(find.text('Whisk eggs with milk and salt.'), findsOneWidget);
      expect(find.text('⏱ 1 min'), findsOneWidget);
      expect(find.text('🔥 low heat'), findsOneWidget);
      expect(find.text('Tip: Keep heat low to avoid rubbery eggs.'), findsOneWidget);
    });

    testWidgets('Missing preparation instructions display interactive AI generation card', (WidgetTester tester) async {
      const emptyStepsRec = RecipeRecommendation(
        id: 'rec_unknown',
        title: 'Uncataloged Custom Soup',
        calories: 200,
        proteinGrams: 10,
        fridgeItemsUsed: 2,
        imageUrl: 'assets/images/paneer_rice_bowl.jpg',
        preparationSteps: [],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: MealDetailScreen(recommendation: emptyStepsRec),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Step-by-step instructions available via AI'), findsOneWidget);
      expect(find.text('Tap "Cook with AI" to generate full preparation steps, timings, and heat levels tailored to your fridge.'), findsOneWidget);
      expect(find.text("Preparation instructions aren't available for this recipe yet."), findsNothing);
      expect(find.text('Generate Steps'), findsOneWidget);
      expect(find.text('Cook with AI'), findsWidgets);
    });

    testWidgets('Tapping Generate Steps generates and populates preparation steps in-place', (WidgetTester tester) async {
      AiAssistantService.mockHandler = (payload) async {
        return {
          'ok': true,
          'action': 'assistant_reply',
          'assistantMessage': '''Here are your cooking steps:
1. Wash and chop vegetables into 1-inch pieces (3 mins).
2. Heat 1 tbsp oil in a pot over medium heat and sauté for 5 minutes.
3. Add broth and simmer for 10 minutes until tender.''',
        };
      };

      const emptyStepsRec = RecipeRecommendation(
        id: 'rec_unknown_soup',
        title: 'Uncataloged Custom Soup',
        calories: 200,
        proteinGrams: 10,
        fridgeItemsUsed: 2,
        imageUrl: 'assets/images/paneer_rice_bowl.jpg',
        preparationSteps: [],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: MealDetailScreen(recommendation: emptyStepsRec),
        ),
      );
      await tester.pumpAndSettle();

      final genButton = find.text('Generate Steps');
      expect(genButton, findsOneWidget);
      await tester.ensureVisible(genButton);
      await tester.tap(genButton);
      await tester.pumpAndSettle();

      expect(find.text('3 steps'), findsOneWidget);
      expect(find.textContaining('Wash and chop vegetables'), findsOneWidget);
      expect(find.textContaining('Heat 1 tbsp oil in a pot'), findsOneWidget);
    });
  });

  group('WATCH HOW IT\'S MADE — Genuine Discovery', () {
    testWidgets('Displays Find cooking videos action card when no video URL exists', (WidgetTester tester) async {
      const rec = RecipeRecommendation(
        id: 'rec_no_video',
        title: 'Comfort Dal Rice',
        calories: 420,
        proteinGrams: 18,
        fridgeItemsUsed: 3,
        imageUrl: 'assets/images/paneer_rice_bowl.jpg',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: MealDetailScreen(recommendation: rec),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Watch how it's made"), findsOneWidget);
      expect(find.text('Find cooking videos'), findsOneWidget);
      expect(find.text('Watch tutorials for this recipe.'), findsOneWidget);
      expect(find.text('Video suggestions will appear here when available.'), findsNothing);
    });

    test('Video search query is generated truthfully from recipe title', () {
      const rec = RecipeRecommendation(
        id: 'rec_search',
        title: 'Paneer Rice Bowl',
        calories: 520,
        proteinGrams: 24,
        fridgeItemsUsed: 4,
        imageUrl: 'assets/images/paneer_rice_bowl.jpg',
      );

      final meal = MealDetailInfo.fromRecommendation(rec);
      expect(meal.videoSearchQuery, 'Paneer Rice Bowl recipe');

      final query = Uri.encodeComponent(meal.videoSearchQuery!);
      expect(query, 'Paneer%20Rice%20Bowl%20recipe');
    });

    testWidgets('Displays genuine video card when verified videoUrl is present', (WidgetTester tester) async {
      const recWithVideo = RecipeRecommendation(
        id: 'rec_verified_vid',
        title: 'Paneer Rice Bowl',
        calories: 520,
        proteinGrams: 24,
        fridgeItemsUsed: 4,
        imageUrl: 'assets/images/paneer_rice_bowl.jpg',
        videoUrl: 'https://www.youtube.com/watch?v=real_sample_video',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: MealDetailScreen(recommendation: recWithVideo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Paneer Rice Bowl - Video Guide'), findsOneWidget);
    });
  });

  group('COOK WITH AI — First-Response Recipe Generation & Conversation Integrity', () {
    testWidgets('Cook with AI initiates request with complete recipe context and receives full instructions', (WidgetTester tester) async {
      Map<String, dynamic>? receivedPayload;

      AiAssistantService.mockHandler = (payload) async {
        receivedPayload = payload;
        return {
          'ok': true,
          'action': 'cook_recipe',
          'assistantMessage': '''# Scrambled Eggs on Toast with Milk
A delicious, high-protein breakfast made with ingredients from your fridge.

### Preparation Details
- **Prep Time:** 5 mins
- **Cooking Time:** 5 mins
- **Serving Size:** 1 serving

### Ingredients
- Eggs: 2 large (Available in fridge)
- Bread: 2 slices (Available in fridge)
- Milk: 30 ml (Available in fridge)

### Step-by-Step Instructions
1. Crack 2 eggs into a bowl with 30ml milk, salt and black pepper; whisk until frothy.
2. Heat a skillet over medium-low heat with butter or olive oil.
3. Pour eggs in and gently push from edges to center to form soft, tender curds.
4. Toast bread slices; serve warm scrambled eggs immediately on toast.

### Chef's Cooking Tips & Substitutions
- **Tip:** Low heat ensures creamy curds without dryness.
- **Substitution:** Water can replace milk for fluffy eggs.

### Nutrition Information (Approximate)
- **Calories:** 320 kcal
- **Protein:** 18g
- **Carbs:** 28g
- **Fat:** 14g''',
          'requiresConfirmation': false,
        };
      };

      const mealContext = MealAiContext(
        mealId: 'rec_scrambled_eggs',
        mealTitle: 'Scrambled Eggs on Toast with Milk',
        mealDescription: 'High-protein breakfast dish.',
        mealType: 'breakfast',
        nutritionSummary: '320 kcal, 18g protein, 28g carbs, 14g fat',
        servingSize: '1 serving',
        prepTimeMinutes: 5,
        cookingTimeMinutes: 5,
        requiredIngredients: ['Eggs (2 pieces)', 'Bread (2 slices)', 'Milk (30 ml)'],
        availableFridgeQuantities: {'Eggs': '6 pieces', 'Milk': '500 ml', 'Bread': '1 pack'},
        missingIngredients: [],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: AiAssistantScreen(
            initialPrompt: 'I want to cook Scrambled Eggs on Toast with Milk. Please give me the complete recipe with ingredients from my fridge and step-by-step cooking instructions.',
            mealContext: mealContext,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify request payload was constructed with complete recipe context and normalized actionHint
      expect(receivedPayload, isNotNull);
      expect(receivedPayload!['actionHint'], anyOf('assistant', 'cook_recipe'));
      expect(receivedPayload!['mealContext'], isNotNull);
      expect(receivedPayload!['mealContext']['mealTitle'], 'Scrambled Eggs on Toast with Milk');

      // Verify first assistant response contains complete recipe
      expect(find.textContaining('Scrambled Eggs on Toast with Milk'), findsWidgets);
      expect(find.textContaining('Step-by-Step Instructions'), findsOneWidget);
      expect(find.textContaining('Crack 2 eggs into a bowl with 30ml milk'), findsOneWidget);
      expect(find.textContaining("Chef's Cooking Tips"), findsOneWidget);
    });

    testWidgets('Follow-up questions retain active recipe context', (WidgetTester tester) async {
      final List<Map<String, dynamic>> payloads = [];

      AiAssistantService.mockHandler = (payload) async {
        payloads.add(payload);
        return {
          'ok': true,
          'action': 'assistant_reply',
          'assistantMessage': 'You can safely substitute butter with olive oil for a lighter taste.',
        };
      };

      const mealContext = MealAiContext(
        mealId: 'rec_scrambled_eggs',
        mealTitle: 'Scrambled Eggs on Toast with Milk',
        mealType: 'breakfast',
        nutritionSummary: '320 kcal, 18g protein',
        requiredIngredients: ['Eggs (2 pieces)', 'Bread (2 slices)', 'Milk (30 ml)'],
        availableFridgeQuantities: {'Eggs': '6 pieces', 'Milk': '500 ml'},
        missingIngredients: [],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: AiAssistantScreen(
            initialPrompt: 'I want to cook Scrambled Eggs on Toast with Milk.',
            mealContext: mealContext,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Send follow-up question
      final inputFinder = find.byType(TextField);
      expect(inputFinder, findsOneWidget);
      await tester.enterText(inputFinder, 'Can I replace butter?');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      // Verify both calls received mealContext
      expect(payloads.length, 2);
      expect(payloads[1]['mealContext'], isNotNull);
      expect(payloads[1]['mealContext']['mealTitle'], 'Scrambled Eggs on Toast with Milk');
    });

    testWidgets('First assistant response immediately provides complete recipe with all 5 steps when Gemini returns 1-sentence acknowledgment', (WidgetTester tester) async {
      AiAssistantService.mockHandler = (payload) async {
        return {
          'ok': true,
          'action': 'assistant_reply',
          'assistantMessage': 'Here is a recipe for Pan-seared Chicken with Tomatoes & Peas using ingredients from your fridge!',
        };
      };

      const mealContext = MealAiContext(
        mealId: 'rec_chicken_peas_123',
        mealTitle: 'Pan-seared Chicken with Tomatoes & Peas',
        mealDescription: 'A protein-packed skillet dish using fresh ingredients from your fridge.',
        mealType: 'Dinner',
        nutritionSummary: '420 kcal, 38g protein, 12g carbs, 14g fat',
        servingSize: '1 serving',
        prepTimeMinutes: 10,
        cookingTimeMinutes: 15,
        calories: 420,
        proteinGrams: 38,
        carbsGrams: 12,
        fatGrams: 14,
        requiredIngredients: [
          'Chicken Breast (200 g)',
          'Tomatoes (2 pieces)',
          'Green Peas (50 g)',
          'Olive Oil (1 tbsp)',
        ],
        availableFridgeQuantities: {
          'Chicken Breast': '500 g',
          'Tomatoes': '4 pieces',
          'Green Peas': '150 g',
          'Olive Oil': '250 ml',
        },
        missingIngredients: [],
        detailedSteps: [
          {
            'stepNumber': 1,
            'instruction': 'Pat the chicken breast dry with a paper towel and season both sides with salt and black pepper.',
            'time': '2 mins',
          },
          {
            'stepNumber': 2,
            'instruction': 'Heat 1 tbsp olive oil in a skillet over medium-high heat until shimmering.',
            'time': '2 mins',
            'temperature': 'medium-high',
          },
          {
            'stepNumber': 3,
            'instruction': 'Place chicken in skillet and sear undisturbed for 5-6 minutes until golden brown, then flip.',
            'time': '6 mins',
            'temperature': 'medium-high',
            'tip': 'Do not move chicken too early to get a crisp crust.',
          },
          {
            'stepNumber': 4,
            'instruction': 'Add sliced tomatoes and green peas around the chicken; sauté for 3-4 minutes until softened.',
            'time': '4 mins',
            'temperature': 'medium',
          },
          {
            'stepNumber': 5,
            'instruction': 'Remove from heat, rest for 2 minutes, slice chicken, and serve warm with the pan vegetables.',
            'time': '2 mins',
          },
        ],
        cookingTips: ['Rest chicken before slicing to keep it juicy.'],
        substitutions: ['Cherry tomatoes can substitute regular tomatoes.'],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: AiAssistantScreen(
            initialPrompt: 'I want to cook Pan-seared Chicken with Tomatoes & Peas. Please give me the complete recipe with ingredients from my fridge and step-by-step cooking instructions.',
            mealContext: mealContext,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the response is NOT just the 1-sentence acknowledgment
      // It must immediately show title, ingredients with available fridge quantities, all 5 steps, tips, and nutrition
      expect(find.textContaining('Pan-seared Chicken with Tomatoes & Peas'), findsWidgets);
      expect(find.textContaining('Here is a recipe for Pan-seared Chicken with Tomatoes & Peas'), findsOneWidget);
      expect(find.textContaining('Step-by-Step Instructions'), findsOneWidget);
      expect(find.textContaining('1. Pat the chicken breast dry'), findsOneWidget);
      expect(find.textContaining('2. Heat 1 tbsp olive oil'), findsOneWidget);
      expect(find.textContaining('3. Place chicken in skillet'), findsOneWidget);
      expect(find.textContaining('4. Add sliced tomatoes and green peas'), findsOneWidget);
      expect(find.textContaining('5. Remove from heat, rest for 2 minutes'), findsOneWidget);
      expect(find.textContaining('Available in fridge: 500 g'), findsOneWidget);
      expect(find.textContaining('420 kcal'), findsOneWidget);
      expect(find.textContaining("Chef's Cooking Tips"), findsOneWidget);
    });

    testWidgets('Follow-up questions do NOT repeat the entire recipe', (WidgetTester tester) async {
      int requestCount = 0;
      AiAssistantService.mockHandler = (payload) async {
        requestCount++;
        if (requestCount == 1) {
          return {
            'ok': true,
            'action': 'assistant_reply',
            'assistantMessage': 'Here is a recipe for Pan-seared Chicken with Tomatoes & Peas using ingredients from your fridge!',
          };
        } else {
          return {
            'ok': true,
            'action': 'assistant_reply',
            'assistantMessage': 'Yes, you can cook it without oil by using a splash of water or vegetable broth in a non-stick skillet.',
          };
        }
      };

      const mealContext = MealAiContext(
        mealId: 'rec_chicken_peas_123',
        mealTitle: 'Pan-seared Chicken with Tomatoes & Peas',
        mealType: 'Dinner',
        nutritionSummary: '420 kcal, 38g protein',
        requiredIngredients: ['Chicken Breast (200 g)', 'Tomatoes (2 pieces)'],
        availableFridgeQuantities: {'Chicken Breast': '500 g', 'Tomatoes': '4 pieces'},
        missingIngredients: [],
        detailedSteps: [
          {
            'stepNumber': 1,
            'instruction': 'Season chicken breast with salt and pepper.',
          },
          {
            'stepNumber': 2,
            'instruction': 'Sear chicken in skillet for 6 minutes per side.',
          },
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: AiAssistantScreen(
            initialPrompt: 'I want to cook Pan-seared Chicken with Tomatoes & Peas.',
            mealContext: mealContext,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First response has the recipe
      expect(find.textContaining('Step-by-Step Instructions'), findsOneWidget);

      // Now ask follow-up question
      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, 'Can I make this without oil?');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      // The follow-up response should answer the question without duplicating the whole recipe
      expect(find.textContaining('Yes, you can cook it without oil by using a splash of water'), findsOneWidget);
      // 'Step-by-Step Instructions' should still only appear once in total (from message 1)
      expect(find.textContaining('Step-by-Step Instructions'), findsOneWidget);
    });

    testWidgets('Duplicate request prevention prevents re-sending initial prompt on re-entry', (WidgetTester tester) async {
      int requestCount = 0;
      AiAssistantService.mockHandler = (payload) async {
        requestCount++;
        return {
          'ok': true,
          'action': 'assistant_reply',
          'assistantMessage': 'Here is the recipe!',
        };
      };

      const mealContext = MealAiContext(
        mealId: 'rec_dedup_test',
        mealTitle: 'Pan-seared Chicken with Tomatoes & Peas',
        mealType: 'Dinner',
        nutritionSummary: '420 kcal',
        requiredIngredients: ['Chicken Breast'],
        availableFridgeQuantities: {'Chicken Breast': '500 g'},
        missingIngredients: [],
      );

      // First launch
      await tester.pumpWidget(
        const MaterialApp(
          home: AiAssistantScreen(
            mealContext: mealContext,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requestCount, 1);

      // Re-enter / rebuild same screen with same meal context
      await tester.pumpWidget(
        const MaterialApp(
          home: AiAssistantScreen(
            mealContext: mealContext,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // requestCount must remain 1 — no duplicate prompt sent
      expect(requestCount, 1);
    });
  });

  group('DATA INTEGRITY & SAFETY', () {
    testWidgets('Viewing recipe and tapping Cook with AI does NOT mutate fridge inventory', (WidgetTester tester) async {
      final milkInitial = FridgeCategoryRepository.findItemByName('Milk', exact: true);
      final milkQtyInitial = milkInitial?.quantity;

      const rec = RecipeRecommendation(
        id: 'rec_safety_check',
        title: 'Comfort Dal Rice',
        calories: 420,
        proteinGrams: 18,
        fridgeItemsUsed: 3,
        imageUrl: 'assets/images/paneer_rice_bowl.jpg',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: MealDetailScreen(recommendation: rec),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Cook with AI
      final cookWithAiBtn = find.text('Cook with AI');
      expect(cookWithAiBtn, findsWidgets);
      await tester.ensureVisible(cookWithAiBtn.first);
      await tester.tap(cookWithAiBtn.first);
      await tester.pumpAndSettle();

      // Verify fridge inventory remains completely unmodified
      final milkAfter = FridgeCategoryRepository.findItemByName('Milk', exact: true);
      expect(milkAfter?.quantity, milkQtyInitial);
    });
  });
}
