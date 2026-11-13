import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nutrifridge/core/theme/app_colors.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/screens/ai_assistant/services/ai_assistant_service.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/screens/fridge/services/cooking_basket_service.dart';
import 'package:nutrifridge/screens/fridge/services/use_soon_service.dart';
import 'package:nutrifridge/screens/fridge/widgets/use_soon_section.dart';
import 'package:nutrifridge/screens/home/services/meal_recommendation_service.dart';
import 'package:nutrifridge/services/food_image/food_image_model.dart';
import 'package:nutrifridge/services/food_image/food_image_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fixedNow = DateTime(2026, 11, 14, 12, 0, 0);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MockDataRepository.forceInMemoryForTesting = true;
    MockDataRepository.reset();
    FridgeCategoryRepository.forceInMemoryForTesting = true;
    FridgeCategoryRepository.reset();
    UseSoonService.setClockProvider(() => fixedNow);
    FoodImageRepository.instance.clearMemoryCache();
    AiAssistantService.mockHandler = null;
  });

  tearDown(() {
    UseSoonService.resetClock();
    FridgeCategoryRepository.reset();
    AiAssistantService.mockHandler = null;
  });

  group('NutriFridge — Smart Fridge Intelligence v1: Use Soon', () {
    // 1. Ingredient expiring today appears first.
    test('1. Ingredient expiring today appears first', () {
      final itemTomorrow = CategoryFoodItem(
        id: 'spinach_tomorrow',
        name: 'Spinach',
        quantity: '1 bunch',
        expiryDate: fixedNow.add(const Duration(days: 1)), // Expires tomorrow (1)
        category: 'Vegetables',
      );

      final itemToday = CategoryFoodItem(
        id: 'apple_today',
        name: 'Apple',
        quantity: '2 pieces',
        expiryDate: fixedNow, // Expires today (0)
        category: 'Fruits',
      );

      final items = UseSoonService.getUseSoonItems(
        sourceItems: [itemTomorrow, itemToday],
        localNow: fixedNow,
      );

      expect(items.length, 2);
      expect(items.first.name, 'Apple'); // Expiring today must appear first
      expect(UseSoonService.getEffectiveExpiryDays(items.first, fixedNow), 0);
      expect(UseSoonService.getExpiryLabel(items.first, fixedNow), 'Expires today');
    });

    // 2. Ingredient expiring tomorrow appears next.
    test('2. Ingredient expiring tomorrow appears next', () {
      final itemIn3Days = CategoryFoodItem(
        id: 'milk_3d',
        name: 'Milk',
        quantity: '1 carton',
        expiryDate: fixedNow.add(const Duration(days: 3)), // Expires in 3 days (3)
        category: 'Dairy Products',
      );

      final itemTomorrow = CategoryFoodItem(
        id: 'paneer_tomorrow',
        name: 'Paneer',
        quantity: '200 g',
        expiryDate: fixedNow.add(const Duration(days: 1)), // Expires tomorrow (1)
        category: 'Dairy Products',
      );

      final itemToday = CategoryFoodItem(
        id: 'banana_today',
        name: 'Banana',
        quantity: '3 pieces',
        expiryDate: fixedNow, // Expires today (0)
        category: 'Fruits',
      );

      final items = UseSoonService.getUseSoonItems(
        sourceItems: [itemIn3Days, itemTomorrow, itemToday],
        localNow: fixedNow,
      );

      expect(items.length, 3);
      expect(items[0].name, 'Banana'); // Today first
      expect(items[1].name, 'Paneer'); // Tomorrow next
      expect(UseSoonService.getExpiryLabel(items[1], fixedNow), 'Expires tomorrow');
      expect(items[2].name, 'Milk'); // In 3 days after
    });

    // 3. Ingredient expiring in three days appears.
    test('3. Ingredient expiring in three days appears', () {
      final itemIn3Days = CategoryFoodItem(
        id: 'milk_3d',
        name: 'Milk',
        quantity: '1 carton',
        expiryDate: fixedNow.add(const Duration(days: 3)),
        category: 'Dairy Products',
      );

      final items = UseSoonService.getUseSoonItems(
        sourceItems: [itemIn3Days],
        localNow: fixedNow,
      );

      expect(items.length, 1);
      expect(items.first.name, 'Milk');
      expect(UseSoonService.getEffectiveExpiryDays(items.first, fixedNow), 3);
      expect(UseSoonService.getExpiryLabel(items.first, fixedNow), 'Expires in 3 days');
      expect(UseSoonService.getUseSoonCategory(items.first, fixedNow), UseSoonCategory.expiresIn3Days);
    });

    // 4. Ingredient expiring after three days does not appear.
    test('4. Ingredient expiring after three days does not appear', () {
      final itemIn4Days = CategoryFoodItem(
        id: 'carrot_4d',
        name: 'Carrot',
        quantity: '500 g',
        expiryDate: fixedNow.add(const Duration(days: 4)), // > 3 days
        category: 'Vegetables',
      );

      final itemIn7Days = CategoryFoodItem(
        id: 'capsicum_7d',
        name: 'Capsicum',
        quantity: '2 pieces',
        expiryDate: fixedNow.add(const Duration(days: 7)), // > 3 days
        category: 'Vegetables',
      );

      final itemIn3Days = CategoryFoodItem(
        id: 'tomato_3d',
        name: 'Tomato',
        quantity: '4 pieces',
        expiryDate: fixedNow.add(const Duration(days: 3)),
        category: 'Vegetables',
      );

      final items = UseSoonService.getUseSoonItems(
        sourceItems: [itemIn4Days, itemIn7Days, itemIn3Days],
        localNow: fixedNow,
      );

      expect(items.length, 1);
      expect(items.first.name, 'Tomato');
      expect(items.any((it) => it.name == 'Carrot'), isFalse);
      expect(items.any((it) => it.name == 'Capsicum'), isFalse);
    });

    // 5. Expired ingredients receive a distinct expired status.
    test('5. Expired ingredients receive a distinct expired status', () {
      final expiredYogurt = CategoryFoodItem(
        id: 'yogurt_exp',
        name: 'Yogurt',
        quantity: '1 tub',
        expiryDate: fixedNow.subtract(const Duration(days: 1)), // Expired yesterday (-1)
        category: 'Dairy Products',
      );

      final items = UseSoonService.getUseSoonItems(
        sourceItems: [expiredYogurt],
        localNow: fixedNow,
      );

      expect(items.length, 1);
      expect(items.first.name, 'Yogurt');
      expect(UseSoonService.getEffectiveExpiryDays(items.first, fixedNow), -1);
      expect(UseSoonService.getExpiryLabel(items.first, fixedNow), 'Already Expired');
      expect(UseSoonService.getUseSoonCategory(items.first, fixedNow), UseSoonCategory.alreadyExpired);

      final colors = UseSoonService.getUrgencyColors(items.first, fixedNow);
      expect(colors.text, const Color(0xFFB91C1C)); // Distinct warning red
      expect(colors.background, const Color(0xFFFEE2E2));
    });

    // 6. Ingredients without expiry dates are not assigned fabricated dates.
    test('6. Ingredients without expiry dates are not assigned fabricated dates', () {
      const mysteryItem = CategoryFoodItem(
        id: 'mystery_salt',
        name: 'Sea Salt',
        quantity: '1 pack',
        expiryDate: null,
        expiryDays: null,
        category: 'Others',
      );

      // Must return null for expiry calculations; never invent a date
      expect(UseSoonService.getEffectiveExpiryDays(mysteryItem, fixedNow), isNull);
      expect(UseSoonService.getExpiryLabel(mysteryItem, fixedNow), 'Expiry not set');
      expect(UseSoonService.getUseSoonCategory(mysteryItem, fixedNow), isNull);

      final items = UseSoonService.getUseSoonItems(
        sourceItems: [mysteryItem],
        localNow: fixedNow,
      );

      // Must be excluded from Use Soon section
      expect(items, isEmpty);
    });

    // 7. Zero-quantity ingredients are excluded.
    test('7. Zero-quantity ingredients are excluded', () {
      final zeroQtyApple = CategoryFoodItem(
        id: 'zero_apple',
        name: 'Apple',
        quantity: '0 pieces',
        expiryDate: fixedNow.add(const Duration(days: 1)),
        category: 'Fruits',
      );

      final zeroGramsCheese = CategoryFoodItem(
        id: 'zero_cheese',
        name: 'Cheese',
        quantity: '0 g',
        expiryDate: fixedNow,
        category: 'Dairy Products',
      );

      final validApple = CategoryFoodItem(
        id: 'valid_apple',
        name: 'Fresh Apple',
        quantity: '2 pieces',
        expiryDate: fixedNow.add(const Duration(days: 1)),
        category: 'Fruits',
      );

      final items = UseSoonService.getUseSoonItems(
        sourceItems: [zeroQtyApple, zeroGramsCheese, validApple],
        localNow: fixedNow,
      );

      expect(items.length, 1);
      expect(items.first.name, 'Fresh Apple');
      expect(items.any((it) => it.id == 'zero_apple'), isFalse);
      expect(items.any((it) => it.id == 'zero_cheese'), isFalse);
    });

    // 8. Quantities and units display correctly.
    testWidgets('8. Quantities and units display correctly in Use Soon cards', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testItems = [
        CategoryFoodItem(
          id: 'item_apple',
          name: 'Apple',
          quantity: '2 pieces',
          expiryDate: fixedNow.add(const Duration(days: 1)),
          category: 'Fruits',
        ),
        CategoryFoodItem(
          id: 'item_spinach',
          name: 'Spinach',
          quantity: '1 bunch',
          expiryDate: fixedNow,
          category: 'Vegetables',
        ),
        CategoryFoodItem(
          id: 'item_milk',
          name: 'Milk',
          quantity: '1 carton',
          expiryDate: fixedNow.add(const Duration(days: 3)),
          category: 'Dairy Products',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UseSoonSection(
              itemsOverride: testItems,
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify names and formatted quantity text exist
      expect(find.text('Use Soon'), findsOneWidget);
      expect(find.text('Make the most of your fresh ingredients.'), findsOneWidget);
      expect(find.text('Apple · 2 pieces', findRichText: true), findsOneWidget);
      expect(find.text('Spinach · 1 bunch', findRichText: true), findsOneWidget);
      expect(find.text('Milk · 1 carton', findRichText: true), findsOneWidget);
      expect(find.text('Expires today'), findsOneWidget);
      expect(find.text('Expires tomorrow'), findsOneWidget);
      expect(find.text('Expires in 3 days'), findsOneWidget);
    });

    // 9. Find Meals passes the correct expiring ingredients and available quantities.
    testWidgets('9. Find Meals passes the correct expiring ingredients and available quantities', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testExpiringItems = [
        CategoryFoodItem(
          id: 'spinach_1',
          name: 'Spinach',
          quantity: '1 bunch',
          expiryDate: fixedNow,
          category: 'Vegetables',
        ),
        CategoryFoodItem(
          id: 'paneer_1',
          name: 'Paneer',
          quantity: '200 g',
          expiryDate: fixedNow.add(const Duration(days: 1)),
          category: 'Dairy Products',
        ),
      ];

      // Expired item (should be excluded from recipe generation)
      final expiredMilk = CategoryFoodItem(
        id: 'milk_exp',
        name: 'Milk',
        quantity: '1 L',
        expiryDate: fixedNow.subtract(const Duration(days: 2)),
        category: 'Dairy Products',
      );

      final allUseSoonItems = [...testExpiringItems, expiredMilk];

      // Verify that edible expiring items collection excludes already expired food
      final edibleExpiring = UseSoonService.getEdibleExpiringItems(
        sourceItems: allUseSoonItems,
        localNow: fixedNow,
      );
      expect(edibleExpiring.length, 2);
      expect(edibleExpiring.map((it) => it.name).toList(), ['Spinach', 'Paneer']);

      bool findMealsCallbackCalled = false;
      Map<String, dynamic>? interceptedAiPayload;

      AiAssistantService.mockHandler = (request) async {
        interceptedAiPayload = request;
        return {
          'action': 'cook_recipe',
          'recipe': {
            'name': 'Palak Paneer Delight',
            'mealType': 'lunch',
            'description': 'A nutritious meal crafted to use your fresh spinach and paneer before expiry.',
            'calories': 420,
            'proteinG': 26,
            'carbsG': 18,
            'fatG': 15,
            'preparationTimeMinutes': 10,
            'cookingTimeMinutes': 15,
            'servingSize': '1 serving',
            'requiredIngredients': ['Spinach (1 bunch)', 'Paneer (200 g)'],
            'missingIngredients': [],
            'preparationSteps': ['Wash spinach', 'Sauté paneer with spices'],
          },
        };
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UseSoonSection(
              itemsOverride: allUseSoonItems,
              onFindMealsComplete: () {
                findMealsCallbackCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.pump();

      // Find Meals button is present
      final findMealsBtn = find.byKey(const ValueKey('find_meals_use_soon_btn'));
      expect(findMealsBtn, findsOneWidget);

      await tester.tap(findMealsBtn);
      await tester.pump();

      // Verified: AI request payload received the expiring items and available quantities
      expect(interceptedAiPayload, isNotNull);
      expect(interceptedAiPayload!['recipeMode'], 'selected_ingredients');
      expect(interceptedAiPayload!['message'], contains('Spinach'));
      expect(interceptedAiPayload!['message'], contains('Paneer'));
      expect(interceptedAiPayload!['message'], isNot(contains('Milk'))); // Expired item excluded!

      // Verified: Recipe recommendation was generated and set
      expect(MealRecommendationService.discoveryModeNotifier.value, MealDiscoveryMode.useMyIngredients);
      expect(MealRecommendationService.currentRecommendation, isNotNull);
      final generatedRec = MealRecommendationService.currentRecommendation!;
      expect(generatedRec.title, contains('Spinach'));
      expect(generatedRec.title, contains('Paneer'));
      expect(generatedRec.explanation, contains('Spinach'));
      expect(generatedRec.explanation, contains('Paneer'));
      expect(findMealsCallbackCalled, isTrue);
    });

    // 10. No-expiry-items state displays correctly.
    testWidgets('10. No-expiry-items state displays correctly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Pass empty list (no items expiring within 3 days)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UseSoonSection(
              itemsOverride: [],
            ),
          ),
        ),
      );

      await tester.pump();

      // Displays small, attractive fresh message
      expect(find.text('Your fridge is looking fresh!'), findsOneWidget);
      expect(find.text('Nothing needs attention right now.'), findsOneWidget);
      expect(find.text('🌱'), findsOneWidget);
      // No broken horizontal cards or Find Meals button rendered
      expect(find.byKey(const ValueKey('find_meals_use_soon_btn')), findsNothing);
    });

    // 11. Existing Fridge inventory remains unchanged.
    test('11. Existing Fridge inventory remains unchanged', () async {
      FridgeCategoryRepository.seedSampleDataForTesting();

      // Baseline total items in repository
      final initialTotal = FridgeCategoryRepository.totalFridgeItems;
      expect(initialTotal, greaterThan(0));

      final initialSnapshot = FridgeCategoryRepository.allItems.map((it) => '${it.id}:${it.name}:${it.quantity}').toList();

      // Query Use Soon items multiple times
      final useSoon1 = UseSoonService.getUseSoonItems(localNow: fixedNow);
      final useSoon2 = UseSoonService.getUseSoonItems(localNow: fixedNow);
      expect(useSoon1.length, useSoon2.length);

      // Verify that no inventory items were deleted, modified, or re-categorized
      final postTotal = FridgeCategoryRepository.totalFridgeItems;
      expect(postTotal, initialTotal);

      final postSnapshot = FridgeCategoryRepository.allItems.map((it) => '${it.id}:${it.name}:${it.quantity}').toList();
      expect(postSnapshot, equals(initialSnapshot));
    });
  });

  group('NutriFridge — Fix Stuck Ingredient Freshness Loading State', () {
    // 1. Freshness check completes when inventory is loaded.
    testWidgets('1. Freshness check completes when inventory is loaded', (WidgetTester tester) async {
      final item = const CategoryFoodItem(
        id: 'spinach_freshness_1',
        name: 'Spinach',
        quantity: '1 bunch',
        expiryDays: 0,
        category: 'Vegetables',
      );
      await FridgeCategoryRepository.addItemToCategory('Vegetables', item);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UseSoonSection(),
          ),
        ),
      );
      await tester.pump();

      // Freshness check completes immediately from loaded inventory
      expect(find.byKey(const ValueKey('use_soon_loading_banner')), findsNothing);
      expect(find.byKey(const ValueKey('use_soon_section_container')), findsOneWidget);
      expect(find.text('Spinach · 1 bunch', findRichText: true), findsOneWidget);
    });

    // 2. Loading banner disappears after successful calculation.
    testWidgets('2. Loading banner disappears after successful calculation', (WidgetTester tester) async {
      final completer = Completer<FreshnessCheckResult>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UseSoonSection(
              freshnessCheckOverride: () => completer.future,
            ),
          ),
        ),
      );
      await tester.pump();

      // Initially showing loading banner
      expect(find.byKey(const ValueKey('use_soon_loading_banner')), findsOneWidget);
      expect(find.text('Checking ingredient freshness...'), findsOneWidget);

      // Complete the async calculation
      completer.complete(
        const FreshnessCheckResult(
          status: FreshnessStatus.ready,
          expiringItems: [
            CategoryFoodItem(
              id: 'apple_freshness_1',
              name: 'Apple',
              quantity: '2 pieces',
              expiryDays: 1,
              category: 'Fruits',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Loading banner has disappeared
      expect(find.byKey(const ValueKey('use_soon_loading_banner')), findsNothing);
      expect(find.text('Apple · 2 pieces', findRichText: true), findsOneWidget);
    });

    // 3. Expiring ingredients appear correctly.
    testWidgets('3. Expiring ingredients appear correctly', (WidgetTester tester) async {
      const item1 = CategoryFoodItem(id: 'i1', name: 'Milk', quantity: '1 L', expiryDays: 1, category: 'Dairy Products');
      const item2 = CategoryFoodItem(id: 'i2', name: 'Paneer', quantity: '200 g', expiryDays: 2, category: 'Dairy Products');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UseSoonSection(
              itemsOverride: [item1, item2],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Milk · 1 L', findRichText: true), findsOneWidget);
      expect(find.text('Paneer · 200 g', findRichText: true), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // badge count
    });

    // 4. No-expiring-items state displays correctly.
    testWidgets('4. No-expiring-items state displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UseSoonSection(
              itemsOverride: [],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('use_soon_loading_banner')), findsNothing);
      expect(find.byKey(const ValueKey('use_soon_empty_banner')), findsOneWidget);
      expect(find.text('Your fridge is looking fresh!'), findsOneWidget);
      expect(find.text('Nothing needs attention right now.'), findsOneWidget);
    });

    // 5. Missing expiry dates are handled without inventing dates.
    test('5. Missing expiry dates are handled without inventing dates', () {
      const itemNoDate = CategoryFoodItem(
        id: 'item_no_date',
        name: 'Almonds',
        quantity: '100 g',
        expiryDays: null,
        expiryDate: null,
        category: 'Dry Fruits',
      );

      final result = UseSoonService.getEffectiveExpiryDays(itemNoDate);
      expect(result, isNull);

      final qualifying = UseSoonService.getUseSoonItems(sourceItems: [itemNoDate]);
      expect(qualifying, isEmpty);
    });

    // 6. Failed requests clear the loading state.
    testWidgets('6. Failed requests clear the loading state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UseSoonSection(
              freshnessCheckOverride: () async {
                throw Exception('Network disconnected');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Loading state is cleared, error banner is displayed
      expect(find.byKey(const ValueKey('use_soon_loading_banner')), findsNothing);
      expect(find.byKey(const ValueKey('use_soon_error_banner')), findsOneWidget);
      expect(find.byKey(const ValueKey('use_soon_retry_button')), findsOneWidget);
    });

    // 7. Retry works correctly.
    testWidgets('7. Retry works correctly', (WidgetTester tester) async {
      int attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UseSoonSection(
              freshnessCheckOverride: () async {
                attempts++;
                if (attempts == 1) {
                  return const FreshnessCheckResult(
                    status: FreshnessStatus.error,
                    errorMessage: 'Temporary network failure',
                  );
                }
                return const FreshnessCheckResult(
                  status: FreshnessStatus.ready,
                  expiringItems: [
                    CategoryFoodItem(
                      id: 'curd_freshness_1',
                      name: 'Curd',
                      quantity: '500 g',
                      expiryDays: 1,
                      category: 'Dairy Products',
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First attempt failed
      expect(find.byKey(const ValueKey('use_soon_error_banner')), findsOneWidget);
      expect(find.text('Temporary network failure'), findsOneWidget);

      // Tap Retry
      await tester.tap(find.byKey(const ValueKey('use_soon_retry_button')));
      await tester.pumpAndSettle();

      // Succeeded after retry
      expect(find.byKey(const ValueKey('use_soon_error_banner')), findsNothing);
      expect(find.byKey(const ValueKey('use_soon_loading_banner')), findsNothing);
      expect(find.text('Curd · 500 g', findRichText: true), findsOneWidget);
      expect(attempts, 2);
    });

    // 8. Widget rebuilds do not start duplicate requests.
    testWidgets('8. Widget rebuilds do not start duplicate requests', (WidgetTester tester) async {
      int checkCount = 0;
      final completer = Completer<FreshnessCheckResult>();

      final widget = MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Rebuild'),
                  ),
                  UseSoonSection(
                    freshnessCheckOverride: () {
                      checkCount++;
                      return completer.future;
                    },
                  ),
                ],
              );
            },
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pump();
      expect(checkCount, 1);

      // Trigger widget rebuild while check is in flight
      await tester.tap(find.text('Rebuild'));
      await tester.pump();
      expect(checkCount, 1); // Does not start duplicate concurrent request

      // Finish check
      completer.complete(const FreshnessCheckResult(status: FreshnessStatus.empty));
      await tester.pumpAndSettle();
      expect(checkCount, 1);
    });

    // 9. Existing inventory data remains unchanged.
    test('9. Existing inventory data remains unchanged', () async {
      FridgeCategoryRepository.seedSampleDataForTesting();
      final itemsBefore = FridgeCategoryRepository.allItems.map((e) => '${e.id}:${e.name}:${e.decimalAmount}').toList();

      final result = await UseSoonService.checkFreshness();
      expect(result.status, isIn([FreshnessStatus.ready, FreshnessStatus.empty]));

      final itemsAfter = FridgeCategoryRepository.allItems.map((e) => '${e.id}:${e.name}:${e.decimalAmount}').toList();
      expect(itemsAfter, equals(itemsBefore));
    });

    group('Smart Fridge Intelligence — Verify Genuine AI Recipe Generation', () {
      test('Controlled test inventory payload verification (Spinach 1d, Tomatoes 2d, Paneer 4d)', () async {
        // Setup controlled inventory:
        // Spinach (expires tomorrow: 1 day)
        // Tomatoes (expire in two days: 2 days)
        // Paneer (expires in four days: 4 days - not expiring soon)
        final spinach = CategoryFoodItem(
          id: 'spinach-uuid-001',
          name: 'Spinach',
          quantity: '1 bunch',
          category: 'Vegetables',
          expiryDate: fixedNow.add(const Duration(days: 1)),
        );
        final tomatoes = CategoryFoodItem(
          id: 'tomatoes-uuid-002',
          name: 'Tomatoes',
          quantity: '2 pieces',
          category: 'Vegetables',
          expiryDate: fixedNow.add(const Duration(days: 2)),
        );
        final paneer = CategoryFoodItem(
          id: 'paneer-uuid-003',
          name: 'Paneer',
          quantity: '250 g',
          category: 'Dairy Products',
          expiryDate: fixedNow.add(const Duration(days: 4)),
        );

        // Put into inventory
        await FridgeCategoryRepository.addItemToCategory('Vegetables', spinach);
        await FridgeCategoryRepository.addItemToCategory('Vegetables', tomatoes);
        await FridgeCategoryRepository.addItemToCategory('Dairy Products', paneer);

        // Get expiring items via UseSoonService
        final expiringItems = UseSoonService.getUseSoonItems(localNow: fixedNow);
        expect(expiringItems.length, 2);
        expect(expiringItems.map((e) => e.name), containsAll(['Spinach', 'Tomatoes']));
        expect(expiringItems.map((e) => e.name), isNot(contains('Paneer')));

        Map<String, dynamic>? capturedPayload;
        String? capturedMessage;

        AiAssistantService.mockHandler = (request) async {
          capturedMessage = request['message'];
          capturedPayload = request;

          return {
            'ok': true,
            'action': 'meal_recommendation',
            'meal': {
              'id': 'rec_spinach_tomato_paneer',
              'name': 'Spinach Tomato Paneer Curry',
              'description': 'A vibrant Indian curry prioritizing fresh spinach and ripe tomatoes.',
              'mealType': 'dinner',
              'calories': 380,
              'preparationTimeMinutes': 10,
              'cookingTimeMinutes': 20,
              'servings': '2 servings',
              'ingredients': [
                {'name': 'Spinach', 'quantity': '1 bunch', 'status': 'available', 'isAvailable': true},
                {'name': 'Tomatoes', 'quantity': '2 pieces', 'status': 'available', 'isAvailable': true},
                {'name': 'Paneer', 'quantity': '200 g', 'status': 'available', 'isAvailable': true},
                {'name': 'Cooking oil', 'quantity': '1 tbsp', 'status': 'pantry_staple', 'isAvailable': true},
                {'name': 'Cumin seeds', 'quantity': '1 tsp', 'status': 'pantry_staple', 'isAvailable': true},
                {'name': 'Salt', 'quantity': '1 tsp', 'status': 'pantry_staple', 'isAvailable': true},
              ],
              'missingIngredients': [],
              'preparationSteps': [
                {'stepNumber': 1, 'instruction': 'Wash and blanch the spinach leaves.'},
                {'stepNumber': 2, 'instruction': 'Chop the tomatoes and sauté with spices.'},
                {'stepNumber': 3, 'instruction': 'Puree the spinach and combine with tomatoes and paneer cubes.'},
              ],
              'cookingTips': ['Simmer gently to preserve spinach color.'],
              'substitutions': ['Tofu can be substituted for paneer.'],
            },
          };
        };

        final rec = await MealRecommendationService.findMealsForUseSoon(
          expiringItems: expiringItems,
        );

        // 1. Verify AI Integration & Payload
        expect(capturedPayload, isNotNull);
        expect(capturedPayload!['recipeMode'], 'selected_ingredients');
        expect(capturedPayload!['isUseSoon'], true);

        // Canonical names of ingredients approaching expiry
        final expiringInPayload = capturedPayload!['expiringIngredients'] as List;
        expect(expiringInPayload.length, 2);
        final expiringNames = expiringInPayload.map((e) => e['name']).toList();
        expect(expiringNames, containsAll(['Spinach', 'Tomatoes']));

        // Their actual available quantities and units
        final spinachEntry = expiringInPayload.firstWhere((e) => e['name'] == 'Spinach');
        expect(spinachEntry['quantity'], '1 bunch');
        expect(spinachEntry['unit'], 'bunch');

        final tomatoEntry = expiringInPayload.firstWhere((e) => e['name'] == 'Tomatoes');
        expect(tomatoEntry['quantity'], '2 pieces');
        expect(tomatoEntry['unit'], 'pieces');

        // Their expiry priority or urgency
        expect(spinachEntry['urgencyLabel'], 'Expires tomorrow');
        expect(spinachEntry['urgencyRank'], 1);
        expect(tomatoEntry['urgencyLabel'], 'Expires in 2 days');
        expect(tomatoEntry['urgencyRank'], 2);

        // Other available fridge ingredients
        final otherInPayload = capturedPayload!['otherAvailableFridgeIngredients'] as List;
        expect(otherInPayload.length, 1);
        expect(otherInPayload.first['name'], 'Paneer');
        expect(otherInPayload.first['quantity'], '250 g');
        expect(otherInPayload.first['unit'], 'g');

        // 2. Verify AI Prompt instructions
        expect(capturedMessage, isNotNull);
        // Prioritize ingredients approaching expiry
        expect(capturedMessage, contains('Prioritize ingredients approaching expiry'));
        // Prefer recipes that use multiple expiring ingredients together
        expect(capturedMessage, contains('Prefer recipes that use multiple expiring ingredients together'));
        // Respect available ingredient quantities
        expect(capturedMessage, contains('Respect available ingredient quantities'));
        // Avoid claiming unavailable ingredients are in the fridge
        expect(capturedMessage, contains('Avoid claiming unavailable ingredients are in the fridge'));
        // Suggest practical, genuinely cookable recipes
        expect(capturedMessage, contains('Suggest practical, genuinely cookable recipes'));
        // Never recommend using ingredients already marked expired
        expect(capturedMessage, contains('Never recommend using ingredients already marked expired'));
        // Allow reasonable pantry staples as additional ingredients
        expect(capturedMessage, contains('Allow reasonable pantry staples as additional ingredients where appropriate'));

        // 3. Verify Genuine Generation & Details
        expect(rec, isNotNull);
        expect(rec!.title, 'Spinach Tomato Paneer Curry');
        expect(rec.requiredIngredients.length, 6);
        expect(rec.requiredIngredients.join(', '), contains('Spinach'));
        expect(rec.requiredIngredients.join(', '), contains('Tomatoes'));
        expect(rec.requiredIngredients.join(', '), contains('Paneer'));
        expect(rec.calories, 380);
        expect(rec.preparationSteps.length, 3);
      });

      test('Gracefully propagates AI errors without synthetic fallback when live', () async {
        AiAssistantService.mockHandler = (request) async {
          return {
            'ok': false,
            'action': 'error',
            'assistantMessage': 'AI Assistant is currently overloaded. Please tap retry.',
          };
        };

        MockDataRepository.forceInMemoryForTesting = false;

        final rec = await MealRecommendationService.findMealsForUseSoon(
          expiringItems: [
            const CategoryFoodItem(
              id: 'spinach-1',
              name: 'Spinach',
              quantity: '1 bunch',
              category: 'Vegetables',
              expiryDays: 1,
            ),
          ],
        );

        // Does not return a synthetic recipe fallback
        expect(rec, isNull);
        // Clean error message is surfaced to CookingBasketService error notifier
        expect(
          CookingBasketService.generationErrorNotifier.value,
          'AI Assistant is currently overloaded. Please tap retry.',
        );
      });
    });
  });
}
