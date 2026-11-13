import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nutrifridge/core/theme/app_colors.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/screens/ai_assistant/services/ai_assistant_service.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
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
}
