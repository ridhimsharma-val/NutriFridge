import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/screens/fridge/services/cooking_basket_service.dart';
import 'package:nutrifridge/screens/fridge/widgets/cooking_pan_painter.dart';
import 'package:nutrifridge/screens/fridge/widgets/cooking_pan_widget.dart';
import 'package:nutrifridge/screens/fridge/widgets/flying_ingredient_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    CookingBasketService.clear();
    CookingPanCoordinator.clear();
  });

  tearDown(() {
    CookingBasketService.clear();
    CookingPanCoordinator.clear();
  });

  group('Phase 1 & 2: Physical Cooking Pan States & Design', () {
    testWidgets('Empty pan renders intentional "Your pan is ready" state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CookingPanWidget(
                width: 175,
                height: 96,
                showEmptyGuide: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CookingPanWidget), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('Your pan is ready'), findsOneWidget);
      expect(find.text('Select items from fridge'), findsOneWidget);
    });

    testWidgets('Pan with 1 ingredient displays thumbnail and no empty text', (tester) async {
      const item1 = CategoryFoodItem(
        id: 'item-chicken-001',
        name: 'Chicken Breast',
        quantity: '500 g',
        category: 'Non Veg',
        expiryDays: 4,
        imageAsset: 'assets/images/foods/chicken.jpg',
      );

      CookingBasketService.toggleItem(item1);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CookingPanWidget(
                width: 175,
                height: 96,
                showEmptyGuide: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Your pan is ready'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('Pan with multiple ingredients arranges thumbnails naturally', (tester) async {
      const item1 = CategoryFoodItem(
        id: 'item-chicken-001',
        name: 'Chicken Breast',
        quantity: '500 g',
        category: 'Non Veg',
        expiryDays: 4,
        imageAsset: 'assets/images/foods/chicken.jpg',
      );
      const item2 = CategoryFoodItem(
        id: 'item-tomato-002',
        name: 'Ripe Tomatoes',
        quantity: '3 pcs',
        category: 'Produce',
        expiryDays: 3,
        imageAsset: 'assets/images/foods/tomato.jpg',
      );
      const item3 = CategoryFoodItem(
        id: 'item-peas-003',
        name: 'Frozen Peas',
        quantity: '250 g',
        category: 'Frozen Food',
        expiryDays: 30,
        imageAsset: 'assets/images/foods/frozen_peas.jpg',
      );

      CookingBasketService.toggleItem(item1);
      CookingBasketService.toggleItem(item2);
      CookingBasketService.toggleItem(item3);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CookingPanWidget(
                width: 175,
                height: 96,
              ),
            ),
          ),
        ),
      );

      expect(CookingBasketService.count, equals(3));
      expect(find.byType(Image), findsNWidgets(3));
    });

    testWidgets('Pan with 5+ items displays +N overflow badge inside pan', (tester) async {
      for (int i = 1; i <= 6; i++) {
        CookingBasketService.toggleItem(
          CategoryFoodItem(
            id: 'item-$i',
            name: 'Food $i',
            quantity: '$i pcs',
            category: 'Produce',
            expiryDays: 5,
            iconEmoji: '🥦',
          ),
        );
      }

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CookingPanWidget(
                width: 175,
                height: 96,
              ),
            ),
          ),
        ),
      );

      expect(CookingBasketService.count, equals(6));
      // 3 individual items + 1 '+3' overflow badge
      expect(find.text('+3'), findsOneWidget);
    });

    testWidgets('Missing thumbnail image uses iconEmoji fallback smoothly', (tester) async {
      const itemFallback = CategoryFoodItem(
        id: 'item-mystery-999',
        name: 'Dragonfruit',
        quantity: '1 pc',
        category: 'Fruits',
        expiryDays: 7,
        iconEmoji: '🐉',
      );

      CookingBasketService.toggleItem(itemFallback);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CookingPanWidget(
                width: 175,
                height: 96,
              ),
            ),
          ),
        ),
      );

      expect(find.text('🐉'), findsOneWidget);
    });
  });

  group('Phase 3 & 4: Flying Animation & Coordinator', () {
    testWidgets('FlyingIngredientHelper launches overlay and completes landing cleanly', (tester) async {
      final sourceKey = GlobalKey();
      final targetKey = GlobalKey();

      const item = CategoryFoodItem(
        id: 'item-fly-1',
        name: 'Fresh Mint',
        quantity: '1 bunch',
        category: 'Produce',
        expiryDays: 3,
        iconEmoji: '🌿',
      );

      bool landedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  top: 100,
                  left: 50,
                  child: Container(
                    key: sourceKey,
                    width: 50,
                    height: 50,
                    color: Colors.green,
                  ),
                ),
                Positioned(
                  top: 500,
                  left: 150,
                  child: CookingPanWidget(
                    key: targetKey,
                    width: 175,
                    height: 96,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Trigger flying animation
      FlyingIngredientHelper.flyIngredient(
        context: tester.element(find.byKey(sourceKey)),
        sourceKey: sourceKey,
        targetKey: targetKey,
        item: item,
        duration: const Duration(milliseconds: 300),
        onLanded: () {
          landedCalled = true;
        },
      );

      // During flight: item is registered in flying items
      expect(CookingPanCoordinator.isFlying(item.id), isTrue);

      // Advance animation halfway
      await tester.pump(const Duration(milliseconds: 150));
      expect(CookingPanCoordinator.isFlying(item.id), isTrue);

      // Advance to completion
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pumpAndSettle();

      expect(landedCalled, isTrue);
      expect(CookingPanCoordinator.isFlying(item.id), isFalse);
    });

    testWidgets('Deselecting ingredient clears item from pan and updates count', (tester) async {
      const item = CategoryFoodItem(
        id: 'item-chicken-001',
        name: 'Chicken Breast',
        quantity: '500 g',
        category: 'Non Veg',
        expiryDays: 4,
        imageAsset: 'assets/images/foods/chicken.jpg',
      );

      CookingBasketService.toggleItem(item);
      expect(CookingBasketService.count, equals(1));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CookingPanWidget(width: 175, height: 96),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);

      // Deselect
      CookingBasketService.toggleItem(item);
      await tester.pumpAndSettle();

      expect(CookingBasketService.count, equals(0));
      expect(find.byType(Image), findsNothing);
      expect(find.text('Your pan is ready'), findsOneWidget);
    });

    testWidgets('CookingPanPainter repaints on bounceFactor and rippleProgress changes', (tester) async {
      const p1 = CookingPanPainter(bounceFactor: 0.0, rippleProgress: 0.0);
      const p2 = CookingPanPainter(bounceFactor: 0.5, rippleProgress: 0.0);
      const p3 = CookingPanPainter(bounceFactor: 0.0, rippleProgress: 0.8);

      expect(p1.shouldRepaint(p2), isTrue);
      expect(p1.shouldRepaint(p3), isTrue);
      expect(p1.shouldRepaint(p1), isFalse);
    });
  });
}
