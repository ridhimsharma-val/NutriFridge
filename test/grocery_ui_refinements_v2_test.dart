import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/screens/grocery/grocery_list_screen.dart';
import 'package:nutrifridge/services/grocery/grocery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    GroceryService.instance.resetTestingState();
    GroceryService.instance.testUserIdOverride = 'test_user_refinements';
    GroceryService.instance.mockSupabaseTable = {'grocery_items': []};
    await GroceryService.instance.initialize();
  });

  Widget buildTestApp(Widget child, {Size size = const Size(390, 844)}) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('NutriFridge — Grocery List UI Refinements (v2) Tests', () {
    // -------------------------------------------------------------------------
    // 1 & 2: Empty-state basket illustration removed; heading & description kept
    // -------------------------------------------------------------------------
    testWidgets('1 & 2. Empty-state basket illustration is removed; heading & description remain', (tester) async {
      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      // Heading and description are present
      expect(find.text('Your shopping list is empty'), findsOneWidget);
      expect(
        find.text('Add ingredients for your next grocery run or bookmark them directly from recipe cards.'),
        findsOneWidget,
      );

      // Basket icon is completely removed
      expect(find.byIcon(Icons.shopping_basket_outlined), findsNothing);
      expect(find.byIcon(Icons.shopping_basket), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 3 & 4 & 8: Quantity can be manually entered (500, 1000, 2.5) and persists accurately
    // -------------------------------------------------------------------------
    testWidgets('3, 4 & 8. Quantity can be entered manually (500 grams, 2.5 kg) and saved to Supabase', (tester) async {
      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      // Enter item name
      await tester.enterText(find.byKey(const Key('grocery_item_name_input')), 'Rolled Oats');

      // Enter quantity manually: 500
      final qtyInput = find.byKey(const Key('grocery_qty_input'));
      expect(qtyInput, findsOneWidget);
      await tester.enterText(qtyInput, '500');

      // Select unit 'grams'
      await tester.tap(find.byKey(const Key('grocery_unit_selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('grams').last);
      await tester.pumpAndSettle();

      // Tap Add
      await tester.tap(find.byKey(const Key('grocery_add_item_btn')));
      await tester.pumpAndSettle();

      // Verify item saved in GroceryService and Supabase
      expect(GroceryService.instance.currentItems.length, 1);
      final item = GroceryService.instance.currentItems.first;
      expect(item.name, 'Rolled Oats');
      expect(item.quantity, 500.0);
      expect(item.unit, 'grams');

      // Verify decimal value entry: 2.5 kg
      await tester.enterText(find.byKey(const Key('grocery_item_name_input')), 'Potatoes');
      await tester.enterText(qtyInput, '2.5');
      await tester.tap(find.byKey(const Key('grocery_unit_selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('kg').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('grocery_add_item_btn')));
      await tester.pumpAndSettle();

      expect(GroceryService.instance.currentItems.length, 2);
      final item2 = GroceryService.instance.currentItems.firstWhere((it) => it.name == 'Potatoes');
      expect(item2.quantity, 2.5);
      expect(item2.unit, 'kg');

      // Verify large multi-digit value: 1000
      await tester.enterText(find.byKey(const Key('grocery_item_name_input')), 'Flour');
      await tester.enterText(qtyInput, '1000');
      await tester.tap(find.byKey(const Key('grocery_add_item_btn')));
      await tester.pumpAndSettle();

      final item3 = GroceryService.instance.currentItems.firstWhere((it) => it.name == 'Flour');
      expect(item3.quantity, 1000.0);
    });

    // -------------------------------------------------------------------------
    // 5: Plus and minus stepper buttons continue working alongside manual input
    // -------------------------------------------------------------------------
    testWidgets('5. Plus and minus buttons increment and decrement quantity', (tester) async {
      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      final qtyInput = find.byKey(const Key('grocery_qty_input'));
      final incBtn = find.byKey(const Key('grocery_qty_increment_btn'));
      final decBtn = find.byKey(const Key('grocery_qty_decrement_btn'));

      // Initially 1
      expect(find.descendant(of: qtyInput, matching: find.text('1')), findsOneWidget);

      // Tap + twice -> 3
      await tester.tap(incBtn);
      await tester.pump();
      await tester.tap(incBtn);
      await tester.pump();
      expect(find.descendant(of: qtyInput, matching: find.text('3')), findsOneWidget);

      // Tap - once -> 2
      await tester.tap(decBtn);
      await tester.pump();
      expect(find.descendant(of: qtyInput, matching: find.text('2')), findsOneWidget);

      // Enter manual 10 then tap + -> 11
      await tester.enterText(qtyInput, '10');
      await tester.pump();
      await tester.tap(incBtn);
      await tester.pump();
      expect(find.descendant(of: qtyInput, matching: find.text('11')), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 6: Zero, negative, and invalid values are rejected
    // -------------------------------------------------------------------------
    testWidgets('6. Zero, negative, and invalid values are rejected with alert', (tester) async {
      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('grocery_item_name_input')), 'Almond Milk');
      final qtyInput = find.byKey(const Key('grocery_qty_input'));

      // Test 0
      await tester.enterText(qtyInput, '0');
      await tester.tap(find.byKey(const Key('grocery_add_item_btn')));
      await tester.pump();

      expect(find.text('Please enter a valid quantity greater than zero'), findsOneWidget);
      expect(GroceryService.instance.currentItems.isEmpty, isTrue);

      // Test negative
      await tester.enterText(qtyInput, '-5');
      await tester.tap(find.byKey(const Key('grocery_add_item_btn')));
      await tester.pump();

      expect(find.text('Please enter a valid quantity greater than zero'), findsOneWidget);
      expect(GroceryService.instance.currentItems.isEmpty, isTrue);

      // Test invalid text
      await tester.enterText(qtyInput, 'abc');
      await tester.tap(find.byKey(const Key('grocery_add_item_btn')));
      await tester.pump();

      expect(find.text('Please enter a valid quantity greater than zero'), findsOneWidget);
      expect(GroceryService.instance.currentItems.isEmpty, isTrue);
    });

    // -------------------------------------------------------------------------
    // 7: Changing unit or category preserves the entered quantity
    // -------------------------------------------------------------------------
    testWidgets('7. Changing unit or category preserves the entered quantity', (tester) async {
      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      final qtyInput = find.byKey(const Key('grocery_qty_input'));
      await tester.enterText(qtyInput, '750');
      await tester.pump();

      // Change unit
      await tester.tap(find.byKey(const Key('grocery_unit_selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('millilitres').last);
      await tester.pumpAndSettle();

      // Change category
      await tester.tap(find.byKey(const Key('grocery_category_pill')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beverages').last);
      await tester.pumpAndSettle();

      // Verify quantity is preserved as 750
      expect(find.descendant(of: qtyInput, matching: find.text('750')), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 9 & 10: Category headings display WITHOUT decorative leading icons
    // -------------------------------------------------------------------------
    testWidgets('9 & 10. Category headings display cleanly without decorative leading icons', (tester) async {
      await GroceryService.instance.addItem(
        name: 'Whole Milk',
        quantity: 1,
        unit: 'litres',
        category: 'Dairy & Eggs',
      );
      await GroceryService.instance.addItem(
        name: 'Bananas',
        quantity: 6,
        unit: 'pieces',
        category: 'Fruits & Vegetables',
      );

      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      // Category names are displayed
      expect(find.text('Dairy & Eggs'), findsOneWidget);
      expect(find.text('Fruits & Vegetables'), findsOneWidget);

      // Item count badges are displayed
      expect(find.text('1'), findsWidgets);

      // Ensure decorative category heading icons are NOT present
      expect(find.byIcon(Icons.eco_outlined), findsNothing);
      expect(find.byIcon(Icons.egg_outlined), findsNothing);
      expect(find.byIcon(Icons.breakfast_dining_outlined), findsNothing);
      expect(find.byIcon(Icons.set_meal_outlined), findsNothing);
      expect(find.byIcon(Icons.grain_outlined), findsNothing);
      expect(find.byIcon(Icons.local_drink_outlined), findsNothing);
      expect(find.byIcon(Icons.category_outlined), findsNothing);

      // Functional icons remain
      expect(find.byIcon(Icons.delete_outline_rounded), findsWidgets);
      expect(find.byIcon(Icons.edit_outlined), findsWidgets);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 11 & 12: No layout overflow on compact or standard mobile viewports
    // -------------------------------------------------------------------------
    testWidgets('11 & 12. No layout overflow occurs on compact 360px viewport', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await GroceryService.instance.addItem(
        name: 'Extra Virgin Olive Oil',
        quantity: 500,
        unit: 'ml',
        category: 'Others',
      );

      await tester.pumpWidget(buildTestApp(const GroceryListScreen(), size: const Size(360, 740)));
      await tester.pumpAndSettle();

      // Check for zero render overflows
      expect(tester.takeException(), isNull);

      // Input 1000 into qty field and check again
      await tester.enterText(find.byKey(const Key('grocery_qty_input')), '1000');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
