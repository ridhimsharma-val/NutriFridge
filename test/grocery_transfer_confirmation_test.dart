import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/models/grocery_item.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/screens/grocery/grocery_list_screen.dart';
import 'package:nutrifridge/services/grocery/grocery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget buildTestApp(Widget child, WidgetTester tester, [double width = 390.0, double height = 1200.0]) {
  final size = Size(width, height);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    GroceryService.instance.resetTestingState();
    GroceryService.instance.testUserIdOverride = 'test_confirmation_user';
    GroceryService.instance.mockSupabaseTable = {
      'grocery_items': <Map<String, dynamic>>[],
      'fridge_items': <Map<String, dynamic>>[],
    };
    FridgeCategoryRepository.forceInMemoryForTesting = true;
    await GroceryService.instance.initialize();
  });

  tearDown(() {
    FridgeCategoryRepository.forceInMemoryForTesting = false;
  });

  group('Grocery Transfer Confirmation & Button Visibility', () {
    // -------------------------------------------------------------------------
    // 1. Zero eligible items hides the transfer button
    // -------------------------------------------------------------------------
    testWidgets('1. Zero eligible items hides the transfer button', (tester) async {
      await GroceryService.instance.addItem(name: 'Watermelon', category: 'Fruits');
      final item = GroceryService.instance.currentItems.first;
      await GroceryService.instance.togglePurchased(item.id);

      // Successfully transfer the watermelon
      await GroceryService.instance.transferPurchasedToFridge();

      await tester.pumpWidget(buildTestApp(const GroceryListScreen(), tester));
      await tester.pumpAndSettle();

      // Zero-count button is completely removed
      expect(find.byKey(const Key('add_purchased_to_fridge_btn')), findsNothing);
      expect(find.text('Add 0 Purchased Items to Fridge'), findsNothing);
      expect(find.textContaining('Add 0 Purchased'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 2. One successful transfer displays "1 item added to Fridge"
    // -------------------------------------------------------------------------
    testWidgets('2. One successful transfer displays "1 item added to Fridge"', (tester) async {
      await GroceryService.instance.addItem(name: 'Watermelon', category: 'Fruits');
      final item = GroceryService.instance.currentItems.first;
      await GroceryService.instance.togglePurchased(item.id);

      // Perform transfer
      final result = await GroceryService.instance.transferPurchasedToFridge();
      expect(result.transferredCount, 1);

      await tester.pumpWidget(buildTestApp(const GroceryListScreen(), tester));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('grocery_all_transferred_message')), findsOneWidget);
      expect(find.text('1 item added to Fridge'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
    });

    // -------------------------------------------------------------------------
    // 3. Multiple successful transfers display the correct count
    // -------------------------------------------------------------------------
    testWidgets('3. Multiple successful transfers display "3 items added to Fridge"', (tester) async {
      final i1 = await GroceryService.instance.addItem(name: 'Milk', category: 'Dairy Products');
      final i2 = await GroceryService.instance.addItem(name: 'Eggs', category: 'Non-Veg');
      final i3 = await GroceryService.instance.addItem(name: 'Spinach', category: 'Vegetables');

      await GroceryService.instance.togglePurchased(i1.id);
      await GroceryService.instance.togglePurchased(i2.id);
      await GroceryService.instance.togglePurchased(i3.id);

      final result = await GroceryService.instance.transferPurchasedToFridge();
      expect(result.transferredCount, 3);

      await tester.pumpWidget(buildTestApp(const GroceryListScreen(), tester));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('grocery_all_transferred_message')), findsOneWidget);
      expect(find.text('3 items added to Fridge'), findsOneWidget);
      expect(find.byKey(const Key('add_purchased_to_fridge_btn')), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 4. Failed transfers are not counted
    // -------------------------------------------------------------------------
    testWidgets('4. Failed transfers are not counted in confirmation', (tester) async {
      final i1 = await GroceryService.instance.addItem(name: 'Tomatoes', category: 'Vegetables');
      final i2 = await GroceryService.instance.addItem(name: 'Cucumber', category: 'Vegetables');

      await GroceryService.instance.togglePurchased(i1.id);
      await GroceryService.instance.togglePurchased(i2.id);

      // First item succeeds
      final item1 = GroceryService.instance.currentItems.firstWhere((it) => it.id == i1.id);
      await GroceryService.instance.transferPurchasedToFridge(itemsToTransfer: [item1]);

      // Second item fails due to simulated error
      GroceryService.instance.simulateFridgeInventoryError = true;
      final item2 = GroceryService.instance.currentItems.firstWhere((it) => it.id == i2.id);
      final failedResult = await GroceryService.instance.transferPurchasedToFridge(itemsToTransfer: [item2]);
      GroceryService.instance.simulateFridgeInventoryError = false;

      expect(failedResult.failedCount, 1);
      expect(failedResult.transferredCount, 0);

      await tester.pumpWidget(buildTestApp(const GroceryListScreen(), tester));
      await tester.pumpAndSettle();

      // Since item2 is still untransferred, button reappears with 1 eligible item
      expect(find.text('Add 1 Purchased Item to Fridge'), findsOneWidget);

      // Failed item is not counted
      expect(find.text('2 items added to Fridge'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 5. Previously transferred items are not counted again
    // -------------------------------------------------------------------------
    testWidgets('5. Previously transferred items are not counted again in subsequent transfer', (tester) async {
      final i1 = await GroceryService.instance.addItem(name: 'Yogurt', category: 'Dairy Products');
      await GroceryService.instance.togglePurchased(i1.id);
      await GroceryService.instance.transferPurchasedToFridge();

      // Later, add 2 new items
      final i2 = await GroceryService.instance.addItem(name: 'Apples', category: 'Fruits');
      final i3 = await GroceryService.instance.addItem(name: 'Oranges', category: 'Fruits');

      await GroceryService.instance.togglePurchased(i2.id);
      await GroceryService.instance.togglePurchased(i3.id);

      // Transfer the 2 new items
      final res = await GroceryService.instance.transferPurchasedToFridge();
      expect(res.transferredCount, 2);

      await tester.pumpWidget(buildTestApp(const GroceryListScreen(), tester));
      await tester.pumpAndSettle();

      // Displays 2 items added (the newly transferred count), not 3
      expect(find.text('2 items added to Fridge'), findsOneWidget);
      expect(find.text('3 items added to Fridge'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 6. Newly purchased items make the transfer button reappear
    // -------------------------------------------------------------------------
    testWidgets('6. Newly purchased items make the transfer button reappear', (tester) async {
      await GroceryService.instance.addItem(name: 'Watermelon', category: 'Fruits');
      final item1 = GroceryService.instance.currentItems.first;
      await GroceryService.instance.togglePurchased(item1.id);
      await GroceryService.instance.transferPurchasedToFridge();

      await tester.pumpWidget(buildTestApp(const GroceryListScreen(), tester));
      await tester.pumpAndSettle();

      // Button is hidden
      expect(find.byKey(const Key('add_purchased_to_fridge_btn')), findsNothing);
      expect(find.text('1 item added to Fridge'), findsOneWidget);

      // Now add another item and mark as purchased
      final item2 = await GroceryService.instance.addItem(name: 'Grapes', category: 'Fruits');
      await GroceryService.instance.togglePurchased(item2.id);

      await tester.pumpAndSettle();

      // Transfer button reappears with 1 eligible item
      expect(find.byKey(const Key('add_purchased_to_fridge_btn')), findsOneWidget);
      expect(find.text('Add 1 Purchased Item to Fridge'), findsOneWidget);
      expect(find.byKey(const Key('grocery_all_transferred_message')), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 7. Per-item "In Fridge" badges remain visible
    // -------------------------------------------------------------------------
    testWidgets('7. Per-item "In Fridge" badges remain visible after transfer', (tester) async {
      final i1 = await GroceryService.instance.addItem(name: 'Watermelon', category: 'Fruits');
      await GroceryService.instance.togglePurchased(i1.id);
      await GroceryService.instance.transferPurchasedToFridge();

      await tester.pumpWidget(buildTestApp(const GroceryListScreen(), tester));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('transferred_badge_${i1.id}')), findsOneWidget);
      expect(find.text('In Fridge'), findsOneWidget);
      expect(find.text('1 item added to Fridge'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 8. No unnecessary empty space remains & hide confirmation when no transfer has occurred
    // -------------------------------------------------------------------------
    testWidgets('8. Hide confirmation when no transfer has occurred in session', (tester) async {
      // Create an item that was already transferred in a previous session
      final preTransferred = GroceryItem(
        id: 'pre_transferred_1',
        userId: 'test_confirmation_user',
        name: 'Pre-transferred Cheese',
        quantity: 1,
        unit: 'pieces',
        category: 'Dairy Products',
        isPurchased: true,
        isTransferred: true,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
        transferredAt: DateTime.now().subtract(const Duration(days: 1)),
        inventoryItemId: 'inv_old_1',
      );
      GroceryService.instance.mockSupabaseTable!['grocery_items'] = [preTransferred.toSupabaseRow('test_confirmation_user')];
      await GroceryService.instance.initialize();

      // Verify no transfer in this session
      expect(GroceryService.instance.sessionTransferredCount, isNull);

      await tester.pumpWidget(buildTestApp(const GroceryListScreen(), tester));
      await tester.pumpAndSettle();

      // No transfer button
      expect(find.byKey(const Key('add_purchased_to_fridge_btn')), findsNothing);
      // Confirmation message is hidden because no transfer occurred in this session
      expect(find.byKey(const Key('grocery_all_transferred_message')), findsNothing);
      expect(find.textContaining('added to Fridge'), findsNothing);
      // Badge is visible
      expect(find.text('In Fridge'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 9. No horizontal or vertical overflow across 320, 360, 390, 430px viewports
    // -------------------------------------------------------------------------
    testWidgets('9. No layout overflow across 320, 360, 390, 430px viewports', (tester) async {
      final widths = [320.0, 360.0, 390.0, 430.0];

      final i1 = await GroceryService.instance.addItem(
        name: 'Extremely Long Descriptive Organic Heirloom Watermelon Seedless',
        category: 'Fruits',
      );
      await GroceryService.instance.togglePurchased(i1.id);
      await GroceryService.instance.transferPurchasedToFridge();

      for (final w in widths) {
        await tester.pumpWidget(buildTestApp(const GroceryListScreen(), tester, w, 800.0));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Must not throw layout overflow at width $w');
        expect(find.text('1 item added to Fridge'), findsOneWidget);
        expect(find.byKey(const Key('add_purchased_to_fridge_btn')), findsNothing);
      }
    });

    // -------------------------------------------------------------------------
    // 10. Interactive One-Tap Transfer in UI updates button and confirmation
    // -------------------------------------------------------------------------
    testWidgets('10. Interactive One-Tap Transfer via UI updates button to confirmation', (tester) async {
      final item = await GroceryService.instance.addItem(name: 'Watermelon', category: 'Fruits');
      await GroceryService.instance.togglePurchased(item.id);

      await tester.pumpWidget(buildTestApp(const GroceryListScreen(), tester));
      await tester.pumpAndSettle();

      // Before transfer: button visible
      expect(find.byKey(const Key('add_purchased_to_fridge_btn')), findsOneWidget);
      expect(find.text('Add 1 Purchased Item to Fridge'), findsOneWidget);
      expect(find.byKey(const Key('grocery_all_transferred_message')), findsNothing);

      // Tap transfer button
      await tester.ensureVisible(find.byKey(const Key('add_purchased_to_fridge_btn')));
      await tester.tap(find.byKey(const Key('add_purchased_to_fridge_btn')));
      await tester.pumpAndSettle();

      // After transfer: button gone, confirmation displayed
      expect(find.byKey(const Key('add_purchased_to_fridge_btn')), findsNothing);
      expect(find.byKey(const Key('grocery_all_transferred_message')), findsOneWidget);
      expect(find.text('1 item added to Fridge'), findsOneWidget);
      expect(find.text('In Fridge'), findsOneWidget);
    });
  });
}
