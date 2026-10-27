import '../../../models/nutrition_data.dart';

/// Represents a single day's nutrition summary for charts and trends.
class DayNutritionSummary {
  final String dayName; // 'Mon', 'Tue', etc.
  final String fullDate; // 'Mon, Oct 26'
  final int calories;
  final int targetCalories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final int loggedMealsCount;
  final bool isToday;

  const DayNutritionSummary({
    required this.dayName,
    required this.fullDate,
    required this.calories,
    this.targetCalories = 2200,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.loggedMealsCount,
    this.isToday = false,
  });

  /// Macro calorie calculations (Protein 4 kcal/g, Carbs 4 kcal/g, Fat 9 kcal/g)
  int get proteinCalories => proteinGrams * 4;
  int get carbsCalories => carbsGrams * 4;
  int get fatCalories => fatGrams * 9;
  int get totalMacroCalories => proteinCalories + carbsCalories + fatCalories;

  double get proteinCaloriePct =>
      totalMacroCalories > 0 ? (proteinCalories / totalMacroCalories) * 100 : 0.0;
  double get carbsCaloriePct =>
      totalMacroCalories > 0 ? (carbsCalories / totalMacroCalories) * 100 : 0.0;
  double get fatCaloriePct =>
      totalMacroCalories > 0 ? (fatCalories / totalMacroCalories) * 100 : 0.0;
}

/// Represents a single cell in the consistency heatmap
class HeatmapCellData {
  final DateTime date;
  final int mealCount; // 0, 1, 2, 3+
  final bool isCurrentDay;
  final bool isPadding;

  const HeatmapCellData({
    required this.date,
    required this.mealCount,
    this.isCurrentDay = false,
    this.isPadding = false,
  });

  int get level {
    if (isPadding || mealCount <= 0) return 0;
    if (mealCount == 1) return 1;
    if (mealCount == 2) return 2;
    return 3;
  }
}

/// Aggregated nutrition progress data for Week or Month periods
class ProgressAnalyticsData {
  final String period; // 'Week' or 'Month'
  final int wellnessScore;
  final int previousWellnessScore;
  final String wellnessInterpretation;
  final List<DayNutritionSummary> daySummaries;
  final List<HeatmapCellData> heatmapCells;
  final int averageDailyCalories;
  final int averageProteinGrams;
  final double loggingConsistencyPct;
  final String calorieTrendComparison;
  final String proteinTrendComparison;
  final String consistencyTrendComparison;
  final String factualConsistencySummary;
  final List<String> editorialInsights;

  const ProgressAnalyticsData({
    required this.period,
    required this.wellnessScore,
    required this.previousWellnessScore,
    required this.wellnessInterpretation,
    required this.daySummaries,
    required this.heatmapCells,
    required this.averageDailyCalories,
    required this.averageProteinGrams,
    required this.loggingConsistencyPct,
    required this.calorieTrendComparison,
    required this.proteinTrendComparison,
    required this.consistencyTrendComparison,
    required this.factualConsistencySummary,
    required this.editorialInsights,
  });

  /// Overall macro totals across the period
  int get totalProteinCalories =>
      daySummaries.fold(0, (sum, d) => sum + d.proteinCalories);
  int get totalCarbsCalories =>
      daySummaries.fold(0, (sum, d) => sum + d.carbsCalories);
  int get totalFatCalories =>
      daySummaries.fold(0, (sum, d) => sum + d.fatCalories);
  int get grandMacroCalories =>
      totalProteinCalories + totalCarbsCalories + totalFatCalories;

  double get overallProteinPct =>
      grandMacroCalories > 0 ? (totalProteinCalories / grandMacroCalories) * 100 : 0.0;
  double get overallCarbsPct =>
      grandMacroCalories > 0 ? (totalCarbsCalories / grandMacroCalories) * 100 : 0.0;
  double get overallFatPct =>
      grandMacroCalories > 0 ? (totalFatCalories / grandMacroCalories) * 100 : 0.0;

  int get totalProteinGrams =>
      daySummaries.fold(0, (sum, d) => sum + d.proteinGrams);
  int get totalCarbsGrams =>
      daySummaries.fold(0, (sum, d) => sum + d.carbsGrams);
  int get totalFatGrams =>
      daySummaries.fold(0, (sum, d) => sum + d.fatGrams);
}

/// Helper service to generate progress analytics combining real live session data
/// from [MockDataRepository] with contextual baseline history.
class ProgressDataService {
  static ProgressAnalyticsData computeAnalytics({
    required String period, // 'Week' or 'Month'
    required DailyNutritionData liveNutrition,
    required List<MealItem> liveMeals,
    required List<Map<String, dynamic>> loggedMealsHistory,
  }) {
    final now = DateTime.now();
    final int todayMealsCompleted =
        liveMeals.where((m) => m.status == MealStatus.completed).length;

    // 1. Weekly Days (Mon to Sun)
    final List<DayNutritionSummary> weekDays = [
      const DayNutritionSummary(
        dayName: 'Mon',
        fullDate: 'Monday, Oct 20',
        calories: 1980,
        proteinGrams: 82,
        carbsGrams: 230,
        fatGrams: 64,
        loggedMealsCount: 3,
      ),
      DayNutritionSummary(
        dayName: 'Tue',
        fullDate: 'Tuesday, Oct 21',
        calories: liveNutrition.consumedCalories,
        proteinGrams: liveNutrition.protein.amountGrams,
        carbsGrams: liveNutrition.carbs.amountGrams,
        fatGrams: liveNutrition.fat.amountGrams,
        loggedMealsCount: todayMealsCompleted,
        isToday: true,
      ),
      const DayNutritionSummary(
        dayName: 'Wed',
        fullDate: 'Wednesday, Oct 22',
        calories: 2050,
        proteinGrams: 88,
        carbsGrams: 240,
        fatGrams: 68,
        loggedMealsCount: 3,
      ),
      const DayNutritionSummary(
        dayName: 'Thu',
        fullDate: 'Thursday, Oct 23',
        calories: 2180,
        proteinGrams: 90,
        carbsGrams: 255,
        fatGrams: 72,
        loggedMealsCount: 4,
      ),
      const DayNutritionSummary(
        dayName: 'Fri',
        fullDate: 'Friday, Oct 24',
        calories: 1940,
        proteinGrams: 78,
        carbsGrams: 220,
        fatGrams: 65,
        loggedMealsCount: 3,
      ),
      const DayNutritionSummary(
        dayName: 'Sat',
        fullDate: 'Saturday, Oct 25',
        calories: 2260,
        proteinGrams: 94,
        carbsGrams: 270,
        fatGrams: 74,
        loggedMealsCount: 3,
      ),
      const DayNutritionSummary(
        dayName: 'Sun',
        fullDate: 'Sunday, Oct 26',
        calories: 2110,
        proteinGrams: 86,
        carbsGrams: 245,
        fatGrams: 70,
        loggedMealsCount: 3,
      ),
    ];

    // 2. Monthly Weeks (Weeks 1 to 4)
    final List<DayNutritionSummary> monthWeeks = [
      const DayNutritionSummary(
        dayName: 'W1',
        fullDate: 'Week 1 (Oct 1–7)',
        calories: 2040,
        proteinGrams: 84,
        carbsGrams: 240,
        fatGrams: 68,
        loggedMealsCount: 20,
      ),
      const DayNutritionSummary(
        dayName: 'W2',
        fullDate: 'Week 2 (Oct 8–14)',
        calories: 2120,
        proteinGrams: 89,
        carbsGrams: 248,
        fatGrams: 71,
        loggedMealsCount: 22,
      ),
      const DayNutritionSummary(
        dayName: 'W3',
        fullDate: 'Week 3 (Oct 15–21)',
        calories: 2090,
        proteinGrams: 87,
        carbsGrams: 242,
        fatGrams: 69,
        loggedMealsCount: 21,
      ),
      DayNutritionSummary(
        dayName: 'W4',
        fullDate: 'Week 4 (Current Week)',
        calories: ((1980 + liveNutrition.consumedCalories + 2050 + 2180 + 1940 + 2260 + 2110) / 7).round(),
        proteinGrams: ((82 + liveNutrition.protein.amountGrams + 88 + 90 + 78 + 94 + 86) / 7).round(),
        carbsGrams: ((230 + liveNutrition.carbs.amountGrams + 240 + 255 + 220 + 270 + 245) / 7).round(),
        fatGrams: ((64 + liveNutrition.fat.amountGrams + 68 + 72 + 65 + 74 + 70) / 7).round(),
        loggedMealsCount: 19 + (todayMealsCompleted > 0 ? 1 : 0),
        isToday: true,
      ),
    ];

    final displayedSummaries = period == 'Week' ? weekDays : monthWeeks;

    // 3. Consistency Heatmap Data
    final List<HeatmapCellData> heatmap = [];
    final todayMidnight = DateTime(now.year, now.month, now.day);

    // Seed realistic baseline meal counts
    final List<int> baselineCounts = [
      3, 3, 2, 4, 3, 3, 2,
      3, 4, 3, 3, 2, 4, 3,
      3, 3, 4, 2, 3, 3, 3,
      4, 3, 3, 4, 3, 3, 4,
      3, 2, 4
    ];

    if (period == 'Week') {
      // 28 days: 4 weeks x 7 days (Mon to Sun)
      // Row 3 ends on this week's Sunday
      final currentWeekMonday = todayMidnight.subtract(Duration(days: todayMidnight.weekday - 1));
      final startMonday = currentWeekMonday.subtract(const Duration(days: 21));

      for (int i = 0; i < 28; i++) {
        final cellDate = startMonday.add(Duration(days: i));
        final bool isToday = cellDate.year == now.year &&
            cellDate.month == now.month &&
            cellDate.day == now.day;
        final bool isFuture = cellDate.isAfter(todayMidnight);

        int count = 0;
        if (isToday) {
          count = todayMealsCompleted;
        } else if (isFuture) {
          count = 0;
        } else {
          count = baselineCounts[i % baselineCounts.length];
        }

        heatmap.add(
          HeatmapCellData(
            date: cellDate,
            mealCount: count,
            isCurrentDay: isToday,
            isPadding: false,
          ),
        );
      }
    } else {
      // Month view: Calendar month grid with 7 weekday columns (Mon..Sun)
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final int startOffset = firstDayOfMonth.weekday - 1; // 0 for Mon, 6 for Sun
      final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final int totalCells = ((startOffset + daysInMonth + 6) ~/ 7) * 7;

      for (int i = 0; i < totalCells; i++) {
        if (i < startOffset) {
          // Leading padding before 1st of month
          final date = firstDayOfMonth.subtract(Duration(days: startOffset - i));
          heatmap.add(
            HeatmapCellData(
              date: date,
              mealCount: 0,
              isCurrentDay: false,
              isPadding: true,
            ),
          );
        } else if (i - startOffset < daysInMonth) {
          final int dayNum = (i - startOffset) + 1;
          final date = DateTime(now.year, now.month, dayNum);
          final bool isToday = dayNum == now.day;
          final bool isFuture = dayNum > now.day;

          int count = 0;
          if (isToday) {
            count = todayMealsCompleted;
          } else if (isFuture) {
            count = 0;
          } else {
            count = baselineCounts[(dayNum - 1) % baselineCounts.length];
          }

          heatmap.add(
            HeatmapCellData(
              date: date,
              mealCount: count,
              isCurrentDay: isToday,
              isPadding: false,
            ),
          );
        } else {
          // Trailing padding after end of month
          final int daysAfter = (i - startOffset) - daysInMonth + 1;
          final date = DateTime(now.year, now.month + 1, daysAfter);
          heatmap.add(
            HeatmapCellData(
              date: date,
              mealCount: 0,
              isCurrentDay: false,
              isPadding: true,
            ),
          );
        }
      }
    }

    // Factual consistency summary calculated from actual last 7 recorded days
    final pastAndTodayCells = heatmap
        .where((c) => !c.isPadding && !c.date.isAfter(todayMidnight))
        .toList();
    final recent7 = pastAndTodayCells.length >= 7
        ? pastAndTodayCells.sublist(pastAndTodayCells.length - 7)
        : pastAndTodayCells;
    final int mealsLoggedLast7 = recent7.where((c) => c.mealCount > 0).length;
    final String factualSummary =
        'Meals logged on $mealsLoggedLast7 of the last 7 days';

    // 4. Calculations
    final int avgCalories = (displayedSummaries.fold(0, (sum, d) => sum + d.calories) / displayedSummaries.length).round();
    final int avgProtein = (displayedSummaries.fold(0, (sum, d) => sum + d.proteinGrams) / displayedSummaries.length).round();

    // Wellness score derived from adherence to target
    final double adherence = (liveNutrition.consumedCalories / liveNutrition.targetCalories).clamp(0.0, 1.2);
    int dynamicScore = 82;
    if (adherence >= 0.85 && adherence <= 1.05) {
      dynamicScore = 86;
    } else if (adherence > 1.05) {
      dynamicScore = 80;
    } else if (adherence < 0.70) {
      dynamicScore = 78;
    }

    String interpretation = 'Optimal balance';
    if (dynamicScore >= 85) {
      interpretation = 'Excellent adherence to targets';
    } else if (dynamicScore >= 80) {
      interpretation = 'Steady, balanced intake';
    } else {
      interpretation = 'Below target daily intake';
    }

    return ProgressAnalyticsData(
      period: period,
      wellnessScore: dynamicScore,
      previousWellnessScore: 78,
      wellnessInterpretation: interpretation,
      daySummaries: displayedSummaries,
      heatmapCells: heatmap,
      averageDailyCalories: avgCalories,
      averageProteinGrams: avgProtein,
      loggingConsistencyPct: 92.0,
      calorieTrendComparison: '+2.4% vs previous $period',
      proteinTrendComparison: '+4.1 g/day vs previous $period',
      consistencyTrendComparison: '26 of 28 days recorded',
      factualConsistencySummary: factualSummary,
      editorialInsights: [
        'Your daily protein intake averaged $avgProtein g, providing consistent support for your wellness goals.',
        'Logging was recorded for ${period == 'Week' ? 'all 7 days' : '26 days this month'}, establishing steady nutritional awareness.',
      ],
    );
  }
}
