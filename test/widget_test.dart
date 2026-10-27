import 'package:image_picker/image_picker.dart';
import 'package:nutrifridge/core/services/app_image_picker.dart';
import 'package:nutrifridge/screens/splash/magic_fridge_splash.dart';
import 'package:nutrifridge/screens/home/widgets/dashboard_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/main.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/screens/log_meal/meal_analysis_screen.dart';
import 'package:nutrifridge/screens/log_meal/meal_nutrition_review_screen.dart';
import 'package:nutrifridge/screens/log_meal/log_meal_screen.dart';
import 'package:nutrifridge/screens/add_food/single_food_scan_page.dart';
import 'package:nutrifridge/screens/log_meal/models/detected_food_item.dart';
import 'package:nutrifridge/screens/profile/widgets/edit_profile_dialog.dart';
import 'package:nutrifridge/models/notification_data.dart';
import 'package:nutrifridge/screens/home/widgets/recommendation_card.dart';
import 'package:nutrifridge/screens/fridge/models/fridge_preferences.dart';

void main() {
  setUp(() {
    FridgeCategoryRepository.reset();
    FridgePreferencesRepository.reset();
    MockDataRepository.reset();
    AppImagePicker.mockHandler = (source) async {
      return XFile.fromData(AppImagePicker.sampleMockBytes, name: 'test_photo.png');
    };
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

    // Verify Navigation Bar items (Design 06: Float - Icons only, no text labels)
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.kitchen_rounded), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);

    // Navigate to Fridge screen
    await tester.tap(find.byIcon(Icons.kitchen_rounded));
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
    await tester.tap(find.byIcon(Icons.kitchen_rounded));
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
    await tester.tap(find.byIcon(Icons.kitchen_rounded));
    await tester.pumpAndSettle();
    expect(find.text('My Fridge'), findsOneWidget);
    expect(find.byType(MagicFridgeSplashScreen), findsNothing);

    await tester.tap(find.byIcon(Icons.home_rounded));
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

  testWidgets('Camera and Gallery Independent Source Selection Test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    ImageSource? lastRequestedSource;

    // Handler recording requested source
    AppImagePicker.mockHandler = (source) async {
      lastRequestedSource = source;
      return XFile.fromData(AppImagePicker.sampleMockBytes, name: 'captured.png');
    };

    // --- A. Log Meal Screen Tests ---
    await tester.pumpWidget(
      const MaterialApp(
        home: LogMealScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Test "Take Photo" opens device camera
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();
    expect(lastRequestedSource, ImageSource.camera);
    // Captured photo appears in preview
    expect(find.byType(Image), findsOneWidget);

    // 2. Test "Choose from Gallery" opens gallery picker
    await tester.tap(find.text('Choose from Gallery'));
    await tester.pumpAndSettle();
    expect(lastRequestedSource, ImageSource.gallery);
    expect(find.byType(Image), findsOneWidget);

    // 3. Test cancellation: returns null, preview remains intact
    AppImagePicker.mockHandler = (source) async {
      lastRequestedSource = source;
      return null; // User cancelled
    };
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();
    expect(lastRequestedSource, ImageSource.camera);
    // Preview is NOT erased on cancellation
    expect(find.byType(Image), findsOneWidget);

    // --- B. Add Food — Single Food Scan Tests ---
    AppImagePicker.mockHandler = (source) async {
      lastRequestedSource = source;
      return XFile.fromData(AppImagePicker.sampleMockBytes, name: 'food.png');
    };

    await tester.pumpWidget(
      const MaterialApp(
        home: SingleFoodScanPage(),
      ),
    );
    await tester.pumpAndSettle();

    // 4. Test "Take Photo" opens camera
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();
    expect(lastRequestedSource, ImageSource.camera);
    expect(find.text('Analyze Food'), findsOneWidget);

    // 5. Test "Gallery" opens gallery picker
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    expect(lastRequestedSource, ImageSource.gallery);
    expect(find.text('Analyze Food'), findsOneWidget);

    // 6. Test cancellation in Single Food: preview remains intact
    AppImagePicker.mockHandler = (source) async {
      lastRequestedSource = source;
      return null; // Cancelled
    };
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();
    expect(lastRequestedSource, ImageSource.camera);
    expect(find.text('Analyze Food'), findsOneWidget);
  });

  testWidgets('Complete End-to-End Log Meal Flow with Dynamic Nutrition and Inventory Adjustment', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      AppImagePicker.mockHandler = null;
    });

    // Reset shared state
    MockDataRepository.reset();
    FridgeCategoryRepository.reset();

    AppImagePicker.mockHandler = (source) async {
      return XFile.fromData(AppImagePicker.sampleMockBytes, name: 'captured_meal.png');
    };

    // 1. Pump full Dashboard
    await tester.pumpWidget(const NutriFridgeApp());
    await tester.pumpAndSettle();

    expect(find.text("Today's Meals"), findsOneWidget);
    expect(MockDataRepository.nutrition.consumedCalories, 1620);
    expect(FridgeCategoryRepository.getCategoryData('Dairy Products').items.firstWhere((it) => it.name == 'Paneer').quantity, '250 g');

    // 2. Open Quick Actions sheet
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    // 3. Tap "Log Meal"
    expect(find.text('Log Meal'), findsOneWidget);
    await tester.tap(find.text('Log Meal'));
    await tester.pumpAndSettle();

    expect(find.text("Let's see what you had."), findsOneWidget);
    expect(find.text('Analyze Meal'), findsOneWidget);

    // 4. Capture meal photo
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);

    // 5. Tap "Analyze Meal" -> Screen 2 (Meal Analysis)
    await tester.tap(find.text('Analyze Meal'));
    await tester.pumpAndSettle();

    expect(find.text('Review your meal'), findsOneWidget);
    expect(find.text('Paneer Rice Bowl'), findsOneWidget);
    expect(find.text('Paneer'), findsOneWidget);
    expect(find.text('100 g'), findsOneWidget);

    // 6. Edit Meal Name to "Chef Special Bowl"
    await tester.tap(find.text('Paneer Rice Bowl'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Chef Special Bowl');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Chef Special Bowl'), findsOneWidget);

    // 7. Edit Paneer portion from 100 g to 200 g
    await tester.tap(find.text('Paneer'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Portion — Paneer'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '200');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('200 g'), findsOneWidget);

    // 8. Tap "Review Nutrition" -> Screen 3 (Nutrition Review)
    await tester.tap(find.text('Review Nutrition'));
    await tester.pumpAndSettle();

    expect(find.text('Your meal breakdown'), findsOneWidget);
    expect(find.text('Chef Special Bowl'), findsOneWidget);

    // Dynamic nutrition should reflect 200g Paneer (530) + 150g Rice (195) + 80g Veg (60) = 785 kcal
    expect(find.text('785'), findsOneWidget);
    expect(find.text('42 g'), findsOneWidget); // Protein: 36 + 4 + 2 = 42 g
    expect(find.text('66 g'), findsOneWidget); // Carbs: 8 + 45 + 13 = 66 g
    expect(find.text('33 g'), findsOneWidget); // Fat: 30 + 0.5 + 2.5 = 33 g

    // 9. Test Back Navigation from Screen 3 to Screen 2
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Review your meal'), findsOneWidget);
    expect(find.text('Chef Special Bowl'), findsOneWidget);
    expect(find.text('200 g'), findsOneWidget);

    // Re-advance to Screen 3
    await tester.tap(find.text('Review Nutrition'));
    await tester.pumpAndSettle();
    expect(find.text('Your meal breakdown'), findsOneWidget);

    // 10. Check "Update your fridge": Paneer 200 g matches Dairy Products (250 g available)
    await tester.ensureVisible(find.text('Update your fridge'));
    expect(find.textContaining('Deducting 200 g (50 g remaining)'), findsOneWidget);

    // 11. Confirm & Log Meal
    await tester.ensureVisible(find.text('Confirm & Log Meal'));
    await tester.tap(find.text('Confirm & Log Meal'));
    await tester.pumpAndSettle();

    // 12. Returned to Dashboard
    expect(find.text("Today's Meals"), findsOneWidget);

    // Verify MockDataRepository updated: 1620 + 785 = 2405 kcal
    expect(MockDataRepository.nutrition.consumedCalories, 2405);
    expect(MockDataRepository.nutrition.protein.amountGrams, 72 + 42);
    expect(MockDataRepository.nutrition.carbs.amountGrams, 210 + 66);
    expect(MockDataRepository.nutrition.fat.amountGrams, 62 + 33);
    expect(MockDataRepository.loggedMealsHistory.length, 1);
    expect(MockDataRepository.loggedMealsHistory.first['mealName'], 'Chef Special Bowl');

    // Verify FridgeCategoryRepository updated: Paneer reduced from 250 g to 50 g
    final updatedPaneer = FridgeCategoryRepository.getCategoryData('Dairy Products').items.firstWhere((it) => it.name == 'Paneer');
    expect(updatedPaneer.quantity, '50 g');
  });

  testWidgets('Progress Screen - Cinematic Data Visualization & Live Sync', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    MockDataRepository.reset();
    FridgeCategoryRepository.reset();

    // 1. Pump App and Settle
    await tester.pumpWidget(const NutriFridgeApp());
    await tester.pumpAndSettle();

    // 2. Tap on "Progress" in Bottom Navigation
    expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.bar_chart_rounded));
    await tester.pumpAndSettle();

    // 3. Verify Header and Subtitle
    expect(find.text('Your nutrition, over time.'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);

    // 4. Verify Cinematic Wellness Hero
    expect(find.text('WELLNESS SCORE'), findsOneWidget);
    expect(find.text('out of 100'), findsOneWidget);
    expect(find.text('NutriFridge wellness indicator • Not a medical assessment'), findsOneWidget);

    // 5. Verify Macronutrient Donut Chart
    expect(find.text('Calorie distribution by macro'), findsOneWidget);
    expect(find.text('Protein'), findsWidgets);
    expect(find.text('Carbs'), findsWidgets);
    expect(find.text('Fat'), findsWidgets);

    // 6. Verify Weekly Calories Bar Chart & Day Interactivity
    await tester.ensureVisible(find.text('Calories through the week'));
    expect(find.text('Calories through the week'), findsOneWidget);
    expect(find.text('Target: 2200'), findsOneWidget);
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Tue'), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);

    // Tap on Monday bar
    await tester.tap(find.text('Mon'));
    await tester.pumpAndSettle();
    expect(find.text('Monday, Oct 20'), findsOneWidget);
    expect(find.text('1980 kcal • 3 meals logged'), findsOneWidget);

    // 7. Verify LeetCode-style Consistency Heatmap
    await tester.ensureVisible(find.text('Meal logging consistency'));
    expect(find.text('Meal logging consistency'), findsOneWidget);
    expect(find.text('Your meal activity'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3+'), findsOneWidget);
    expect(find.textContaining('Meals logged on'), findsOneWidget);

    // 8. Verify Removed Sections are NOT present
    expect(find.text('Nutrition trends'), findsNothing);
    expect(find.text('Your week in food'), findsNothing);

    // 9. Switch Period to "Month"
    await tester.ensureVisible(find.text('Month'));
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(find.text('Weekly averages this month'), findsOneWidget);
    expect(find.text('W1'), findsOneWidget);
    expect(find.text('W4'), findsOneWidget);
  });

  testWidgets('NutriFridge Profile Screen - Preferences, Restrictions, Toggles & Session Persistence', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    MockDataRepository.reset();
    FridgeCategoryRepository.reset();

    // 1. Pump App and Settle
    await tester.pumpWidget(const NutriFridgeApp());
    await tester.pumpAndSettle();

    // 2. Tap on "Profile" in Bottom Navigation
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.person_rounded));
    await tester.pumpAndSettle();

    // 3. Verify Header Title and Subtitle
    expect(find.text('Your food preferences and personal settings.'), findsOneWidget);

    // 4. Verify Profile Header Card
    expect(find.text('Ridhim'), findsOneWidget);
    expect(find.text('R'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);

    // Test Edit Profile Dialog
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Profile'), findsOneWidget);

    // Enter new name "Alex Morgan"
    final nameField = find.descendant(
      of: find.byType(EditProfileDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(nameField, 'Alex Morgan');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(find.text('AM'), findsOneWidget);

    // 5. Verify Compact Nutrition Preferences Card & Popup
    await tester.ensureVisible(find.text('Nutrition preferences'));
    expect(find.text('Nutrition preferences'), findsOneWidget);
    // Initial summary
    expect(find.text('Vegetarian · Balanced eating'), findsOneWidget);
    expect(find.text('Daily target: 2,200 kcal'), findsOneWidget);

    // Tap to open Nutrition Preferences Popup
    await tester.tap(find.text('Nutrition preferences'));
    await tester.pumpAndSettle();

    // Verify popup controls are visible
    expect(find.text('Dietary preference'), findsOneWidget);
    expect(find.text('Vegan'), findsOneWidget);

    // Select "Vegan"
    await tester.tap(find.text('Vegan'));
    await tester.pumpAndSettle();

    // Select Nutrition Goal: "Increase protein intake"
    await tester.tap(find.text('Increase protein intake'));
    await tester.pumpAndSettle();

    // Edit Calorie Target
    final calorieFinder = find.widgetWithText(TextField, '2200');
    expect(calorieFinder, findsOneWidget);
    await tester.enterText(calorieFinder, '2400');
    await tester.pumpAndSettle();

    // Save and verify popup closes
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify summary card immediately updated on main page
    expect(find.text('Vegan · Increase protein intake'), findsOneWidget);
    expect(find.text('Daily target: 2,400 kcal'), findsOneWidget);
    expect(MockDataRepository.profile.dietaryPreference, 'Vegan');
    expect(MockDataRepository.profile.nutritionGoal, 'Increase protein intake');
    expect(MockDataRepository.profile.dailyCalorieTarget, 2400);

    // Test Cancel on Nutrition Preferences popup preserves saved state
    await tester.tap(find.text('Nutrition preferences'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Non-vegetarian'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(MockDataRepository.profile.dietaryPreference, 'Vegan');
    expect(find.text('Vegan · Increase protein intake'), findsOneWidget);

    // 6. Verify Compact Dietary Restrictions Card & Popup
    await tester.ensureVisible(find.text('Dietary restrictions'));
    expect(find.text('Dietary restrictions'), findsOneWidget);
    // Initial summary
    expect(find.text('No restrictions selected'), findsOneWidget);

    // Tap to open Dietary Restrictions Popup
    await tester.tap(find.text('Dietary restrictions'));
    await tester.pumpAndSettle();

    // Verify popup controls are visible
    expect(find.text('Food allergies'), findsOneWidget);
    expect(find.text('Foods you avoid'), findsOneWidget);

    // Toggle Allergy: "Peanuts"
    await tester.tap(find.text('Peanuts'));
    await tester.pumpAndSettle();

    // Toggle Avoided Food: "Refined sugar"
    await tester.tap(find.text('Refined sugar'));
    await tester.pumpAndSettle();

    // Add Custom Restriction: "Cilantro"
    final customField = find.widgetWithText(TextField, 'e.g. Cilantro, Bell peppers');
    await tester.ensureVisible(customField);
    await tester.enterText(customField, 'Cilantro');
    await tester.ensureVisible(find.text('Add'));
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Cilantro'), findsOneWidget);

    // Remove Custom Restriction: "Cilantro"
    await tester.ensureVisible(find.byIcon(Icons.close_rounded).last);
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();

    // Tap Save and close popup
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify summary card updated on main page
    expect(find.text('1 allergy · 1 food avoided'), findsOneWidget);
    expect(MockDataRepository.profile.allergies.contains('Peanuts'), isTrue);
    expect(MockDataRepository.profile.avoidedFoods.contains('Refined sugar'), isTrue);
    expect(MockDataRepository.profile.customRestrictions.contains('Cilantro'), isFalse);

    // Test Cancel on Dietary Restrictions popup preserves saved state
    await tester.tap(find.text('Dietary restrictions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shellfish'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(MockDataRepository.profile.allergies.contains('Shellfish'), isFalse);
    expect(find.text('1 allergy · 1 food avoided'), findsOneWidget);

    // 7. Verify App Preferences (Switches)
    await tester.ensureVisible(find.text('App preferences'));
    expect(find.text('Meal reminders'), findsOneWidget);
    expect(find.text('Remind me to log meals.'), findsOneWidget);
    expect(find.text('Expiry alerts'), findsOneWidget);
    expect(find.text('Notify me when tracked food is nearing expiry.'), findsOneWidget);

    // Toggle Meal reminders switch
    final mealSwitchFinder = find.byType(Switch).first;
    await tester.tap(mealSwitchFinder);
    await tester.pumpAndSettle();
    expect(MockDataRepository.profile.mealRemindersEnabled, isFalse);

    // 8. Verify Removed About & Privacy Section
    expect(find.text('About NutriFridge'), findsNothing);
    expect(find.text('Privacy & data'), findsNothing);

    // 9. Session Persistence Across Screen Navigation
    // Switch to Home screen
    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Today\'s Meals'), findsOneWidget);

    // Return to Profile screen
    await tester.tap(find.byIcon(Icons.person_rounded));
    await tester.pumpAndSettle();

    // Confirm all settings were retained!
    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(find.text('AM'), findsOneWidget);
    expect(MockDataRepository.profile.dietaryPreference, 'Vegan');
    expect(MockDataRepository.profile.nutritionGoal, 'Increase protein intake');
    expect(MockDataRepository.profile.dailyCalorieTarget, 2400);
    expect(MockDataRepository.profile.mealRemindersEnabled, isFalse);
  });

  testWidgets('Home Screen - Notification Popover, Expandable Wellness & Expandable Nutrition Breakdown', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    FridgeCategoryRepository.reset();
    MockDataRepository.reset();
    NotificationRepository.reset();

    // 1. Pump App and Settle on Home Screen
    await tester.pumpWidget(const NutriFridgeApp());
    await tester.pumpAndSettle();

    // 2. Notification Bell Interaction → Popover Card
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    expect(NotificationRepository.unreadCount, greaterThan(0));

    // Tap notification bell
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    // Verify Notification Popover is visible
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Food expiring soon'), findsOneWidget);
    expect(find.text('Meal logged'), findsOneWidget);
    expect(find.text('Mark all read'), findsOneWidget);

    // Tap "Mark all read"
    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();
    expect(NotificationRepository.unreadCount, 0);

    // Close Popover
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsNothing);

    // 3. Today's Wellness Expandable Card Interaction
    expect(find.text("Today's Wellness"), findsOneWidget);
    expect(find.text('7-day wellness trend'), findsNothing);

    // Tap to expand Today's Wellness
    await tester.tap(find.text("Today's Wellness"));
    await tester.pumpAndSettle();

    // Verify Expanded Wellness Content
    expect(find.text('7-day wellness trend'), findsOneWidget);
    expect(find.text("Today's contributing factors"), findsOneWidget);
    expect(find.text('Protein intake'), findsOneWidget);
    expect(find.text('Food variety'), findsOneWidget);
    expect(find.text('Meal consistency'), findsOneWidget);
    expect(find.text('NutriFridge wellness indicator · Not a medical assessment'), findsOneWidget);

    // Tap on Friday in the 7-day trend
    await tester.tap(find.text('Fri'));
    await tester.pumpAndSettle();
    expect(find.text('Fri: 85 pts'), findsOneWidget);

    // Tap to collapse Today's Wellness
    await tester.tap(find.text("Today's Wellness"));
    await tester.pumpAndSettle();
    expect(find.text('7-day wellness trend'), findsNothing);

    // 4. Nutrition Today Expandable Breakdown Interaction
    expect(find.text('Nutrition Today'), findsOneWidget);
    expect(find.text("Today's meals"), findsNothing);

    // Tap "See" to expand Nutrition Today
    await tester.tap(find.text('See'));
    await tester.pumpAndSettle();

    // Verify Expanded Nutrition Content
    expect(find.text('Daily calorie summary'), findsOneWidget);
    expect(find.text("Today's meals"), findsOneWidget);
    expect(find.text('Oats & Banana'), findsOneWidget);
    expect(find.text('Paneer Rice Bowl'), findsNWidgets(2));
    expect(find.text('Target progress & remaining'), findsOneWidget);
    expect(find.text('Collapse'), findsOneWidget);

    // Tap "Collapse" to collapse Nutrition Today
    await tester.tap(find.text('Collapse'));
    await tester.pumpAndSettle();
    expect(find.text("Today's meals"), findsNothing);

    // 5. Dual Independent Expansion
    // Expand Wellness
    await tester.tap(find.text("Today's Wellness"));
    await tester.pumpAndSettle();

    // Expand Nutrition
    await tester.ensureVisible(find.text('Nutrition Today'));
    await tester.tap(find.text('Nutrition Today'));
    await tester.pumpAndSettle();

    // Both are expanded simultaneously without conflict
    expect(find.text('7-day wellness trend'), findsOneWidget);
    expect(find.text("Today's meals"), findsOneWidget);

    // Collapse Wellness, Nutrition remains expanded
    await tester.ensureVisible(find.text("Today's Wellness"));
    await tester.tap(find.text("Today's Wellness"));
    await tester.pumpAndSettle();

    expect(find.text('7-day wellness trend'), findsNothing);
    expect(find.text("Today's meals"), findsOneWidget);
  });

  testWidgets('Meal Detail Page - Cinematic Food Experience, Nutrition, Fridge Ingredients, AI Context & Video Inspiration', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    FridgeCategoryRepository.reset();
    MockDataRepository.reset();
    NotificationRepository.reset();

    // 1. Pump App and Settle on Dashboard
    await tester.pumpWidget(const NutriFridgeApp());
    await tester.pumpAndSettle();

    // Verify Suggested for You recommendation card is visible
    expect(find.text('Suggested for you'), findsOneWidget);
    expect(find.text('Paneer Rice Bowl'), findsWidgets);

    // Verify Hero widget with matching tag exists on recommendation card
    final heroFinder = find.byWidgetPredicate(
      (w) => w is Hero && w.tag == 'meal-hero-image-paneer-rice-bowl',
    );
    expect(heroFinder, findsOneWidget);

    // 2. Tap on the Recommendation Card -> Navigate to MealDetailScreen
    await tester.tap(find.byType(RecommendationCard));
    await tester.pumpAndSettle();

    // Verify Hero widget on destination has matching tag
    expect(heroFinder, findsOneWidget);

    // 3. Verify Hero Section
    expect(find.text('Picked for your fridge'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

    // 4. Verify Meal Information & Nutrition Overview
    expect(find.text('Nutrition & prep'), findsOneWidget);
    expect(find.text('20 mins prep'), findsOneWidget);
    expect(find.text('520'), findsOneWidget);
    expect(find.text('kcal'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
    expect(find.text('Protein'), findsOneWidget);
    expect(find.text('62'), findsOneWidget);
    expect(find.text('Carbs'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('Fat'), findsOneWidget);

    // 5. Verify "Why this meal?"
    expect(find.text('Why this meal?'), findsOneWidget);
    expect(find.text('Uses 4 ingredients from your fridge'), findsOneWidget);
    expect(find.text("Helps support today's protein goal"), findsOneWidget);

    // 6. Verify Ingredients & Real-time Shared Inventory
    expect(find.text('Ingredients'), findsOneWidget);
    expect(find.text('4 items'), findsOneWidget);
    expect(find.text('Paneer'), findsOneWidget);
    expect(find.text('In fridge · 250 g'), findsOneWidget);
    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('Available in pantry'), findsOneWidget);
    expect(find.text('Capsicum'), findsOneWidget);
    expect(find.text('In fridge · 3 pieces'), findsOneWidget);
    expect(find.text('Onion'), findsOneWidget);
    expect(find.text('Not in fridge'), findsOneWidget);

    // 7. Verify AI Cooking Section ("Cook it your way")
    expect(find.text('Cook it your way'), findsOneWidget);
    expect(find.text('Get a recipe tailored to your ingredients and preferences.'), findsOneWidget);
    expect(find.text('Get AI Recipe'), findsOneWidget);
    expect(find.text('Ask NutriFridge AI'), findsOneWidget);

    // Tap "Get AI Recipe" -> Opens AI Assistant Modal Sheet
    await tester.ensureVisible(find.text('Get AI Recipe'));
    await tester.tap(find.text('Get AI Recipe'));
    await tester.pumpAndSettle();

    // Verify AI Assistant Modal Sheet & Context Handoff
    expect(find.text('NutriFridge Assistant'), findsOneWidget);
    expect(find.text('Recipe Request for Paneer Rice Bowl'), findsOneWidget);
    expect(find.textContaining('Give me a recipe for Paneer Rice Bowl'), findsOneWidget);
    expect(find.text('Send to Assistant'), findsOneWidget);

    // Send to Assistant & dismiss
    await tester.tap(find.text('Send to Assistant'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('NutriFridge Assistant'), findsNothing);

    // 8. Verify YouTube Video Carousel
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -320));
    await tester.pumpAndSettle();
    expect(find.text("Watch how it's made"), findsOneWidget);
    expect(find.text('Cooking videos for this meal.'), findsOneWidget);
    expect(find.text('Homestyle Paneer Rice Bowl in 15 Minutes'), findsOneWidget);
    expect(find.text('Fresh Kitchen Tales'), findsOneWidget);
    expect(find.text('8:24'), findsOneWidget);

    // Tap video card -> honest sample notice
    await tester.tap(find.text('Homestyle Paneer Rice Bowl in 15 Minutes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sample Video'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // 9. Back Navigation -> Returns to Dashboard in previous state
    await tester.ensureVisible(find.byIcon(Icons.arrow_back_rounded));
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // Verify we are back on Dashboard
    expect(find.text('Suggested for you'), findsOneWidget);
    expect(find.text("Today's Wellness"), findsOneWidget);
    expect(find.text('Nutrition Today'), findsOneWidget);
  });

  testWidgets('Design 06 Float Bottom Navigation - icon-only wave animation, active circle, and Quick Actions', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    MockDataRepository.reset();
    FridgeCategoryRepository.reset();

    await tester.pumpWidget(const NutriFridgeApp());
    await tester.pumpAndSettle();

    // 1. Verify 5 destinations exist in exact order without text labels in navigation
    expect(find.byKey(const ValueKey('nav_tab_home')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_tab_fridge')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_tab_quick_actions')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_tab_progress')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_tab_profile')), findsOneWidget);

    // 2. Verify raised floating circle starts at Home (index 0)
    final raisedCircle = find.byKey(const ValueKey('liquid_float_raised_circle'));
    expect(raisedCircle, findsOneWidget);

    // 3. Navigate to Fridge tab
    await tester.tap(find.byKey(const ValueKey('nav_tab_fridge')));
    await tester.pumpAndSettle();

    expect(find.text('My Fridge'), findsOneWidget);

    // 4. Tap central '+' Quick Actions button - should open modal without changing active tab
    await tester.tap(find.byKey(const ValueKey('nav_tab_quick_actions')));
    await tester.pumpAndSettle();

    // Quick Actions sheet is shown
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Log Meal'), findsOneWidget);
    expect(find.text('Add Food'), findsOneWidget);

    // Close the Quick Action sheet by tapping top barrier / handle
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('Log Meal'), findsNothing);

    // Still on Fridge screen
    expect(find.text('My Fridge'), findsOneWidget);

    // 5. Navigate to Progress tab
    await tester.tap(find.byKey(const ValueKey('nav_tab_progress')));
    await tester.pumpAndSettle();

    expect(find.text('Your nutrition, over time.'), findsOneWidget);

    // 6. Navigate to Profile tab
    await tester.tap(find.byKey(const ValueKey('nav_tab_profile')));
    await tester.pumpAndSettle();

    expect(find.text('Your food preferences and personal settings.'), findsOneWidget);

    // 7. Navigate back to Home tab
    await tester.tap(find.byKey(const ValueKey('nav_tab_home')));
    await tester.pumpAndSettle();

    expect(find.text('Suggested for you'), findsOneWidget);
  });

  testWidgets('Design 1 — Hero Transition: Suggested for you arrow trigger, shared element matching tag & return', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    MockDataRepository.reset();
    FridgeCategoryRepository.reset();

    await tester.pumpWidget(const NutriFridgeApp());
    await tester.pumpAndSettle();

    // 1. Verify card and arrow button exist
    expect(find.byKey(const ValueKey('recommendation_card_arrow')), findsOneWidget);

    // Verify source Hero element on recommendation card
    final sourceHero = find.byWidgetPredicate(
      (w) => w is Hero && w.tag == 'meal-hero-image-paneer-rice-bowl',
    );
    expect(sourceHero, findsOneWidget);

    // 2. Tap arrow specifically to trigger the Hero transition
    await tester.tap(find.byKey(const ValueKey('recommendation_card_arrow')));
    await tester.pumpAndSettle();

    // 3. Confirm we are on Meal Detail screen with destination Hero element
    expect(find.text('Picked for your fridge'), findsOneWidget);
    expect(find.text('Nutrition & prep'), findsOneWidget);

    final destHero = find.byWidgetPredicate(
      (w) => w is Hero && w.tag == 'meal-hero-image-paneer-rice-bowl',
    );
    expect(destHero, findsOneWidget);

    // 4. Tap back button to test reverse Hero transition
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // 5. Back on Dashboard, source Hero exists again, no splash screen
    expect(find.text('Suggested for you'), findsOneWidget);
    expect(find.byType(MagicFridgeSplashScreen), findsNothing);
    expect(sourceHero, findsOneWidget);
  });

  testWidgets('Fridge Personalization - Preferences sheet, 4 color finishes, freezer position & live layout update', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    MockDataRepository.reset();
    FridgeCategoryRepository.reset();
    FridgePreferencesRepository.reset();

    await tester.pumpWidget(const NutriFridgeApp());
    await tester.pumpAndSettle();

    // 1. Navigate to Fridge page via bottom nav
    await tester.tap(find.byIcon(Icons.kitchen_rounded));
    await tester.pumpAndSettle();

    expect(find.text('My Fridge'), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

    // 2. Tap settings/preferences icon to open Fridge Preferences bottom sheet
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    // Verify bottom sheet contents
    expect(find.text('Fridge Preferences'), findsOneWidget);
    expect(find.text('Make your fridge feel like yours.'), findsOneWidget);

    // Verify Fridge Colour section
    expect(find.text('Fridge Colour'), findsOneWidget);
    expect(find.text('Choose the finish for your refrigerator.'), findsOneWidget);
    expect(find.text('Midnight Navy'), findsOneWidget);
    expect(find.text('Matte Black'), findsOneWidget);
    expect(find.text('Pearl White'), findsOneWidget);
    expect(find.text('Sage Green'), findsOneWidget);

    // Verify Freezer Position section
    expect(find.text('Freezer Position'), findsOneWidget);
    expect(find.text('Choose your refrigerator layout.'), findsOneWidget);
    expect(find.text('Freezer on Top'), findsOneWidget);
    expect(find.text('Freezer on Bottom'), findsOneWidget);
    expect(find.text('Apply Changes'), findsOneWidget);

    // 3. Test cancel/close without applying
    await tester.tap(find.byKey(const ValueKey('swatch_matteBlack')));
    await tester.pumpAndSettle();

    // Close via close icon
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Bottom sheet closed, preferences should NOT have changed (remains Midnight Navy & Top)
    expect(find.text('Fridge Preferences'), findsNothing);
    expect(FridgePreferencesRepository.current.exteriorColor, FridgeColorFinish.midnightNavy);
    expect(FridgePreferencesRepository.current.freezerPosition, FreezerPosition.top);

    // 4. Re-open sheet and apply Matte Black + Freezer on Bottom
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('swatch_matteBlack')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('layout_option_bottom')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply Changes'));
    await tester.pumpAndSettle();

    // Confirm sheet closed and preferences updated
    expect(find.text('Fridge Preferences'), findsNothing);
    expect(FridgePreferencesRepository.current.exteriorColor, FridgeColorFinish.matteBlack);
    expect(FridgePreferencesRepository.current.freezerPosition, FreezerPosition.bottom);

    // 5. Verify Freezer on Bottom layout interaction
    // Touch targets for both doors exist
    expect(find.byKey(const ValueKey('fridge_door_touch_target')), findsOneWidget);
    expect(find.byKey(const ValueKey('freezer_door_touch_target')), findsOneWidget);

    // Open main refrigerator (now on top)
    await tester.tap(find.byKey(const ValueKey('fridge_door_touch_target')));
    await tester.pumpAndSettle();

    // Verify main refrigerator categories are accessible
    expect(find.text('DAIRY PRODUCTS'), findsOneWidget);
    expect(find.text('VEGETABLES'), findsOneWidget);
    expect(find.text('FRUITS'), findsOneWidget);

    // Tap Vegetables category to verify category sheet still works in this arrangement
    await tester.tap(find.text('VEGETABLES'));
    await tester.pumpAndSettle();
    expect(find.text('🥦 Vegetables'), findsOneWidget);
    expect(find.text('4 items'), findsOneWidget);

    // Close category sheet
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Open freezer door (now at bottom)
    await tester.tap(find.byKey(const ValueKey('freezer_door_touch_target')));
    await tester.pumpAndSettle();
    expect(find.text('ICE CREAM'), findsOneWidget);
    expect(find.text('FROZEN FOOD'), findsOneWidget);
    expect(find.text('DRY FRUITS'), findsOneWidget);

    // 6. Test session persistence across tab switches
    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pumpAndSettle();
    expect(find.text("Today's Meals"), findsOneWidget);

    await tester.tap(find.byIcon(Icons.kitchen_rounded));
    await tester.pumpAndSettle();

    // Settings retained!
    expect(FridgePreferencesRepository.current.exteriorColor, FridgeColorFinish.matteBlack);
    expect(FridgePreferencesRepository.current.freezerPosition, FreezerPosition.bottom);

    // 7. Test switching to Pearl White and Freezer on Top
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('swatch_pearlWhite')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('layout_option_top')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply Changes'));
    await tester.pumpAndSettle();

    expect(FridgePreferencesRepository.current.exteriorColor, FridgeColorFinish.pearlWhite);
    expect(FridgePreferencesRepository.current.freezerPosition, FreezerPosition.top);
  });
}
