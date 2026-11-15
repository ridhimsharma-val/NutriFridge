import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/screens/grocery/grocery_list_screen.dart';
import 'package:nutrifridge/services/grocery/grocery_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    GroceryService.instance.resetTestingState();
    GroceryService.instance.testUserIdOverride = 'test_paper_user';
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

  group('NutriFridge — Grocery List Realistic Paper Texture Refinement', () {
    testWidgets('1. Paper texture custom painter is present and renders background surface', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GroceryListScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify custom painter for paper surface is present
      final customPaintFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter.runtimeType.toString() == '_PaperSurfacePainter',
      );
      expect(customPaintFinder, findsOneWidget);

      // Verify heading text remains readable and present
      expect(find.text('Grocery List'), findsOneWidget);
      expect(find.text('Shopping Progress'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('2. Text, controls, and category horizontal separators remain visible', (tester) async {
      await GroceryService.instance.addItem(
        name: 'Honeycrisp Apple',
        quantity: 3,
        unit: 'pieces',
        category: 'Fruits',
      );
      await GroceryService.instance.addItem(
        name: 'Whole Milk',
        quantity: 1,
        unit: 'bottle',
        category: 'Dairy Products',
      );

      final milk = GroceryService.instance.currentItems.firstWhere((it) => it.name == 'Whole Milk');
      await GroceryService.instance.togglePurchased(milk.id);

      await tester.pumpWidget(
        const MaterialApp(
          home: GroceryListScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify items are displayed as checklist rows
      expect(find.text('Honeycrisp Apple'), findsOneWidget);

      // Verify categories and section headers
      expect(find.text('To Buy'), findsOneWidget);
      expect(find.text('Fruits'), findsOneWidget);

      // Action buttons exist
      final apple = GroceryService.instance.currentItems.firstWhere((it) => it.name == 'Honeycrisp Apple');
      expect(find.byKey(Key('grocery_item_checkbox_${apple.id}')), findsOneWidget);
      expect(find.byKey(Key('grocery_item_edit_${apple.id}')), findsOneWidget);
      expect(find.byKey(Key('grocery_item_delete_${apple.id}')), findsOneWidget);
    });

    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      testWidgets('3. No layout overflow occurs on $width px viewport', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await GroceryService.instance.addItem(
          name: 'Organic Bananas',
          quantity: 6,
          unit: 'pieces',
          category: 'Fruits',
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: GroceryListScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Organic Bananas'), findsOneWidget);
        expect(find.text('Grocery List'), findsOneWidget);
      });
    }
  });
}
