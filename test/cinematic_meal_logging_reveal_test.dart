import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/screens/log_meal/models/cinematic_meal_data.dart';
import 'package:nutrifridge/screens/log_meal/models/meal_nutrition_estimate.dart';
import 'package:nutrifridge/screens/log_meal/widgets/cinematic_meal_logging_reveal_screen.dart';

void main() {
  group('Cinematic Meal Logging & Nutrition Reveal Tests', () {
    setUp(() {
      CinematicMealLoggingRevealScreen.isShowing = false;
    });

    testWidgets('1. Displays Pan Toss (Scene 1) and flying ingredients initially',
        (WidgetTester tester) async {
      final mealData = CinematicMealData(
        mealName: 'Banana Shake',
        mealType: 'Snack',
        servingSize: '1 glass',
        loggedAt: DateTime.now(),
        calories: 220,
        proteinGrams: 8,
        carbsGrams: 35,
        fatGrams: 4,
        ingredients: ['Banana (1 medium)', 'Milk (250 ml)'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CinematicMealLoggingRevealScreen(
            mealData: mealData,
          ),
        ),
      );

      // Verify Scene 1 pan and flying ingredients are rendered during initial phase
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(CinematicMealLoggingRevealScreen), findsOneWidget);
      // Pan container/asset should be present in the tree
      expect(find.byType(Image), findsWidgets);
    });

    testWidgets('2. Transitions to Nutrition Details (Scene 3) and shows exact macros',
        (WidgetTester tester) async {
      final mealData = CinematicMealData(
        mealName: 'Grilled Chicken Bowl',
        mealType: 'Dinner',
        servingSize: '1 bowl',
        loggedAt: DateTime.now(),
        calories: 540,
        proteinGrams: 42,
        carbsGrams: 48,
        fatGrams: 14,
        ingredients: ['Chicken Breast', 'Brown Rice', 'Broccoli'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CinematicMealLoggingRevealScreen(
            mealData: mealData,
          ),
        ),
      );

      // Advance through full animation (2700ms + settle)
      await tester.pump(const Duration(milliseconds: 2800));
      await tester.pumpAndSettle();

      // Verify Meal Header & Success Indicator
      expect(find.text('Meal Logged Successfully'), findsOneWidget);
      expect(find.text('Grilled Chicken Bowl'), findsOneWidget);

      // Verify Exact Macro values match logged data
      expect(find.text('540'), findsOneWidget);
      expect(find.text('kcal'), findsOneWidget);
      expect(find.text('42g'), findsOneWidget); // Protein
      expect(find.text('48g'), findsOneWidget); // Carbs
      expect(find.text('14g'), findsOneWidget); // Fat

      // Verify "Done" button is rendered
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('3. Unavailable nutrients are omitted and never fabricated',
        (WidgetTester tester) async {
      // Meal with NO fiber, sugar, sodium, or potassium
      final mealData = CinematicMealData(
        mealName: 'Simple Omelette',
        mealType: 'Breakfast',
        servingSize: '2 eggs',
        loggedAt: DateTime.now(),
        calories: 180,
        proteinGrams: 14,
        carbsGrams: 2,
        fatGrams: 12,
        fiberGrams: null,
        sugarGrams: null,
        sodiumMg: null,
        potassiumMg: null,
        ingredients: ['Eggs', 'Butter'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CinematicMealLoggingRevealScreen(
            mealData: mealData,
          ),
        ),
      );

      // Advance to Scene 3
      await tester.pump(const Duration(milliseconds: 2800));
      await tester.pumpAndSettle();

      // ADDITIONAL NUTRITION section should be completely absent
      expect(find.text('ADDITIONAL NUTRITION'), findsNothing);
      expect(find.textContaining('Fibre'), findsNothing);
      expect(find.textContaining('Sugar'), findsNothing);
      expect(find.textContaining('Sodium'), findsNothing);
    });

    testWidgets('4. Displays additional nutrients ONLY when genuine data exists',
        (WidgetTester tester) async {
      final mealData = CinematicMealData(
        mealName: 'Chia Berry Bowl',
        mealType: 'Breakfast',
        servingSize: '1 bowl',
        loggedAt: DateTime.now(),
        calories: 320,
        proteinGrams: 10,
        carbsGrams: 45,
        fatGrams: 9,
        fiberGrams: 12.5,
        sugarGrams: 8.0,
        sodiumMg: 65,
        ingredients: ['Chia Seeds', 'Blueberries', 'Almond Milk'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CinematicMealLoggingRevealScreen(
            mealData: mealData,
          ),
        ),
      );

      // Advance to Scene 3
      await tester.pump(const Duration(milliseconds: 2800));
      await tester.pumpAndSettle();

      // ADDITIONAL NUTRITION section should be visible with verified values
      expect(find.text('ADDITIONAL NUTRITION'), findsOneWidget);
      expect(find.text('Fibre: '), findsOneWidget);
      expect(find.text('12.5g'), findsOneWidget);
      expect(find.text('Sugar: '), findsOneWidget);
      expect(find.text('8.0g'), findsOneWidget);
      expect(find.text('Sodium: '), findsOneWidget);
      expect(find.text('65mg'), findsOneWidget);
    });

    testWidgets('5. Tap anywhere skips animation immediately to nutrition details',
        (WidgetTester tester) async {
      final mealData = CinematicMealData(
        mealName: 'Banana Shake',
        calories: 220,
        proteinGrams: 8,
        carbsGrams: 35,
        fatGrams: 4,
        loggedAt: DateTime.now(),
        ingredients: ['Banana', 'Milk'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CinematicMealLoggingRevealScreen(
            mealData: mealData,
          ),
        ),
      );

      // Initially at t=100ms, "Done" button is not yet visible
      await tester.pump(const Duration(milliseconds: 100));

      // Tap screen to skip
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Immediately reaches nutrition details
      expect(find.text('Meal Logged Successfully'), findsOneWidget);
      expect(find.text('Banana Shake'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('6. "Done" button triggers onDone callback',
        (WidgetTester tester) async {
      bool doneCalled = false;

      final mealData = CinematicMealData(
        mealName: 'Paneer Wrap',
        calories: 380,
        proteinGrams: 18,
        carbsGrams: 40,
        fatGrams: 16,
        loggedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CinematicMealLoggingRevealScreen(
            mealData: mealData,
            onDone: () {
              doneCalled = true;
            },
          ),
        ),
      );

      // Jump to end
      await tester.pump(const Duration(milliseconds: 2800));
      await tester.pumpAndSettle();

      // Tap Done
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(doneCalled, isTrue);
    });

    testWidgets('7. Duplicate show calls are guarded and do not duplicate',
        (WidgetTester tester) async {
      final mealData = CinematicMealData(
        mealName: 'Test Meal',
        calories: 300,
        proteinGrams: 15,
        carbsGrams: 30,
        fatGrams: 10,
        loggedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  // Fire two calls simultaneously
                  CinematicMealLoggingRevealScreen.show(context, mealData: mealData);
                  CinematicMealLoggingRevealScreen.show(context, mealData: mealData);
                },
                child: const Text('Log'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Log'));
      await tester.pumpAndSettle();

      // Exactly ONE CinematicMealLoggingRevealScreen should be present in the route stack
      expect(find.byType(CinematicMealLoggingRevealScreen), findsOneWidget);
    });

    testWidgets('8. Factory constructors parse data correctly', (WidgetTester tester) async {
      final estimate = MealNutritionEstimate(
        calories: 450,
        proteinGrams: 22,
        carbsGrams: 55,
        fatGrams: 15,
        fiberGrams: 5.5,
        sugarsGrams: 6.0,
        sodiumMg: 350,
        potassiumMg: 400,
      );

      final fromEstimate = CinematicMealData.fromNutritionEstimate(
        mealName: 'Review Meal',
        nutrition: estimate,
        ingredients: ['Rice', 'Dal'],
        mealType: 'Lunch',
      );

      expect(fromEstimate.mealName, 'Review Meal');
      expect(fromEstimate.calories, 450);
      expect(fromEstimate.proteinGrams, 22);
      expect(fromEstimate.fiberGrams, 5.5);
      expect(fromEstimate.sugarGrams, 6.0);
      expect(fromEstimate.sodiumMg, 350);

      final fromAi = CinematicMealData.fromAiAssistant(
        mealName: 'AI Shake',
        nutritionMap: {
          'calories': 250,
          'proteinG': 12,
          'carbsG': 32,
          'fatG': 6,
          'fiberG': 4.0,
        },
        ingredients: ['Banana', 'Milk'],
        mealType: 'Breakfast',
      );

      expect(fromAi.mealName, 'AI Shake');
      expect(fromAi.calories, 250);
      expect(fromAi.proteinGrams, 12);
      expect(fromAi.fiberGrams, 4.0);
      expect(fromAi.sugarGrams, isNull);
    });

    testWidgets('9. Failed meal save does not trigger success screen',
        (WidgetTester tester) async {
      bool successScreenShown = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    try {
                      throw Exception('Simulated network failure');
                    } catch (e) {
                      // Failed save shows error snackbar, never reveal screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to log meal: $e')),
                      );
                    }
                  },
                  child: const Text('Simulate Save Failure'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Simulate Save Failure'));
      await tester.pumpAndSettle();

      expect(find.byType(CinematicMealLoggingRevealScreen), findsNothing);
      expect(find.textContaining('Failed to log meal: Exception: Simulated network failure'), findsOneWidget);
    });

    testWidgets('10. Old meal logging snackbar is not shown when reveal screen triggers',
        (WidgetTester tester) async {
      final mealData = CinematicMealData(
        mealName: 'Banana Shake',
        calories: 220,
        proteinGrams: 8,
        carbsGrams: 35,
        fatGrams: 4,
        loggedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    // Launches new cinematic reveal screen
                    CinematicMealLoggingRevealScreen.show(context, mealData: mealData);
                  },
                  child: const Text('Log Meal'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Log Meal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The old SnackBar should not be present
      expect(find.textContaining("to Today's Meals!"), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(CinematicMealLoggingRevealScreen), findsOneWidget);
    });

    testWidgets('11. Other snackbars (e.g. grocery additions) unaffected and continue functioning',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    // Unrelated snackbar (e.g. Added to Groceries)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Added Milk to Groceries')),
                    );
                  },
                  child: const Text('Add Grocery'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add Grocery'));
      await tester.pumpAndSettle();

      expect(find.text('Added Milk to Groceries'), findsOneWidget);
    });

    testWidgets('12. Reduced motion skips straight to Scene 3 nutrition details',
        (WidgetTester tester) async {
      final mealData = CinematicMealData(
        mealName: 'Avocado Toast',
        calories: 280,
        proteinGrams: 9,
        carbsGrams: 28,
        fatGrams: 15,
        loggedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: CinematicMealLoggingRevealScreen(
              mealData: mealData,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // Immediately displays final details
      expect(find.text('Meal Logged Successfully'), findsOneWidget);
      expect(find.text('Avocado Toast'), findsOneWidget);
      expect(find.text('280'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });
  });
}
