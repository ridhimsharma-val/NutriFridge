import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/main.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/screens/fridge/widgets/expiring_soon_bottom_sheet.dart';
import 'package:nutrifridge/screens/fridge/widgets/food_details_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FridgeCategoryRepository.forceInMemoryForTesting = true;
    FridgeCategoryRepository.reset();
  });

  group('Expiring Soon Bottom Sheet & Badge Interaction Tests', () {
    testWidgets('1. Tap Expiring Soon badge opens bottom sheet with qualifying items', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Seed 2 expiring items into repository
      await FridgeCategoryRepository.addItemToCategory(
        'Dairy Products',
        const CategoryFoodItem(
          id: 'test_milk',
          name: 'Milk',
          quantity: '1 L',
          expiryDays: 1, // Expires tomorrow
        ),
      );
      await FridgeCategoryRepository.addItemToCategory(
        'Fruits',
        const CategoryFoodItem(
          id: 'test_apple',
          name: 'Apple',
          quantity: '1 kg',
          expiryDays: 2, // Expires in 2 days
        ),
      );

      await tester.pumpWidget(const NutriFridgeApp());
      await tester.pumpAndSettle();

      // Navigate to Fridge screen
      await tester.tap(find.byIcon(Icons.kitchen_rounded));
      await tester.pumpAndSettle();

      // Verify badge displays "2 expiring soon"
      expect(find.text('2 expiring soon'), findsOneWidget);

      // Tap Expiring Soon badge
      await tester.tap(find.byKey(const ValueKey('expiring_soon_badge')));
      await tester.pumpAndSettle();

      // Bottom sheet header and items are visible
      expect(find.text('⏳ Expiring Soon'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(ExpiringSoonBottomSheet), matching: find.text('2 items')),
        findsOneWidget,
      );
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('1 L'), findsOneWidget);
      expect(find.text('Expires tomorrow'), findsOneWidget);
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('1 kg'), findsOneWidget);
      expect(find.text('Expires in 2 days'), findsOneWidget);
    });

    testWidgets('2. Tap close button closes the bottom sheet', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await FridgeCategoryRepository.addItemToCategory(
        'Dairy Products',
        const CategoryFoodItem(
          id: 'test_paneer',
          name: 'Paneer',
          quantity: '500 g',
          expiryDays: 3,
        ),
      );

      await tester.pumpWidget(const NutriFridgeApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.kitchen_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('expiring_soon_badge')));
      await tester.pumpAndSettle();

      expect(find.text('⏳ Expiring Soon'), findsOneWidget);

      // Tap close button inside bottom sheet
      await tester.tap(find.byKey(const ValueKey('expiring_soon_close_button')));
      await tester.pumpAndSettle();

      // Sheet is dismissed
      expect(find.text('⏳ Expiring Soon'), findsNothing);
    });

    testWidgets('3. Tap outside (modal barrier) dismisses bottom sheet', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await FridgeCategoryRepository.addItemToCategory(
        'Dairy Products',
        const CategoryFoodItem(
          id: 'test_yogurt',
          name: 'Yogurt',
          quantity: '200 g',
          expiryDays: 0,
        ),
      );

      await tester.pumpWidget(const NutriFridgeApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.kitchen_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('expiring_soon_badge')));
      await tester.pumpAndSettle();

      expect(find.text('⏳ Expiring Soon'), findsOneWidget);

      // Tap top of screen outside the bottom sheet
      await tester.tapAt(const Offset(195, 50));
      await tester.pumpAndSettle();

      expect(find.text('⏳ Expiring Soon'), findsNothing);
    });

    testWidgets('4. Swipe down dismisses the bottom sheet', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await FridgeCategoryRepository.addItemToCategory(
        'Dairy Products',
        const CategoryFoodItem(
          id: 'test_tofu',
          name: 'Tofu',
          quantity: '250 g',
          expiryDays: 2,
        ),
      );

      await tester.pumpWidget(const NutriFridgeApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.kitchen_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('expiring_soon_badge')));
      await tester.pumpAndSettle();

      expect(find.text('⏳ Expiring Soon'), findsOneWidget);

      // Drag downwards from drag handle
      await tester.drag(find.text('⏳ Expiring Soon'), const Offset(0, 400));
      await tester.pumpAndSettle();

      expect(find.text('⏳ Expiring Soon'), findsNothing);
    });

    testWidgets('5 & 6. Multiple expiring items sorted by earliest expiry date first', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Add items in non-chronological order: 3 days, 0 days, 1 day, 2 days
      await FridgeCategoryRepository.addItemToCategory(
        'Dairy Products',
        const CategoryFoodItem(id: 'item_3', name: 'Cheese', quantity: '200 g', expiryDays: 3),
      );
      await FridgeCategoryRepository.addItemToCategory(
        'Fruits',
        const CategoryFoodItem(id: 'item_0', name: 'Berries', quantity: '1 box', expiryDays: 0),
      );
      await FridgeCategoryRepository.addItemToCategory(
        'Vegetables',
        const CategoryFoodItem(id: 'item_1', name: 'Spinach', quantity: '250 g', expiryDays: 1),
      );
      await FridgeCategoryRepository.addItemToCategory(
        'Juices',
        const CategoryFoodItem(id: 'item_2', name: 'Orange Juice', quantity: '500 ml', expiryDays: 2),
      );

      final expiringList = FridgeCategoryRepository.expiringSoonItems;
      expect(expiringList.length, 4);
      // Earliest first: 0 -> 1 -> 2 -> 3
      expect(expiringList[0].name, 'Berries');
      expect(expiringList[0].expiryLabel, 'Expires today');
      expect(expiringList[1].name, 'Spinach');
      expect(expiringList[1].expiryLabel, 'Expires tomorrow');
      expect(expiringList[2].name, 'Orange Juice');
      expect(expiringList[2].expiryLabel, 'Expires in 2 days');
      expect(expiringList[3].name, 'Cheese');
      expect(expiringList[3].expiryLabel, 'Expires in 3 days');

      await tester.pumpWidget(const NutriFridgeApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.kitchen_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('expiring_soon_badge')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byType(ExpiringSoonBottomSheet), matching: find.text('4 items')),
        findsOneWidget,
      );
    });

    testWidgets('7. Zero expiring items displays clean empty state', (WidgetTester tester) async {
      // Direct pump of ExpiringSoonBottomSheet with zero expiring items
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => ExpiringSoonBottomSheet.show(context: context),
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('⏳ Expiring Soon'), findsOneWidget);
      expect(find.text('No items'), findsOneWidget);
      expect(find.text("You're all set!"), findsOneWidget);
      expect(find.text('No items are expiring soon.'), findsOneWidget);
    });

    test('8 & 9. Expired items (< 0 days) and missing expiry dates are excluded safely', () async {
      // Expired item (expiryDays: -2)
      await FridgeCategoryRepository.addItemToCategory(
        'Dairy Products',
        const CategoryFoodItem(id: 'exp_item', name: 'Old Milk', quantity: '1 L', expiryDays: -2),
      );
      // Item with no expiry set (null)
      await FridgeCategoryRepository.addItemToCategory(
        'Dry Fruits',
        const CategoryFoodItem(id: 'no_exp', name: 'Almonds', quantity: '500 g', expiryDays: null),
      );
      // Fresh item (expiryDays: 7)
      await FridgeCategoryRepository.addItemToCategory(
        'Vegetables',
        const CategoryFoodItem(id: 'fresh_item', name: 'Carrots', quantity: '1 kg', expiryDays: 7),
      );
      // Qualifying item (expiryDays: 1)
      await FridgeCategoryRepository.addItemToCategory(
        'Fruits',
        const CategoryFoodItem(id: 'valid_item', name: 'Banana', quantity: '6 pieces', expiryDays: 1),
      );

      final expiringList = FridgeCategoryRepository.expiringSoonItems;
      expect(expiringList.length, 1);
      expect(expiringList.first.name, 'Banana');
      expect(FridgeCategoryRepository.expiringSoonCount, 1);
    });

    testWidgets('10 & 11. Inventory update dynamically updates badge and bottom sheet', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await FridgeCategoryRepository.addItemToCategory(
        'Dairy Products',
        const CategoryFoodItem(id: 'item_a', name: 'Milk', quantity: '1 L', expiryDays: 2),
      );

      await tester.pumpWidget(const NutriFridgeApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.kitchen_rounded));
      await tester.pumpAndSettle();

      expect(find.text('1 expiring soon'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('expiring_soon_badge')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(ExpiringSoonBottomSheet), matching: find.text('1 item')),
        findsOneWidget,
      );

      // Add another expiring item while sheet is open
      await FridgeCategoryRepository.addItemToCategory(
        'Fruits',
        const CategoryFoodItem(id: 'item_b', name: 'Strawberries', quantity: '1 box', expiryDays: 1),
      );
      await tester.pumpAndSettle();

      // Sheet updates dynamically to show 2 items
      expect(
        find.descendant(of: find.byType(ExpiringSoonBottomSheet), matching: find.text('2 items')),
        findsOneWidget,
      );
      expect(find.text('Strawberries'), findsOneWidget);
      expect(FridgeCategoryRepository.expiringSoonCount, 2);
    });

    testWidgets('12. Tapping an item opens the existing FoodDetailsSheet', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await FridgeCategoryRepository.addItemToCategory(
        'Dairy Products',
        const CategoryFoodItem(id: 'item_paneer', name: 'Paneer', quantity: '500 g', expiryDays: 2),
      );

      await tester.pumpWidget(const NutriFridgeApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.kitchen_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('expiring_soon_badge')));
      await tester.pumpAndSettle();

      expect(find.text('Paneer'), findsOneWidget);

      // Tap on Paneer card
      await tester.tap(find.text('Paneer'));
      await tester.pumpAndSettle();

      // Existing FoodDetailsSheet opened with quantity actions
      expect(find.byType(FoodDetailsSheet), findsOneWidget);
      expect(find.text('Use Food'), findsOneWidget);
      expect(find.text('+ Add Food'), findsOneWidget);
    });
  });
}
