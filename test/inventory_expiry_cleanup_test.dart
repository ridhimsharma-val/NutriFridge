import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/screens/fridge/fridge_page.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/screens/fridge/services/use_soon_service.dart';
import 'package:nutrifridge/services/inventory/fridge_inventory_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final localToday = DateTime(2026, 11, 14);
  final yesterday = DateTime(2026, 11, 13);
  final today = DateTime(2026, 11, 14);
  final tomorrow = DateTime(2026, 11, 15);
  final in3Days = DateTime(2026, 11, 17);

  final appleYesterday = CategoryFoodItem(
    id: 'item_apples_exp',
    name: 'Apples',
    quantity: '4 pieces',
    expiryDate: yesterday,
    category: 'Fruits',
  );
  final spinachToday = CategoryFoodItem(
    id: 'item_spinach_today',
    name: 'Spinach',
    quantity: '200 g',
    expiryDate: today,
    category: 'Vegetables',
  );
  final milkTomorrow = CategoryFoodItem(
    id: 'item_milk_tomorrow',
    name: 'Milk',
    quantity: '1 L',
    expiryDate: tomorrow,
    category: 'Dairy Products',
  );
  final bananasIn3Days = CategoryFoodItem(
    id: 'item_bananas_3d',
    name: 'Bananas',
    quantity: '6 pieces',
    expiryDate: in3Days,
    category: 'Fruits',
  );
  final oliveOilUnknown = const CategoryFoodItem(
    id: 'item_olive_oil_unk',
    name: 'Olive Oil',
    quantity: '500 ml',
    expiryDate: null,
    category: 'Others',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FridgeCategoryRepository.forceInMemoryForTesting = true;
    FridgeCategoryRepository.testUserIdOverride = 'test_user_global';
    FridgeCategoryRepository.reset();
    FridgeInventoryRepository.resetTestingState();
  });

  group('NutriFridge — Automatic Expired Inventory Cleanup Tests', () {
    // 1. Opening My Fridge invokes user-scoped cleanup
    test('1. Opening My Fridge invokes user-scoped cleanup', () async {
      FridgeCategoryRepository.forceInMemoryForTesting = false;

      int cleanupCalls = 0;
      FridgeInventoryRepository.mockCleanupHandler = (userId) async {
        cleanupCalls++;
        return 1;
      };
      FridgeInventoryRepository.mockFetchHandler = (userId) async {
        return [spinachToday, milkTomorrow];
      };

      await FridgeCategoryRepository.loadFromSupabase(userId: 'user_test_1', force: true);

      expect(cleanupCalls, 1, reason: 'Cleanup RPC must be triggered when loading My Fridge inventory');
      expect(FridgeCategoryRepository.totalFridgeItems, 2);
    });

    // 2. Cleanup completes before updated inventory is fetched
    test('2. Cleanup completes before updated inventory is fetched', () async {
      FridgeCategoryRepository.forceInMemoryForTesting = false;

      FridgeInventoryRepository.mockCleanupHandler = (userId) async {
        return 2;
      };
      FridgeInventoryRepository.mockFetchHandler = (userId) async {
        return [spinachToday];
      };

      await FridgeCategoryRepository.loadFromSupabase(userId: 'user_test_2', force: true);

      expect(
        FridgeInventoryRepository.operationTrace,
        ['cleanup', 'fetch'],
        reason: 'Cleanup must strictly execute and complete before fetching active inventory',
      );
    });

    // 3. Expired items disappear from the Fridge
    test('3. Expired items disappear from the Fridge', () async {
      FridgeCategoryRepository.forceInMemoryForTesting = false;

      // Simulated DB state before cleanup: apples (yesterday) was cleaned up on server,
      // so fetch returns only the remaining active items
      FridgeInventoryRepository.mockCleanupHandler = (userId) async => 1;
      FridgeInventoryRepository.mockFetchHandler = (userId) async => [spinachToday, milkTomorrow];

      await FridgeCategoryRepository.loadFromSupabase(userId: 'user_test_3', force: true);

      final activeIds = FridgeCategoryRepository.allItems.map((e) => e.id).toSet();
      expect(activeIds.contains('item_apples_exp'), isFalse);
      expect(FridgeCategoryRepository.totalFridgeItems, 2);
    });

    // 4. Items expiring today remain
    test('4. Items expiring today remain available throughout their expiry date', () async {
      FridgeCategoryRepository.forceInMemoryForTesting = true;
      await FridgeCategoryRepository.addItemToCategory('Vegetables', spinachToday);

      expect(spinachToday.isExpired, isFalse);
      expect(UseSoonService.getEffectiveExpiryDays(spinachToday, localToday), 0);
      expect(FridgeCategoryRepository.totalFridgeItems, 1);

      // Purge run on localToday must NOT remove today's item
      final purged = FridgeCategoryRepository.purgeExpiredItems(localToday);
      expect(purged, 0);
      expect(FridgeCategoryRepository.totalFridgeItems, 1);
      expect(FridgeCategoryRepository.allItems.first.id, 'item_spinach_today');
    });

    // 5. Future-expiry items remain
    test('5. Future-expiry items remain in inventory', () async {
      FridgeCategoryRepository.forceInMemoryForTesting = true;
      await FridgeCategoryRepository.addItemToCategory('Dairy Products', milkTomorrow);
      await FridgeCategoryRepository.addItemToCategory('Fruits', bananasIn3Days);

      expect(milkTomorrow.isExpired, isFalse);
      expect(bananasIn3Days.isExpired, isFalse);

      final purged = FridgeCategoryRepository.purgeExpiredItems(localToday);
      expect(purged, 0);
      expect(FridgeCategoryRepository.totalFridgeItems, 2);
    });

    // 6. Unknown-expiry items remain
    test('6. Unknown-expiry items remain without fabricated dates', () async {
      FridgeCategoryRepository.forceInMemoryForTesting = true;
      await FridgeCategoryRepository.addItemToCategory('Others', oliveOilUnknown);

      expect(oliveOilUnknown.expiryDate, isNull);
      expect(oliveOilUnknown.isExpired, isFalse);
      expect(UseSoonService.getEffectiveExpiryDays(oliveOilUnknown, localToday), isNull);

      final purged = FridgeCategoryRepository.purgeExpiredItems(localToday);
      expect(purged, 0);
      expect(FridgeCategoryRepository.totalFridgeItems, 1);
      expect(FridgeCategoryRepository.allItems.first.id, 'item_olive_oil_unk');
    });

    // 7. Multiple batches are handled independently
    test('7. Multiple batches are handled independently: expired batch deleted, valid batch preserved', () async {
      FridgeCategoryRepository.forceInMemoryForTesting = true;

      final expiredTomatoes = CategoryFoodItem(
        id: 'tomatoes_batch_old',
        name: 'Tomatoes',
        quantity: '500 g',
        expiryDate: yesterday,
        category: 'Vegetables',
      );
      final freshTomatoes = CategoryFoodItem(
        id: 'tomatoes_batch_fresh',
        name: 'Tomatoes',
        quantity: '1 kg',
        expiryDate: DateTime(2026, 11, 18),
        category: 'Vegetables',
      );

      await FridgeCategoryRepository.addItemToCategory('Vegetables', expiredTomatoes);
      await FridgeCategoryRepository.addItemToCategory('Vegetables', freshTomatoes);
      expect(FridgeCategoryRepository.totalFridgeItems, 2);

      final purged = FridgeCategoryRepository.purgeExpiredItems(localToday);
      expect(purged, 1);

      final remaining = FridgeCategoryRepository.getItemsForCategory('Vegetables');
      expect(remaining.length, 1);
      expect(remaining.first.id, 'tomatoes_batch_fresh');
      expect(remaining.first.quantity, '1 kg');
      expect(remaining.first.decimalAmount, 1.0);
    });

    // 8. Realtime DELETE events update visible inventory
    test('8. Realtime DELETE events update visible inventory immediately', () async {
      FridgeCategoryRepository.forceInMemoryForTesting = true;
      await FridgeCategoryRepository.addItemToCategory('Fruits', appleYesterday);
      await FridgeCategoryRepository.addItemToCategory('Vegetables', spinachToday);

      expect(FridgeCategoryRepository.totalFridgeItems, 2);

      // Simulate Realtime DELETE event payload pushed by PostgreSQL pg_cron
      FridgeCategoryRepository.handleRealtimeEvent('DELETE', {'id': 'item_apples_exp'});

      expect(FridgeCategoryRepository.totalFridgeItems, 1);
      final remainingIds = FridgeCategoryRepository.allItems.map((e) => e.id).toList();
      expect(remainingIds, ['item_spinach_today']);
      expect(remainingIds.contains('item_apples_exp'), isFalse);
    });

    // 9. App foreground refresh updates inventory
    testWidgets('9. App foreground refresh triggers inventory reload', (tester) async {
      FridgeCategoryRepository.forceInMemoryForTesting = false;
      int reloadCount = 0;
      FridgeInventoryRepository.mockCleanupHandler = (userId) async {
        reloadCount++;
        return 0;
      };
      FridgeInventoryRepository.mockFetchHandler = (userId) async => [spinachToday];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FridgePage()),
        ),
      );
      await tester.pumpAndSettle();

      final initialCount = reloadCount;
      expect(initialCount, greaterThanOrEqualTo(1));

      // Simulate app transitioning to foreground (resumed)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(reloadCount, greaterThan(initialCount), reason: 'App foreground resume must trigger inventory refresh');
    });

    // 10. Failed cleanup does not falsely report success
    test('10. Failed cleanup does not falsely report success', () async {
      final repo = FridgeInventoryRepository.instance;
      FridgeInventoryRepository.simulateRpcError = true;

      // When RPC fails, cleanup must rethrow or fail without returning fake deleted records
      expect(
        () => repo.cleanupMyExpiredItems(userId: 'test_user_err', force: true),
        throwsA(isA<StateError>()),
      );
    });

    // 11. Duplicate cleanup requests are prevented
    test('11. Duplicate cleanup requests are prevented', () async {
      final repo = FridgeInventoryRepository.instance;
      FridgeInventoryRepository.resetTestingState();

      int calls = 0;
      FridgeInventoryRepository.mockCleanupHandler = (userId) async {
        calls++;
        await Future.delayed(const Duration(milliseconds: 50));
        return 1;
      };

      // Launch 2 simultaneous calls with force: true to isolate the concurrency guard
      final f1 = repo.cleanupMyExpiredItems(userId: 'user_dup', force: true);
      final f2 = repo.cleanupMyExpiredItems(userId: 'user_dup', force: true);

      final results = await Future.wait([f1, f2]);
      // One succeeds, second concurrent call skipped
      expect(calls, 1, reason: 'Concurrency guard must prevent duplicate simultaneous cleanup RPCs');
      expect(results.contains(1), isTrue);
      expect(results.contains(0), isTrue);
    });

    // 12. Use Soon and inventory counts recalculate correctly
    test('12. Use Soon and inventory counts recalculate correctly', () async {
      FridgeCategoryRepository.forceInMemoryForTesting = true;

      await FridgeCategoryRepository.addItemToCategory('Fruits', appleYesterday); // Expired yesterday
      await FridgeCategoryRepository.addItemToCategory('Vegetables', spinachToday); // Today (0 days)
      await FridgeCategoryRepository.addItemToCategory('Dairy Products', milkTomorrow); // Tomorrow (1 day)
      await FridgeCategoryRepository.addItemToCategory('Others', oliveOilUnknown); // Unknown expiry

      expect(FridgeCategoryRepository.totalFridgeItems, 4);

      // Before purge:
      // Edible expiring items should exclude already expired apples
      final edibleBefore = UseSoonService.getEdibleExpiringItems();
      expect(edibleBefore.any((it) => it.id == 'item_apples_exp'), isFalse);
      expect(edibleBefore.any((it) => it.id == 'item_spinach_today'), isTrue);

      // Purge expired items
      final purged = FridgeCategoryRepository.purgeExpiredItems(localToday);
      expect(purged, 1);

      // After purge:
      expect(FridgeCategoryRepository.totalFridgeItems, 3);
      expect(FridgeCategoryRepository.expiringSoonCount, 2, reason: 'Spinach (today) and Milk (tomorrow)');

      final remainingCategories = FridgeCategoryRepository.getItemsForCategory('Fruits');
      expect(remainingCategories, isEmpty, reason: 'Fruits category shelf should now be empty');

      final edibleAfter = UseSoonService.getEdibleExpiringItems();
      expect(edibleAfter.length, 2);
      expect(edibleAfter.map((e) => e.name).toList(), ['Spinach', 'Milk']);
    });
  });
}
