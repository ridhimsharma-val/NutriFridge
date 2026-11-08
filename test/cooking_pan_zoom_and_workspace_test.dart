import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/screens/ai_assistant/services/ai_assistant_service.dart';
import 'package:nutrifridge/screens/fridge/fridge_page.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/screens/fridge/screens/cooking_workspace_screen.dart';
import 'package:nutrifridge/screens/fridge/services/cooking_basket_service.dart';
import 'package:nutrifridge/screens/fridge/widgets/category_bottom_sheet.dart';
import 'package:nutrifridge/screens/fridge/widgets/cooking_pan_visual.dart';
import 'package:nutrifridge/screens/home/services/meal_recommendation_service.dart';
import 'package:nutrifridge/services/ai/supabase_ai_function_client.dart';

void main() {
  setUp(() {
    CookingBasketService.clear();
    MealRecommendationService.reset();
    MockDataRepository.forceInMemoryForTesting = true;
    FridgeCategoryRepository.forceInMemoryForTesting = true;
  });

  tearDown(() {
    CookingBasketService.clear();
    MealRecommendationService.reset();
    AiAssistantService.mockHandler = null;
    SupabaseAiFunctionClient.resetTestState();
  });

  group('Phase 2 & 3: Main Selection Screen & Cooking Pan', () {
    testWidgets('FridgePage in selection mode hides settings icon and renders large Hero CookingPanVisual',
        (tester) async {
      tester.view.physicalSize = const Size(400, 850);
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
      await tester.pumpAndSettle();

      // Verify header in selection mode
      expect(find.text('Select Ingredients'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      // Settings button (tune_rounded) must be HIDDEN in selection mode
      expect(find.byIcon(Icons.tune_rounded), findsNothing);

      // Hero CookingPanVisual is rendered directly below the refrigerator
      expect(find.byType(CookingPanVisual), findsOneWidget);
      final heroFinder = find.byWidgetPredicate(
        (widget) => widget is Hero && widget.tag == 'cooking_pan_hero',
      );
      expect(heroFinder, findsOneWidget);

      // Verify enlarged dimensions: ~3x area compared to original 240x130
      final panWidget = tester.widget<CookingPanVisual>(find.byType(CookingPanVisual));
      expect(panWidget.width, greaterThanOrEqualTo(320.0));
      expect(panWidget.height, greaterThanOrEqualTo(170.0));

      // Verify pan is shifted slightly right for optimal visual balance with refrigerator
      final transformFinder = find.byWidgetPredicate(
        (widget) => widget is Transform && widget.transform.getTranslation().x > 0,
      );
      expect(transformFinder, findsWidgets);
    });

    testWidgets('CategoryBottomSheet footer renders enlarged standalone pan and Add action card, retaining selections on pop',
        (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final item = CategoryFoodItem(
        id: 'dairy-1',
        name: 'Whole Milk',
        category: 'Dairy Products',
        quantity: '1 L',
        expiryDays: 5,
      );
      final category = CategoryData(
        id: 'dairy',
        name: 'Dairy Products',
        iconEmoji: '🥛',
        items: [item],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryBottomSheet(
              category: category,
              isSelectionMode: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Standalone pan is rendered outside card and enlarged substantially
      expect(find.byType(CookingPanVisual), findsOneWidget);
      final miniPan = tester.widget<CookingPanVisual>(find.byType(CookingPanVisual));
      expect(miniPan.width, greaterThanOrEqualTo(240.0));
      expect(miniPan.height, greaterThanOrEqualTo(120.0));

      // Button is labeled "Add" (not "Done")
      expect(find.widgetWithText(ElevatedButton, 'Add'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Done'), findsNothing);

      // Select an item
      final firstItem = category.items.first;
      await tester.tap(find.text(firstItem.name));
      await tester.pump();
      expect(CookingBasketService.isSelected(firstItem), isTrue);

      // Tap Add button to confirm and close
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      // Selection remains retained in service
      expect(CookingBasketService.isSelected(firstItem), isTrue);
      expect(CookingBasketService.count, 1);
    });

    testWidgets('FridgePage in normal mode displays settings icon and does not render CookingPanVisual',
        (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: FridgePage(isSelectionMode: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Fridge'), findsOneWidget);
      // Settings button (tune_rounded) is VISIBLE in normal mode
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      // Cooking pan is NOT shown in normal mode
      expect(find.byType(CookingPanVisual), findsNothing);
    });
  });

  group('Phase 7: Pan Zoom Transition into Cooking Workspace', () {
    testWidgets('Tapping the collapsed pan zooms into CookingWorkspaceScreen via Hero transition',
        (tester) async {
      tester.view.physicalSize = const Size(400, 850);
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
      await tester.pumpAndSettle();

      // Tap on the large pan
      await tester.tap(find.byType(CookingPanVisual));
      await tester.pumpAndSettle();

      // Workspace screen is now active
      expect(find.byType(CookingWorkspaceScreen), findsOneWidget);
      expect(find.text('Your Cooking Workspace'), findsOneWidget);

      // Pan is present as the Hero object in the workspace
      final heroFinder = find.byWidgetPredicate(
        (widget) => widget is Hero && widget.tag == 'cooking_pan_hero',
      );
      expect(heroFinder, findsOneWidget);

      // Back button reverses transition
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(CookingWorkspaceScreen), findsNothing);
      expect(find.byType(FridgePage), findsOneWidget);
    });
  });

  group('Phase 8: Expanded Cooking Workspace Hierarchy & Form Elements', () {
    testWidgets('Dish name input is the FIRST form element immediately below the pan',
        (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: CookingWorkspaceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Pan is visible at the top
      expect(find.byType(CookingPanVisual), findsOneWidget);

      // Dish name input section is immediately below
      expect(find.text('What would you like to cook?'), findsOneWidget);
      expect(find.text('Optional'), findsOneWidget);
      expect(find.text('Leave empty and let AI surprise you.'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Second section is Selected Ingredients
      expect(find.text('Selected ingredients · 0'), findsOneWidget);
      expect(
        find.textContaining('No ingredients selected from fridge yet'),
        findsOneWidget,
      );
    });

    testWidgets('Entering dish name updates CookingBasketService and clears cleanly',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CookingWorkspaceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Chicken Curry');
      await tester.pump();

      expect(CookingBasketService.preferredDishName, 'Chicken Curry');

      // Clear button appears and clears text
      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pump();

      expect(CookingBasketService.preferredDishName, isNull);
    });

    testWidgets('Selected ingredients are displayed as removable chips and reflect in pan',
        (tester) async {
      final item1 = CategoryFoodItem(
        id: 'uuid-milk-1',
        name: 'Milk',
        category: 'Dairy Products',
        quantity: '3 L',
        expiryDays: 12,
      );
      final item2 = CategoryFoodItem(
        id: 'uuid-paneer-2',
        name: 'Paneer',
        category: 'Dairy Products',
        quantity: '500 g',
        expiryDays: 14,
      );

      CookingBasketService.toggleItem(item1);
      CookingBasketService.toggleItem(item2);

      await tester.pumpWidget(
        const MaterialApp(
          home: CookingWorkspaceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Selected ingredients · 2'), findsOneWidget);
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('3 L'), findsOneWidget);
      expect(find.text('Paneer'), findsOneWidget);
      expect(find.text('500 g'), findsOneWidget);

      // Remove one item by tapping its chip close button
      final closeIcons = find.byIcon(Icons.close_rounded);
      expect(closeIcons, findsNWidgets(2));

      await tester.tap(closeIcons.first);
      await tester.pumpAndSettle();

      expect(CookingBasketService.count, 1);
      expect(CookingBasketService.isSelected(item1), isFalse);
      expect(CookingBasketService.isSelected(item2), isTrue);
    });

    testWidgets('Generate My Meal CTA state matrix: disabled when empty, active with items or dish name',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CookingWorkspaceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.widgetWithText(ElevatedButton, 'Generate My Meal');
      expect(buttonFinder, findsOneWidget);

      // 1. Neither items nor dish name: DISABLED
      ElevatedButton btn = tester.widget(buttonFinder);
      expect(btn.onPressed, isNull);

      // 2. Dish name only (no items selected): ACTIVE
      await tester.enterText(find.byType(TextField), 'Paneer Butter Masala');
      await tester.pump();
      btn = tester.widget(buttonFinder);
      expect(btn.onPressed, isNotNull);

      // 3. Clear dish name -> back to DISABLED
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      btn = tester.widget(buttonFinder);
      expect(btn.onPressed, isNull);

      // 4. Selected items (no dish name): ACTIVE with count in label
      final item = CategoryFoodItem(
        id: 'uuid-chicken-1',
        name: 'Chicken Breast',
        category: 'Non-Veg',
        quantity: '500 g',
        expiryDays: 5,
      );
      CookingBasketService.toggleItem(item);
      await tester.pump();

      final buttonWithCountFinder =
          find.widgetWithText(ElevatedButton, 'Generate My Meal · 1');
      expect(buttonWithCountFinder, findsOneWidget);
      btn = tester.widget(buttonWithCountFinder);
      expect(btn.onPressed, isNotNull);
    });
  });

  group('Phase 9: Named Dish Generation Without Selected Ingredients', () {
    test('generateFromDishName generates recipe using complete fridge inventory', () async {
      AiAssistantService.mockHandler = (payload) async {
        expect(payload['recipeMode'], 'named_dish_from_inventory');
        expect(payload['preferredDishName'], 'Vegetable Fried Rice');
        return {
          'action': 'meal_recommendation',
          'meal': {
            'id': 'meal-vfr-1',
            'title': 'Vegetable Fried Rice',
            'calories': 420,
            'prepTimeMinutes': 20,
            'proteinGrams': 12,
            'carbsGrams': 65,
            'fatGrams': 10,
            'ingredients': ['Rice', 'Carrots', 'Peas', 'Soy Sauce'],
            'instructions': ['Cook rice', 'Stir fry veggies', 'Combine and serve'],
          },
        };
      };

      final rec = await MealRecommendationService.generateFromDishName(
        dishName: 'Vegetable Fried Rice',
      );

      expect(rec, isNotNull);
      expect(rec!.title, 'Vegetable Fried Rice');
      expect(MealRecommendationService.discoveryMode, MealDiscoveryMode.useMyIngredients);
      expect(MealRecommendationService.currentRecommendation?.title, 'Vegetable Fried Rice');
    });

    test('generateFromSelectedIngredients delegates to generateFromDishName when items empty and dish name provided',
        () async {
      AiAssistantService.mockHandler = (payload) async {
        expect(payload['recipeMode'], 'named_dish_from_inventory');
        expect(payload['preferredDishName'], 'Chicken Curry');
        return {
          'action': 'meal_recommendation',
          'meal': {
            'id': 'meal-cc-1',
            'title': 'Chicken Curry',
            'calories': 520,
            'prepTimeMinutes': 30,
            'proteinGrams': 42,
            'carbsGrams': 15,
            'fatGrams': 22,
            'ingredients': ['Chicken', 'Onion', 'Curry Spices'],
            'instructions': ['Sauté onions', 'Add spices and chicken', 'Simmer until tender'],
          },
        };
      };

      final rec = await MealRecommendationService.generateFromSelectedIngredients(
        selectedItems: const [],
        preferredDishName: 'Chicken Curry',
      );

      expect(rec, isNotNull);
      expect(rec!.title, 'Chicken Curry');
    });

    test('generateFromDishName with empty dish name returns null and does not invoke AI', () async {
      bool aiInvoked = false;
      AiAssistantService.mockHandler = (_) async {
        aiInvoked = true;
        return {'ok': true};
      };

      final rec = await MealRecommendationService.generateFromDishName(
        dishName: '   ',
      );

      expect(rec, isNull);
      expect(aiInvoked, isFalse);
    });

    test('Supabase Edge Function source verifies named_dish_from_inventory contract', () {
      final file = File('supabase/functions/nutrifridge-ai/index.ts');
      expect(file.existsSync(), isTrue);
      final source = file.readAsStringSync();

      expect(source, contains("recipeMode === 'named_dish_from_inventory'"));
      expect(source, contains("'EMPTY_DISH_NAME'"));
      expect(source, contains("preferredDishName.trim().length === 0"));
    });
  });

  group('Phase 9: Interactive Cooking Pan Layout & Workspace Carousel', () {
    testWidgets('CookingPanVisual renders adaptive balanced layout for 1-6 items and separate +N badge for >6',
        (tester) async {
      // 5 items: all 5 displayed in 3 + 2 layout with NO overflow indicator
      final items5 = [
        CategoryFoodItem(id: '1', name: 'Apples', category: 'Fruits', quantity: '2', expiryDays: 3),
        CategoryFoodItem(id: '2', name: 'Bananas', category: 'Fruits', quantity: '3', expiryDays: 2),
        CategoryFoodItem(id: '3', name: 'Milk', category: 'Dairy', quantity: '1 L', expiryDays: 4),
        CategoryFoodItem(id: '4', name: 'Bread', category: 'Bakery', quantity: '1 pack', expiryDays: 5),
        CategoryFoodItem(id: '5', name: 'Tomatoes', category: 'Vegetables', quantity: '400 g', expiryDays: 6),
      ];

      for (final it in items5) {
        CookingBasketService.toggleItem(it);
      }

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CookingPanVisual(
                width: 340,
                height: 184,
                isExpanded: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // For 5 items, no overflow badge should be rendered
      expect(find.byKey(const ValueKey('pan_overflow_badge')), findsNothing);

      // Add 2 more items (total 7 > 6): shows 5 food items + '+2' badge in slot 5
      final item6 = CategoryFoodItem(id: '6', name: 'Eggs', category: 'Dairy', quantity: '6 pcs', expiryDays: 7);
      final item7 = CategoryFoodItem(id: '7', name: 'Cheese', category: 'Dairy', quantity: '200 g', expiryDays: 8);
      CookingBasketService.toggleItem(item6);
      CookingBasketService.toggleItem(item7);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CookingPanVisual(
                width: 340,
                height: 184,
                isExpanded: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Overflow indicator should show +2 (7 items total - 5 displayed = +2 overflow)
      expect(find.text('+2'), findsOneWidget);
      expect(find.byKey(const ValueKey('pan_overflow_badge')), findsOneWidget);
    });

    test('CookingPanVisual adaptive offsets math provides centered, non-overlapping layouts for counts 1 to 6', () {
      const double rx = 50.0;
      const double ry = 28.0;

      // 1 item: centered
      final off1 = CookingPanVisual.getAdaptiveOffsets(1, rx, ry);
      expect(off1.length, 1);
      expect(off1[0], const Offset(0.0, 0.0));

      // 2 items: balanced side by side
      final off2 = CookingPanVisual.getAdaptiveOffsets(2, rx, ry);
      expect(off2.length, 2);
      expect(off2[0].dx, lessThan(0));
      expect(off2[1].dx, greaterThan(0));
      expect(off2[0].dy, 0.0);
      expect(off2[1].dy, 0.0);

      // 3 items: balanced triangular
      final off3 = CookingPanVisual.getAdaptiveOffsets(3, rx, ry);
      expect(off3.length, 3);
      expect(off3[0].dy, lessThan(0)); // top center
      expect(off3[1].dy, greaterThan(0)); // bottom left
      expect(off3[2].dy, greaterThan(0)); // bottom right

      // 4 items: symmetric 2 x 2
      final off4 = CookingPanVisual.getAdaptiveOffsets(4, rx, ry);
      expect(off4.length, 4);
      expect(off4[0].dy, lessThan(0));
      expect(off4[1].dy, lessThan(0));
      expect(off4[2].dy, greaterThan(0));
      expect(off4[3].dy, greaterThan(0));

      // 5 items: 3 upper, 2 centered underneath
      final off5 = CookingPanVisual.getAdaptiveOffsets(5, rx, ry);
      expect(off5.length, 5);
      expect(off5[0].dy, lessThan(0));
      expect(off5[1].dy, lessThan(0));
      expect(off5[2].dy, lessThan(0));
      expect(off5[3].dy, greaterThan(0));
      expect(off5[4].dy, greaterThan(0));

      // 6 items: balanced 3 x 2
      final off6 = CookingPanVisual.getAdaptiveOffsets(6, rx, ry);
      expect(off6.length, 6);
      expect(off6.where((o) => o.dy < 0).length, 3);
      expect(off6.where((o) => o.dy > 0).length, 3);
    });

    testWidgets('Tapping empty pan in CookingWorkspaceScreen shows informative snackbar without opening carousel',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CookingWorkspaceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsNothing);

      // Tap the pan
      await tester.tap(find.byType(CookingPanVisual));
      await tester.pumpAndSettle();

      // Carousel is not opened
      expect(find.byType(PageView), findsNothing);
      // Informative SnackBar appears
      expect(find.text('Your pan is empty. Add ingredients to inspect them!'), findsOneWidget);
    });

    testWidgets('Tapping pan with ingredients in CookingWorkspaceScreen opens interactive carousel, supports swiping and tap-to-focus, and collapses on second tap',
        (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final itemA = CategoryFoodItem(id: '1', name: 'Brown Bread', category: 'Bakery', quantity: '1 pack', expiryDays: 3);
      final itemB = CategoryFoodItem(id: '2', name: 'Apples', category: 'Fruits', quantity: '1 kg', expiryDays: 5);
      CookingBasketService.toggleItem(itemA);
      CookingBasketService.toggleItem(itemB);

      await tester.pumpWidget(
        const MaterialApp(
          home: CookingWorkspaceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state: Carousel is closed
      expect(find.text('2 in pan · Tap to inspect'), findsOneWidget);
      expect(find.byType(PageView), findsNothing);

      // Tap the pan to open carousel
      await tester.tap(find.byType(CookingPanVisual));
      await tester.pumpAndSettle();

      // Carousel is now open
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('Tap pan to hide carousel'), findsOneWidget);
      expect(find.text('Brown Bread'), findsWidgets);
      expect(find.text('Apples'), findsWidgets);

      // Swipe PageView to next item
      await tester.drag(find.byType(PageView), const Offset(-200, 0));
      await tester.pumpAndSettle();

      // Tap pan again to collapse carousel
      await tester.tap(find.byType(CookingPanVisual));
      await tester.pumpAndSettle();

      // Carousel is collapsed
      expect(find.byType(PageView), findsNothing);
      expect(find.text('2 in pan · Tap to inspect'), findsOneWidget);
    });

    testWidgets('Clearing all ingredients while carousel is open cleanly resets carousel state',
        (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final item = CategoryFoodItem(id: '1', name: 'Apples', category: 'Fruits', quantity: '1 kg', expiryDays: 5);
      CookingBasketService.toggleItem(item);

      await tester.pumpWidget(
        const MaterialApp(
          home: CookingWorkspaceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Open carousel
      await tester.tap(find.byType(CookingPanVisual));
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsOneWidget);

      // Tap Clear all
      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();

      // Carousel collapses cleanly without errors
      expect(find.byType(PageView), findsNothing);
      expect(find.text('Your pan is ready'), findsOneWidget);
    });
  });
}
