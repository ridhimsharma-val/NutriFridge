import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/screens/fridge/services/use_soon_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final localToday = DateTime(2026, 11, 14);
  final yesterday = DateTime(2026, 11, 13);
  final today = DateTime(2026, 11, 14);
  final tomorrow = DateTime(2026, 11, 15);
  final in3Days = DateTime(2026, 11, 17);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FridgeCategoryRepository.forceInMemoryForTesting = true;
    FridgeCategoryRepository.reset();
  });

  group('NutriFridge — Automatic Expired Inventory Cleanup Tests', () {
    // 1. Controlled Test Dataset Expiry Matrix
    test('1. Controlled Test Dataset Expiry Matrix (Yesterday vs Today vs Future vs Unknown)', () async {
      // Setup dataset:
      // - Apples: Yesterday -> Expired
      // - Spinach: Today -> Retained
      // - Milk: Tomorrow -> Retained
      // - Bananas: In 3 days -> Retained
      // - Olive Oil: Missing/Unknown expiry -> Retained
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

      // Verify individual expiry semantics
      expect(appleYesterday.isExpired, isTrue);
      expect(spinachToday.isExpired, isFalse, reason: 'Expiring today is valid throughout today');
      expect(milkTomorrow.isExpired, isFalse);
      expect(bananasIn3Days.isExpired, isFalse);
      expect(oliveOilUnknown.isExpired, isFalse, reason: 'Unknown expiry must not be marked expired');

      // Add all to repository
      await FridgeCategoryRepository.addItemToCategory('Fruits', appleYesterday);
      await FridgeCategoryRepository.addItemToCategory('Vegetables', spinachToday);
      await FridgeCategoryRepository.addItemToCategory('Dairy Products', milkTomorrow);
      await FridgeCategoryRepository.addItemToCategory('Fruits', bananasIn3Days);
      await FridgeCategoryRepository.addItemToCategory('Others', oliveOilUnknown);

      expect(FridgeCategoryRepository.totalFridgeItems, 5);

      // Execute cleanup / purge
      final purged = FridgeCategoryRepository.purgeExpiredItems(localToday);
      expect(purged, 1, reason: 'Only Apples (yesterday) should be purged');

      // Verify active inventory post-cleanup
      expect(FridgeCategoryRepository.totalFridgeItems, 4);

      final activeIds = FridgeCategoryRepository.allItems.map((e) => e.id).toSet();
      expect(activeIds.contains('item_apples_exp'), isFalse, reason: 'Expired Apples must disappear');
      expect(activeIds.contains('item_spinach_today'), isTrue, reason: 'Spinach (today) must be retained');
      expect(activeIds.contains('item_milk_tomorrow'), isTrue, reason: 'Milk (tomorrow) must be retained');
      expect(activeIds.contains('item_bananas_3d'), isTrue, reason: 'Bananas (in 3 days) must be retained');
      expect(activeIds.contains('item_olive_oil_unk'), isTrue, reason: 'Olive Oil (unknown) must be retained');
    });

    // 2. Multiple batches of the same ingredient with different expiry dates
    test('2. Multiple batches of the same ingredient: only expired batch deleted, valid batch preserved', () async {
      // User has 2 separate batches of Tomatoes:
      // - Batch 1: 500g, expired yesterday -> Deleted
      // - Batch 2: 1 kg, expires in 4 days -> Retained
      final expiredBatchTomatoes = CategoryFoodItem(
        id: 'tomatoes_batch_old',
        name: 'Tomatoes',
        quantity: '500 g',
        expiryDate: yesterday,
        category: 'Vegetables',
      );
      final validBatchTomatoes = CategoryFoodItem(
        id: 'tomatoes_batch_fresh',
        name: 'Tomatoes',
        quantity: '1 kg',
        expiryDate: DateTime(2026, 11, 18),
        category: 'Vegetables',
      );

      await FridgeCategoryRepository.addItemToCategory('Vegetables', expiredBatchTomatoes);
      await FridgeCategoryRepository.addItemToCategory('Vegetables', validBatchTomatoes);

      expect(FridgeCategoryRepository.totalFridgeItems, 2);

      // Execute cleanup
      final purged = FridgeCategoryRepository.purgeExpiredItems(localToday);
      expect(purged, 1);

      // Active inventory contains only the fresh batch with its exact quantity preserved
      final remaining = FridgeCategoryRepository.getItemsForCategory('Vegetables');
      expect(remaining.length, 1);
      expect(remaining.first.id, 'tomatoes_batch_fresh');
      expect(remaining.first.quantity, '1 kg');
      expect(remaining.first.decimalAmount, 1.0);
    });

    // 3. Repeated cleanup does not create errors (idempotency)
    test('3. Repeated cleanup is idempotent and safe to execute consecutively', () async {
      final expiredYogurt = CategoryFoodItem(
        id: 'yogurt_exp',
        name: 'Yogurt',
        quantity: '400 g',
        expiryDate: yesterday,
        category: 'Dairy Products',
      );
      final freshCheese = CategoryFoodItem(
        id: 'cheese_fresh',
        name: 'Cheddar Cheese',
        quantity: '200 g',
        expiryDate: in3Days,
        category: 'Dairy Products',
      );

      await FridgeCategoryRepository.addItemToCategory('Dairy Products', expiredYogurt);
      await FridgeCategoryRepository.addItemToCategory('Dairy Products', freshCheese);

      // First run: purges 1 item
      final firstRun = FridgeCategoryRepository.purgeExpiredItems(localToday);
      expect(firstRun, 1);
      expect(FridgeCategoryRepository.totalFridgeItems, 1);

      // Second run: purges 0 items without error
      final secondRun = FridgeCategoryRepository.purgeExpiredItems(localToday);
      expect(secondRun, 0);
      expect(FridgeCategoryRepository.totalFridgeItems, 1);

      // Third run: still 0 items without error
      final thirdRun = FridgeCategoryRepository.purgeExpiredItems(localToday);
      expect(thirdRun, 0);
      expect(FridgeCategoryRepository.totalFridgeItems, 1);
      expect(FridgeCategoryRepository.allItems.first.id, 'cheese_fresh');
    });

    // 4. Use Soon freshness and AI meals reflect cleanup immediately
    test('4. Use Soon and AI meal edible items exclude expired inventory after cleanup', () async {
      final expiredBread = CategoryFoodItem(
        id: 'bread_exp',
        name: 'Whole Wheat Bread',
        quantity: '1 loaf',
        expiryDate: yesterday,
        category: 'Packaged Food',
      );
      final todayPaneer = CategoryFoodItem(
        id: 'paneer_today',
        name: 'Paneer',
        quantity: '250 g',
        expiryDate: today,
        category: 'Dairy Products',
      );

      await FridgeCategoryRepository.addItemToCategory('Packaged Food', expiredBread);
      await FridgeCategoryRepository.addItemToCategory('Dairy Products', todayPaneer);

      // Before cleanup: UseSoon contains todayPaneer, edible expiring items exclude expiredBread
      final edibleBefore = UseSoonService.getEdibleExpiringItems();
      expect(edibleBefore.any((it) => it.id == 'bread_exp'), isFalse);
      expect(edibleBefore.any((it) => it.id == 'paneer_today'), isTrue);

      // Run cleanup
      FridgeCategoryRepository.purgeExpiredItems(localToday);

      // Active fridge inventory contains only paneer
      expect(FridgeCategoryRepository.allItems.any((it) => it.id == 'bread_exp'), isFalse);
      expect(FridgeCategoryRepository.allItems.length, 1);

      final edibleAfter = UseSoonService.getEdibleExpiringItems();
      expect(edibleAfter.length, 1);
      expect(edibleAfter.first.name, 'Paneer');
    });

    // 5. User timezone boundary evaluation
    test('5. Item expiring on local calendar boundary is evaluated against user local date', () {
      // If user local date is 2026-11-14:
      // Item with expiry 2026-11-14:
      final itemNov14 = CategoryFoodItem(
        id: 'i1',
        name: 'Carrots',
        quantity: '500 g',
        expiryDate: DateTime(2026, 11, 14),
      );
      // Evaluated at 2026-11-14 23:59:59 (still today) -> Not expired
      final daysOnNov14 = UseSoonService.getEffectiveExpiryDays(itemNov14, DateTime(2026, 11, 14, 23, 59));
      expect(daysOnNov14, 0);
      expect(daysOnNov14! < 0, isFalse, reason: 'Valid on expiry day');

      // Evaluated at 2026-11-15 00:00:01 (next calendar day in user timezone) -> Expired
      final daysOnNov15 = UseSoonService.getEffectiveExpiryDays(itemNov14, DateTime(2026, 11, 15, 0, 1));
      expect(daysOnNov15, -1);
      expect(daysOnNov15! < 0, isTrue, reason: 'Expired on next calendar day');
    });
  });
}
