import 'package:nutrifridge/screens/splash/magic_fridge_splash.dart';
import 'package:nutrifridge/screens/home/widgets/dashboard_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/main.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/screens/log_meal/meal_analysis_screen.dart';
import 'package:nutrifridge/screens/log_meal/meal_nutrition_review_screen.dart';
import 'package:nutrifridge/screens/log_meal/models/detected_food_item.dart';

void main() {
  setUp(() {
    FridgeCategoryRepository.reset();
    MockDataRepository.reset();
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
    expect(find.byType(DashboardHeader), findsOneWidget);
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);

    // Verify Suggested for you
    expect(find.text('Suggested for you'), findsOneWidget);
    expect(find.text('Paneer Rice Bowl'), findsOneWidget);
    expect(find.text('Uses 4 items from your fridge'), findsOneWidget);
    expect(find.text("Helps complete today's protein goal"), findsOneWidget);

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

    // Tap Log Meal -> Opens LogMealScreen
    await tester.tap(find.text('Log Meal'));
    await tester.pumpAndSettle();

    expect(find.text('Log Meal'), findsOneWidget);
    expect(find.text("Let's see what you had."), findsOneWidget);
    expect(find.text('Capture your meal'), findsOneWidget);
    expect(find.text('Take Photo'), findsOneWidget);
    expect(find.text('Choose from Gallery'), findsOneWidget);
    expect(find.text('Analyze Meal'), findsOneWidget);

    // Return back
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    // Reopen Quick Actions and test AI Assistant placeholder
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

  testWidgets('Magic Fridge Splash Screen - Startup animation and dashboard navigation', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const NutriFridgeApp());

    // 1. Initial state: Splash Screen is present and Skip option is removed
    expect(find.byType(MagicFridgeSplashScreen), findsOneWidget);
    expect(find.text('Skip'), findsNothing);

    // 2. Advance time through the 4400ms animation
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    // 3. Splash has finished and navigated to Dashboard
    expect(find.byType(DashboardHeader), findsOneWidget);
    expect(find.byType(MagicFridgeSplashScreen), findsNothing);

    // 4. Switching tabs (e.g. to Fridge and back to Home) does not restart splash
    await tester.tap(find.text('Fridge'));
    await tester.pumpAndSettle();
    expect(find.text('My Fridge'), findsOneWidget);
    expect(find.byType(MagicFridgeSplashScreen), findsNothing);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardHeader), findsOneWidget);
    expect(find.byType(MagicFridgeSplashScreen), findsNothing);
  });

  testWidgets('Log Meal Screen 2 - Meal Analysis and portion adjustments', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // 1. Pump MealAnalysisScreen directly inside a MaterialApp
    await tester.pumpWidget(
      const MaterialApp(
        home: MealAnalysisScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 2. Verify Header elements
    expect(find.text('Review your meal'), findsOneWidget);
    expect(find.text('Check what we found and adjust the portions.'), findsOneWidget);

    // 3. Verify Default Meal Name and edit it
    expect(find.text('Paneer Rice Bowl'), findsOneWidget);
    await tester.tap(find.text('Paneer Rice Bowl'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Meal Name'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Roasted Paneer & Rice');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Roasted Paneer & Rice'), findsOneWidget);

    // 4. Verify initial detected food items
    expect(find.text('Detected foods'), findsOneWidget);
    expect(find.text('Paneer'), findsOneWidget);
    expect(find.text('100 g'), findsOneWidget);
    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('150 g'), findsOneWidget);
    expect(find.text('Vegetables'), findsOneWidget);
    expect(find.text('80 g'), findsOneWidget);

    // 5. Verify portion estimation disclaimer note
    expect(find.text('Portions are estimates. Review them before continuing.'), findsOneWidget);

    // 6. Edit portion of Paneer (tap edit on Paneer)
    await tester.tap(find.text('Paneer'));
    await tester.pumpAndSettle();

    // Bottom sheet for editing portion appears
    expect(find.text('Edit Portion — Paneer'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '125');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify updated portion
    expect(find.text('125 g'), findsOneWidget);

    // 7. Remove an item (tap remove icon for Vegetables, which is the 3rd item)
    expect(find.text('Vegetables'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove').at(2));
    await tester.pumpAndSettle();
    expect(find.text('Vegetables'), findsNothing);

    // 8. Add food item manually (Add food item button)
    await tester.tap(find.text('Add food item'));
    await tester.pumpAndSettle();

    expect(find.text('Add Food Item'), findsOneWidget);
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'Curd');
    await tester.enterText(textFields.at(1), '60');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Curd'), findsOneWidget);
    expect(find.text('60 g'), findsOneWidget);

    // 9. Tap "Review Nutrition" button navigating to Screen 3 placeholder
    expect(find.text('Review Nutrition'), findsOneWidget);
    await tester.tap(find.text('Review Nutrition'));
    await tester.pumpAndSettle();

    expect(find.byType(MealNutritionReviewPlaceholderScreen), findsOneWidget);
    expect(find.text('Nutrition Review'), findsOneWidget);
    expect(find.text('Roasted Paneer & Rice'), findsOneWidget);
  });

  testWidgets('Log Meal Screen 3 - Nutrition Review and Fridge Update Flow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // 1. Initial Fridge and Dashboard state check
    expect(MockDataRepository.nutrition.consumedCalories, 1620);
    expect(FridgeCategoryRepository.getCategoryData('Dairy Products').items.firstWhere((it) => it.name == 'Paneer').quantity, '250 g');

    // 2. Pump MealNutritionReviewScreen directly inside MaterialApp
    await tester.pumpWidget(
      MaterialApp(
        home: MealNutritionReviewScreen(
          mealName: 'Paneer Rice Bowl',
          detectedFoods: DetectedFoodItem.initialSampleDetection,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 3. Header verification
    expect(find.text('Your meal breakdown'), findsOneWidget);
    expect(find.text("Here's the estimated nutrition for your meal."), findsOneWidget);

    // 4. Meal Summary: rename meal
    expect(find.text('Paneer Rice Bowl'), findsOneWidget);
    await tester.tap(find.text('Paneer Rice Bowl'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Meal Name'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Delicious Paneer Rice Bowl');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Delicious Paneer Rice Bowl'), findsOneWidget);

    // 5. Meal Type Selector: select Dinner
    expect(find.text('Meal type'), findsOneWidget);
    expect(find.text('Dinner'), findsOneWidget);
    await tester.tap(find.text('Dinner'));
    await tester.pumpAndSettle();

    // 6. Calories & Macronutrients verification
    expect(find.text('Estimated Calories'), findsOneWidget);
    expect(find.text('520'), findsOneWidget);
    expect(find.text('kcal'), findsOneWidget);
    expect(find.text('Protein'), findsOneWidget);
    expect(find.text('24 g'), findsOneWidget);
    expect(find.text('Carbohydrates'), findsOneWidget);
    expect(find.text('62 g'), findsOneWidget);
    expect(find.text('Fat'), findsOneWidget);
    expect(find.text('18 g'), findsOneWidget);

    // 7. Ingredients detected verification
    expect(find.text('Ingredients detected'), findsOneWidget);
    expect(find.text('Paneer'), findsOneWidget);
    expect(find.text('100 g'), findsOneWidget);
    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('150 g'), findsOneWidget);
    expect(find.text('Vegetables'), findsOneWidget);
    expect(find.text('80 g'), findsOneWidget);
    expect(find.text('Edit ingredients'), findsOneWidget);

    // 8. Expandable More nutrition details
    await tester.ensureVisible(find.text('More nutrition details'));
    await tester.tap(find.text('More nutrition details'));
    await tester.pumpAndSettle();
    expect(find.text('Dietary Fiber'), findsOneWidget);
    expect(find.text('6.2 g'), findsOneWidget);
    expect(find.text('Sodium'), findsOneWidget);
    expect(find.text('380 mg'), findsOneWidget);

    // 9. Update your fridge section verification
    await tester.ensureVisible(find.text('Update your fridge'));
    expect(find.text('Update your fridge'), findsOneWidget);
    expect(find.text('Select ingredients that came from your tracked inventory.'), findsOneWidget);

    // Paneer should be matched in Dairy Products and checked by default
    expect(find.textContaining('Deducting 100 g (150 g remaining)'), findsOneWidget);

    // Rice & Vegetables are not tracked in fridge
    expect(find.text('Not tracked in fridge inventory'), findsNWidgets(2));

    // 10. Tap "Confirm & Log Meal"
    expect(find.text('Confirm & Log Meal'), findsOneWidget);
    await tester.tap(find.text('Confirm & Log Meal'));
    await tester.pumpAndSettle();

    // 11. Verify Nutrition Totals Updated in MockDataRepository
    // 1620 + 520 = 2140 kcal
    expect(MockDataRepository.nutrition.consumedCalories, 2140);
    // Protein: 72 + 24 = 96 g
    expect(MockDataRepository.nutrition.protein.amountGrams, 96);
    // Carbs: 210 + 62 = 272 g
    expect(MockDataRepository.nutrition.carbs.amountGrams, 272);
    // Fat: 62 + 18 = 80 g
    expect(MockDataRepository.nutrition.fat.amountGrams, 80);

    // 12. Verify Dinner was marked completed in meals list
    final dinnerMeal = MockDataRepository.meals.firstWhere((m) => m.name == 'Dinner');
    expect(dinnerMeal.isCompleted, isTrue);

    // 13. Verify Paneer deducted in FridgeCategoryRepository
    // 250 g - 100 g = 150 g
    final paneerItem = FridgeCategoryRepository.getCategoryData('Dairy Products').items.firstWhere((it) => it.name == 'Paneer');
    expect(paneerItem.quantity, '150 g');
  });
}