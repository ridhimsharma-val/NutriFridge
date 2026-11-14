import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/screens/grocery/grocery_list_screen.dart';
import 'package:nutrifridge/services/grocery/grocery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FridgeCategoryRepository.forceInMemoryForTesting = true;
    FridgeCategoryRepository.testUserIdOverride = 'test_transfer_user';
    FridgeCategoryRepository.reset();
    GroceryService.instance.resetTestingState();
    GroceryService.instance.testUserIdOverride = 'test_transfer_user';
    await GroceryService.instance.initialize();
  });

  Widget buildTestApp(Widget child, {Size size = const Size(600, 1200)}) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        home: child,
      ),
    );
  }

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('NutriFridge — One-Tap Grocery to Fridge Inventory Transfer Test Suite', () {
    // -------------------------------------------------------------------------
    // 1. No purchased items means transfer is unavailable
    // -------------------------------------------------------------------------
    testWidgets('1. No purchased items means transfer is unavailable', (tester) async {
      configureViewport(tester);

      // Add only pending items
      await GroceryService.instance.addItem(name: 'Fresh Kale', quantity: 1, unit: 'bunches');
      await GroceryService.instance.addItem(name: 'Oat Milk', quantity: 1, unit: 'litres');

      expect(GroceryService.instance.eligibleTransferCount, 0);

      final result = await GroceryService.instance.transferPurchasedToFridge();
      expect(result.totalRequested, 0);
      expect(result.transferredCount, 0);

      // In UI, transfer button is unavailable (either hidden or disabled)
      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      final transferBtnFinder = find.byKey(const Key('add_purchased_to_fridge_btn'));
      if (transferBtnFinder.evaluate().isNotEmpty) {
        final btn = tester.widget<ElevatedButton>(transferBtnFinder);
        expect(btn.onPressed, isNull, reason: 'Transfer button must be disabled when no items are purchased');
      } else {
        expect(transferBtnFinder, findsNothing, reason: 'Transfer button is safely hidden when no completed items exist');
      }
    });

    // -------------------------------------------------------------------------
    // 2. Pending items are never transferred
    // -------------------------------------------------------------------------
    testWidgets('2. Pending items are never transferred', (tester) async {
      final resPending = await GroceryService.instance.addItem(
        name: 'Whole Grain Bread',
        quantity: 1,
        unit: 'pieces',
        category: 'Bakery',
      );
      final resPurchased = await GroceryService.instance.addItem(
        name: 'Cheddar Cheese',
        quantity: 200,
        unit: 'g',
        category: 'Dairy & Eggs',
      );

      // Only mark cheddar purchased
      await GroceryService.instance.togglePurchased(resPurchased.id);

      final result = await GroceryService.instance.transferPurchasedToFridge();
      expect(result.transferredCount, 1);

      // Check pending item was NOT transferred
      final freshPending = GroceryService.instance.currentItems.firstWhere((it) => it.id == resPending.id);
      expect(freshPending.isPurchased, isFalse);
      expect(freshPending.isTransferred, isFalse);
      expect(freshPending.inventoryItemId, isNull);

      // Verify fridge inventory contains cheese in Dairy Products, but NOT bread in Packaged Food
      final packagedItems = FridgeCategoryRepository.getCategoryData('Packaged Food').items;
      expect(packagedItems.any((it) => it.name == 'Whole Grain Bread'), isFalse);

      final dairyItems = FridgeCategoryRepository.getCategoryData('Dairy Products').items;
      expect(dairyItems.any((it) => it.name == 'Cheddar Cheese'), isTrue);
    });

    // -------------------------------------------------------------------------
    // 3. One purchased item transfers correctly
    // -------------------------------------------------------------------------
    testWidgets('3. One purchased item transfers correctly with compact feedback', (tester) async {
      configureViewport(tester);

      final res = await GroceryService.instance.addItem(
        name: 'Fresh Spinach',
        quantity: 250,
        unit: 'g',
        category: 'Fruits & Vegetables',
      );
      await GroceryService.instance.togglePurchased(res.id);

      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Add 1 Purchased Item to Fridge'), findsOneWidget);

      // Tap the one-tap transfer button
      final btnFinder = find.byKey(const Key('add_purchased_to_fridge_btn'));
      await tester.ensureVisible(btnFinder);
      await tester.tap(btnFinder);
      await tester.pumpAndSettle();

      // Verify compact SnackBar
      expect(find.text('1 grocery added to your fridge!'), findsOneWidget);

      // Verify item marked transferred
      final updated = GroceryService.instance.currentItems.firstWhere((it) => it.id == res.id);
      expect(updated.isTransferred, isTrue);
      expect(updated.transferredAt, isNotNull);
      expect(updated.inventoryItemId, isNotNull);

      // Verify in fridge inventory
      final vegItems = FridgeCategoryRepository.getCategoryData('Vegetables').items;
      expect(vegItems.any((it) => it.name == 'Fresh Spinach'), isTrue);
    });

    // -------------------------------------------------------------------------
    // 4. Multiple purchased items transfer in one action
    // -------------------------------------------------------------------------
    testWidgets('4. Multiple purchased items transfer in one action', (tester) async {
      configureViewport(tester);

      final r1 = await GroceryService.instance.addItem(name: 'Greek Yogurt', quantity: 500, unit: 'g', category: 'Dairy & Eggs');
      final r2 = await GroceryService.instance.addItem(name: 'Bananas', quantity: 6, unit: 'pieces', category: 'Fruits & Vegetables');
      final r3 = await GroceryService.instance.addItem(name: 'Brown Rice', quantity: 1, unit: 'kg', category: 'Grains & Staples');

      await GroceryService.instance.togglePurchased(r1.id);
      await GroceryService.instance.togglePurchased(r2.id);
      await GroceryService.instance.togglePurchased(r3.id);

      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Add 3 Purchased Items to Fridge'), findsOneWidget);

      final btnFinder = find.byKey(const Key('add_purchased_to_fridge_btn'));
      await tester.ensureVisible(btnFinder);
      await tester.tap(btnFinder);
      await tester.pumpAndSettle();

      expect(find.text('3 groceries added to your fridge!'), findsOneWidget);

      expect(GroceryService.instance.transferredItems.length, 3);
      expect(GroceryService.instance.eligibleTransferCount, 0);

      expect(FridgeCategoryRepository.getCategoryData('Dairy Products').items.any((it) => it.name == 'Greek Yogurt'), isTrue);
      expect(FridgeCategoryRepository.getCategoryData('Fruits').items.any((it) => it.name == 'Bananas'), isTrue);
      expect(FridgeCategoryRepository.getCategoryData('Packaged Food').items.any((it) => it.name == 'Brown Rice'), isTrue);
    });

    // -------------------------------------------------------------------------
    // 5. Correct names, quantities, units and categories are preserved
    // -------------------------------------------------------------------------
    testWidgets('5. Correct names, quantities, units and categories are preserved', (tester) async {
      final res = await GroceryService.instance.addItem(
        name: 'Almond Milk',
        quantity: 2.5,
        unit: 'litres',
        category: 'Beverages',
      );
      await GroceryService.instance.togglePurchased(res.id);

      final result = await GroceryService.instance.transferPurchasedToFridge();
      expect(result.transferredCount, 1);

      final drinkItems = FridgeCategoryRepository.getCategoryData('Drinks & Juices').items;
      final transferredInv = drinkItems.firstWhere((it) => it.name == 'Almond Milk');

      expect(transferredInv.name, 'Almond Milk');
      expect(transferredInv.category, 'Drinks & Juices');
      expect(transferredInv.quantity, contains('2.5'));
      expect(transferredInv.quantity, contains('litres'));
    });

    // -------------------------------------------------------------------------
    // 6. Expiry handling follows existing rules
    // -------------------------------------------------------------------------
    testWidgets('6. Expiry handling follows existing rules and preserves custom expiry', (tester) async {
      final customExpiry = DateTime(2026, 12, 25);
      final r1 = await GroceryService.instance.addItem(
        name: 'Fresh Tofu',
        quantity: 1,
        unit: 'pieces',
        category: 'Dairy & Eggs',
      );
      await GroceryService.instance.togglePurchased(r1.id);
      // Set custom expiry date
      final tofuItem = GroceryService.instance.currentItems.firstWhere((it) => it.id == r1.id);
      await GroceryService.instance.updateItem(tofuItem.copyWith(expiryDate: customExpiry));

      final r2 = await GroceryService.instance.addItem(
        name: 'Eggs',
        quantity: 12,
        unit: 'pieces',
        category: 'Dairy & Eggs',
      );
      await GroceryService.instance.togglePurchased(r2.id);

      final result = await GroceryService.instance.transferPurchasedToFridge(defaultExpiryDays: 10);
      expect(result.transferredCount, 2);

      final dairyItems = FridgeCategoryRepository.getCategoryData('Dairy Products').items;
      final tofu = dairyItems.firstWhere((it) => it.name == 'Fresh Tofu');
      final eggs = dairyItems.firstWhere((it) => it.name == 'Eggs');

      // Tofu preserves exact custom expiry
      expect(tofu.expiryDate, customExpiry);

      // Eggs received standard 10 days preset
      expect(eggs.expiryDays, 10);
      expect(eggs.expiryDate, isNotNull);
    });

    // -------------------------------------------------------------------------
    // 7. Duplicate taps do not cause duplicate inventory entries
    // -------------------------------------------------------------------------
    testWidgets('7. Duplicate taps do not cause duplicate inventory entries (concurrency guard)', (tester) async {
      final res = await GroceryService.instance.addItem(
        name: 'Strawberries',
        quantity: 1,
        unit: 'pieces',
        category: 'Fruits & Vegetables',
      );
      await GroceryService.instance.togglePurchased(res.id);

      // Fire two concurrent transfers simultaneously
      final results = await Future.wait([
        GroceryService.instance.transferPurchasedToFridge(),
        GroceryService.instance.transferPurchasedToFridge(),
      ]);

      // Exactly one succeeds, the other safely returns 0 without inserting duplicates
      final totalTransferred = results[0].transferredCount + results[1].transferredCount;
      expect(totalTransferred, 1);

      final fruitItems = FridgeCategoryRepository.getCategoryData('Fruits').items;
      final strawberryMatches = fruitItems.where((it) => it.name == 'Strawberries').toList();
      expect(strawberryMatches.length, 1, reason: 'Duplicate tap must not produce duplicate inventory entries');
    });

    // -------------------------------------------------------------------------
    // 8. Successful items are marked as transferred
    // -------------------------------------------------------------------------
    testWidgets('8. Successful items are marked as transferred and display In Fridge badge', (tester) async {
      configureViewport(tester);

      final res = await GroceryService.instance.addItem(
        name: 'Avocado',
        quantity: 2,
        unit: 'pieces',
        category: 'Fruits & Vegetables',
      );
      await GroceryService.instance.togglePurchased(res.id);

      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      final btnFinder = find.byKey(const Key('add_purchased_to_fridge_btn'));
      await tester.ensureVisible(btnFinder);
      await tester.tap(btnFinder);
      await tester.pumpAndSettle();

      // Check badge rendered in UI
      expect(find.byKey(Key('transferred_badge_${res.id}')), findsOneWidget);
      expect(find.text('In Fridge'), findsOneWidget);

      // Check shopping completion is preserved (100%)
      expect(GroceryService.instance.progress, 1.0);
      expect(GroceryService.instance.allCompletedCount, 1);
      expect(find.text('1 of 1 items completed'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 9. Failed items remain available for retry
    // -------------------------------------------------------------------------
    testWidgets('9. Failed items remain available for retry after simulated error', (tester) async {
      final res = await GroceryService.instance.addItem(
        name: 'Salmon Fillet',
        quantity: 300,
        unit: 'g',
        category: 'Meat & Seafood',
      );
      await GroceryService.instance.togglePurchased(res.id);

      // Simulate repository failure
      GroceryService.instance.simulateFridgeInventoryError = true;

      final failedResult = await GroceryService.instance.transferPurchasedToFridge();
      expect(failedResult.failedCount, 1);
      expect(failedResult.transferredCount, 0);

      // Item must remain untransferred and eligible
      final itemAfterFail = GroceryService.instance.currentItems.firstWhere((it) => it.id == res.id);
      expect(itemAfterFail.isTransferred, isFalse);
      expect(GroceryService.instance.eligibleTransferCount, 1);

      // Clear failure and retry
      GroceryService.instance.simulateFridgeInventoryError = false;
      final retryResult = await GroceryService.instance.transferPurchasedToFridge();
      expect(retryResult.transferredCount, 1);
      expect(retryResult.failedCount, 0);

      final itemAfterRetry = GroceryService.instance.currentItems.firstWhere((it) => it.id == res.id);
      expect(itemAfterRetry.isTransferred, isTrue);
      expect(GroceryService.instance.eligibleTransferCount, 0);
    });

    // -------------------------------------------------------------------------
    // 10. Partial success is handled correctly
    // -------------------------------------------------------------------------
    testWidgets('10. Partial success is handled correctly', (tester) async {
      final r1 = await GroceryService.instance.addItem(name: 'Oranges', quantity: 4, unit: 'pieces');
      final r2 = await GroceryService.instance.addItem(name: 'Carrots', quantity: 500, unit: 'g');

      await GroceryService.instance.togglePurchased(r1.id);
      await GroceryService.instance.togglePurchased(r2.id);

      final item1 = GroceryService.instance.currentItems.firstWhere((it) => it.id == r1.id);
      final item2 = GroceryService.instance.currentItems.firstWhere((it) => it.id == r2.id);

      // Transfer item1 successfully
      final result1 = await GroceryService.instance.transferPurchasedToFridge(itemsToTransfer: [item1]);
      expect(result1.transferredCount, 1);

      // Fail item2
      GroceryService.instance.simulateFridgeInventoryError = true;
      final result2 = await GroceryService.instance.transferPurchasedToFridge(itemsToTransfer: [item2]);
      expect(result2.failedCount, 1);
      expect(result2.transferredCount, 0);

      final freshI1 = GroceryService.instance.currentItems.firstWhere((it) => it.id == r1.id);
      final freshI2 = GroceryService.instance.currentItems.firstWhere((it) => it.id == r2.id);

      expect(freshI1.isTransferred, isTrue);
      expect(freshI2.isTransferred, isFalse);
      expect(GroceryService.instance.eligibleTransferCount, 1);

      GroceryService.instance.simulateFridgeInventoryError = false;
    });

    // -------------------------------------------------------------------------
    // 11. Fridge inventory updates after successful transfer
    // -------------------------------------------------------------------------
    testWidgets('11. Fridge inventory updates after successful transfer', (tester) async {
      final res = await GroceryService.instance.addItem(
        name: 'Sourdough Bread',
        quantity: 1,
        unit: 'pieces',
        category: 'Bakery',
      );
      await GroceryService.instance.togglePurchased(res.id);

      final initialPackagedCount = FridgeCategoryRepository.getCategoryData('Packaged Food').items.length;

      final result = await GroceryService.instance.transferPurchasedToFridge();
      expect(result.transferredCount, 1);

      final updatedPackagedItems = FridgeCategoryRepository.getCategoryData('Packaged Food').items;
      expect(updatedPackagedItems.length, initialPackagedCount + 1);
      expect(updatedPackagedItems.any((it) => it.name == 'Sourdough Bread'), isTrue);
    });

    // -------------------------------------------------------------------------
    // 12. Successfully transferred items cannot be transferred again
    // -------------------------------------------------------------------------
    testWidgets('12. Successfully transferred items cannot be transferred again', (tester) async {
      configureViewport(tester);

      final res = await GroceryService.instance.addItem(
        name: 'Soy Milk',
        quantity: 1,
        unit: 'litres',
        category: 'Beverages',
      );
      await GroceryService.instance.togglePurchased(res.id);

      // First transfer succeeds
      final res1 = await GroceryService.instance.transferPurchasedToFridge();
      expect(res1.transferredCount, 1);

      // Attempt second transfer
      final res2 = await GroceryService.instance.transferPurchasedToFridge();
      expect(res2.transferredCount, 0);
      expect(res2.totalRequested, 0);

      // In UI, button displays 0 eligible and is disabled
      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      final transferBtn = tester.widget<ElevatedButton>(find.byKey(const Key('add_purchased_to_fridge_btn')));
      expect(transferBtn.onPressed, isNull);
      expect(find.text('Add 0 Purchased Items to Fridge'), findsOneWidget);

      // Verify no duplicate in fridge (Beverages maps to Drinks & Juices)
      final drinkCount = FridgeCategoryRepository.getCategoryData('Drinks & Juices')
          .items
          .where((it) => it.name == 'Soy Milk')
          .length;
      expect(drinkCount, 1);
    });
  });
}
