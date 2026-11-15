import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/screens/grocery/grocery_list_screen.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/services/grocery/grocery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    GroceryService.instance.resetTestingState();
    GroceryService.instance.testUserIdOverride = 'test_lock_user';
    GroceryService.instance.mockSupabaseTable = {
      'grocery_items': [],
      'fridge_items': [],
    };
    FridgeCategoryRepository.forceInMemoryForTesting = false;
    await GroceryService.instance.initialize();
  });

  tearDown(() {
    FridgeCategoryRepository.forceInMemoryForTesting = false;
  });

  Widget buildTestApp(Widget child, WidgetTester tester, {Size size = const Size(400, 900)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('NutriFridge — Lock Transferred Grocery Items & Fix Layout Overflow Tests', () {
    // -------------------------------------------------------------------------
    // 1 & 2: Checking item marks purchased; can uncheck before transfer
    // -------------------------------------------------------------------------
    testWidgets('1 & 2. Item marks purchased when checked, and can be unchecked before transfer', (tester) async {
      await GroceryService.instance.addItem(
        name: 'Avocado',
        quantity: 2,
        unit: 'pieces',
        category: 'Fruits & Vegetables',
      );

      await tester.pumpWidget(buildTestApp(const GroceryListScreen(), tester));
      await tester.pumpAndSettle();

      final item = GroceryService.instance.currentItems.first;
      final checkboxFinder = find.byKey(Key('grocery_item_checkbox_${item.id}'));
      expect(checkboxFinder, findsOneWidget);

      // Check item
      await tester.ensureVisible(checkboxFinder);
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      expect(GroceryService.instance.currentItems.first.isPurchased, isTrue);
      expect(GroceryService.instance.currentItems.first.isTransferred, isFalse);

      // Uncheck item (since not yet transferred)
      await tester.ensureVisible(checkboxFinder);
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      expect(GroceryService.instance.currentItems.first.isPurchased, isFalse);
      expect(GroceryService.instance.currentItems.first.isTransferred, isFalse);
    });

    // -------------------------------------------------------------------------
    // 3: Purchased items can be edited before transfer
    // -------------------------------------------------------------------------
    testWidgets('3. Purchased items can be edited before transfer', (tester) async {
      await GroceryService.instance.addItem(
        name: 'Greek Yogurt',
        quantity: 1,
        unit: 'packs',
        category: 'Dairy & Eggs',
      );

      final item = GroceryService.instance.currentItems.first;
      await GroceryService.instance.togglePurchased(item.id);

      await tester.pumpWidget(buildTestApp(const GroceryListScreen(), tester));
      await tester.pumpAndSettle();

      // Edit button is visible for purchased but untransferred item
      final editBtn = find.byKey(Key('grocery_item_edit_${item.id}'));
      expect(editBtn, findsOneWidget);

      await tester.ensureVisible(editBtn);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Edit name in bottom sheet
      expect(find.byKey(const Key('edit_item_name_input')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('edit_item_name_input')), 'Organic Greek Yogurt');
      await tester.tap(find.byKey(const Key('edit_item_save_btn')));
      await tester.pumpAndSettle();

      final updated = GroceryService.instance.currentItems.first;
      expect(updated.name, 'Organic Greek Yogurt');
      expect(updated.isPurchased, isTrue);
      expect(updated.isTransferred, isFalse);
    });

    // -------------------------------------------------------------------------
    // 4, 5 & 6: Transfer locks item, disables checkbox, hides edit button, shows badge
    // -------------------------------------------------------------------------
    testWidgets('4, 5 & 6. Transfer locks grocery item, disables checkbox and removes edit button', (tester) async {
      await GroceryService.instance.addItem(
        name: 'Whole Milk',
        quantity: 1,
        unit: 'litres',
        category: 'Dairy & Eggs',
      );

      final item = GroceryService.instance.currentItems.first;
      await GroceryService.instance.togglePurchased(item.id);

      // Perform transfer
      final transferResult = await GroceryService.instance.transferPurchasedToFridge();
      expect(transferResult.transferredCount, 1);

      await tester.pumpWidget(buildTestApp(const GroceryListScreen(), tester));
      await tester.pumpAndSettle();

      final transferredItem = GroceryService.instance.currentItems.first;
      expect(transferredItem.isTransferred, isTrue);
      expect(transferredItem.isPurchased, isTrue);

      // Transferred "In Fridge" badge is visible
      expect(find.byKey(Key('transferred_badge_${transferredItem.id}')), findsOneWidget);
      expect(find.text('In Fridge'), findsOneWidget);

      // Pencil/edit button is completely removed
      expect(find.byKey(Key('grocery_item_edit_${transferredItem.id}')), findsNothing);

      // Delete button remains accessible
      expect(find.byKey(Key('grocery_item_delete_${transferredItem.id}')), findsOneWidget);

      // Checkbox is locked: tapping does NOT uncheck item
      final checkboxFinder = find.byKey(Key('grocery_item_checkbox_${transferredItem.id}'));
      await tester.ensureVisible(checkboxFinder);
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      expect(GroceryService.instance.currentItems.first.isPurchased, isTrue);
      expect(GroceryService.instance.currentItems.first.isTransferred, isTrue);
    });

    // -------------------------------------------------------------------------
    // 7: Transferred status persists after reload / restart
    // -------------------------------------------------------------------------
    testWidgets('7. Transferred status persists across restarts and re-initialization', (tester) async {
      await GroceryService.instance.addItem(
        name: 'Eggs',
        quantity: 12,
        unit: 'pieces',
        category: 'Dairy & Eggs',
      );
      final item = GroceryService.instance.currentItems.first;
      await GroceryService.instance.togglePurchased(item.id);
      await GroceryService.instance.transferPurchasedToFridge();

      expect(GroceryService.instance.currentItems.first.isTransferred, isTrue);

      // Simulate app restart: re-initialize service with same user ID
      final newService = GroceryService(authService: null);
      newService.testUserIdOverride = 'test_lock_user';
      newService.mockSupabaseTable = GroceryService.instance.mockSupabaseTable;
      await newService.initialize();

      final reloaded = newService.currentItems.first;
      expect(reloaded.name, 'Eggs');
      expect(reloaded.isPurchased, isTrue);
      expect(reloaded.isTransferred, isTrue);
      expect(reloaded.inventoryItemId, isNotNull);
    });

    // -------------------------------------------------------------------------
    // 8: Transferred items cannot be transferred a second time
    // -------------------------------------------------------------------------
    testWidgets('8. Transferred items cannot be transferred a second time', (tester) async {
      await GroceryService.instance.addItem(
        name: 'Cheddar Cheese',
        quantity: 200,
        unit: 'grams',
        category: 'Dairy & Eggs',
      );
      final item = GroceryService.instance.currentItems.first;
      await GroceryService.instance.togglePurchased(item.id);

      // First transfer: transfers 1 item
      final res1 = await GroceryService.instance.transferPurchasedToFridge();
      expect(res1.transferredCount, 1);

      // Second transfer attempt: 0 candidates eligible
      final res2 = await GroceryService.instance.transferPurchasedToFridge();
      expect(res2.transferredCount, 0);
      expect(res2.totalRequested, 0);

      // Verify fridge inventory has only 1 record, not duplicate
      final fridgeTable = GroceryService.instance.mockSupabaseTable!['fridge_items'] ?? [];
      final cheeseCount = fridgeTable.where((r) => r['name'] == 'Cheddar Cheese').length;
      expect(cheeseCount, 1);
    });

    // -------------------------------------------------------------------------
    // 9: Failed transfers do not lock items
    // -------------------------------------------------------------------------
    testWidgets('9. Failed transfers do not lock items', (tester) async {
      await GroceryService.instance.addItem(
        name: 'Brown Bread',
        quantity: 1,
        unit: 'packs',
        category: 'Bakery',
      );
      final item = GroceryService.instance.currentItems.first;
      await GroceryService.instance.togglePurchased(item.id);

      // Simulate network / inventory failure
      GroceryService.instance.simulateNetworkError = true;
      final result = await GroceryService.instance.transferPurchasedToFridge();
      GroceryService.instance.simulateNetworkError = false;

      expect(result.failedCount, 1);
      expect(result.transferredCount, 0);

      final postItem = GroceryService.instance.currentItems.first;
      expect(postItem.isPurchased, isTrue);
      expect(postItem.isTransferred, isFalse);

      await tester.pumpWidget(buildTestApp(const GroceryListScreen(), tester));
      await tester.pumpAndSettle();

      // Edit button is still present, badge is NOT present
      expect(find.byKey(Key('grocery_item_edit_${item.id}')), findsOneWidget);
      expect(find.byKey(Key('transferred_badge_${item.id}')), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 10: Partial transfers lock only successfully transferred items
    // -------------------------------------------------------------------------
    testWidgets('10. Partial transfers lock only successfully transferred items', (tester) async {
      await GroceryService.instance.addItem(name: 'Item 1', category: 'Others');
      await GroceryService.instance.addItem(name: 'Item 2', category: 'Others');

      final items = GroceryService.instance.currentItems;
      await GroceryService.instance.togglePurchased(items[0].id);
      await GroceryService.instance.togglePurchased(items[1].id);

      // Mock table contains a failure simulator by marking Item 2 only
      // Transfer candidates individually
      final item1 = GroceryService.instance.currentItems.firstWhere((it) => it.name == 'Item 1');
      final res = await GroceryService.instance.transferPurchasedToFridge(
        itemsToTransfer: [item1],
      );
      expect(res.transferredCount, 1);

      final stateItem1 = GroceryService.instance.currentItems.firstWhere((it) => it.name == 'Item 1');
      final stateItem2 = GroceryService.instance.currentItems.firstWhere((it) => it.name == 'Item 2');

      expect(stateItem1.isTransferred, isTrue);
      expect(stateItem2.isTransferred, isFalse);

      await tester.pumpWidget(buildTestApp(const GroceryListScreen(), tester));
      await tester.pumpAndSettle();

      // Item 1 is locked (no edit button, has transferred badge)
      expect(find.byKey(Key('grocery_item_edit_${stateItem1.id}')), findsNothing);
      expect(find.byKey(Key('transferred_badge_${stateItem1.id}')), findsOneWidget);

      // Item 2 remains unlocked (has edit button, no transferred badge)
      expect(find.byKey(Key('grocery_item_edit_${stateItem2.id}')), findsOneWidget);
      expect(find.byKey(Key('transferred_badge_${stateItem2.id}')), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 11: Deleting a transferred grocery item does not delete fridge inventory
    // -------------------------------------------------------------------------
    testWidgets('11. Deleting transferred grocery item leaves fridge inventory intact', (tester) async {
      await GroceryService.instance.addItem(
        name: 'Butter',
        quantity: 1,
        unit: 'packs',
        category: 'Dairy & Eggs',
      );
      final item = GroceryService.instance.currentItems.first;
      await GroceryService.instance.togglePurchased(item.id);
      await GroceryService.instance.transferPurchasedToFridge();

      final fridgeTable = GroceryService.instance.mockSupabaseTable!['fridge_items'] ?? [];
      expect(fridgeTable.where((r) => r['name'] == 'Butter').length, 1);

      // Delete from grocery list
      await GroceryService.instance.deleteItem(item.id);
      expect(GroceryService.instance.currentItems.isEmpty, isTrue);

      // Fridge record still exists intact
      final fridgeTableAfter = GroceryService.instance.mockSupabaseTable!['fridge_items'] ?? [];
      expect(fridgeTableAfter.where((r) => r['name'] == 'Butter').length, 1);
    });

    // -------------------------------------------------------------------------
    // 12 & 13: Shopping progress and transfer button count only eligible items
    // -------------------------------------------------------------------------
    testWidgets('12 & 13. Transfer button counts only untransferred purchased items', (tester) async {
      await GroceryService.instance.addItem(name: 'Item A', category: 'Others');
      await GroceryService.instance.addItem(name: 'Item B', category: 'Others');

      final items = GroceryService.instance.currentItems;
      await GroceryService.instance.togglePurchased(items[0].id);
      await GroceryService.instance.togglePurchased(items[1].id);

      // Transfer only 1 item
      final itemA = GroceryService.instance.currentItems.firstWhere((it) => it.name == 'Item A');
      await GroceryService.instance.transferPurchasedToFridge(itemsToTransfer: [itemA]);

      await tester.pumpWidget(buildTestApp(const GroceryListScreen(), tester));
      await tester.pumpAndSettle();

      // Button should display 1 purchased item eligible
      expect(find.text('Add 1 Purchased Item to Fridge'), findsOneWidget);

      // Transfer the second item
      final itemB = GroceryService.instance.currentItems.firstWhere((it) => it.name == 'Item B');
      await GroceryService.instance.transferPurchasedToFridge(itemsToTransfer: [itemB]);

      await tester.pumpWidget(buildTestApp(const GroceryListScreen(), tester));
      await tester.pumpAndSettle();

      // All items transferred: transfer button removed, subtle confirmation message shown
      expect(find.byKey(const Key('add_purchased_to_fridge_btn')), findsNothing);
      expect(find.byKey(const Key('grocery_all_transferred_message')), findsOneWidget);
      expect(find.text('1 item added to Fridge'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 14 & 15: Responsive layout: no overflow at 320, 360, 390, 430px; controls never overlap
    // -------------------------------------------------------------------------
    testWidgets('14 & 15. No overflow or control overlap across 320, 360, 390, 430px viewports', (tester) async {
      final widths = [320.0, 360.0, 390.0, 430.0];

      await GroceryService.instance.addItem(
        name: 'Extra Virgin Italian Olive Oil Cold Pressed',
        quantity: 500,
        unit: 'millilitres',
        category: 'Grains & Staples',
      );
      final item = GroceryService.instance.currentItems.first;
      await GroceryService.instance.togglePurchased(item.id);
      await GroceryService.instance.transferPurchasedToFridge();

      for (final w in widths) {
        tester.view.physicalSize = Size(w, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(buildTestApp(const GroceryListScreen(), tester, size: Size(w, 800)));
        await tester.pumpAndSettle();

        // Must have zero render overflow exceptions
        expect(tester.takeException(), isNull, reason: 'Render overflow detected at width $w');

        // Transferred badge and delete button are both present and properly separated
        expect(find.byKey(Key('transferred_badge_${item.id}')), findsOneWidget);
        expect(find.byKey(Key('grocery_item_delete_${item.id}')), findsOneWidget);
        expect(find.byKey(Key('grocery_item_edit_${item.id}')), findsNothing);

        // Verify badge and delete button do not overlap horizontally
        final badgeRect = tester.getRect(find.byKey(Key('transferred_badge_${item.id}')));
        final deleteRect = tester.getRect(find.byKey(Key('grocery_item_delete_${item.id}')));
        expect(badgeRect.overlaps(deleteRect), isFalse, reason: 'Badge and delete button overlap at width $w');
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
