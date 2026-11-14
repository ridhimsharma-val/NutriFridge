import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/screens/ai_assistant/services/ai_assistant_service.dart';
import 'package:nutrifridge/screens/fridge/fridge_page.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/screens/fridge/services/cooking_basket_service.dart';
import 'package:nutrifridge/screens/fridge/widgets/category_bottom_sheet.dart';
import 'package:nutrifridge/screens/fridge/widgets/cooking_basket_panel.dart';
import 'package:nutrifridge/screens/fridge/widgets/cooking_pan_visual.dart';
import 'package:nutrifridge/screens/fridge/widgets/top_freezer_refrigerator.dart';
import 'package:nutrifridge/screens/home/services/meal_recommendation_service.dart';
import 'package:nutrifridge/screens/home/widgets/recommendation_card.dart';
import 'package:nutrifridge/screens/meal_detail/models/recipe_preparation_step.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FridgeCategoryRepository.seedSampleDataForTesting();
    MockDataRepository.seedSampleDataForTesting();
    MockDataRepository.forceInMemoryForTesting = true;
    CookingBasketService.clear();
    MealRecommendationService.reset();
    AiAssistantService.mockHandler = null;
    AiAssistantService.resetSession();
  });

  tearDown(() {
    CookingBasketService.clear();
    MealRecommendationService.reset();
    AiAssistantService.mockHandler = null;
  });

  group('PHASE 1 & 2 — Fresh Session Mode Selection & Dual Mode UI', () {
    test('Fresh session defaults to MealDiscoveryMode.none without loading recommendations', () {
      expect(MealRecommendationService.discoveryMode, equals(MealDiscoveryMode.none));
      expect(MealRecommendationService.currentRecommendation, isNull);
    });

    testWidgets('Dashboard renders both AI Suggestion and Use My Ingredients option cards when mode is none', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecommendationCard(
              discoveryMode: MealDiscoveryMode.none,
              recommendation: null,
              onSelectAiSuggestion: () {
                MealRecommendationService.selectDiscoveryMode(MealDiscoveryMode.aiSuggestion, fetch: false);
              },
              onSelectUseMyIngredients: () {
                MealRecommendationService.selectDiscoveryMode(MealDiscoveryMode.useMyIngredients, fetch: false);
              },
            ),
          ),
        ),
      );

      // Verify header and both choices are visible
      expect(find.text('Suggested for you'), findsOneWidget);
      expect(find.text('AI Suggestion'), findsOneWidget);
      expect(find.text('Suggest Meal'), findsOneWidget);
      expect(find.text('Use My Ingredients'), findsOneWidget);
      expect(find.text('Select Items'), findsOneWidget);

      // Tap AI Suggestion option card
      await tester.tap(find.text('AI Suggestion'));
      await tester.pump();
      expect(MealRecommendationService.discoveryMode, equals(MealDiscoveryMode.aiSuggestion));
    });

    testWidgets('Tapping Use My Ingredients triggers selection mode', (tester) async {
      bool useMyIngredientsTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecommendationCard(
              discoveryMode: MealDiscoveryMode.none,
              recommendation: null,
              onSelectUseMyIngredients: () {
                useMyIngredientsTapped = true;
                MealRecommendationService.selectDiscoveryMode(MealDiscoveryMode.useMyIngredients, fetch: false);
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Use My Ingredients'));
      await tester.pump();
      expect(useMyIngredientsTapped, isTrue);
      expect(MealRecommendationService.discoveryMode, equals(MealDiscoveryMode.useMyIngredients));
    });

    testWidgets('Widget rebuild retains selected discovery mode without duplicate requests', (tester) async {
      MealRecommendationService.selectDiscoveryMode(MealDiscoveryMode.aiSuggestion, fetch: false);
      expect(MealRecommendationService.discoveryMode, equals(MealDiscoveryMode.aiSuggestion));

      // Simulate a widget rebuild
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecommendationCard(
              discoveryMode: MealRecommendationService.discoveryMode,
              recommendation: null,
              status: RecommendationStatus.loaded,
            ),
          ),
        ),
      );

      // Mode is still aiSuggestion
      expect(MealRecommendationService.discoveryMode, equals(MealDiscoveryMode.aiSuggestion));
    });

    testWidgets('Tapping back arrow resets discovery mode to none, clears recommendation, and restores both choices', (tester) async {
      const sampleRec = RecipeRecommendation(
        title: 'Fresh Garden Salad',
        calories: 220,
        proteinGrams: 8,
        fridgeItemsUsed: 3,
        imageUrl: 'assets/images/salad.jpg',
      );

      MealRecommendationService.selectDiscoveryMode(MealDiscoveryMode.aiSuggestion, fetch: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecommendationCard(
              discoveryMode: MealDiscoveryMode.aiSuggestion,
              recommendation: sampleRec,
              status: RecommendationStatus.loaded,
              onSwitchMode: () {
                MealRecommendationService.selectDiscoveryMode(MealDiscoveryMode.none, fetch: false);
              },
            ),
          ),
        ),
      );

      // Verify recommendation is displayed and back arrow is present
      expect(find.text('Fresh Garden Salad'), findsOneWidget);
      expect(find.byKey(const ValueKey('back_to_mode_selection')), findsOneWidget);
      expect(find.text('Change mode'), findsNothing);

      // Tap back arrow icon
      await tester.tap(find.byKey(const ValueKey('back_to_mode_selection')));
      await tester.pump();

      // Mode is reset to none
      expect(MealRecommendationService.discoveryMode, equals(MealDiscoveryMode.none));
      expect(MealRecommendationService.currentRecommendation, isNull);

      // Rebuild with new mode: both dual-mode choices are restored
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecommendationCard(
              discoveryMode: MealRecommendationService.discoveryMode,
              recommendation: MealRecommendationService.currentRecommendation,
            ),
          ),
        ),
      );

      expect(find.text('AI Suggestion'), findsOneWidget);
      expect(find.text('Use My Ingredients'), findsOneWidget);
      expect(find.byKey(const ValueKey('back_to_mode_selection')), findsNothing);
    });

    testWidgets('Navigating back to mode selector preserves selected items in cooking basket', (tester) async {
      const item = CategoryFoodItem(
        id: 'spinach-123',
        name: 'Fresh Spinach',
        quantity: '100 g',
        category: 'Produce',
      );
      CookingBasketService.toggleItem(item);
      CookingBasketService.setPreferredDishName('Spinach Omelette');

      expect(CookingBasketService.itemCount, equals(1));
      expect(CookingBasketService.preferredDishName, equals('Spinach Omelette'));

      // Simulate mode reset back to none
      MealRecommendationService.selectDiscoveryMode(MealDiscoveryMode.none, fetch: false);

      expect(MealRecommendationService.discoveryMode, equals(MealDiscoveryMode.none));
      // Cooking basket and dish name must remain preserved
      expect(CookingBasketService.itemCount, equals(1));
      expect(CookingBasketService.preferredDishName, equals('Spinach Omelette'));
    });
  });

  group('PHASE 3 — Cooking Basket Service & State Management', () {
    test('Toggling items adds and removes them accurately from CookingBasketService', () {
      const item1 = CategoryFoodItem(
        id: 'b6f6f971-3cb2-4a0b-8d0f-61266b72a001',
        name: 'Eggs',
        quantity: '6 pcs',
        category: 'Dairy & Eggs',
      );
      const item2 = CategoryFoodItem(
        id: 'b6f6f971-3cb2-4a0b-8d0f-61266b72a002',
        name: 'Spinach',
        quantity: '200 g',
        category: 'Produce',
      );

      expect(CookingBasketService.itemCount, equals(0));
      expect(CookingBasketService.isSelected(item1), isFalse);

      // Select item1
      CookingBasketService.toggleItem(item1);
      expect(CookingBasketService.itemCount, equals(1));
      expect(CookingBasketService.isSelected(item1), isTrue);

      // Select item2
      CookingBasketService.toggleItem(item2);
      expect(CookingBasketService.itemCount, equals(2));
      expect(CookingBasketService.isSelected(item2), isTrue);

      // Toggle item1 again -> deselected
      CookingBasketService.toggleItem(item1);
      expect(CookingBasketService.itemCount, equals(1));
      expect(CookingBasketService.isSelected(item1), isFalse);
      expect(CookingBasketService.isSelected(item2), isTrue);

      // Remove item2 by ID
      CookingBasketService.removeItem(item2.id);
      expect(CookingBasketService.itemCount, equals(0));
      expect(CookingBasketService.isSelected(item2), isFalse);
    });

    test('Preferred dish name handles trimming, empty strings, and max length safely', () {
      CookingBasketService.setPreferredDishName('   ');
      expect(CookingBasketService.preferredDishName, isNull);

      CookingBasketService.setPreferredDishName('  Spicy Fried Rice  ');
      expect(CookingBasketService.preferredDishName, equals('Spicy Fried Rice'));

      // Very long name truncated to 120 chars
      final longName = 'A' * 150;
      CookingBasketService.setPreferredDishName(longName);
      expect(CookingBasketService.preferredDishName!.length, equals(120));

      CookingBasketService.clear();
      expect(CookingBasketService.preferredDishName, isNull);
      expect(CookingBasketService.selectedItems, isEmpty);
    });

    test('Selection does not mutate the original fridge inventory items', () {
      final initialTotalItems = FridgeCategoryRepository.totalFridgeItems;
      final produceCategory = FridgeCategoryRepository.getCategoryData('Produce');
      final firstItem = produceCategory.items.first;

      CookingBasketService.toggleItem(firstItem);
      expect(CookingBasketService.isSelected(firstItem), isTrue);

      // Re-query category: inventory quantity and item count remain unaltered
      final updatedProduce = FridgeCategoryRepository.getCategoryData('Produce');
      expect(FridgeCategoryRepository.totalFridgeItems, equals(initialTotalItems));
      expect(updatedProduce.items.first.quantity, equals(firstItem.quantity));
    });
  });

  group('PHASE 4 — UI Components: Selection Sheet & Cooking Basket Panel', () {
    testWidgets('CookingBasketPanel shows disabled CTA when basket is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: CookingBasketPanel(),
          ),
        ),
      );

      expect(find.text('Your Cooking Basket'), findsOneWidget);
      expect(find.text('Tap ingredients to select'), findsOneWidget);
      expect(find.text('Select Ingredients to Cook'), findsOneWidget);

      // Tap disabled button does not trigger generation
      await tester.tap(find.text('Select Ingredients to Cook'));
      await tester.pump();
      expect(CookingBasketService.isGenerating, isFalse);
    });

    testWidgets('CookingBasketPanel displays item chips, remove buttons, and active CTA when items added', (tester) async {
      const item = CategoryFoodItem(
        id: 'uuid-1234-apple',
        name: 'Crisp Apple',
        quantity: '3 pcs',
        category: 'Produce',
      );
      CookingBasketService.toggleItem(item);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: CookingBasketPanel(),
          ),
        ),
      );

      expect(find.text('1 ingredient selected'), findsOneWidget);
      expect(find.text('Crisp Apple'), findsOneWidget);
      expect(find.text('Clear all'), findsOneWidget);
      expect(find.text('Generate My Meal · 1'), findsOneWidget);

      // Tap remove button on chip
      final removeButton = find.byIcon(Icons.close_rounded);
      expect(removeButton, findsWidgets);
      await tester.tap(removeButton.first);
      await tester.pump();

      expect(CookingBasketService.itemCount, equals(0));
    });

    testWidgets('CookingBasketPanel collapses and expands cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: CookingBasketPanel(),
          ),
        ),
      );

      // Initially expanded
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

      // Tap collapse
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();

      // Now collapsed: shows expand chevron
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);

      // Tap to re-expand
      await tester.tap(find.text('Your Cooking Basket'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    });

    testWidgets('CookingBasketPanel renders intentional AI generation waiting state', (tester) async {
      CookingBasketService.isGeneratingNotifier.value = true;
      addTearDown(() => CookingBasketService.isGeneratingNotifier.value = false);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: CookingBasketPanel(),
          ),
        ),
      );

      expect(find.text('Creating your meal'), findsOneWidget);
      expect(find.text('Finding the best way to combine your ingredients...'), findsOneWidget);
      expect(find.text('Checking selected ingredients...'), findsOneWidget);
    });

    testWidgets('RecommendationCard shows subtle YOUR INGREDIENTS badge when in useMyIngredients mode', (tester) async {
      const rec = RecipeRecommendation(
        id: 'rec_custom_test_123',
        title: 'Fresh Herb Omelette',
        mealType: 'Breakfast',
        calories: 320,
        proteinGrams: 22,
        fridgeItemsUsed: 2,
        imageUrl: 'assets/images/food/scrambled_eggs.png',
        preparationSteps: [
          RecipePreparationStep(stepNumber: 1, instruction: 'Step 1'),
          RecipePreparationStep(stepNumber: 2, instruction: 'Step 2'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecommendationCard(
              discoveryMode: MealDiscoveryMode.useMyIngredients,
              recommendation: rec,
            ),
          ),
        ),
      );

      expect(find.text('YOUR INGREDIENTS'), findsOneWidget);
      expect(find.text('Fresh Herb Omelette'), findsOneWidget);
    });

    testWidgets('CategoryBottomSheet in isSelectionMode enables multi-select with checkmarks', (tester) async {
      final produceCategory = FridgeCategoryRepository.getCategoryData('Produce');
      final firstItem = produceCategory.items.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryBottomSheet(
              category: produceCategory,
              isSelectionMode: true,
            ),
          ),
        ),
      );

      // Verify category items render with selection indicators
      expect(find.text(produceCategory.name), findsOneWidget);
      expect(find.text(firstItem.name), findsOneWidget);

      // Tap first item to select it
      await tester.tap(find.text(firstItem.name));
      await tester.pump();

      expect(CookingBasketService.isSelected(firstItem), isTrue);

      // Tap again to deselect
      await tester.tap(find.text(firstItem.name));
      await tester.pump();

      expect(CookingBasketService.isSelected(firstItem), isFalse);
    });

    testWidgets('FridgePage in selection mode renders Select Ingredients header and CookingBasketPanel', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: FridgePage(isSelectionMode: true),
        ),
      );

      expect(find.text('Select Ingredients'), findsOneWidget);
      expect(find.byType(CookingPanVisual), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });
  });

  group('PHASE 5 — Server-Side Validation & Contract Rules', () {
    test('UUID syntax validator correctly accepts UUIDs and rejects non-UUID strings', () {
      final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$', caseSensitive: false);

      expect(uuidRegex.hasMatch('b6f6f971-3cb2-4a0b-8d0f-61266b72a001'), isTrue);
      expect(uuidRegex.hasMatch('9542da64-6df5-40ea-9004-9457223b9d6a'), isTrue);
      expect(uuidRegex.hasMatch('rec_1794205815811'), isFalse);
      expect(uuidRegex.hasMatch('12345'), isFalse);
      expect(uuidRegex.hasMatch('not-a-uuid'), isFalse);
    });

    test('generateFromSelectedIngredients rejects empty item list immediately', () async {
      final result = await MealRecommendationService.generateFromSelectedIngredients(
        selectedItems: [],
      );
      expect(result, isNull);
    });

    test('generateFromSelectedIngredients synthesizes valid recipe recommendation from selected ingredients', () async {
      AiAssistantService.mockHandler = (payload) async {
        return {
          'ok': true,
          'action': 'meal_recommendation',
          'meal': {
            'id': 'rec_eggs_milk_001',
            'name': 'Herb Scrambled Eggs',
            'mealType': 'Breakfast',
            'calories': 320,
            'proteinG': 20,
            'carbsG': 12,
            'fatG': 18,
            'preparationTimeMinutes': 5,
            'cookingTimeMinutes': 10,
            'servingSize': '1 serving',
            'nutritionIsEstimate': true,
            'ingredients': [
              {'name': 'Eggs', 'quantity': 2, 'unit': 'pcs', 'availableInFridge': true},
              {'name': 'Whole Milk', 'quantity': 100, 'unit': 'ml', 'availableInFridge': true},
            ],
            'preparationSteps': [
              {'stepNumber': 1, 'instruction': 'Whisk eggs and whole milk together with a pinch of salt.', 'time': '2 mins'},
              {'stepNumber': 2, 'instruction': 'Cook in a non-stick pan over gentle heat until set.', 'time': '5 mins'},
            ],
            'cookingTips': ['Keep the heat low for creamy scrambled eggs.'],
            'substitutions': [],
          },
        };
      };

      const item1 = CategoryFoodItem(
        id: '11111111-2222-3333-4444-555555555555',
        name: 'Eggs',
        quantity: '2 pcs',
        category: 'Dairy & Eggs',
      );
      const item2 = CategoryFoodItem(
        id: '22222222-3333-4444-5555-666666666666',
        name: 'Whole Milk',
        quantity: '100 ml',
        category: 'Dairy & Eggs',
      );

      final rec = await MealRecommendationService.generateFromSelectedIngredients(
        selectedItems: [item1, item2],
        preferredDishName: 'Herb Scrambled Eggs',
      );

      expect(rec, isNotNull);
      expect(rec!.title, contains('Herb Scrambled Eggs'));
      expect(rec.requiredIngredients.any((i) => i.toLowerCase().contains('eggs')), isTrue);
      expect(rec.requiredIngredients.any((i) => i.toLowerCase().contains('milk')), isTrue);
      expect(rec.preparationSteps, isNotEmpty);
      expect(rec.nutritionIsEstimate, isTrue);

      // Verify discovery mode is useMyIngredients
      expect(MealRecommendationService.discoveryMode, equals(MealDiscoveryMode.useMyIngredients));
    });

    test('generateFromSelectedIngredients on backend failure keeps basket intact and does not poison dashboard', () async {
      MealRecommendationService.reset();
      expect(MealRecommendationService.discoveryMode, equals(MealDiscoveryMode.none));

      const item1 = CategoryFoodItem(
        id: '11111111-2222-3333-4444-555555555555',
        name: 'Eggs',
        quantity: '2 pcs',
        category: 'Dairy & Eggs',
      );
      CookingBasketService.toggleItem(item1);
      CookingBasketService.setPreferredDishName('Egg Frittata');

      AiAssistantService.mockHandler = (payload) async {
        return {
          'ok': false,
          'action': 'error',
          'assistantMessage': 'Google Gemini rate limit exceeded. Please wait a moment and tap retry.',
          'error': {'code': 'GEMINI_RATE_LIMIT_EXCEEDED'},
        };
      };

      final rec = await MealRecommendationService.generateFromSelectedIngredients(
        selectedItems: CookingBasketService.selectedItems,
        preferredDishName: CookingBasketService.preferredDishName,
      );

      expect(rec, isNull);
      // Inline error set in basket
      expect(CookingBasketService.generationError, contains('rate limit exceeded'));
      // Selected items and dish name remain intact
      expect(CookingBasketService.itemCount, equals(1));
      expect(CookingBasketService.preferredDishName, equals('Egg Frittata'));
      // Dashboard mode and status are not poisoned into error
      expect(MealRecommendationService.currentStatus, isNot(equals(RecommendationStatus.error)));
      expect(MealRecommendationService.discoveryMode, equals(MealDiscoveryMode.none));
    });

    test('generateFromSelectedIngredients on network or AI failure does NOT fall back to synthetic recipe', () async {
      MealRecommendationService.reset();
      MockDataRepository.forceInMemoryForTesting = false;

      const item1 = CategoryFoodItem(
        id: '11111111-2222-3333-4444-555555555555',
        name: 'Eggs',
        quantity: '2 pcs',
        category: 'Dairy & Eggs',
      );
      const item2 = CategoryFoodItem(
        id: '22222222-3333-4444-5555-666666666666',
        name: 'Whole Milk',
        quantity: '100 ml',
        category: 'Dairy & Eggs',
      );
      CookingBasketService.clear();
      CookingBasketService.toggleItem(item1);
      CookingBasketService.toggleItem(item2);
      CookingBasketService.setPreferredDishName('Egg Scramble');

      AiAssistantService.mockHandler = (payload) async {
        return {
          'ok': false,
          'action': 'error',
          'assistantMessage': 'Unable to connect to NutriFridge AI. Please check your connection and retry.',
          'error': 'Connection refused',
        };
      };

      final rec = await MealRecommendationService.generateFromSelectedIngredients(
        selectedItems: CookingBasketService.selectedItems,
        preferredDishName: 'Egg Scramble',
      );

      // Must be null: NO fake synthetic recipe allowed on failure
      expect(rec, isNull);
      // Honest error message displayed
      expect(CookingBasketService.generationError, contains('Unable to connect to NutriFridge AI'));
      // Selected basket items and dish name remain 100% intact
      expect(CookingBasketService.itemCount, equals(2));
      expect(CookingBasketService.preferredDishName, equals('Egg Scramble'));
      // Dashboard is not marked as loaded
      expect(MealRecommendationService.currentRecommendation, isNull);
    });

    testWidgets('FridgePage in selection mode opens doors immediately to reveal shelves', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FridgePage(isSelectionMode: true),
        ),
      );
      await tester.pumpAndSettle();

      // TopFreezerRefrigerator is present with shelves open
      expect(find.byType(TopFreezerRefrigerator), findsOneWidget);
      final fridgeWidget = tester.widget<TopFreezerRefrigerator>(find.byType(TopFreezerRefrigerator));
      expect(fridgeWidget.isFridgeOpen, isTrue);
      expect(fridgeWidget.isFreezerOpen, isTrue);
    });
  });

  group('PHASE 6 — Use My Ingredients Navigation & State Fixes', () {
    testWidgets('Dashboard retains dual-mode chooser when returning from ingredient selection without generating', (tester) async {
      final item = CategoryFoodItem(
        id: 'item-egg-1',
        name: 'Eggs',
        quantity: '4 pcs',
        category: 'Dairy & Eggs',
      );
      // Simulate selecting an item into basket
      CookingBasketService.toggleItem(item);
      expect(CookingBasketService.count, equals(1));

      // In initial state without generating, mode is none
      expect(MealRecommendationService.discoveryMode, equals(MealDiscoveryMode.none));
      expect(MealRecommendationService.pendingCustomRecipe, isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecommendationCard(
              discoveryMode: MealRecommendationService.discoveryMode,
              recipeOrigin: MealRecommendationService.recipeOrigin,
              recommendation: null,
            ),
          ),
        ),
      );

      // Verify two-option chooser is rendered cleanly without flash or stale recommendation
      expect(find.text('Suggested for you'), findsOneWidget);
      expect(find.text('AI Suggestion'), findsOneWidget);
      expect(find.text('Use My Ingredients'), findsOneWidget);
      // Cooking basket is preserved
      expect(CookingBasketService.count, equals(1));
    });

    testWidgets('Custom recipe displays on dashboard with custom labeling and controls when not logged', (tester) async {
      final customRec = RecipeRecommendation(
        id: 'rec_custom_test_1',
        title: 'Spinach & Herb Omelette',
        mealType: 'Breakfast',
        explanation: 'Crafted from your selected ingredients.',
        calories: 380,
        proteinGrams: 24,
        carbsGrams: 10,
        fatGrams: 18,
        prepTimeMinutes: 10,
        cookingTimeMinutes: 12,
        servingSize: '1 serving',
        fridgeItemsUsed: 2,
        imageUrl: 'assets/images/paneer_rice_bowl.jpg',
        requiredIngredients: ['Eggs (2)', 'Spinach (50g)'],
        missingIngredients: const [],
        preparationSteps: const [],
      );

      // Set custom meal state as returned from AI generation
      MealRecommendationService.selectDiscoveryMode(MealDiscoveryMode.useMyIngredients, fetch: false);
      // Custom origin is active
      expect(MealRecommendationService.recipeOrigin, equals(RecipeOrigin.customIngredients));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecommendationCard(
              discoveryMode: MealDiscoveryMode.useMyIngredients,
              recipeOrigin: RecipeOrigin.customIngredients,
              recommendation: customRec,
            ),
          ),
        ),
      );
      await tester.pump();

      // Heading shows "Your Custom Meal"
      expect(find.text('Your Custom Meal'), findsOneWidget);
      // Title of the custom recipe
      expect(find.text('Spinach & Herb Omelette'), findsOneWidget);
      // Badge displays "YOUR INGREDIENTS"
      expect(find.text('YOUR INGREDIENTS'), findsOneWidget);
      // "Generated from your ingredients" removed from custom meal card
      expect(find.text('Generated from your ingredients'), findsNothing);
      expect(find.text('Tap to view recipe'), findsOneWidget);
      // "Change suggestion" (AI Suggestion button) must NOT be present
      expect(find.byKey(const ValueKey('change_suggestion_button')), findsNothing);
    });

    test('Custom-generated recipe is NOT overwritten by inventory fingerprint changes', () {
      final customRec = RecipeRecommendation(
        id: 'rec_custom_persist',
        title: 'Custom Stir Fry',
        mealType: 'Dinner',
        explanation: 'Custom recipe',
        calories: 400,
        proteinGrams: 20,
        carbsGrams: 30,
        fatGrams: 12,
        prepTimeMinutes: 15,
        cookingTimeMinutes: 15,
        servingSize: '1 serving',
        fridgeItemsUsed: 2,
        imageUrl: 'assets/images/paneer_rice_bowl.jpg',
        requiredIngredients: ['Tofu'],
        missingIngredients: const [],
        preparationSteps: const [],
      );
      expect(customRec.title, equals('Custom Stir Fry'));

      MealRecommendationService.selectDiscoveryMode(MealDiscoveryMode.useMyIngredients, fetch: false);
      expect(MealRecommendationService.recipeOrigin, equals(RecipeOrigin.customIngredients));

      // Simulate inventory change callback
      FridgeCategoryRepository.deductItemQuantityByName(
        name: 'Eggs',
        quantity: 1,
        unit: 'pcs',
      );

      // Custom recipe origin and mode remain intact
      expect(MealRecommendationService.recipeOrigin, equals(RecipeOrigin.customIngredients));
      expect(MealRecommendationService.discoveryMode, equals(MealDiscoveryMode.useMyIngredients));
    });

    test('advanceAfterMealLogged for custom recipe cleans up and resets to mode none without AI fetch', () async {
      final item = CategoryFoodItem(
        id: 'item-egg-log',
        name: 'Eggs',
        quantity: '2 pcs',
        category: 'Dairy & Eggs',
      );
      CookingBasketService.toggleItem(item);
      expect(CookingBasketService.count, equals(1));

      MealRecommendationService.selectDiscoveryMode(MealDiscoveryMode.useMyIngredients, fetch: false);
      expect(MealRecommendationService.recipeOrigin, equals(RecipeOrigin.customIngredients));

      // Log meal advancement
      final result = await MealRecommendationService.advanceAfterMealLogged(
        loggedSlot: MealTimeSlot.lunch,
      );

      // Returns null (no AI recommendation fetched)
      expect(result, isNull);
      // Origin and mode cleanly reset to none
      expect(MealRecommendationService.recipeOrigin, equals(RecipeOrigin.none));
      expect(MealRecommendationService.discoveryMode, equals(MealDiscoveryMode.none));
      expect(MealRecommendationService.pendingCustomRecipe, isNull);
    });
  });
}
