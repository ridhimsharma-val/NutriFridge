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
    GroceryService.instance.testUserIdOverride = 'test_cat_sync_user';
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

  group('Grocery List Categories Synchronized with My Fridge', () {
    // -------------------------------------------------------------------------
    // 1. GroceryItem.canonicalCategories matches FridgeCategoryRepository
    // -------------------------------------------------------------------------
    test('1. Canonical categories match My Fridge categories exactly', () {
      expect(
        GroceryItem.canonicalCategories,
        equals(FridgeCategoryRepository.canonicalCategories),
      );
      expect(GroceryItem.canonicalCategories.contains('Fruits'), isTrue);
      expect(GroceryItem.canonicalCategories.contains('Vegetables'), isTrue);
      expect(GroceryItem.canonicalCategories.contains('Dairy Products'), isTrue);
      expect(GroceryItem.canonicalCategories.contains('Non-Veg'), isTrue);
      expect(GroceryItem.canonicalCategories.contains('Packaged Food'), isTrue);
      expect(GroceryItem.canonicalCategories.contains('Drinks & Juices'), isTrue);
      expect(GroceryItem.canonicalCategories.contains('Meals & Leftovers'), isTrue);
      expect(GroceryItem.canonicalCategories.contains('Others'), isTrue);
    });

    // -------------------------------------------------------------------------
    // 2. Keyword Auto-Resolver classifies into canonical Fridge categories
    // -------------------------------------------------------------------------
    test('2. Auto-resolver maps foods to canonical Fridge categories', () {
      expect(GroceryCategoryResolver.resolveCategory('Watermelon'), equals('Fruits'));
      expect(GroceryCategoryResolver.resolveCategory('Fresh Spinach'), equals('Vegetables'));
      expect(GroceryCategoryResolver.resolveCategory('Almond Milk'), equals('Dairy Products'));
      expect(GroceryCategoryResolver.resolveCategory('Chicken Breast'), equals('Non-Veg'));
      expect(GroceryCategoryResolver.resolveCategory('Sourdough Bread'), equals('Packaged Food'));
      expect(GroceryCategoryResolver.resolveCategory('Orange Juice'), equals('Drinks & Juices'));
      expect(GroceryCategoryResolver.resolveCategory('Vanilla Gelato'), equals('Ice Cream'));
      expect(GroceryCategoryResolver.resolveCategory('Roasted Almonds'), equals('Dry Fruits'));
      expect(GroceryCategoryResolver.resolveCategory('Leftover Pasta'), equals('Meals & Leftovers'));
      expect(GroceryCategoryResolver.resolveCategory('Random Thing 123'), equals('Others'));
    });

    // -------------------------------------------------------------------------
    // 3. Legacy category migration
    // -------------------------------------------------------------------------
    test('3. Safely normalizes legacy grocery categories', () {
      // Fruits & Vegetables splits appropriately
      expect(GroceryCategoryResolver.normalizeCategory('Fruits & Vegetables', 'Watermelon'), equals('Fruits'));
      expect(GroceryCategoryResolver.normalizeCategory('Fruits & Vegetables', 'Carrot'), equals('Vegetables'));

      // Dairy & Eggs maps to Dairy Products
      expect(GroceryCategoryResolver.normalizeCategory('Dairy & Eggs', 'Greek Yogurt'), equals('Dairy Products'));
      expect(GroceryCategoryResolver.normalizeCategory('Dairy & Eggs', 'Butter'), equals('Dairy Products'));

      // Meat & Seafood -> Non-Veg
      expect(GroceryCategoryResolver.normalizeCategory('Meat & Seafood', 'Salmon'), equals('Non-Veg'));

      // Beverages -> Drinks & Juices
      expect(GroceryCategoryResolver.normalizeCategory('Beverages', 'Sparkling Water'), equals('Drinks & Juices'));

      // Bakery & Grains -> Packaged Food
      expect(GroceryCategoryResolver.normalizeCategory('Bakery', 'Croissant'), equals('Packaged Food'));
      expect(GroceryCategoryResolver.normalizeCategory('Grains & Staples', 'Brown Rice'), equals('Packaged Food'));

      // Already canonical returns unchanged
      expect(GroceryCategoryResolver.normalizeCategory('Fruits', 'Apple'), equals('Fruits'));
      expect(GroceryCategoryResolver.normalizeCategory('Vegetables', 'Broccoli'), equals('Vegetables'));
      expect(GroceryCategoryResolver.normalizeCategory('Dairy Products', 'Butter'), equals('Dairy Products'));
    });

    // -------------------------------------------------------------------------
    // 4. Category pill dropdown displays canonical Fridge options with emojis
    // -------------------------------------------------------------------------
    testWidgets('4. Category dropdown in Quick Add displays canonical Fridge options with emojis', (tester) async {
      await tester.pumpWidget(buildTestApp(const GroceryListScreen(), tester));
      await tester.pumpAndSettle();

      // Tap the category pill in the Quick Add bar
      final pillFinder = find.byKey(const Key('grocery_category_pill'));
      expect(pillFinder, findsOneWidget);

      await tester.tap(pillFinder);
      await tester.pumpAndSettle();

      // Verify all Fridge canonical categories appear as dropdown options
      for (final cat in FridgeCategoryRepository.canonicalCategories) {
        expect(find.text(cat), findsWidgets, reason: 'Category "$cat" must appear in dropdown options');
      }

      // Verify emojis appear
      expect(find.text(FridgeCategoryRepository.categoryEmoji('Fruits')), findsWidgets);
      expect(find.text(FridgeCategoryRepository.categoryEmoji('Vegetables')), findsWidgets);
      expect(find.text(FridgeCategoryRepository.categoryEmoji('Dairy Products')), findsWidgets);
      expect(find.text(FridgeCategoryRepository.categoryEmoji('Non-Veg')), findsWidgets);
    });

    // -------------------------------------------------------------------------
    // 5. Selecting a category adds item to that exact category
    // -------------------------------------------------------------------------
    testWidgets('5. Selecting category from dropdown adds item to that exact category', (tester) async {
      await tester.pumpWidget(buildTestApp(const GroceryListScreen(), tester));
      await tester.pumpAndSettle();

      // Enter item name
      await tester.enterText(find.byKey(const Key('grocery_item_name_input')), 'Sweet Treat');
      await tester.pumpAndSettle();

      // Open category dropdown
      await tester.tap(find.byKey(const Key('grocery_category_pill')));
      await tester.pumpAndSettle();

      // Select 'Ice Cream'
      await tester.tap(find.text('Ice Cream').last);
      await tester.pumpAndSettle();

      // Tap Add
      await tester.tap(find.byKey(const Key('grocery_add_item_btn')));
      await tester.pumpAndSettle();

      final added = GroceryService.instance.currentItems.firstWhere((it) => it.name == 'Sweet Treat');
      expect(added.category, equals('Ice Cream'));
    });

    // -------------------------------------------------------------------------
    // 6. Transferred items go directly into that exact Fridge category
    // -------------------------------------------------------------------------
    testWidgets('6. Transferred grocery item enters that exact Fridge category', (tester) async {
      // Add watermelon with 'Fruits' category
      final item = await GroceryService.instance.addItem(
        name: 'Watermelon',
        category: 'Fruits',
      );
      await GroceryService.instance.togglePurchased(item.id);

      final initialFruitsCount = FridgeCategoryRepository.getCategoryData('Fruits').items.length;

      // Transfer to fridge
      final result = await GroceryService.instance.transferPurchasedToFridge();
      expect(result.transferredCount, 1);

      final fruitsData = FridgeCategoryRepository.getCategoryData('Fruits');
      expect(fruitsData.items.length, initialFruitsCount + 1);
      expect(fruitsData.items.any((it) => it.name == 'Watermelon'), isTrue);

      // Verify it was NOT added to Vegetables or Others
      expect(FridgeCategoryRepository.getCategoryData('Vegetables').items.any((it) => it.name == 'Watermelon'), isFalse);
    });

    // -------------------------------------------------------------------------
    // 7. No overflow on narrow mobile screens (320px, 360px)
    // -------------------------------------------------------------------------
    testWidgets('7. No overflow on narrow mobile screens (320px, 360px)', (tester) async {
      final widths = [320.0, 360.0];

      for (final w in widths) {
        await tester.pumpWidget(buildTestApp(const GroceryListScreen(), tester, w, 800.0));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Must not overflow at $w px');

        // Open dropdown
        await tester.tap(find.byKey(const Key('grocery_category_pill')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Dropdown must not overflow at $w px');

        // Close popup by tapping backdrop
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
      }
    });
  });
}
