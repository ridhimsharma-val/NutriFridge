import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/core/utils/date_range_utils.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/screens/progress/models/progress_data.dart';

DailyNutritionData _createNutrition({
  int cals = 0,
  int target = 2000,
  int protein = 0,
  int carbs = 0,
  int fat = 0,
}) {
  return DailyNutritionData(
    consumedCalories: cals,
    targetCalories: target,
    protein: MacroNutrient(name: 'Protein', amountGrams: protein, targetGrams: 90),
    carbs: MacroNutrient(name: 'Carbs', amountGrams: carbs, targetGrams: 260),
    fat: MacroNutrient(name: 'Fat', amountGrams: fat, targetGrams: 70),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MockDataRepository.forceInMemoryForTesting = true;
    MockDataRepository.reset();
  });

  tearDown(() {
    MockDataRepository.resetClock();
  });

  group('1. Monthly Calendar and Week Numbering Tests', () {
    test('November 8, 2026 is Week 2', () {
      final weekNum = DateRangeUtils.getWeekNumberForDay(8);
      expect(weekNum, 2);

      final date = DateTime(2026, 11, 8, 11, 6, 44);
      final segments = DateRangeUtils.getMonthWeekSegments(date);
      expect(segments.length, 5); // Nov has 30 days -> 5 segments

      final currentSegment = segments.firstWhere((s) => s.isCurrentWeek(date));
      expect(currentSegment.weekNumber, 2);
      expect(currentSegment.startDay, 8);
      expect(currentSegment.endDay, 14);
      expect(currentSegment.dateRangeLabel, 'Nov 8–14');
    });

    test('November 22, 2026 is Week 4', () {
      final weekNum = DateRangeUtils.getWeekNumberForDay(22);
      expect(weekNum, 4);

      final date = DateTime(2026, 11, 22, 14, 0, 0);
      final segments = DateRangeUtils.getMonthWeekSegments(date);
      final currentSegment = segments.firstWhere((s) => s.isCurrentWeek(date));
      expect(currentSegment.weekNumber, 4);
      expect(currentSegment.startDay, 22);
      expect(currentSegment.endDay, 28);
      expect(currentSegment.dateRangeLabel, 'Nov 22–28');
    });

    test('November 29, 2026 is Week 5', () {
      final weekNum = DateRangeUtils.getWeekNumberForDay(29);
      expect(weekNum, 5);

      final date = DateTime(2026, 11, 29, 9, 30, 0);
      final segments = DateRangeUtils.getMonthWeekSegments(date);
      final currentSegment = segments.firstWhere((s) => s.isCurrentWeek(date));
      expect(currentSegment.weekNumber, 5);
      expect(currentSegment.startDay, 29);
      expect(currentSegment.endDay, 30);
      expect(currentSegment.dateRangeLabel, 'Nov 29–30');
    });

    test('February 2027 has 28 days and exactly 4 weeks', () {
      final days = DateRangeUtils.getDaysInMonth(2027, 2);
      expect(days, 28);

      final segments = DateRangeUtils.getMonthWeekSegments(DateTime(2027, 2, 15));
      expect(segments.length, 4);
      expect(segments.map((s) => s.weekNumber).toList(), [1, 2, 3, 4]);
      expect(segments[3].startDay, 22);
      expect(segments[3].endDay, 28);
    });

    test('February 2028 (leap year) has 29 days and 5 weeks', () {
      final days = DateRangeUtils.getDaysInMonth(2028, 2);
      expect(days, 29);

      final segments = DateRangeUtils.getMonthWeekSegments(DateTime(2028, 2, 29));
      expect(segments.length, 5);
      expect(segments[4].weekNumber, 5);
      expect(segments[4].startDay, 29);
      expect(segments[4].endDay, 29);
      expect(segments[4].dateRangeLabel, 'Feb 29');
    });

    test('Month transitions across December 2026 and January 2027', () {
      final decRange = DateRangeUtils.getCalendarMonthRange(DateTime(2026, 12, 15));
      expect(decRange.daysInMonth, 31);
      expect(decRange.start, DateTime(2026, 12, 1, 0, 0, 0));
      expect(decRange.endExclusive, DateTime(2027, 1, 1, 0, 0, 0));

      final janRange = DateRangeUtils.getCalendarMonthRange(DateTime(2027, 1, 10));
      expect(janRange.daysInMonth, 31);
      expect(janRange.start, DateTime(2027, 1, 1, 0, 0, 0));
      expect(janRange.endExclusive, DateTime(2027, 2, 1, 0, 0, 0));
    });

    test('Calendar month contains only dates of that month and excludes adjacent months', () {
      final novRange = DateRangeUtils.getCalendarMonthRange(DateTime(2026, 11, 8));

      expect(novRange.contains(DateTime(2026, 10, 31, 23, 59, 59)), isFalse);
      expect(novRange.contains(DateTime(2026, 11, 1, 0, 0, 0)), isTrue);
      expect(novRange.contains(DateTime(2026, 11, 30, 23, 59, 59)), isTrue);
      expect(novRange.contains(DateTime(2026, 12, 1, 0, 0, 0)), isFalse);
    });
  });

  group('2. Macronutrient Distribution and Mathematical Consistency Tests', () {
    test('Actual macro values are aggregated and percentages match mathematically', () {
      final now = DateTime(2026, 11, 8, 12, 0, 0);

      // Meal with 25g protein (100 kcal), 50g carbs (200 kcal), 10g fat (90 kcal) -> total 390 kcal
      final weekly = ProgressDataService.computeAnalytics(
        period: 'Week',
        liveNutrition: _createNutrition(cals: 390, protein: 25, carbs: 50, fat: 10),
        liveMeals: const [],
        loggedMealsHistory: [
          {
            'calories': 390,
            'protein': 25 * 7, // 175g for week -> 25g/day
            'carbs': 50 * 7,   // 350g for week -> 50g/day
            'fat': 10 * 7,     // 70g for week -> 10g/day
            'timestamp': DateTime(2026, 11, 8, 12, 0, 0),
          },
        ],
        currentTime: now,
      );

      expect(weekly.macroChartProteinGrams, 25);
      expect(weekly.macroChartCarbsGrams, 50);
      expect(weekly.macroChartFatGrams, 10);
      // 25*4 + 50*4 + 10*9 = 100 + 200 + 90 = 390 kcal
      expect(weekly.macroChartCalories, 390);

      final pKcal = weekly.macroChartProteinGrams * 4;
      final cKcal = weekly.macroChartCarbsGrams * 4;
      final fKcal = weekly.macroChartFatGrams * 9;
      expect(pKcal + cKcal + fKcal, weekly.macroChartCalories);
    });

    test('Empty data produces zero values for macros', () {
      final now = DateTime(2026, 11, 8, 12, 0, 0);

      final weekly = ProgressDataService.computeAnalytics(
        period: 'Week',
        liveNutrition: _createNutrition(),
        liveMeals: const [],
        loggedMealsHistory: const [],
        currentTime: now,
      );

      expect(weekly.macroChartProteinGrams, 0);
      expect(weekly.macroChartCarbsGrams, 0);
      expect(weekly.macroChartFatGrams, 0);
      expect(weekly.macroChartCalories, 0);
    });
  });

  group('4. Weekly Calories and Monthly Averages Chart Tests', () {
    test('Weekly calories chart has 7 days (Mon to Sun) with accurate daily totals', () {
      final now = DateTime(2026, 11, 8, 12, 0, 0); // Sunday Nov 8

      final weekly = ProgressDataService.computeAnalytics(
        period: 'Week',
        liveNutrition: _createNutrition(cals: 400, target: 2200, protein: 20, carbs: 50, fat: 10),
        liveMeals: const [],
        loggedMealsHistory: [
          {
            'calories': 400,
            'protein': 20,
            'carbs': 50,
            'fat': 10,
            'timestamp': DateTime(2026, 11, 8, 10, 0, 0), // Sunday Nov 8
          },
          {
            'calories': 600,
            'protein': 30,
            'carbs': 70,
            'fat': 20,
            'timestamp': DateTime(2026, 11, 2, 9, 0, 0), // Monday Nov 2
          },
        ],
        currentTime: now,
        targetCalories: 2200,
      );

      expect(weekly.daySummaries.length, 7);
      expect(weekly.daySummaries[0].dayName, 'Mon');
      expect(weekly.daySummaries[0].calories, 600);
      expect(weekly.daySummaries[0].loggedMealsCount, 1);

      expect(weekly.daySummaries[6].dayName, 'Sun');
      expect(weekly.daySummaries[6].calories, 400);
      expect(weekly.daySummaries[6].isToday, isTrue);

      // Tuesday (empty) has 0 calories
      expect(weekly.daySummaries[1].dayName, 'Tue');
      expect(weekly.daySummaries[1].calories, 0);
      expect(weekly.daySummaries[1].loggedMealsCount, 0);
    });

    test('Monthly averages chart has 5 week segments for November 2026, identifying Week 2 as current', () {
      final now = DateTime(2026, 11, 8, 12, 0, 0); // Sunday Nov 8

      final monthly = ProgressDataService.computeAnalytics(
        period: 'Month',
        liveNutrition: _createNutrition(cals: 500, target: 2200, protein: 25, carbs: 60, fat: 15),
        liveMeals: const [],
        loggedMealsHistory: [
          {
            'calories': 700,
            'protein': 35,
            'carbs': 80,
            'fat': 25,
            'timestamp': DateTime(2026, 11, 3, 12, 0, 0), // In Week 1 (Nov 1-7)
          },
          {
            'calories': 500,
            'protein': 25,
            'carbs': 60,
            'fat': 15,
            'timestamp': DateTime(2026, 11, 8, 12, 0, 0), // In Week 2 (Nov 8-14)
          },
        ],
        currentTime: now,
        targetCalories: 2200,
      );

      expect(monthly.daySummaries.length, 5);
      expect(monthly.daySummaries[0].dayName, 'W1');
      expect(monthly.daySummaries[0].fullDate, contains('Nov 1–7'));
      expect(monthly.daySummaries[0].isToday, isFalse);
      expect(monthly.daySummaries[0].loggedMealsCount, 1);

      expect(monthly.daySummaries[1].dayName, 'W2');
      expect(monthly.daySummaries[1].fullDate, contains('Current Week'));
      expect(monthly.daySummaries[1].fullDate, contains('Nov 8–14'));
      expect(monthly.daySummaries[1].isToday, isTrue);
      expect(monthly.daySummaries[1].loggedMealsCount, 1);

      // Future weeks (W3, W4, W5) have 0
      expect(monthly.daySummaries[2].dayName, 'W3');
      expect(monthly.daySummaries[2].calories, 0);
      expect(monthly.daySummaries[3].dayName, 'W4');
      expect(monthly.daySummaries[3].calories, 0);
      expect(monthly.daySummaries[4].dayName, 'W5');
      expect(monthly.daySummaries[4].calories, 0);
    });
  });

  group('5. Meal Logging Consistency Heatmap Tests', () {
    test('Weekly view contains exactly 7 days', () {
      final now = DateTime(2026, 11, 8, 12, 0, 0);

      final weekly = ProgressDataService.computeAnalytics(
        period: 'Week',
        liveNutrition: _createNutrition(),
        liveMeals: const [],
        loggedMealsHistory: const [],
        currentTime: now,
      );

      expect(weekly.heatmapCells.length, 7);
      expect(weekly.heatmapCells.every((c) => !c.isPadding), isTrue);
      expect(weekly.heatmapCells.last.isCurrentDay, isTrue); // Nov 8 Sunday is today
    });

    test('Monthly view contains only dates belonging to that month (non-padding)', () {
      final now = DateTime(2026, 11, 8, 12, 0, 0);

      final monthly = ProgressDataService.computeAnalytics(
        period: 'Month',
        liveNutrition: _createNutrition(),
        liveMeals: const [],
        loggedMealsHistory: const [],
        currentTime: now,
      );

      final monthCells = monthly.heatmapCells.where((c) => !c.isPadding).toList();
      expect(monthCells.length, 30); // November has 30 days
      expect(monthCells.every((c) => c.date.month == 11), isTrue);

      final todayCell = monthCells.firstWhere((c) => c.isCurrentDay);
      expect(todayCell.date.day, 8);
    });

    test('Actual logged days are highlighted with meal counts and empty days have 0', () {
      final now = DateTime(2026, 11, 8, 12, 0, 0);

      final weekly = ProgressDataService.computeAnalytics(
        period: 'Week',
        liveNutrition: _createNutrition(cals: 500, protein: 25, carbs: 60, fat: 15),
        liveMeals: const [],
        loggedMealsHistory: [
          {
            'calories': 500,
            'protein': 25,
            'carbs': 60,
            'fat': 15,
            'timestamp': DateTime(2026, 11, 8, 12, 0, 0),
          },
        ],
        currentTime: now,
      );

      // Sunday (index 6) has 1 meal -> level 1
      expect(weekly.heatmapCells[6].mealCount, 1);
      expect(weekly.heatmapCells[6].level, 1);

      // Monday (index 0) has 0 meals -> level 0
      expect(weekly.heatmapCells[0].mealCount, 0);
      expect(weekly.heatmapCells[0].level, 0);
    });
  });

  group('6. Week/Month Switching Tests', () {
    test('Switching between Week and Month updates period without stale data', () {
      final now = DateTime(2026, 11, 8, 12, 0, 0);
      final history = [
        {
          'calories': 400,
          'protein': 20,
          'carbs': 40,
          'fat': 10,
          'timestamp': DateTime(2026, 11, 8, 10, 0, 0),
        },
      ];

      final weekAnalytics = ProgressDataService.computeAnalytics(
        period: 'Week',
        liveNutrition: _createNutrition(cals: 400, protein: 20, carbs: 40, fat: 10),
        liveMeals: const [],
        loggedMealsHistory: history,
        currentTime: now,
      );
      expect(weekAnalytics.period, 'Week');
      expect(weekAnalytics.daySummaries.length, 7);

      final monthAnalytics = ProgressDataService.computeAnalytics(
        period: 'Month',
        liveNutrition: _createNutrition(cals: 400, protein: 20, carbs: 40, fat: 10),
        liveMeals: const [],
        loggedMealsHistory: history,
        currentTime: now,
      );
      expect(monthAnalytics.period, 'Month');
      expect(monthAnalytics.daySummaries.length, 5);
      expect(monthAnalytics.daySummaries[1].isToday, isTrue); // Week 2
    });
  });
}
