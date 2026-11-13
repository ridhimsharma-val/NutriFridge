import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/screens/add_food/manual_entry_page.dart';
import 'package:nutrifridge/screens/ai_assistant/ai_assistant_screen.dart';
import 'package:nutrifridge/screens/ai_assistant/models/ai_message.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/screens/log_meal/models/cinematic_meal_data.dart';
import 'package:nutrifridge/screens/log_meal/widgets/cinematic_meal_logging_reveal_screen.dart';
import 'package:nutrifridge/services/food_image/food_image_model.dart';
import 'package:nutrifridge/services/food_image/food_image_repository.dart';
import 'package:nutrifridge/services/food_image/food_image_service.dart';

void main() {
  setUp(() {
    MockDataRepository.forceInMemoryForTesting = true;
    MockDataRepository.reset();
    FridgeCategoryRepository.reset();
    FoodImageService.instance.resetForTesting();
    CinematicMealLoggingRevealScreen.isShowing = false;
  });

  tearDown(() {
    MockDataRepository.reset();
    FridgeCategoryRepository.reset();
    FoodImageService.instance.resetForTesting();
    CinematicMealLoggingRevealScreen.isShowing = false;
  });

  group('NutriFridge — Simple Ingredient Addition Flow (No Cinematic Animation)', () {
    // 1. Adding one ingredient saves successfully
    testWidgets('1. Adding one ingredient saves successfully and displays compact snackbar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManualEntryPage(),
          ),
        ),
      );

      // Fill in manual entry form
      final nameField = find.widgetWithText(TextFormField, 'e.g., Greek Yogurt, Strawberries, Paneer');
      expect(nameField, findsOneWidget);
      await tester.enterText(nameField, 'Milk');

      final qtyField = find.widgetWithText(TextFormField, 'e.g., 250');
      expect(qtyField, findsOneWidget);
      await tester.enterText(qtyField, '1');

      // Submit
      final submitButton = find.widgetWithText(ElevatedButton, 'Add to Fridge');
      expect(submitButton, findsOneWidget);
      await tester.tap(submitButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify compact success snackbar appears
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Added Milk (1 pieces) to your fridge!'), findsOneWidget);

      // Verify saved in FridgeCategoryRepository
      final dairy = FridgeCategoryRepository.getCategoryData('Dairy Products').items;
      expect(dairy.any((item) => item.name == 'Milk'), isTrue);
    });

    // 2 & 3. Adding multiple ingredients saves successfully & inventory updates correctly
    testWidgets('2 & 3. Adding multiple ingredients saves successfully and updates inventory', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiAssistantScreen(),
          ),
        ),
      );

      await tester.pump();
      final dynamic state = tester.state(find.byType(AiAssistantScreen));

      // Simulate a message with proposed grocery additions
      final proposedMessage = AiChatMessage(
        id: 'msg_groceries_test',
        text: 'I found 2 items to add to your fridge:',
        isUser: false,
        timestamp: DateTime.now(),
        action: 'add_inventory_items',
        requiresConfirmation: true,
        inventoryItems: [
          {
            'name': 'Apple',
            'category': 'Fruits',
            'quantity': 2,
            'unit': 'pieces',
            'expiryDaysEstimate': 7,
          },
          {
            'name': 'Banana',
            'category': 'Fruits',
            'quantity': 4,
            'unit': 'pieces',
            'expiryDaysEstimate': 5,
          },
        ],
      );

      state.confirmAddInventoryForTesting(proposedMessage);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 4. Compact success notification appears
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Added Apples and bananas to your fridge!'), findsOneWidget);

      // Verify inventory updated
      final fruits = FridgeCategoryRepository.getCategoryData('Fruits').items;
      expect(fruits.any((i) => i.name.toLowerCase() == 'apple'), isTrue);
      expect(fruits.any((i) => i.name.toLowerCase() == 'banana'), isTrue);
    });

    // 5 & 6. No refrigerator animation appears and no summary screen opens
    testWidgets('5 & 6. No refrigerator animation appears and no summary screen opens', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiAssistantScreen(),
          ),
        ),
      );

      await tester.pump();
      final dynamic state = tester.state(find.byType(AiAssistantScreen));

      final message = AiChatMessage(
        id: 'msg_test_single',
        text: 'Added milk',
        isUser: false,
        timestamp: DateTime.now(),
        action: 'add_inventory_items',
        inventoryItems: [
          {
            'name': 'Milk',
            'category': 'Dairy Products',
            'quantity': 1,
            'unit': 'L',
            'expiryDaysEstimate': 5,
          },
        ],
      );

      state.confirmAddInventoryForTesting(message);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Strictly verify no full-screen modal/summary was pushed
      expect(find.text('Ingredient Addition Summary'), findsNothing);
      expect(find.text('Added to Fridge'), findsNothing);
      expect(find.text('Cold mist'), findsNothing);

      // Verify compact snackbar instead
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Added 1 L milk to your fridge!'), findsOneWidget);
    });

    // 7. Failed saves continue to display existing error handling
    testWidgets('7. Failed saves do not display success notification', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiAssistantScreen(),
          ),
        ),
      );

      await tester.pump();
      final dynamic state = tester.state(find.byType(AiAssistantScreen));

      // Empty inventory message (invalid / failed addition)
      final emptyMessage = AiChatMessage(
        id: 'msg_empty_test',
        text: 'Adding nothing',
        isUser: false,
        timestamp: DateTime.now(),
        action: 'add_inventory_items',
        inventoryItems: [],
      );

      state.confirmAddInventoryForTesting(emptyMessage);
      await tester.pump();

      // No success snackbar
      expect(find.byType(SnackBar), findsNothing);
    });

    // 8. Quantity and expiry information remain correct
    test('8. Quantity and expiry information remain correct on saved items', () {
      FridgeCategoryRepository.addOrMergeItem(
        categoryName: 'Vegetables',
        name: 'Broccoli',
        quantity: 500,
        unit: 'g',
        expiryDays: 6,
      );

      final veggies = FridgeCategoryRepository.getCategoryData('Vegetables').items;
      final broccoli = veggies.firstWhere((i) => i.name == 'Broccoli');

      expect(broccoli.decimalAmount, 500);
      expect(broccoli.unit, 'g');
      expect(broccoli.expiryDays, 6);
    });

    // 9. Pixabay food images continue working
    test('9. Pixabay food images continue working with ingredient additions', () async {
      final watermelonModel = FoodImageModel(
        entityType: FoodEntityType.ingredient,
        entityKey: 'watermelon',
        displayName: 'Watermelon',
        imageUrl: 'https://cdn.pixabay.com/photo/watermelon_slice.jpg',
        provider: 'pixabay',
      );
      FoodImageRepository.instance.putInMemoryCache(watermelonModel);

      FridgeCategoryRepository.addOrMergeItem(
        categoryName: 'Fruits',
        name: 'Watermelon',
        quantity: 1,
        unit: 'piece',
      );

      final fruits = FridgeCategoryRepository.getCategoryData('Fruits').items;
      final item = fruits.firstWhere((i) => i.name == 'Watermelon');

      expect(item.effectiveImageAsset, 'https://cdn.pixabay.com/photo/watermelon_slice.jpg');
      expect(item.effectiveImageAsset, isNot('assets/images/foods/apple.png'));
    });

    // 10. Meal Logging still opens its original pan-toss animation and nutrition summary screen
    testWidgets('10. Meal Logging retains its original cinematic animation and nutrition summary screen', (tester) async {
      final mealData = CinematicMealData(
        mealName: 'Banana Shake',
        mealType: 'Snack',
        servingSize: '1 glass',
        calories: 220,
        proteinGrams: 5,
        carbsGrams: 42,
        fatGrams: 3,
        ingredients: ['Banana', 'Milk', 'Honey'],
        loggedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CinematicMealLoggingRevealScreen(
              mealData: mealData,
            ),
          ),
        ),
      );

      // Initial pan-toss phase
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(CinematicMealLoggingRevealScreen), findsOneWidget);

      // Fast-forward animation to Scene 3 (Nutrition Reveal)
      await tester.pump(const Duration(milliseconds: 2500));

      // Verify Meal Nutrition Summary screen components are preserved
      expect(find.text('Banana Shake'), findsOneWidget);
      expect(find.text('Meal Logged Successfully'), findsOneWidget);
      expect(find.text('220'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('Fat'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });
  });
}
