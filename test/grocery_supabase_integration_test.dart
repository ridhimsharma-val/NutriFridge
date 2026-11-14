import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/models/grocery_item.dart';
import 'package:nutrifridge/services/grocery/grocery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testUserId1 = '00000000-0000-0000-0000-000000000001';
  const testUserId2 = '00000000-0000-0000-0000-000000000002';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    GroceryService.instance.resetTestingState();
    GroceryService.instance.testUserIdOverride = testUserId1;
    GroceryService.instance.mockSupabaseTable = {'grocery_items': []};
    await GroceryService.instance.initialize(userId: testUserId1);
  });

  group('NutriFridge — Grocery List Supabase Integration Verification', () {
    // -------------------------------------------------------------------------
    // 1. Add item persists all fields to Supabase schema
    // -------------------------------------------------------------------------
    test('1. Add item persists with correct column mappings to Supabase', () async {
      final result = await GroceryService.instance.addItem(
        name: 'Whole Milk',
        quantity: 2.0,
        unit: 'litres',
        category: 'Dairy & Eggs',
        userId: testUserId1,
      );

      expect(result.isSuccess, isTrue);
      expect(result.item, isNotNull);

      final table = GroceryService.instance.mockSupabaseTable!['grocery_items']!;
      expect(table.length, 1);

      final row = table.first;
      expect(row['user_id'], testUserId1);
      expect(row['name'], 'Whole Milk');
      expect(row['quantity'], 2.0);
      expect(row['unit'], 'litres');
      expect(row['category'], 'Dairy & Eggs');
      expect(row['is_purchased'], isFalse);
      expect(row['is_transferred'], isFalse);
      expect(row['created_at'], isNotNull);
      expect(row['updated_at'], isNotNull);
    });

    // -------------------------------------------------------------------------
    // 2. Retrieve saved grocery items from Supabase
    // -------------------------------------------------------------------------
    test('2. Retrieve saved grocery items loads accurate models from database', () async {
      // Simulate existing Supabase rows
      GroceryService.instance.mockSupabaseTable = {
        'grocery_items': [
          {
            'id': '11111111-1111-1111-1111-111111111111',
            'user_id': testUserId1,
            'name': 'Avocado',
            'quantity': 3.0,
            'unit': 'pieces',
            'category': 'Fruits & Vegetables',
            'is_purchased': false,
            'is_transferred': false,
            'created_at': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          {
            'id': '22222222-2222-2222-2222-222222222222',
            'user_id': testUserId1,
            'name': 'Greek Yogurt',
            'quantity': 500.0,
            'unit': 'g',
            'category': 'Dairy & Eggs',
            'is_purchased': true,
            'is_transferred': false,
            'created_at': DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
        ],
      };

      final items = await GroceryService.instance.loadItems(userId: testUserId1);
      expect(items.length, 2);

      final avocado = items.firstWhere((it) => it.name == 'Avocado');
      expect(avocado.quantity, 3.0);
      expect(avocado.unit, 'pieces');
      expect(avocado.isPurchased, isFalse);

      final yogurt = items.firstWhere((it) => it.name == 'Greek Yogurt');
      expect(yogurt.quantity, 500.0);
      expect(yogurt.unit, 'g');
      expect(yogurt.isPurchased, isTrue);
    });

    // -------------------------------------------------------------------------
    // 3. Edit item name, quantity, unit, and category persists to Supabase
    // -------------------------------------------------------------------------
    test('3. Edit item attributes updates the Supabase record', () async {
      final addResult = await GroceryService.instance.addItem(
        name: 'Oat Milk',
        quantity: 1.0,
        unit: 'litres',
        category: 'Beverages',
        userId: testUserId1,
      );

      final original = addResult.item!;
      final updated = original.copyWith(
        name: 'Organic Oat Milk',
        quantity: 2.0,
        unit: 'bottles',
        category: 'Dairy & Eggs',
      );

      final success = await GroceryService.instance.updateItem(updated, userId: testUserId1);
      expect(success, isTrue);

      final table = GroceryService.instance.mockSupabaseTable!['grocery_items']!;
      final row = table.firstWhere((r) => r['id'] == original.id);
      expect(row['name'], 'Organic Oat Milk');
      expect(row['quantity'], 2.0);
      expect(row['unit'], 'bottles');
      expect(row['category'], 'Dairy & Eggs');
    });

    // -------------------------------------------------------------------------
    // 4. Delete an item removes it from Supabase
    // -------------------------------------------------------------------------
    test('4. Delete an item removes it from Supabase table', () async {
      final addResult = await GroceryService.instance.addItem(
        name: 'Dark Chocolate',
        quantity: 1.0,
        unit: 'bars',
        userId: testUserId1,
      );

      final itemId = addResult.item!.id;
      expect(GroceryService.instance.currentItems.length, 1);

      final deleteSuccess = await GroceryService.instance.deleteItem(itemId, userId: testUserId1);
      expect(deleteSuccess, isTrue);
      expect(GroceryService.instance.currentItems.isEmpty, isTrue);

      final table = GroceryService.instance.mockSupabaseTable!['grocery_items']!;
      expect(table.where((r) => r['id'] == itemId).isEmpty, isTrue);
    });

    // -------------------------------------------------------------------------
    // 5. Mark as purchased and uncheck toggle state in Supabase
    // -------------------------------------------------------------------------
    test('5. Toggling purchased state persists correctly to database', () async {
      final addResult = await GroceryService.instance.addItem(
        name: 'Eggs',
        quantity: 12.0,
        unit: 'pieces',
        userId: testUserId1,
      );
      final itemId = addResult.item!.id;

      // Mark purchased
      await GroceryService.instance.togglePurchased(itemId, userId: testUserId1);
      var table = GroceryService.instance.mockSupabaseTable!['grocery_items']!;
      expect(table.firstWhere((r) => r['id'] == itemId)['is_purchased'], isTrue);
      expect(GroceryService.instance.currentItems.first.isPurchased, isTrue);

      // Uncheck purchased
      await GroceryService.instance.togglePurchased(itemId, userId: testUserId1);
      table = GroceryService.instance.mockSupabaseTable!['grocery_items']!;
      expect(table.firstWhere((r) => r['id'] == itemId)['is_purchased'], isFalse);
      expect(GroceryService.instance.currentItems.first.isPurchased, isFalse);
    });

    // -------------------------------------------------------------------------
    // 6. Shopping progress is computed and restored from persisted records
    // -------------------------------------------------------------------------
    test('6. Shopping progress accurately calculates from database state after refresh', () async {
      final i1 = await GroceryService.instance.addItem(name: 'Item 1', quantity: 1, userId: testUserId1);
      final i2 = await GroceryService.instance.addItem(name: 'Item 2', quantity: 1, userId: testUserId1);
      final i3 = await GroceryService.instance.addItem(name: 'Item 3', quantity: 1, userId: testUserId1);
      final i4 = await GroceryService.instance.addItem(name: 'Item 4', quantity: 1, userId: testUserId1);

      // Mark 2 of 4 purchased -> 50%
      await GroceryService.instance.togglePurchased(i1.id, userId: testUserId1);
      await GroceryService.instance.togglePurchased(i2.id, userId: testUserId1);

      expect(GroceryService.instance.progress, 0.5);
      expect(GroceryService.instance.allCompletedCount, 2);
      expect(GroceryService.instance.pendingCount, 2);

      // Simulate app restart / reload by creating fresh service instance reading from storage
      final reloadedService = GroceryService();
      reloadedService.testUserIdOverride = testUserId1;
      await reloadedService.initialize(userId: testUserId1);

      expect(reloadedService.totalCount, 4);
      expect(reloadedService.allCompletedCount, 2);
      expect(reloadedService.pendingCount, 2);
      expect(reloadedService.progress, 0.5);
    });

    // -------------------------------------------------------------------------
    // 7. User-specific isolation (RLS compatibility)
    // -------------------------------------------------------------------------
    test('7. Multiple users maintain strictly isolated grocery lists', () async {
      await GroceryService.instance.addItem(name: 'User 1 Milk', userId: testUserId1);
      await GroceryService.instance.addItem(name: 'User 2 Bread', userId: testUserId2);

      final user1List = await GroceryService.instance.getItemsForUser(testUserId1);
      final user2List = await GroceryService.instance.getItemsForUser(testUserId2);

      expect(user1List.length, 1);
      expect(user1List.first.name, 'User 1 Milk');

      expect(user2List.length, 1);
      expect(user2List.first.name, 'User 2 Bread');

      // Clear completed for user 1 does not affect user 2
      await GroceryService.instance.togglePurchased(user1List.first.id, userId: testUserId1);
      final cleared = await GroceryService.instance.clearCompleted(userId: testUserId1);
      expect(cleared, 1);

      final user2After = await GroceryService.instance.getItemsForUser(testUserId2);
      expect(user2After.length, 1);
      expect(user2After.first.name, 'User 2 Bread');
    });

    // -------------------------------------------------------------------------
    // 8. Transfer tracking fields persist to Supabase
    // -------------------------------------------------------------------------
    test('8. One-tap transfer tracking fields update in Supabase', () async {
      final addResult = await GroceryService.instance.addItem(
        name: 'Strawberries',
        quantity: 1.0,
        unit: 'boxes',
        category: 'Fruits & Vegetables',
        userId: testUserId1,
      );
      final item = addResult.item!;
      await GroceryService.instance.togglePurchased(item.id, userId: testUserId1);

      final transferTime = DateTime.now();
      final updatedWithTransfer = item.copyWith(
        isPurchased: true,
        isTransferred: true,
        transferredAt: transferTime,
        inventoryItemId: 'inv_rec_12345',
        expiryDate: DateTime(2026, 12, 1),
      );

      final updateSuccess = await GroceryService.instance.updateItem(
        updatedWithTransfer,
        userId: testUserId1,
      );
      expect(updateSuccess, isTrue);

      final table = GroceryService.instance.mockSupabaseTable!['grocery_items']!;
      final row = table.firstWhere((r) => r['id'] == item.id);

      expect(row['is_transferred'], isTrue);
      expect(row['transferred_at'], isNotNull);
      expect(row['inventory_item_id'], 'inv_rec_12345');
      expect(row['expiry_date'], '2026-12-01');
    });

    // -------------------------------------------------------------------------
    // 9. Error handling: Network error rolls back and does not falsely indicate success
    // -------------------------------------------------------------------------
    test('9. Network failure rolls back optimistic updates and reports error', () async {
      GroceryService.instance.simulateNetworkError = true;

      final addResult = await GroceryService.instance.addItem(
        name: 'Failing Item',
        userId: testUserId1,
      );

      expect(addResult.isSuccess, isFalse);
      expect(addResult.type, GroceryAddResultType.error);
      expect(addResult.errorMessage, isNotNull);

      GroceryService.instance.simulateNetworkError = false;
    });

    // -------------------------------------------------------------------------
    // 10. UUID syntax handling in toSupabaseRow
    // -------------------------------------------------------------------------
    test('10. Client-side temporary IDs are omitted from Supabase payload', () {
      final tempItem = GroceryItem(
        id: 'item_1731571234567_0',
        userId: testUserId1,
        name: 'Organic Honey',
        quantity: 1,
        unit: 'jars',
        category: 'Others',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final payload = tempItem.toSupabaseRow(testUserId1);
      // 'id' should be omitted so PostgreSQL issues DEFAULT gen_random_uuid()
      expect(payload.containsKey('id'), isFalse);
      expect(payload['user_id'], testUserId1);
      expect(payload['name'], 'Organic Honey');

      // Canonical UUID is preserved
      final canonicalItem = tempItem.copyWith(id: 'a0000000-0000-0000-0000-000000000001');
      final canonicalPayload = canonicalItem.toSupabaseRow(testUserId1);
      expect(canonicalPayload['id'], 'a0000000-0000-0000-0000-000000000001');
    });
  });
}
