import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/screens/home/widgets/nutrition_card.dart';
import 'package:nutrifridge/screens/progress/models/progress_data.dart';
import 'package:nutrifridge/screens/progress/progress_screen.dart';

void main() {
  setUp(() {
    MockDataRepository.reset();
    MockDataRepository.forceInMemoryForTesting = true;
    MockDataRepository.currentTimeProvider = () => DateTime(2026, 11, 10, 14, 30);
  });

  tearDown(() {
    MockDataRepository.resetClock();
    MockDataRepository.reset();
  });

  group('NutriFridge — Dashboard & Progress Nutrition Today Synchronization', () {
    // 5 real meals for November 10, 2026 totaling 1,410 kcal, 125g protein, 75g carbs, 66g fat
    final nov10Meals = [
      {
        'id': 'meal_1',
        'mealType': 'Breakfast',
        'mealName': 'Eggs & Brown Bread',
        'calories': 350,
        'protein': 30,
        'carbs': 25,
        'fat': 12,
        'timestamp': DateTime(2026, 11, 10, 8, 30),
      },
      {
        'id': 'meal_2',
        'mealType': 'Lunch',
        'mealName': 'Chicken Salad Bowl',
        'calories': 480,
        'protein': 45,
        'carbs': 15,
        'fat': 24,
        'timestamp': DateTime(2026, 11, 10, 13, 0),
      },
      {
        'id': 'meal_3',
        'mealType': 'Snack',
        'mealName': 'Greek Yogurt & Almonds',
        'calories': 200,
        'protein': 18,
        'carbs': 10,
        'fat': 10,
        'timestamp': DateTime(2026, 11, 10, 16, 15),
      },
      {
        'id': 'meal_4',
        'mealType': 'Dinner',
        'mealName': 'Grilled Salmon & Veggies',
        'calories': 260,
        'protein': 22,
        'carbs': 15,
        'fat': 12,
        'timestamp': DateTime(2026, 11, 10, 19, 45),
      },
      {
        'id': 'meal_5',
        'mealType': 'Dinner',
        'mealName': 'Protein Shake',
        'calories': 120,
        'protein': 10,
        'carbs': 10,
        'fat': 8,
        'timestamp': DateTime(2026, 11, 10, 21, 30),
      },
    ];

    test('1 & 2. Authoritative calculation sums all 5 meals for November 10 (1,410 kcal, 125g P, 75g C, 66g F)', () {
      final totals = DailyNutritionData.calculateDailyTotals(
        date: DateTime(2026, 11, 10),
        loggedMealsHistory: nov10Meals,
      );

      expect(totals.calories, 1410);
      expect(totals.protein, 125);
      expect(totals.carbs, 75);
      expect(totals.fat, 66);
      expect(totals.mealsCount, 5);

      // Verify ProgressDataService delegates to the exact same logic
      final progressTotals = ProgressDataService.calculateDailyTotals(
        date: DateTime(2026, 11, 10),
        loggedMealsHistory: nov10Meals,
      );
      expect(progressTotals.calories, totals.calories);
      expect(progressTotals.protein, totals.protein);
      expect(progressTotals.carbs, totals.carbs);
      expect(progressTotals.fat, totals.fat);
      expect(progressTotals.mealsCount, totals.mealsCount);
    });

    test('3. Progress page weekly analytics and Dashboard Nutrition totals match exactly for November 10', () {
      final totals = DailyNutritionData.calculateDailyTotals(
        date: DateTime(2026, 11, 10),
        loggedMealsHistory: nov10Meals,
      );

      final liveNutrition = DailyNutritionData(
        consumedCalories: totals.calories,
        targetCalories: 2000,
        protein: MacroNutrient(name: 'Protein', amountGrams: totals.protein, targetGrams: 90),
        carbs: MacroNutrient(name: 'Carbs', amountGrams: totals.carbs, targetGrams: 260),
        fat: MacroNutrient(name: 'Fat', amountGrams: totals.fat, targetGrams: 70),
      );

      final analytics = ProgressDataService.computeAnalytics(
        period: 'Week',
        liveNutrition: liveNutrition,
        liveMeals: const [],
        loggedMealsHistory: nov10Meals,
        currentTime: DateTime(2026, 11, 10, 14, 30),
      );

      // Find Tuesday, Nov 10 summary
      final tuesdaySummary = analytics.daySummaries.firstWhere((d) => d.date?.day == 10);
      expect(tuesdaySummary.calories, 1410);
      expect(tuesdaySummary.proteinGrams, 125);
      expect(tuesdaySummary.carbsGrams, 75);
      expect(tuesdaySummary.fatGrams, 66);
      expect(tuesdaySummary.loggedMealsCount, 5);

      // Verify exact match with live nutrition
      expect(liveNutrition.consumedCalories, tuesdaySummary.calories);
      expect(liveNutrition.protein.amountGrams, tuesdaySummary.proteinGrams);
      expect(liveNutrition.carbs.amountGrams, tuesdaySummary.carbsGrams);
      expect(liveNutrition.fat.amountGrams, tuesdaySummary.fatGrams);
    });

    testWidgets('4. Dashboard Nutrition Today card renders 1,410 kcal, 125g P, 75g C, 66g F', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final totals = DailyNutritionData.calculateDailyTotals(
        date: DateTime(2026, 11, 10),
        loggedMealsHistory: nov10Meals,
      );

      final nutrition = DailyNutritionData(
        consumedCalories: totals.calories,
        targetCalories: 2000,
        protein: MacroNutrient(name: 'Protein', amountGrams: totals.protein, targetGrams: 90),
        carbs: MacroNutrient(name: 'Carbs', amountGrams: totals.carbs, targetGrams: 260),
        fat: MacroNutrient(name: 'Fat', amountGrams: totals.fat, targetGrams: 70),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NutritionCard(
                nutritionData: nutrition,
                isExpanded: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check rendered calories
      expect(find.text('1,410'), findsOneWidget);
      expect(find.text('kcal'), findsWidgets);

      // Check rendered macros
      expect(find.textContaining('125g'), findsWidgets);
      expect(find.textContaining('75g'), findsWidgets);
      expect(find.textContaining('66g'), findsWidgets);
    });

    test('5. Logging a 6th meal updates totals immediately without restoring zeros', () async {
      // Seed with initial 5 meals in history
      for (final m in nov10Meals) {
        await MockDataRepository.logMeal(
          mealType: m['mealType'] as String,
          mealName: m['mealName'] as String,
          calories: m['calories'] as int,
          protein: m['protein'] as int,
          carbs: m['carbs'] as int,
          fat: m['fat'] as int,
          timestamp: m['timestamp'] as DateTime,
        );
      }

      // Check state after 5 meals
      expect(MockDataRepository.nutrition.consumedCalories, 1410);
      expect(MockDataRepository.nutrition.protein.amountGrams, 125);
      expect(MockDataRepository.nutrition.carbs.amountGrams, 75);
      expect(MockDataRepository.nutrition.fat.amountGrams, 66);

      // Log 6th meal: Evening snack +250 kcal, 15g P, 30g C, 8g F
      await MockDataRepository.logMeal(
        mealType: 'Snack',
        mealName: 'Fruit & Nut Bar',
        calories: 250,
        protein: 15,
        carbs: 30,
        fat: 8,
        timestamp: DateTime(2026, 11, 10, 22, 15),
      );

      // Verify updated totals (1410 + 250 = 1660)
      expect(MockDataRepository.nutrition.consumedCalories, 1660);
      expect(MockDataRepository.nutrition.protein.amountGrams, 140);
      expect(MockDataRepository.nutrition.carbs.amountGrams, 105);
      expect(MockDataRepository.nutrition.fat.amountGrams, 74);

      // Synchronize from meals again to verify stability
      MockDataRepository.syncTodayNutritionFromMeals();
      expect(MockDataRepository.nutrition.consumedCalories, 1660);
    });

    test('6. A day with genuinely no meals correctly displays zero', () {
      final totals = DailyNutritionData.calculateDailyTotals(
        date: DateTime(2026, 11, 10),
        loggedMealsHistory: const [],
      );

      expect(totals.calories, 0);
      expect(totals.protein, 0);
      expect(totals.carbs, 0);
      expect(totals.fat, 0);
      expect(totals.mealsCount, 0);
    });

    test('7. Switching to another date does not mix nutrition totals', () {
      final mixedMeals = [
        ...nov10Meals,
        // Yesterday meal (Nov 9)
        {
          'id': 'meal_y1',
          'mealType': 'Dinner',
          'mealName': 'Yesterday Pasta',
          'calories': 600,
          'protein': 25,
          'carbs': 85,
          'fat': 15,
          'timestamp': DateTime(2026, 11, 9, 20, 0),
        },
        // Tomorrow meal (Nov 11)
        {
          'id': 'meal_t1',
          'mealType': 'Breakfast',
          'mealName': 'Tomorrow Oatmeal',
          'calories': 300,
          'protein': 12,
          'carbs': 50,
          'fat': 6,
          'timestamp': DateTime(2026, 11, 11, 8, 0),
        },
      ];

      // Nov 10 totals should remain strictly 1410
      final nov10Totals = DailyNutritionData.calculateDailyTotals(
        date: DateTime(2026, 11, 10),
        loggedMealsHistory: mixedMeals,
      );
      expect(nov10Totals.calories, 1410);
      expect(nov10Totals.mealsCount, 5);

      // Nov 9 totals should strictly be 600
      final nov9Totals = DailyNutritionData.calculateDailyTotals(
        date: DateTime(2026, 11, 9),
        loggedMealsHistory: mixedMeals,
      );
      expect(nov9Totals.calories, 600);
      expect(nov9Totals.mealsCount, 1);

      // Nov 11 totals should strictly be 300
      final nov11Totals = DailyNutritionData.calculateDailyTotals(
        date: DateTime(2026, 11, 11),
        loggedMealsHistory: mixedMeals,
      );
      expect(nov11Totals.calories, 300);
      expect(nov11Totals.mealsCount, 1);
    });

    test('8. Meals logged shortly before and after midnight are assigned to the correct local day', () {
      final edgeMeals = [
        // Logged at 23:59:45 on Nov 10
        {
          'id': 'late_night',
          'mealType': 'Snack',
          'mealName': 'Midnight Snack',
          'calories': 150,
          'protein': 5,
          'carbs': 20,
          'fat': 5,
          'timestamp': DateTime(2026, 11, 10, 23, 59, 45),
        },
        // Logged at 00:00:15 on Nov 11
        {
          'id': 'early_morning',
          'mealType': 'Snack',
          'mealName': 'Post-Midnight Drink',
          'calories': 90,
          'protein': 2,
          'carbs': 15,
          'fat': 1,
          'timestamp': DateTime(2026, 11, 11, 0, 0, 15),
        },
      ];

      final day10 = DailyNutritionData.calculateDailyTotals(
        date: DateTime(2026, 11, 10),
        loggedMealsHistory: edgeMeals,
      );
      expect(day10.calories, 150);
      expect(day10.mealsCount, 1);

      final day11 = DailyNutritionData.calculateDailyTotals(
        date: DateTime(2026, 11, 11),
        loggedMealsHistory: edgeMeals,
      );
      expect(day11.calories, 90);
      expect(day11.mealsCount, 1);
    });

    testWidgets('9. ProgressScreen displays the exact same 1,410 kcal and 5 meals for November 10', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Populate history with the 5 meals
      MockDataRepository.clearLoggedMealsHistoryForTesting();
      for (final m in nov10Meals) {
        await MockDataRepository.logMeal(
          mealType: m['mealType'] as String,
          mealName: m['mealName'] as String,
          calories: m['calories'] as int,
          protein: m['protein'] as int,
          carbs: m['carbs'] as int,
          fat: m['fat'] as int,
          timestamp: m['timestamp'] as DateTime,
        );
      }

      await tester.pumpWidget(
        const MaterialApp(
          home: ProgressScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that Tuesday (Nov 10) in the weekly calorie chart contains 1410
      expect(find.text('Tue'), findsOneWidget);
      expect(find.textContaining('1410'), findsWidgets);
    });
  });
}
