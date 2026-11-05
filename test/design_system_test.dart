import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/widgets/common/common.dart';

void main() {
  group('NutriFridge Phase 1 Design System Tests', () {
    testWidgets('CircularCalorieRing renders consumed, goal and remaining calories',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CircularCalorieRing(
              consumedCalories: 1840,
              targetCalories: 2200,
            ),
          ),
        ),
      );

      expect(find.text('1,840'), findsOneWidget);
      expect(find.text('kcal consumed'), findsOneWidget);
      expect(find.text('360 left'), findsOneWidget);
    });

    testWidgets('CircularCalorieRing handles zero-consumption clean state',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CircularCalorieRing(
              consumedCalories: 0,
              targetCalories: 2000,
            ),
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);
      expect(find.text('2,000 goal'), findsOneWidget);
    });

    testWidgets('CircularCalorieRing handles over-target state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CircularCalorieRing(
              consumedCalories: 2400,
              targetCalories: 2000,
            ),
          ),
        ),
      );

      expect(find.text('2,400'), findsOneWidget);
      expect(find.text('400 over'), findsOneWidget);
    });

    testWidgets('MacroMetricRow renders Protein, Carbs, and Fat cards correctly',
        (tester) async {
      const protein = MacroNutrient(
        name: 'Protein',
        amountGrams: 96,
        targetGrams: 130,
        unit: 'g',
      );
      const carbs = MacroNutrient(
        name: 'Carbs',
        amountGrams: 210,
        targetGrams: 280,
        unit: 'g',
      );
      const fat = MacroNutrient(
        name: 'Fat',
        amountGrams: 55,
        targetGrams: 70,
        unit: 'g',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MacroMetricRow(
              protein: protein,
              carbs: carbs,
              fat: fat,
            ),
          ),
        ),
      );

      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('96'), findsOneWidget);
      expect(find.text('/ 130 g'), findsOneWidget);

      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('210'), findsOneWidget);
      expect(find.text('/ 280 g'), findsOneWidget);

      expect(find.text('Fat'), findsOneWidget);
      expect(find.text('55'), findsOneWidget);
      expect(find.text('/ 70 g'), findsOneWidget);
    });

    testWidgets('AppCard variants render correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppCard.white(child: const Text('White Card')),
                AppCard.cream(child: const Text('Cream Card')),
                AppCard.mint(child: const Text('Mint Card')),
              ],
            ),
          ),
        ),
      );

      expect(find.text('White Card'), findsOneWidget);
      expect(find.text('Cream Card'), findsOneWidget);
      expect(find.text('Mint Card'), findsOneWidget);
    });

    testWidgets('AppPrimaryButton triggers callback', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppPrimaryButton(
              label: 'Cook Meal',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Cook Meal'), findsOneWidget);
      await tester.tap(find.text('Cook Meal'));
      expect(tapped, isTrue);
    });

    testWidgets('SectionHeader renders title and action callback', (tester) async {
      bool actionTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SectionHeader(
              title: 'Recommended Recipes',
              subtitle: 'Based on your fridge items',
              actionText: 'View All',
              onActionTap: () => actionTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Recommended Recipes'), findsOneWidget);
      expect(find.text('Based on your fridge items'), findsOneWidget);
      expect(find.text('View All'), findsOneWidget);

      await tester.tap(find.text('View All'));
      expect(actionTapped, isTrue);
    });
  });
}
