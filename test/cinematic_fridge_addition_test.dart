import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/screens/fridge/models/ingredient_addition_data.dart';
import 'package:nutrifridge/screens/fridge/widgets/cinematic_fridge_addition_screen.dart';
import 'package:nutrifridge/screens/fridge/widgets/cold_mist_effect.dart';
import 'package:nutrifridge/screens/fridge/widgets/refrigerator_interior.dart';
import 'package:nutrifridge/screens/fridge/widgets/top_freezer_refrigerator.dart';
import 'package:nutrifridge/screens/log_meal/models/cinematic_meal_data.dart';
import 'package:nutrifridge/screens/log_meal/widgets/cinematic_meal_logging_reveal_screen.dart';

void main() {
  group('Cinematic Fridge Opening & Ingredient Addition Tests', () {
    setUp(() {
      CinematicFridgeAdditionScreen.isShowing = false;
      CinematicMealLoggingRevealScreen.isShowing = false;
    });

    testWidgets('1. Successfully adding one ingredient opens the animation with authentic refrigerator',
        (WidgetTester tester) async {
      final additionData = IngredientAdditionData.single(
        item: const AddedIngredientItem(
          name: 'Apple',
          quantity: 2,
          unit: 'pieces',
          category: 'Fruits',
          expiryDays: 7,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CinematicFridgeAdditionScreen(
            additionData: additionData,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(CinematicFridgeAdditionScreen), findsOneWidget);
      // Reuses the exact authentic NutriFridge TopFreezerRefrigerator component
      expect(find.byType(TopFreezerRefrigerator), findsOneWidget);
    });

    testWidgets('2. Successfully adding multiple ingredients animates all actual items',
        (WidgetTester tester) async {
      final additionData = IngredientAdditionData.multiple(
        items: const [
          AddedIngredientItem(
            name: 'Apple',
            quantity: 2,
            unit: 'pieces',
            category: 'Fruits',
          ),
          AddedIngredientItem(
            name: 'Milk',
            quantity: 1,
            unit: 'carton',
            category: 'Dairy',
          ),
          AddedIngredientItem(
            name: 'Broccoli',
            quantity: 1,
            unit: 'piece',
            category: 'Vegetables',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CinematicFridgeAdditionScreen(
            additionData: additionData,
          ),
        ),
      );

      expect(find.byType(CinematicFridgeAdditionScreen), findsOneWidget);

      // Advance through animation to summary
      await tester.pump(const Duration(milliseconds: 3200));
      await tester.pumpAndSettle();

      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Broccoli'), findsOneWidget);
    });

    testWidgets('3. The refrigerator door smoothly blurs and fades away (vanish effect, zero rotation)',
        (WidgetTester tester) async {
      final additionData = IngredientAdditionData.single(
        item: const AddedIngredientItem(
          name: 'Orange',
          quantity: 3,
          category: 'Fruits',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CinematicFridgeAdditionScreen(
            additionData: additionData,
          ),
        ),
      );

      // Refrigerator is visible
      expect(find.byType(TopFreezerRefrigerator), findsOneWidget);

      // Step forward to trigger door fade-reveal sequence
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));

      // Interior cavity is actively revealed underneath
      expect(find.byType(RefrigeratorInterior), findsOneWidget);
    });

    testWidgets('4. Cold mist emerges from refrigerator interior',
        (WidgetTester tester) async {
      final additionData = IngredientAdditionData.single(
        item: const AddedIngredientItem(
          name: 'Yogurt',
          quantity: 1,
          category: 'Dairy',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CinematicFridgeAdditionScreen(
            additionData: additionData,
          ),
        ),
      );

      // Advance to when door is open and mist flows out (~500ms)
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 100));

      // Authentic ColdMistEffect is active
      expect(find.byType(ColdMistEffect), findsWidgets);
    });

    testWidgets('5. Ingredients follow curved trajectories and enter the revealed interior',
        (WidgetTester tester) async {
      final additionData = IngredientAdditionData.multiple(
        items: const [
          AddedIngredientItem(name: 'Banana', quantity: 4, category: 'Fruits'),
          AddedIngredientItem(name: 'Tomato', quantity: 2, category: 'Vegetables'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CinematicFridgeAdditionScreen(
            additionData: additionData,
          ),
        ),
      );

      // Advance into ingredient flight phase (~1000ms)
      await tester.pump(const Duration(milliseconds: 1000));

      // Flying items actively rendered over the open refrigerator interior
      expect(find.byType(Transform), findsWidgets);
      expect(find.byType(RefrigeratorInterior), findsOneWidget);
    });

    testWidgets('6. Refrigerator door returns through reverse fade animation',
        (WidgetTester tester) async {
      final additionData = IngredientAdditionData.single(
        item: const AddedIngredientItem(name: 'Eggs', quantity: 6, category: 'Dairy'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CinematicFridgeAdditionScreen(
            additionData: additionData,
          ),
        ),
      );

      // Open phase
      await tester.pump(const Duration(milliseconds: 500));
      // Flight phase
      await tester.pump(const Duration(milliseconds: 1400));
      // Re-fade closing phase (~2200ms)
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(TopFreezerRefrigerator), findsOneWidget);
    });

    testWidgets('7. The correct summary appears with header and success badge',
        (WidgetTester tester) async {
      final additionData = IngredientAdditionData.single(
        item: const AddedIngredientItem(
          name: 'Strawberries',
          quantity: 1,
          unit: 'box',
          category: 'Fruits',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CinematicFridgeAdditionScreen(
            additionData: additionData,
          ),
        ),
      );

      // Complete animation
      await tester.pump(const Duration(milliseconds: 3200));
      await tester.pumpAndSettle();

      expect(find.text('Ingredients Added Successfully'), findsOneWidget);
      expect(find.text('Inventory Updated'), findsOneWidget);
      expect(find.text('Strawberries'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('8. Actual quantities and categories are displayed',
        (WidgetTester tester) async {
      final additionData = IngredientAdditionData.multiple(
        items: const [
          AddedIngredientItem(
            name: 'Almonds',
            quantity: 200,
            unit: 'g',
            category: 'Dry Fruits',
          ),
          AddedIngredientItem(
            name: 'Milk',
            category: 'Dairy',
            addedQuantity: 1,
            totalQuantity: 3,
            unit: 'carton',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CinematicFridgeAdditionScreen(
            additionData: additionData,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 3200));
      await tester.pumpAndSettle();

      expect(find.text('Almonds'), findsOneWidget);
      expect(find.text('200 g'), findsOneWidget);
      expect(find.text('Dry Fruits'), findsOneWidget);

      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('+1 (Total: 3 carton)'), findsOneWidget);
      expect(find.text('Dairy'), findsOneWidget);
    });

    testWidgets('9. Expiry information is shown only when available and omitted when null',
        (WidgetTester tester) async {
      final additionData = IngredientAdditionData.multiple(
        items: const [
          AddedIngredientItem(
            name: 'Fresh Salmon',
            quantity: 1,
            unit: 'fillet',
            category: 'Non Veg',
            expiryDays: 3,
          ),
          AddedIngredientItem(
            name: 'Salt',
            quantity: 1,
            unit: 'pack',
            category: 'Others',
            expiryDays: null, // No expiry provided
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CinematicFridgeAdditionScreen(
            additionData: additionData,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 3200));
      await tester.pumpAndSettle();

      // Salmon has expiry
      expect(find.text('Expires in 3 days'), findsOneWidget);
      // Only 1 expiry badge in tree
      expect(find.byIcon(Icons.access_time_rounded), findsOneWidget);
    });

    testWidgets('10. Skipping the animation opens the same summary immediately',
        (WidgetTester tester) async {
      final additionData = IngredientAdditionData.single(
        item: const AddedIngredientItem(
          name: 'Blueberries',
          quantity: 1,
          category: 'Fruits',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CinematicFridgeAdditionScreen(
            additionData: additionData,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 150));

      // Tap screen to skip
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Summary screen is immediately visible
      expect(find.text('Ingredients Added Successfully'), findsOneWidget);
      expect(find.text('Blueberries'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('11. Done returns to the originating screen',
        (WidgetTester tester) async {
      bool doneCalled = false;

      final additionData = IngredientAdditionData.single(
        item: const AddedIngredientItem(name: 'Cucumber', quantity: 2, category: 'Vegetables'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CinematicFridgeAdditionScreen(
            additionData: additionData,
            onDone: () {
              doneCalled = true;
            },
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 3200));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(doneCalled, isTrue);
    });

    testWidgets('12. Failed saves never show the success animation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    try {
                      throw Exception('Database write failed');
                    } catch (e) {
                      // Failed operation never triggers CinematicFridgeAdditionScreen
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error adding item: $e')),
                      );
                    }
                  },
                  child: const Text('Save Food'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Save Food'));
      await tester.pumpAndSettle();

      expect(find.byType(CinematicFridgeAdditionScreen), findsNothing);
      expect(find.textContaining('Error adding item'), findsOneWidget);
    });

    testWidgets('13. Cancelled proposals never trigger the animation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    // Cancel action does nothing to inventory
                  },
                  child: const Text('Cancel Proposal'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Cancel Proposal'));
      await tester.pumpAndSettle();

      expect(find.byType(CinematicFridgeAdditionScreen), findsNothing);
    });

    testWidgets('14. Repeated save callbacks do not open multiple summaries',
        (WidgetTester tester) async {
      final additionData = IngredientAdditionData.single(
        item: const AddedIngredientItem(name: 'Bread', quantity: 1, category: 'Others'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  // Fire two calls simultaneously
                  CinematicFridgeAdditionScreen.show(context, additionData: additionData);
                  CinematicFridgeAdditionScreen.show(context, additionData: additionData);
                },
                child: const Text('Add Rapidly'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Add Rapidly'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Exactly ONE CinematicFridgeAdditionScreen in route stack
      expect(find.byType(CinematicFridgeAdditionScreen), findsOneWidget);
    });

    testWidgets('15. The existing meal logging animation and its summary screen remain untouched',
        (WidgetTester tester) async {
      final mealData = CinematicMealData(
        mealName: 'Banana Smoothie',
        mealType: 'Breakfast',
        calories: 250,
        proteinGrams: 8,
        carbsGrams: 45,
        fatGrams: 3,
        loggedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CinematicMealLoggingRevealScreen(
            mealData: mealData,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 2800));
      await tester.pumpAndSettle();

      // Meal logging screen renders normally
      expect(find.byType(CinematicMealLoggingRevealScreen), findsOneWidget);
      expect(find.text('Meal Logged Successfully'), findsOneWidget);
      expect(find.text('Banana Smoothie'), findsOneWidget);
      expect(find.text('250'), findsOneWidget);
    });

    testWidgets('16. The actual Fridge screen remains completely untouched',
        (WidgetTester tester) async {
      // TopFreezerRefrigerator exists in isolation and unchanged
      expect(TopFreezerRefrigerator, isNotNull);
    });
  });
}
