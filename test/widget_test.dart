import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/main.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';

void main() {
  setUp(() {
    FridgeCategoryRepository.reset();
  });

  testWidgets('NutriFridge dashboard smoke test', (WidgetTester tester) async {
    // Set screen size to mobile 390x844
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const NutriFridgeApp());
    await tester.pumpAndSettle();

    // Verify Header
    expect(find.text('Good Evening, Ridhim 👋'), findsOneWidget);
    expect(find.text('Ready for a healthier day?'), findsOneWidget);

    // Verify Suggested for you
    expect(find.text('Suggested for you ✨'), findsOneWidget);
    expect(find.text('Paneer Rice Bowl'), findsOneWidget);
    expect(find.text('🧊 Uses 4 items from your fridge'), findsOneWidget);
    expect(find.text("💪 Helps complete today's protein goal"), findsOneWidget);

    // Verify Today's Wellness
    expect(find.text("Today's Wellness"), findsOneWidget);
    expect(find.text('82'), findsOneWidget);
    expect(find.text('Great today'), findsOneWidget);

    // Verify Nutrition Today
    expect(find.text('Nutrition Today'), findsOneWidget);
    expect(find.text('Protein'), findsOneWidget);
    expect(find.text('Carbs'), findsOneWidget);
    expect(find.text('Fat'), findsOneWidget);

    // Verify Today's Meals
    expect(find.text("Today's Meals"), findsOneWidget);
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('Snack'), findsOneWidget);
    expect(find.text('Dinner'), findsOneWidget);

    // Verify Navigation Bar items
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Fridge'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // Navigate to Fridge screen
    await tester.tap(find.text('Fridge'));
    await tester.pumpAndSettle();

    // Verify Fridge screen elements in closed state (dynamic total items and expiring count)
    expect(find.text('My Fridge'), findsOneWidget);
    expect(find.text('35 items'), findsOneWidget);
    expect(find.text('9 expiring soon'), findsOneWidget);
    expect(find.text('Tap to open'), findsNothing);
    expect(find.text('3°C  OPTIMAL'), findsNothing);
    expect(find.text('-18°C'), findsNothing);

    // Direct tap on lower refrigerator door to open
    await tester.tap(find.byKey(const ValueKey('fridge_door_touch_target')));
    await tester.pumpAndSettle();

    // Verify 8 main refrigerator category zones revealed
    expect(find.text('DAIRY PRODUCTS'), findsOneWidget);
    expect(find.text('OTHERS'), findsOneWidget);
    expect(find.text('NON-VEG'), findsOneWidget);
    expect(find.text('MEALS & LEFTOVERS'), findsOneWidget);
    expect(find.text('PACKAGED FOOD'), findsOneWidget);
    expect(find.text('DRINKS & JUICES'), findsOneWidget);
    expect(find.text('VEGETABLES'), findsOneWidget);
    expect(find.text('FRUITS'), findsOneWidget);

    // Direct tap on top freezer door to open
    await tester.tap(find.byKey(const ValueKey('freezer_door_touch_target')));
    await tester.pumpAndSettle();

    // Verify 3 top freezer category zones revealed
    expect(find.text('ICE CREAM'), findsOneWidget);
    expect(find.text('FROZEN FOOD'), findsOneWidget);
    expect(find.text('DRY FRUITS'), findsOneWidget);

    // Tap on DAIRY PRODUCTS category zone
    await tester.tap(find.text('DAIRY PRODUCTS'));
    await tester.pumpAndSettle();

    // Verify Dairy Products bottom sheet opens
    expect(find.text('🥛 Dairy Products'), findsOneWidget);
    expect(find.text('4 items'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('500 ml'), findsOneWidget);
    expect(find.text('Expires in 2 days'), findsOneWidget);
    expect(find.text('Paneer'), findsOneWidget);
    expect(find.text('250 g'), findsOneWidget);
    expect(find.text('Expires in 3 days'), findsOneWidget);
    expect(find.text('Curd'), findsOneWidget);
    expect(find.text('400 g'), findsOneWidget);
    expect(find.text('Expires in 5 days'), findsOneWidget);

    // Scroll to verify Butter in scrollable sheet
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(find.text('Butter'), findsOneWidget);
    expect(find.text('100 g'), findsOneWidget);
    expect(find.text('Expires in 8 days'), findsOneWidget);
    expect(find.text('Add Food'), findsOneWidget);

    // Scroll back to top
    await tester.drag(find.byType(ListView), const Offset(0, 120));
    await tester.pumpAndSettle();

    // Tap on Paneer to open Food Details Sheet
    await tester.tap(find.text('Paneer'));
    await tester.pumpAndSettle();

    // Verify Food Details Sheet opens layered above category sheet
    expect(find.text('Quantity'), findsOneWidget);
    expect(find.text('Use Food'), findsOneWidget);
    expect(find.text('Remove Food'), findsOneWidget);

    // Tap minus to decrease quantity from 250 g to 200 g, then to 150 g
    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.pumpAndSettle();
    expect(find.text('200 g'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.pumpAndSettle();
    expect(find.text('150 g'), findsOneWidget);

    // Tap "Use Food" to save and return to Category Bottom Sheet
    await tester.tap(find.text('Use Food'));
    await tester.pumpAndSettle();

    // Verify returned to Category Bottom Sheet and Paneer now displays updated 150 g
    expect(find.text('🥛 Dairy Products'), findsOneWidget);
    expect(find.text('150 g'), findsOneWidget);

    // Tap Close button to dismiss bottom sheet
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Verify sheet is closed and fridge remains in open state
    expect(find.text('Milk'), findsNothing);
    expect(find.text('DAIRY PRODUCTS'), findsOneWidget);
    expect(find.text('VEGETABLES'), findsOneWidget);

    // Reopen Dairy Products sheet to test Remove Food
    await tester.tap(find.text('DAIRY PRODUCTS'));
    await tester.pumpAndSettle();

    // Tap Paneer to open Food Details Sheet
    await tester.tap(find.text('Paneer'));
    await tester.pumpAndSettle();

    // Tap Remove Food to open confirmation dialog
    await tester.tap(find.text('Remove Food'));
    await tester.pumpAndSettle();

    // Verify confirmation dialog
    expect(find.text('Remove Paneer?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Paneer?'), findsNothing);

    // Tap Remove Food again and confirm Remove
    await tester.tap(find.text('Remove Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    // Verify item is removed and count updated to 3 items
    expect(find.text('3 items'), findsOneWidget);
    expect(find.text('Paneer'), findsNothing);

    // Close Category Bottom Sheet
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('DAIRY PRODUCTS'), findsOneWidget);
    expect(find.text('34 items'), findsOneWidget);
    expect(find.text('8 expiring soon'), findsOneWidget);
  });

  testWidgets('Quick Actions and Add Food - Single Food Flow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const NutriFridgeApp());
    await tester.pumpAndSettle();

    // 1. Tap center '+' button to open Quick Actions
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    // Verify Quick Actions sheet contents
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Add Food'), findsOneWidget);
    expect(find.text('Add something to your fridge'), findsOneWidget);
    expect(find.text('Log Meal'), findsOneWidget);
    expect(find.text('Record what you ate'), findsOneWidget);
    expect(find.text('AI Assistant'), findsOneWidget);
    expect(find.text('Ask NutriFridge anything'), findsOneWidget);

    // 2. Tap Add Food
    await tester.tap(find.text('Add Food'));
    await tester.pumpAndSettle();

    // Verify Add Food Page options
    expect(find.text('How would you like to add food?'), findsOneWidget);
    expect(find.text('Single Food'), findsOneWidget);
    expect(find.text('Multiple Foods'), findsOneWidget);
    expect(find.text('Grocery / Receipt'), findsOneWidget);
    expect(find.text('Manual Entry'), findsOneWidget);

    // 3. Tap Single Food
    await tester.tap(find.text('Single Food'));
    await tester.pumpAndSettle();

    expect(find.text('Single Food Scan'), findsOneWidget);
    expect(find.text('Take Photo'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);

    // Take photo
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();

    expect(find.text('Analyze Food'), findsOneWidget);

    // Analyze food
    await tester.tap(find.text('Analyze Food'));
    await tester.pump(); // starts analysis
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    // Verify detection result
    expect(find.text('Detection Result'), findsOneWidget);
    expect(find.text('Paneer'), findsOneWidget);
    expect(find.text('Detected Category'), findsOneWidget);
    expect(find.text('Estimated Quantity'), findsOneWidget);
    expect(find.text('250 g'), findsOneWidget);

    // Edit quantity via stepper: 250 g -> 300 g
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.text('300 g'), findsOneWidget);

    // Tap Add to Fridge
    await tester.tap(find.text('Add to Fridge'));
    await tester.pumpAndSettle();

    // Verify returned to main screen with snackbar
    expect(find.text('Added Paneer (300 g) to Dairy Products!'), findsOneWidget);
  });

  testWidgets('Quick Actions and Add Food - Manual Entry Flow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const NutriFridgeApp());
    await tester.pumpAndSettle();

    // 1. Open Quick Actions
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    // 2. Open Add Food
    await tester.tap(find.text('Add Food'));
    await tester.pumpAndSettle();

    // 3. Tap Manual Entry
    await tester.tap(find.text('Manual Entry'));
    await tester.pumpAndSettle();

    expect(find.text('Enter Food Details'), findsOneWidget);

    // 4. Test validation: clear food name and try submit
    await tester.tap(find.text('Add to Fridge'));
    await tester.pumpAndSettle();
    expect(find.text('Food name is required'), findsOneWidget);

    // 5. Enter food details
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && (w.decoration?.hintText?.contains('Greek Yogurt') ?? false),
      ),
      'Organic Strawberries',
    );
    await tester.pumpAndSettle();

    // Submit form
    await tester.tap(find.text('Add to Fridge'));
    await tester.pumpAndSettle();

    // Verify returned with success
    expect(find.text('Added Organic Strawberries (1 pieces) to Dairy Products!'), findsOneWidget);
  });

  testWidgets('Quick Actions - Log Meal and AI Assistant placeholders', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const NutriFridgeApp());
    await tester.pumpAndSettle();

    // Open Quick Actions
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    // Tap Log Meal
    await tester.tap(find.text('Log Meal'));
    await tester.pumpAndSettle();

    expect(find.text('This feature is coming soon! Stay tuned for upcoming updates.'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    // Reopen Quick Actions and test AI Assistant
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('AI Assistant'));
    await tester.pumpAndSettle();

    expect(find.text('This feature is coming soon! Stay tuned for upcoming updates.'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
  });

  testWidgets('Quick Actions and Add Food - Multiple Foods Flow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const NutriFridgeApp());
    await tester.pumpAndSettle();

    // 1. Open Quick Actions
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    // 2. Open Add Food
    await tester.tap(find.text('Add Food'));
    await tester.pumpAndSettle();

    // 3. Tap Multiple Foods
    await tester.tap(find.text('Multiple Foods'));
    await tester.pumpAndSettle();

    // Tap Take Photo & Analyze Foods
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Analyze Foods'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    // Verify detected 4 foods
    expect(find.text('Detected 4 foods'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Carrot'), findsOneWidget);

    // Tap Review & Add
    await tester.tap(find.text('Review & Add (4)'));
    await tester.pumpAndSettle();

    expect(find.text('Added 4 foods to your fridge!'), findsOneWidget);
  });

  testWidgets('Quick Actions and Add Food - Grocery Receipt Flow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const NutriFridgeApp());
    await tester.pumpAndSettle();

    // 1. Open Quick Actions
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    // 2. Open Add Food
    await tester.tap(find.text('Add Food'));
    await tester.pumpAndSettle();

    // 3. Tap Grocery / Receipt
    await tester.tap(find.text('Grocery / Receipt'));
    await tester.pumpAndSettle();

    // Tap Take Photo & Scan Receipt
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan Receipt'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    // Verify items found
    expect(find.text('Items Found'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    // Tap Add Selected to Fridge
    await tester.tap(find.text('Add Selected to Fridge'));
    await tester.pumpAndSettle();

    expect(find.text('Added 5 items to your fridge!'), findsOneWidget);
  });

  testWidgets('Complete Mock Fridge Inventory - All 11 Categories Populated & State Sync', (WidgetTester tester) async {
    // 1. Verify every single category in the repository has items (none empty)
    for (final categoryName in FridgeCategoryRepository.canonicalCategories) {
      final categoryData = FridgeCategoryRepository.getCategoryData(categoryName);
      expect(categoryData.itemCount, greaterThanOrEqualTo(2),
          reason: '$categoryName must contain at least 2 items initially');
    }

    // 2. Initial state counts
    expect(FridgeCategoryRepository.totalFridgeItems, equals(35));
    expect(FridgeCategoryRepository.expiringSoonCount, equals(9));

    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const NutriFridgeApp());
    await tester.pumpAndSettle();

    // Navigate to Fridge
    await tester.tap(find.text('Fridge'));
    await tester.pumpAndSettle();

    expect(find.text('35 items'), findsOneWidget);
    expect(find.text('9 expiring soon'), findsOneWidget);

    // Open lower fridge
    await tester.tap(find.byKey(const ValueKey('fridge_door_touch_target')));
    await tester.pumpAndSettle();

    // Tap on VEGETABLES
    await tester.tap(find.text('VEGETABLES'));
    await tester.pumpAndSettle();

    // Verify Vegetables bottom sheet shows 4 items
    expect(find.text('🥦 Vegetables'), findsOneWidget);
    expect(find.text('4 items'), findsOneWidget);
    expect(find.text('Tomato'), findsOneWidget);
    expect(find.text('Carrot'), findsOneWidget);
    expect(find.text('Broccoli'), findsOneWidget);

    // Close bottom sheet
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Add a new food item to Fruits
    FridgeCategoryRepository.addItemToCategory(
      'Fruits',
      const CategoryFoodItem(
        id: 'frt_mango',
        name: 'Mango',
        quantity: '2 pieces',
        expiryDays: 5,
        iconEmoji: '🥭',
      ),
    );
    await tester.pumpAndSettle();

    // Verify dynamic total count immediately updated to 36 items!
    expect(find.text('36 items'), findsOneWidget);

    // Tap on FRUITS
    await tester.tap(find.text('FRUITS'));
    await tester.pumpAndSettle();

    // Verify Fruits sheet now shows 5 items
    expect(find.text('🍎 Fruits'), findsOneWidget);
    expect(find.text('5 items'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Banana'), findsOneWidget);

    // Scroll to see 5th item (Mango)
    await tester.drag(find.byType(ListView), const Offset(0, -280));
    await tester.pumpAndSettle();
    expect(find.text('Mango'), findsOneWidget);

    // Close sheet
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
  });

  test('Item-specific food imagery verification across all categories', () {
    FridgeCategoryRepository.reset();

    // 1. Check all canonical categories
    for (final categoryName in FridgeCategoryRepository.canonicalCategories) {
      final categoryData = FridgeCategoryRepository.getCategoryData(categoryName);
      final items = categoryData.items;

      expect(items.isNotEmpty, isTrue, reason: '$categoryName should not be empty');

      final assetSet = <String>{};

      for (final item in items) {
        final asset = item.effectiveImageAsset;
        expect(asset, isNotNull, reason: '${item.name} in $categoryName must have an image');
        expect(asset!.isNotEmpty, isTrue);

        // Verify that NO item uses category collage images
        expect(asset.contains('categories/vegetables'), isFalse,
            reason: '${item.name} must not use vegetables category image');
        expect(asset.contains('categories/fruits'), isFalse,
            reason: '${item.name} must not use fruits category image');
        expect(asset.contains('categories/dairy_products'), isFalse,
            reason: '${item.name} must not use dairy category image');
        expect(asset.contains('categories/non_veg'), isFalse,
            reason: '${item.name} must not use non-veg category image');
        expect(asset.contains('categories/leftovers'), isFalse,
            reason: '${item.name} must not use leftovers category image');
        expect(asset.contains('categories/packaged_food'), isFalse,
            reason: '${item.name} must not use packaged food category image');
        expect(asset.contains('categories/juices'), isFalse,
            reason: '${item.name} must not use juices category image');
        expect(asset.contains('categories/ice_cream'), isFalse,
            reason: '${item.name} must not use ice cream category image');
        expect(asset.contains('categories/frozen_food'), isFalse,
            reason: '${item.name} must not use frozen food category image');
        expect(asset.contains('categories/dry_fruits'), isFalse,
            reason: '${item.name} must not use dry fruits category image');
        expect(asset.contains('categories/others'), isFalse,
            reason: '${item.name} must not use others category image');

        assetSet.add(asset);
      }

      // Ensure items within the category have distinct images
      expect(assetSet.length, equals(items.length),
          reason: 'Every item in $categoryName must have a distinct image');
    }

    // 2. Specific checks for Vegetables
    final veg = FridgeCategoryRepository.getCategoryData('Vegetables');
    final tomato = veg.items.firstWhere((it) => it.name == 'Tomato');
    final carrot = veg.items.firstWhere((it) => it.name == 'Carrot');
    final broccoli = veg.items.firstWhere((it) => it.name == 'Broccoli');
    final capsicum = veg.items.firstWhere((it) => it.name == 'Capsicum');

    expect(tomato.effectiveImageAsset, contains('tomato'));
    expect(carrot.effectiveImageAsset, contains('carrot'));
    expect(broccoli.effectiveImageAsset, contains('broccoli'));
    expect(capsicum.effectiveImageAsset, contains('capsicum'));

    // 3. Specific checks for Fruits
    final fruits = FridgeCategoryRepository.getCategoryData('Fruits');
    final apple = fruits.items.firstWhere((it) => it.name == 'Apple');
    final banana = fruits.items.firstWhere((it) => it.name == 'Banana');
    final orange = fruits.items.firstWhere((it) => it.name == 'Orange');
    final grapes = fruits.items.firstWhere((it) => it.name == 'Grapes');

    expect(apple.effectiveImageAsset, contains('apple'));
    expect(banana.effectiveImageAsset, contains('banana'));
    expect(orange.effectiveImageAsset, contains('orange'));
    expect(grapes.effectiveImageAsset, contains('grapes'));

    // 4. Test Add Food resolves specific image for Apple
    FridgeCategoryRepository.addItemToCategory(
      'Fruits',
      const CategoryFoodItem(
        id: 'test_apple',
        name: 'Crisp Apple',
        quantity: '2 pieces',
        expiryDays: 5,
      ),
    );
    final updatedFruits = FridgeCategoryRepository.getCategoryData('Fruits');
    final addedApple = updatedFruits.items.firstWhere((it) => it.id == 'test_apple');
    expect(addedApple.effectiveImageAsset, contains('apple'));
    expect(addedApple.effectiveImageAsset, isNot(contains('categories/fruits')));
  });
}
