import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/screens/home/home_screen.dart';
import 'package:nutrifridge/screens/home/widgets/nutrition_card.dart';
import 'package:nutrifridge/screens/home/widgets/recommendation_card.dart';
import 'package:nutrifridge/screens/progress/models/progress_data.dart';
import 'package:nutrifridge/screens/progress/progress_screen.dart';
import 'package:nutrifridge/screens/progress/widgets/consistency_heatmap.dart';
import 'package:nutrifridge/screens/progress/widgets/macro_donut_chart.dart';
import 'package:nutrifridge/screens/progress/widgets/weekly_calories_chart.dart';

void main() {
  setUp(() {
    MockDataRepository.forceInMemoryForTesting = true;
    MockDataRepository.reset();
    FridgeCategoryRepository.reset();
  });

  tearDown(() {
    MockDataRepository.reset();
    FridgeCategoryRepository.reset();
  });

  group('NutriFridge — Wellness Score Complete Removal Verification', () {
    testWidgets('Dashboard renders cleanly without any Wellness Score card or indicators', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      MockDataRepository.seedSampleDataForTesting();

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert Wellness Score elements are completely absent from Dashboard
      expect(find.text("Today's Wellness"), findsNothing);
      expect(find.text('Your wellness score today'), findsNothing);
      expect(find.text('7-day wellness trend'), findsNothing);
      expect(find.text('WELLNESS SCORE'), findsNothing);
      expect(find.textContaining('wellness indicator'), findsNothing);

      // Assert remaining cards are intact and properly rendered
      expect(find.byType(RecommendationCard), findsOneWidget);
      expect(find.byType(NutritionCard), findsOneWidget);
      expect(find.text('Nutrition Today'), findsOneWidget);
      expect(find.text("Today's Meals"), findsOneWidget);
    });

    testWidgets('Progress screen renders cleanly without any Wellness Hero or Score', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      MockDataRepository.seedSampleDataForTesting();

      await tester.pumpWidget(
        const MaterialApp(
          home: ProgressScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert Wellness Score elements are completely absent from Progress
      expect(find.text('WELLNESS SCORE'), findsNothing);
      expect(find.text('out of 100'), findsNothing);
      expect(find.textContaining('wellness indicator'), findsNothing);
      expect(find.text("Today's Wellness"), findsNothing);

      // Assert Progress analytics charts are preserved and visible
      expect(find.byType(MacroDonutChart), findsOneWidget);
      expect(find.byType(WeeklyCaloriesChart), findsOneWidget);
      expect(find.byType(ConsistencyHeatmap), findsOneWidget);
      expect(find.text('Progress'), findsOneWidget);
      expect(find.text('Your nutrition, over time.'), findsOneWidget);
      expect(find.text('Calorie distribution by macro'), findsOneWidget);
    });

    test('ProgressDataService computes analytics without wellnessScore calculations', () {
      final now = DateTime(2026, 11, 10, 14, 0, 0);

      final weekly = ProgressDataService.computeAnalytics(
        period: 'Week',
        liveNutrition: const DailyNutritionData(
          consumedCalories: 1410,
          targetCalories: 2200,
          protein: MacroNutrient(name: 'Protein', amountGrams: 125, targetGrams: 90),
          carbs: MacroNutrient(name: 'Carbs', amountGrams: 75, targetGrams: 260),
          fat: MacroNutrient(name: 'Fat', amountGrams: 66, targetGrams: 70),
        ),
        liveMeals: const [],
        loggedMealsHistory: [
          {
            'calories': 500,
            'protein': 40,
            'carbs': 30,
            'fat': 20,
            'timestamp': DateTime(2026, 11, 10, 12, 0, 0),
          },
        ],
        currentTime: now,
      );

      // Verify all real nutrition metrics remain fully computed
      expect(weekly.period, 'Week');
      expect(weekly.daySummaries.length, 7);
      expect(weekly.heatmapCells.length, 7);
      expect(weekly.totalPeriodMealsCount, 1);
      expect(weekly.macroChartProteinGrams, greaterThan(0));
      expect(weekly.macroChartCarbsGrams, greaterThan(0));
      expect(weekly.macroChartFatGrams, greaterThan(0));
      expect(weekly.hasRecords, isTrue);
    });

    test('Nutrition Today and Progress aggregation continue to sync accurately', () {
      final now = DateTime(2026, 11, 10, 12, 0, 0);
      MockDataRepository.currentTimeProvider = () => now;

      // Log two meals for today
      MockDataRepository.logMeal(
        mealType: 'Breakfast',
        mealName: 'Oats & Berries',
        calories: 350,
        protein: 15,
        carbs: 60,
        fat: 5,
        timestamp: now,
      );

      MockDataRepository.logMeal(
        mealType: 'Lunch',
        mealName: 'Chicken Salad',
        calories: 550,
        protein: 45,
        carbs: 20,
        fat: 15,
        timestamp: now,
      );

      // Verify Dashboard authoritative aggregation
      final dashNutrition = MockDataRepository.nutrition;
      expect(dashNutrition.consumedCalories, 900);
      expect(dashNutrition.protein.amountGrams, 60);
      expect(dashNutrition.carbs.amountGrams, 80);
      expect(dashNutrition.fat.amountGrams, 20);

      // Verify Progress daily calculation matches identically
      final progressTotals = ProgressDataService.calculateDailyTotals(
        date: now,
        loggedMealsHistory: MockDataRepository.loggedMealsHistory,
      );
      expect(progressTotals.calories, 900);
      expect(progressTotals.protein, 60);
      expect(progressTotals.carbs, 80);
      expect(progressTotals.fat, 20);
      expect(progressTotals.mealsCount, 2);
    });
  });
}
