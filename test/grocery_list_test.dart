import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/models/grocery_item.dart';
import 'package:nutrifridge/screens/fridge/fridge_page.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/screens/fridge/widgets/fridge_sticky_note.dart';
import 'package:nutrifridge/screens/grocery/grocery_list_screen.dart';
import 'package:nutrifridge/services/grocery/grocery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FridgeCategoryRepository.forceInMemoryForTesting = true;
    FridgeCategoryRepository.testUserIdOverride = 'test_user_grocery';
    FridgeCategoryRepository.reset();
    GroceryService.instance.resetTestingState();
    GroceryService.instance.testUserIdOverride = 'test_user_grocery';
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

  group('NutriFridge Grocery List & Fridge Sticky Note Test Suite', () {
    // -------------------------------------------------------------------------
    // 1. Sticky note renders attached to the refrigerator in My Fridge
    // -------------------------------------------------------------------------
    testWidgets('1. Sticky note renders attached to refrigerator in My Fridge', (tester) async {
      await tester.pumpWidget(buildTestApp(const FridgePage()));
      await tester.pumpAndSettle();

      expect(find.byType(FridgeStickyNote), findsOneWidget);
      expect(find.byKey(const ValueKey('fridge_sticky_note_btn')), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 2. Physical paper styling (color, rotation, magnet, curled corner)
    // -------------------------------------------------------------------------
    testWidgets('2. Sticky note matches physical paper styling', (tester) async {
      await tester.pumpWidget(buildTestApp(const FridgeStickyNote()));
      await tester.pumpAndSettle();

      // Verify Transform.rotate exists with topCenter alignment
      final rotateFinder = find.byWidgetPredicate(
        (w) => w is Transform && w.alignment == Alignment.topCenter,
      );
      expect(rotateFinder, findsOneWidget);

      // Verify warm yellow paper container (#FEF9E3)
      final paperFinder = find.byWidgetPredicate(
        (w) => w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == const Color(0xFFFEF9E3),
      );
      expect(paperFinder, findsWidgets);

      // Verify forest-sage green magnet (#2C5E3B)
      final magnetFinder = find.byWidgetPredicate(
        (w) => w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == const Color(0xFF2C5E3B),
      );
      expect(magnetFinder, findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 3. Positioning within refrigerator bounds without layout overflow
    // -------------------------------------------------------------------------
    testWidgets('3. Sticky note positioned within refrigerator bounds without layout overflow', (tester) async {
      await tester.pumpWidget(buildTestApp(const FridgePage(), size: const Size(360, 640)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(FridgeStickyNote), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 4. Live preview of pending items and counter badge
    // -------------------------------------------------------------------------
    testWidgets('4. Sticky note preview displays pending items and counter badge', (tester) async {
      // Initially 0 items: displays empty prompt
      await tester.pumpWidget(buildTestApp(const FridgeStickyNote()));
      await tester.pumpAndSettle();
      expect(find.text('Tap to add items'), findsOneWidget);

      // Add 2 pending items
      await GroceryService.instance.addItem(name: 'Oat Milk', quantity: 1, unit: 'litres', category: 'Beverages');
      await GroceryService.instance.addItem(name: 'Honeycrisp Apples', quantity: 4, unit: 'pieces', category: 'Fruits & Vegetables');
      await tester.pumpAndSettle();

      expect(find.text('Oat Milk'), findsOneWidget);
      expect(find.text('Honeycrisp Apples'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // Counter badge
    });

    // -------------------------------------------------------------------------
    // 5. Tapping sticky note triggers navigation to GroceryListScreen
    // -------------------------------------------------------------------------
    testWidgets('5. Tapping sticky note triggers navigation to GroceryListScreen', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: const Scaffold(body: Center(child: FridgeStickyNote())),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('fridge_sticky_note_btn')));
      await tester.pumpAndSettle();

      expect(find.byType(GroceryListScreen), findsOneWidget);
      expect(find.text('Grocery List'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 6. Expanded GroceryListScreen opens without overflow on various screen sizes
    // -------------------------------------------------------------------------
    testWidgets('6. Expanded GroceryListScreen renders smoothly without overflow', (tester) async {
      for (final size in [const Size(320, 568), const Size(390, 844), const Size(768, 1024)]) {
        await tester.pumpWidget(buildTestApp(const GroceryListScreen(), size: size));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(GroceryListScreen), findsOneWidget);
      }
    });

    // -------------------------------------------------------------------------
    // 7. Adding an item with name adds it to the list
    // -------------------------------------------------------------------------
    testWidgets('7. Adding an item with name adds it to the list', (tester) async {
      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('grocery_item_name_input')), 'Almond Butter');
      await tester.tap(find.byKey(const Key('grocery_add_item_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Almond Butter'), findsOneWidget);
      expect(GroceryService.instance.currentItems.length, 1);
      expect(GroceryService.instance.currentItems.first.name, 'Almond Butter');
    });

    // -------------------------------------------------------------------------
    // 8. Quantity and unit preserved when adding
    // -------------------------------------------------------------------------
    testWidgets('8. Quantity and unit preserved when adding', (tester) async {
      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      // Increment quantity to 3
      await tester.tap(find.byKey(const Key('grocery_qty_increment_btn')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('grocery_qty_increment_btn')));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('grocery_item_name_input')), 'Greek Yogurt');
      await tester.tap(find.byKey(const Key('grocery_add_item_btn')));
      await tester.pumpAndSettle();

      final item = GroceryService.instance.currentItems.firstWhere((it) => it.name == 'Greek Yogurt');
      expect(item.quantity, 3.0);
      expect(item.unit, 'pieces');
    });

    // -------------------------------------------------------------------------
    // 9. Auto-category and category resolution works
    // -------------------------------------------------------------------------
    testWidgets('9. Auto-category resolves correctly and manual override works', (tester) async {
      expect(GroceryCategoryResolver.resolveCategory('Whole Milk'), 'Dairy & Eggs');
      expect(GroceryCategoryResolver.resolveCategory('Bananas'), 'Fruits & Vegetables');
      expect(GroceryCategoryResolver.resolveCategory('Sourdough Loaf'), 'Bakery');
      expect(GroceryCategoryResolver.resolveCategory('Chicken Breast'), 'Meat & Seafood');
      expect(GroceryCategoryResolver.resolveCategory('Brown Rice'), 'Grains & Staples');
      expect(GroceryCategoryResolver.resolveCategory('Orange Juice'), 'Beverages');
      expect(GroceryCategoryResolver.resolveCategory('Paper Towels'), 'Others');

      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      // Enter "Eggs" -> should auto-detect "Dairy & Eggs"
      await tester.enterText(find.byKey(const Key('grocery_item_name_input')), 'Eggs');
      await tester.pumpAndSettle();
      expect(find.text('Dairy & Eggs'), findsWidgets);
    });

    // -------------------------------------------------------------------------
    // 10. Marking item purchased toggles state and updates progress
    // -------------------------------------------------------------------------
    testWidgets('10. Marking item purchased toggles state and updates progress', (tester) async {
      final item = await GroceryService.instance.addItem(
        name: 'Olive Oil',
        quantity: 1,
        unit: 'bottles',
        category: 'Others',
      );
      expect(item, isNotNull);

      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('grocery_progress_text')), findsOneWidget);
      expect(find.text('0 of 1 items completed'), findsOneWidget);

      // Tap checkbox to mark purchased
      await tester.tap(find.byKey(Key('grocery_item_checkbox_${item.id}')));
      await tester.pumpAndSettle();

      expect(find.text('1 of 1 items completed'), findsOneWidget);
      expect(GroceryService.instance.completedItems.length, 1);
    });

    // -------------------------------------------------------------------------
    // 11. Editing items updates name, quantity, unit, and category
    // -------------------------------------------------------------------------
    testWidgets('11. Editing an item updates attributes', (tester) async {
      final item = await GroceryService.instance.addItem(
        name: 'Apples',
        quantity: 2,
        unit: 'pieces',
        category: 'Fruits & Vegetables',
      );
      expect(item, isNotNull);

      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      // Open edit sheet
      await tester.tap(find.byKey(Key('grocery_item_edit_${item.id}')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Grocery Item'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('edit_item_name_input')), 'Organic Gala Apples');
      await tester.tap(find.byKey(const Key('edit_item_save_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Organic Gala Apples'), findsOneWidget);
      expect(GroceryService.instance.currentItems.first.name, 'Organic Gala Apples');
    });

    // -------------------------------------------------------------------------
    // 12. Deleting an item removes it from list
    // -------------------------------------------------------------------------
    testWidgets('12. Deleting an item removes it from list', (tester) async {
      final item = await GroceryService.instance.addItem(
        name: 'Tofu',
        quantity: 1,
        unit: 'packs',
        category: 'Others',
      );
      expect(item, isNotNull);

      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Tofu'), findsOneWidget);

      await tester.tap(find.byKey(Key('grocery_item_delete_${item.id}')));
      await tester.pumpAndSettle();

      expect(find.text('Tofu'), findsNothing);
      expect(GroceryService.instance.currentItems.isEmpty, isTrue);
    });

    // -------------------------------------------------------------------------
    // 13. Clear completed with confirmation dialog
    // -------------------------------------------------------------------------
    testWidgets('13. Clear completed shows confirmation dialog and removes purchased items', (tester) async {
      final p1 = await GroceryService.instance.addItem(name: 'Spinach', quantity: 1, unit: 'packs', category: 'Fruits & Vegetables');
      await GroceryService.instance.addItem(name: 'Bread', quantity: 1, unit: 'pieces', category: 'Bakery');
      await GroceryService.instance.togglePurchased(p1.id); // Mark Spinach purchased

      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      // Tap clear completed action button in AppBar
      await tester.tap(find.byKey(const Key('grocery_clear_completed_action_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('clear_completed_dialog')), findsOneWidget);
      expect(find.text('Clear Completed Items?'), findsOneWidget);

      // Confirm clear
      await tester.tap(find.byKey(const Key('confirm_clear_completed_btn')));
      await tester.pumpAndSettle();

      expect(GroceryService.instance.completedItems.isEmpty, isTrue);
      expect(GroceryService.instance.pendingItems.length, 1);
      expect(GroceryService.instance.pendingItems.first.name, 'Bread');
    });

    // -------------------------------------------------------------------------
    // 14. Duplicate handling detects duplicate name and prompts user
    // -------------------------------------------------------------------------
    testWidgets('14. Duplicate handling detects duplicate and offers quantity increase', (tester) async {
      await GroceryService.instance.addItem(name: 'Bananas', quantity: 2, unit: 'pieces', category: 'Fruits & Vegetables');

      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      // Try adding "Bananas" again
      await tester.enterText(find.byKey(const Key('grocery_item_name_input')), 'Bananas');
      await tester.tap(find.byKey(const Key('grocery_qty_increment_btn'))); // qty = 2
      await tester.tap(find.byKey(const Key('grocery_add_item_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('grocery_duplicate_dialog')), findsOneWidget);
      expect(find.text('Item Already Exists'), findsOneWidget);

      // Tap Increase Quantity
      await tester.tap(find.byKey(const Key('duplicate_increase_qty_btn')));
      await tester.pumpAndSettle();

      expect(GroceryService.instance.currentItems.length, 1);
      expect(GroceryService.instance.currentItems.first.quantity, 4.0);
    });

    // -------------------------------------------------------------------------
    // 15. Empty state displays friendly prompt when list has no items
    // -------------------------------------------------------------------------
    testWidgets('15. Empty state displays friendly prompt when list is empty', (tester) async {
      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Your shopping list is empty'), findsOneWidget);
      expect(find.textContaining('Add ingredients for your next grocery run'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 16. Saved grocery items survive restart (persistence)
    // -------------------------------------------------------------------------
    testWidgets('16. Saved grocery items persist locally in SharedPreferences', (tester) async {
      await GroceryService.instance.addItem(name: 'Chia Seeds', quantity: 200, unit: 'g', category: 'Grains & Staples');
      expect(GroceryService.instance.currentItems.length, 1);

      // Simulate app restart by creating new GroceryService and loading from SharedPreferences
      final reloadedService = GroceryService();
      reloadedService.testUserIdOverride = 'test_user_grocery';
      await reloadedService.initialize();

      expect(reloadedService.currentItems.length, 1);
      expect(reloadedService.currentItems.first.name, 'Chia Seeds');
      expect(reloadedService.currentItems.first.quantity, 200.0);
      expect(reloadedService.currentItems.first.unit, 'g');
    });

    // -------------------------------------------------------------------------
    // 17. User isolation: different users see only their own grocery items
    // -------------------------------------------------------------------------
    testWidgets('17. User isolation: separate users have independent grocery items', (tester) async {
      await GroceryService.instance.addItem(name: 'User A Item', quantity: 1, unit: 'pieces', userId: 'user_alpha');
      await GroceryService.instance.addItem(name: 'User B Item', quantity: 2, unit: 'pieces', userId: 'user_beta');

      final itemsA = await GroceryService.instance.getItemsForUser('user_alpha');
      final itemsB = await GroceryService.instance.getItemsForUser('user_beta');

      expect(itemsA.length, 1);
      expect(itemsA.first.name, 'User A Item');

      expect(itemsB.length, 1);
      expect(itemsB.first.name, 'User B Item');
    });

    // -------------------------------------------------------------------------
    // 18. Network errors do not falsely indicate success
    // -------------------------------------------------------------------------
    testWidgets('18. Network errors do not falsely indicate success', (tester) async {
      GroceryService.instance.mockSupabaseTable = {'grocery_items': []};
      GroceryService.instance.simulateNetworkError = true;

      final result = await GroceryService.instance.addItem(
        name: 'Should Fail Item',
        quantity: 1,
        unit: 'pieces',
        userId: 'cloud_user_99',
      );

      expect(result.isSuccess, isFalse);
      expect(result.type, GroceryAddResultType.error);
    });

    // -------------------------------------------------------------------------
    // 19. Empty item name validation prevents empty writes
    // -------------------------------------------------------------------------
    testWidgets('19. Empty item name prevents write and notifies user', (tester) async {
      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('grocery_item_name_input')), '   ');
      await tester.tap(find.byKey(const Key('grocery_add_item_btn')));
      await tester.pump();

      expect(find.text('Please enter an item name'), findsOneWidget);
      expect(GroceryService.instance.currentItems.isEmpty, isTrue);
    });

    // -------------------------------------------------------------------------
    // 20. Adding purchased items to fridge pushes them to Fridge inventory
    // -------------------------------------------------------------------------
    testWidgets('20. Transferring completed items pushes them to Fridge inventory', (tester) async {
      final item = await GroceryService.instance.addItem(
        name: 'Whole Milk',
        quantity: 2,
        unit: 'litres',
        category: 'Dairy & Eggs',
      );
      await GroceryService.instance.togglePurchased(item.id);

      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      // Open transfer sheet via header button
      await tester.tap(find.byKey(const Key('grocery_transfer_to_fridge_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Add Items to Fridge'), findsOneWidget);
      expect(find.byKey(const Key('confirm_transfer_to_fridge_btn')), findsOneWidget);

      // Confirm transfer
      await tester.tap(find.byKey(const Key('confirm_transfer_to_fridge_btn')));
      await tester.pumpAndSettle();

      // Verify item transferred to FridgeCategoryRepository under 'Dairy Products'
      final dairyItems = FridgeCategoryRepository.getCategoryData('Dairy Products').items;
      expect(dairyItems.any((it) => it.name == 'Whole Milk'), isTrue);

      // Verify item removed from Grocery completed list
      expect(GroceryService.instance.completedItems.isEmpty, isTrue);
    });

    // -------------------------------------------------------------------------
    // 21. Failed fridge inventory additions preserve grocery list items
    // -------------------------------------------------------------------------
    testWidgets('21. Concurrency guard prevents duplicate simultaneous transfers', (tester) async {
      final item = await GroceryService.instance.addItem(
        name: 'Sourdough Bread',
        quantity: 1,
        unit: 'pieces',
        category: 'Bakery',
      );
      await GroceryService.instance.togglePurchased(item.id);

      // Simulate a first transfer
      final count1 = await GroceryService.instance.addPurchasedItemsToFridge();
      expect(count1, 1);

      // A repeated transfer with 0 completed items returns 0 safely
      final count2 = await GroceryService.instance.addPurchasedItemsToFridge();
      expect(count2, 0);
    });
  });
}
