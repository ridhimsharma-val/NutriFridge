import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/models/grocery_item.dart';
import 'package:nutrifridge/screens/fridge/widgets/fridge_sticky_note.dart';
import 'package:nutrifridge/screens/grocery/grocery_list_screen.dart';
import 'package:nutrifridge/services/grocery/grocery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    GroceryService.instance.resetTestingState();
    GroceryService.instance.testUserIdOverride = 'test_progress_user';
    await GroceryService.instance.initialize();
  });

  Widget buildTestApp(Widget child, {Size size = const Size(400, 900)}) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('NutriFridge — Grocery Shopping Progress System Tests', () {
    // -------------------------------------------------------------------------
    // 1. Empty list displays a valid 0% progress state
    // -------------------------------------------------------------------------
    testWidgets('1. Empty list displays a valid 0% progress state without division by zero', (tester) async {
      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Shopping Progress'), findsOneWidget);
      expect(find.byKey(const Key('grocery_progress_text')), findsOneWidget);
      expect(find.text('0 of 0 items completed'), findsOneWidget);
      expect(find.byKey(const Key('grocery_percentage_text')), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('0 completed'), findsOneWidget);
      expect(find.text('0 remaining'), findsOneWidget);

      final progressIndicator = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('grocery_progress_indicator')),
      );
      expect(progressIndicator.value, 0.0);
    });

    // -------------------------------------------------------------------------
    // 2. One completed item updates progress correctly
    // -------------------------------------------------------------------------
    testWidgets('2. One completed item updates progress correctly', (tester) async {
      final item1 = await GroceryService.instance.addItem(name: 'Almond Milk', quantity: 1, unit: 'litres');
      await GroceryService.instance.addItem(name: 'Whole Wheat Bread', quantity: 1, unit: 'pieces');

      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('0 of 2 items completed'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);

      // Check item1
      await tester.tap(find.byKey(Key('grocery_item_checkbox_${item1.id}')));
      await tester.pumpAndSettle();

      expect(find.text('1 of 2 items completed'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('1 completed'), findsOneWidget);
      expect(find.text('1 remaining'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 3. Multiple completed items calculate the correct percentage
    // -------------------------------------------------------------------------
    testWidgets('3. Multiple completed items calculate the correct percentage', (tester) async {
      final i1 = await GroceryService.instance.addItem(name: 'Apples', quantity: 4, unit: 'pieces');
      final i2 = await GroceryService.instance.addItem(name: 'Bananas', quantity: 6, unit: 'pieces');
      final i3 = await GroceryService.instance.addItem(name: 'Carrots', quantity: 500, unit: 'g');
      await GroceryService.instance.addItem(name: 'Dates', quantity: 200, unit: 'g');

      // 4 total items: mark 3 completed -> 3 / 4 * 100 = 75%
      await GroceryService.instance.togglePurchased(i1.id);
      await GroceryService.instance.togglePurchased(i2.id);
      await GroceryService.instance.togglePurchased(i3.id);

      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('3 of 4 items completed'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('3 completed'), findsOneWidget);
      expect(find.text('1 remaining'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 4. Unchecking an item reverses progress
    // -------------------------------------------------------------------------
    testWidgets('4. Unchecking an item reverses progress and recalculates', (tester) async {
      final i1 = await GroceryService.instance.addItem(name: 'Olive Oil', quantity: 1, unit: 'bottles');
      final i2 = await GroceryService.instance.addItem(name: 'Sea Salt', quantity: 1, unit: 'packs');

      await GroceryService.instance.togglePurchased(i1.id);
      await GroceryService.instance.togglePurchased(i2.id);

      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('2 of 2 items completed'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);

      // Uncheck i2: scroll into view, tap, and scroll back up to check header
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('grocery_item_checkbox_${i2.id}')));
      await tester.pumpAndSettle();

      expect(GroceryService.instance.completedCount, 1);
      expect(GroceryService.instance.pendingCount, 1);

      // Scroll back up to verify Shopping Progress header
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 250));
      await tester.pumpAndSettle();

      expect(find.text('1 of 2 items completed'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('1 completed'), findsOneWidget);
      expect(find.text('1 remaining'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 5. Completed items move to the correct section
    // -------------------------------------------------------------------------
    testWidgets('5. Completed items move from To Buy to Completed section', (tester) async {
      final i1 = await GroceryService.instance.addItem(name: 'Spinach', quantity: 1, unit: 'packs');
      final i2 = await GroceryService.instance.addItem(name: 'Tofu', quantity: 1, unit: 'packs');

      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      // Initially both in To Buy
      expect(find.byKey(const Key('grocery_to_buy_header')), findsOneWidget);
      expect(find.byKey(const Key('grocery_to_buy_count_badge')), findsOneWidget);
      expect(find.text('2'), findsWidgets); // To Buy count is 2
      expect(find.byKey(const Key('grocery_completed_header')), findsNothing);

      // Check Spinach
      await tester.tap(find.byKey(Key('grocery_item_checkbox_${i1.id}')));
      await tester.pumpAndSettle();

      // Now To Buy has 1, Completed has 1
      expect(find.byKey(const Key('grocery_to_buy_header')), findsOneWidget);
      expect(find.byKey(const Key('grocery_completed_header')), findsOneWidget);
      expect(find.byKey(const Key('grocery_completed_count_badge')), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 6. Collapsing and expanding Completed works
    // -------------------------------------------------------------------------
    testWidgets('6. Collapsing and expanding Completed section toggles item visibility', (tester) async {
      final item = await GroceryService.instance.addItem(name: 'Oat Milk', quantity: 1, unit: 'litres');
      await GroceryService.instance.togglePurchased(item.id);

      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      // Completed is initially expanded
      expect(find.byKey(Key('grocery_item_name_${item.id}')), findsOneWidget);

      // Tap toggle to collapse
      await tester.tap(find.byKey(const Key('grocery_completed_toggle')));
      await tester.pumpAndSettle();

      // Completed items are hidden
      expect(find.byKey(Key('grocery_item_name_${item.id}')), findsNothing);

      // Tap toggle again to expand
      await tester.tap(find.byKey(const Key('grocery_completed_toggle')));
      await tester.pumpAndSettle();

      // Completed items visible again
      expect(find.byKey(Key('grocery_item_name_${item.id}')), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 7. Progress persists after application restart
    // -------------------------------------------------------------------------
    testWidgets('7. Progress persists after application restart via local/cloud storage', (tester) async {
      final i1 = await GroceryService.instance.addItem(name: 'Greek Yogurt', quantity: 2, unit: 'pieces');
      final i2 = await GroceryService.instance.addItem(name: 'Blueberries', quantity: 1, unit: 'packs');
      final i3 = await GroceryService.instance.addItem(name: 'Granola', quantity: 1, unit: 'packs');

      await GroceryService.instance.togglePurchased(i1.id);
      await GroceryService.instance.togglePurchased(i2.id);

      expect(GroceryService.instance.completedCount, 2);
      expect(GroceryService.instance.totalCount, 3);

      // Simulate app restart
      final newService = GroceryService();
      newService.testUserIdOverride = 'test_progress_user';
      await newService.initialize();

      expect(newService.totalCount, 3);
      expect(newService.completedCount, 2);
      expect(newService.pendingCount, 1);
      expect((newService.progress * 100).round(), 67);
    });

    // -------------------------------------------------------------------------
    // 8. Sticky-note preview updates with pending item counts
    // -------------------------------------------------------------------------
    testWidgets('8. Sticky-note preview updates real-time with pending item counts and indicator', (tester) async {
      final i1 = await GroceryService.instance.addItem(name: 'Avocados', quantity: 3, unit: 'pieces');
      await GroceryService.instance.addItem(name: 'Lemons', quantity: 2, unit: 'pieces');

      await tester.pumpWidget(buildTestApp(const FridgeStickyNote()));
      await tester.pumpAndSettle();

      // Displays 2 items remaining
      expect(find.byKey(const ValueKey('sticky_note_remaining_text')), findsOneWidget);
      expect(find.text('2 items remaining'), findsOneWidget);
      expect(find.text('Avocados'), findsOneWidget);
      expect(find.text('Lemons'), findsOneWidget);

      // Complete one item
      await GroceryService.instance.togglePurchased(i1.id);
      await tester.pumpAndSettle();

      // Updates to 1 item remaining and displays mini progress (1/2)
      expect(find.text('1 item remaining'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 9. Completing the entire list displays the completion state
    // -------------------------------------------------------------------------
    testWidgets('9. Completing entire list displays celebratory completion state on screen and note', (tester) async {
      final i1 = await GroceryService.instance.addItem(name: 'Eggs', quantity: 12, unit: 'pieces');
      final i2 = await GroceryService.instance.addItem(name: 'Butter', quantity: 1, unit: 'packs');

      await GroceryService.instance.togglePurchased(i1.id);
      await GroceryService.instance.togglePurchased(i2.id);

      // 9a. Verify GroceryListScreen shows celebration banner
      await tester.pumpWidget(buildTestApp(const GroceryListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('2 of 2 items completed'), findsOneWidget);
      expect(find.byKey(const Key('grocery_completion_celebration')), findsOneWidget);
      expect(find.text('Shopping list completed!'), findsOneWidget);

      // 9b. Verify FridgeStickyNote displays completion state
      await tester.pumpWidget(buildTestApp(const FridgeStickyNote()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('sticky_note_completed_text')), findsOneWidget);
      expect(find.text('Shopping complete!'), findsOneWidget);
      expect(find.text('All 2 items bought'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 10. Failed persistence rolls back the optimistic UI change
    // -------------------------------------------------------------------------
    testWidgets('10. Failed persistence rolls back the optimistic UI change', (tester) async {
      final item = await GroceryService.instance.addItem(
        name: 'Dark Chocolate',
        quantity: 1,
        unit: 'pieces',
        userId: 'cloud_sync_user',
      );
      expect(item.isPurchased, isFalse);

      // Configure mock Supabase table and simulate network error
      GroceryService.instance.mockSupabaseTable = {
        'grocery_items': [
          item.item!.toSupabaseRow('cloud_sync_user')..['id'] = item.id,
        ],
      };
      GroceryService.instance.simulateNetworkError = true;

      // Attempt to toggle purchased
      final success = await GroceryService.instance.togglePurchased(item.id, userId: 'cloud_sync_user');
      expect(success, isFalse);

      // Verify rollback: item remains unpurchased
      final userItems = await GroceryService.instance.getItemsForUser('cloud_sync_user');
      expect(userItems.first.isPurchased, isFalse);
    });

    // -------------------------------------------------------------------------
    // 11. Different users retain separate progress
    // -------------------------------------------------------------------------
    testWidgets('11. Different users retain separate shopping progress', (tester) async {
      // User 1 has 2 items: 1 completed (50%)
      final u1_i1 = await GroceryService.instance.addItem(name: 'Item A1', userId: 'user_progress_1');
      await GroceryService.instance.addItem(name: 'Item A2', userId: 'user_progress_1');
      await GroceryService.instance.togglePurchased(u1_i1.id, userId: 'user_progress_1');

      // User 2 has 3 items: all 3 completed (100%)
      final u2_i1 = await GroceryService.instance.addItem(name: 'Item B1', userId: 'user_progress_2');
      final u2_i2 = await GroceryService.instance.addItem(name: 'Item B2', userId: 'user_progress_2');
      final u2_i3 = await GroceryService.instance.addItem(name: 'Item B3', userId: 'user_progress_2');
      await GroceryService.instance.togglePurchased(u2_i1.id, userId: 'user_progress_2');
      await GroceryService.instance.togglePurchased(u2_i2.id, userId: 'user_progress_2');
      await GroceryService.instance.togglePurchased(u2_i3.id, userId: 'user_progress_2');

      final list1 = await GroceryService.instance.getItemsForUser('user_progress_1');
      final completed1 = list1.where((it) => it.isPurchased).length;
      final progress1 = completed1 / list1.length;
      expect(list1.length, 2);
      expect(completed1, 1);
      expect(progress1, 0.5);

      final list2 = await GroceryService.instance.getItemsForUser('user_progress_2');
      final completed2 = list2.where((it) => it.isPurchased).length;
      final progress2 = completed2 / list2.length;
      expect(list2.length, 3);
      expect(completed2, 3);
      expect(progress2, 1.0);
    });
  });
}
