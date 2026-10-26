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

  const HeatmapCellData({
    required this.date,
    required this.mealCount,
    this.isCurrentDay = false,
  });

  int get level {
    if (mealCount <= 0) return 0;
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

    // 3. Consistency Heatmap (28 days: 4 weeks x 7 days)
    final List<HeatmapCellData> heatmap = [];
    final startDate = now.subtract(const Duration(days: 27));

    // Seed baseline meal counts for past 27 days
    final List<int> baselineCounts = [
      3, 3, 2, 4, 3, 3, 2,
      3, 4, 3, 3, 2, 4, 3,
      3, 3, 4, 2, 3, 3, 3,
      4, 3, 3, 4, 3, 3
    ];

    for (int i = 0; i < 27; i++) {
      heatmap.add(
        HeatmapCellData(
          date: startDate.add(Duration(days: i)),
          mealCount: baselineCounts[i],
          isCurrentDay: false,
        ),
      );
    }
    // 28th day is today, dynamically using live completed meals count
    heatmap.add(
      HeatmapCellData(
        date: now,
        mealCount: todayMealsCompleted,
        isCurrentDay: true,
      ),
    );

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
      editorialInsights: [
        'Your daily protein intake averaged $avgProtein g, providing consistent support for your wellness goals.',
        'Logging was recorded for ${period == 'Week' ? 'all 7 days' : '26 days this month'}, establishing steady nutritional awareness.',
      ],
    );
  }
}
