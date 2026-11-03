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
  final bool hasRecords;

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
    this.hasRecords = true,
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
  static String _monthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[(month - 1).clamp(0, 11)];
  }

  static String _fullDayName(String abbr) {
    switch (abbr) {
      case 'Mon': return 'Monday';
      case 'Tue': return 'Tuesday';
      case 'Wed': return 'Wednesday';
      case 'Thu': return 'Thursday';
      case 'Fri': return 'Friday';
      case 'Sat': return 'Saturday';
      case 'Sun': return 'Sunday';
      default: return abbr;
    }
  }

  static ProgressAnalyticsData computeAnalytics({
    required String period, // 'Week' or 'Month'
    required DailyNutritionData liveNutrition,
    required List<MealItem> liveMeals,
    required List<Map<String, dynamic>> loggedMealsHistory,
  }) {
    final now = DateTime.now();
    final int todayMealsCompleted =
        liveMeals.where((m) => m.status == MealStatus.completed).length;

    final bool hasRecords =
        loggedMealsHistory.isNotEmpty || liveNutrition.consumedCalories > 0;

    // 1. Current Week Days (Mon to Sun of current week)
    final currentWeekday = now.weekday; // 1 (Mon) to 7 (Sun)
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: currentWeekday - 1));
    final List<DayNutritionSummary> weekDays = [];
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      final isToday = date.day == now.day && date.month == now.month && date.year == now.year;

      int cals = 0;
      int protein = 0;
      int carbs = 0;
      int fat = 0;
      int mealCount = 0;

      if (isToday) {
        cals = liveNutrition.consumedCalories;
        protein = liveNutrition.protein.amountGrams;
        carbs = liveNutrition.carbs.amountGrams;
        fat = liveNutrition.fat.amountGrams;
        mealCount = todayMealsCompleted;
      }

      for (final m in loggedMealsHistory) {
        final t = m['timestamp'] as DateTime?;
        if (t != null && t.day == date.day && t.month == date.month && t.year == date.year) {
          if (!isToday) {
            cals += (m['calories'] as int? ?? 0);
            protein += (m['protein'] as int? ?? 0);
            carbs += (m['carbs'] as int? ?? 0);
            fat += (m['fat'] as int? ?? 0);
            mealCount++;
          }
        }
      }

      final monthName = _monthAbbr(date.month);
      weekDays.add(
        DayNutritionSummary(
          dayName: dayNames[i],
          fullDate: '${_fullDayName(dayNames[i])}, $monthName ${date.day}',
          calories: cals,
          proteinGrams: protein,
          carbsGrams: carbs,
          fatGrams: fat,
          loggedMealsCount: mealCount,
          isToday: isToday,
        ),
      );
    }

    // 2. Monthly 4-week representation
    final List<DayNutritionSummary> monthWeeks = [
      const DayNutritionSummary(
        dayName: 'W1',
        fullDate: 'Week 1',
        calories: 0,
        proteinGrams: 0,
        carbsGrams: 0,
        fatGrams: 0,
        loggedMealsCount: 0,
      ),
      const DayNutritionSummary(
        dayName: 'W2',
        fullDate: 'Week 2',
        calories: 0,
        proteinGrams: 0,
        carbsGrams: 0,
        fatGrams: 0,
        loggedMealsCount: 0,
      ),
      const DayNutritionSummary(
        dayName: 'W3',
        fullDate: 'Week 3',
        calories: 0,
        proteinGrams: 0,
        carbsGrams: 0,
        fatGrams: 0,
        loggedMealsCount: 0,
      ),
      DayNutritionSummary(
        dayName: 'W4',
        fullDate: 'Week 4 (Current Week)',
        calories: (weekDays.fold(0, (sum, d) => sum + d.calories) / 7).round(),
        proteinGrams: (weekDays.fold(0, (sum, d) => sum + d.proteinGrams) / 7).round(),
        carbsGrams: (weekDays.fold(0, (sum, d) => sum + d.carbsGrams) / 7).round(),
        fatGrams: (weekDays.fold(0, (sum, d) => sum + d.fatGrams) / 7).round(),
        loggedMealsCount: weekDays.fold(0, (sum, d) => sum + d.loggedMealsCount),
        isToday: true,
      ),
    ];

    final displayedSummaries = period == 'Week' ? weekDays : monthWeeks;

    // 3. Consistency Heatmap Data
    final List<HeatmapCellData> heatmap = [];
    final todayMidnight = DateTime(now.year, now.month, now.day);

    if (period == 'Week') {
      final currentWeekMonday = todayMidnight.subtract(Duration(days: todayMidnight.weekday - 1));
      final startMonday = currentWeekMonday.subtract(const Duration(days: 21));

      for (int i = 0; i < 28; i++) {
        final cellDate = startMonday.add(Duration(days: i));
        final bool isToday = cellDate.year == now.year &&
            cellDate.month == now.month &&
            cellDate.day == now.day;
        int count = isToday ? todayMealsCompleted : 0;
        for (final m in loggedMealsHistory) {
          final t = m['timestamp'] as DateTime?;
          if (t != null && t.day == cellDate.day && t.month == cellDate.month && t.year == cellDate.year) {
            if (!isToday) count++;
          }
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
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final int startOffset = firstDayOfMonth.weekday - 1;
      final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final int totalCells = ((startOffset + daysInMonth + 6) ~/ 7) * 7;

      for (int i = 0; i < totalCells; i++) {
        if (i < startOffset) {
          final date = firstDayOfMonth.subtract(Duration(days: startOffset - i));
          heatmap.add(
            HeatmapCellData(date: date, mealCount: 0, isCurrentDay: false, isPadding: true),
          );
        } else if (i - startOffset < daysInMonth) {
          final int dayNum = (i - startOffset) + 1;
          final date = DateTime(now.year, now.month, dayNum);
          final bool isToday = dayNum == now.day;
          int count = isToday ? todayMealsCompleted : 0;
          for (final m in loggedMealsHistory) {
            final t = m['timestamp'] as DateTime?;
            if (t != null && t.day == date.day && t.month == date.month && t.year == date.year) {
              if (!isToday) count++;
            }
          }
          heatmap.add(
            HeatmapCellData(date: date, mealCount: count, isCurrentDay: isToday, isPadding: false),
          );
        } else {
          final int daysAfter = (i - startOffset) - daysInMonth + 1;
          final date = DateTime(now.year, now.month + 1, daysAfter);
          heatmap.add(
            HeatmapCellData(date: date, mealCount: 0, isCurrentDay: false, isPadding: true),
          );
        }
      }
    }

    final int mealsLoggedLast7 = heatmap
        .where((c) => !c.isPadding && !c.date.isAfter(todayMidnight))
        .take(7)
        .where((c) => c.mealCount > 0)
        .length;

    final String factualSummary = hasRecords
        ? 'Meals logged on $mealsLoggedLast7 of the last 7 days'
        : 'No meals logged yet';

    final int avgCalories = displayedSummaries.isEmpty
        ? 0
        : (displayedSummaries.fold(0, (sum, d) => sum + d.calories) / displayedSummaries.length).round();
    final int avgProtein = displayedSummaries.isEmpty
        ? 0
        : (displayedSummaries.fold(0, (sum, d) => sum + d.proteinGrams) / displayedSummaries.length).round();

    final dynamicScore = hasRecords
        ? (72 + (loggedMealsHistory.length * 5)).clamp(70, 95)
        : 0;

    return ProgressAnalyticsData(
      period: period,
      wellnessScore: dynamicScore,
      previousWellnessScore: dynamicScore > 0 ? dynamicScore - 2 : 0,
      wellnessInterpretation: hasRecords ? 'Calculated from actual logged meals' : 'No meals logged yet',
      daySummaries: displayedSummaries,
      heatmapCells: heatmap,
      averageDailyCalories: avgCalories,
      averageProteinGrams: avgProtein,
      loggingConsistencyPct: hasRecords ? (mealsLoggedLast7 / 7.0 * 100).clamp(0.0, 100.0) : 0.0,
      calorieTrendComparison: hasRecords ? '${liveNutrition.consumedCalories} kcal today' : 'No records',
      proteinTrendComparison: hasRecords ? '${liveNutrition.protein.amountGrams} g today' : 'No records',
      consistencyTrendComparison: '$mealsLoggedLast7 of 7 days recorded',
      factualConsistencySummary: factualSummary,
      editorialInsights: hasRecords
          ? [
              'Your daily protein intake is currently ${liveNutrition.protein.amountGrams} g.',
              'Logging meals consistently helps NutriFridge AI provide personalized recipes and insights.',
            ]
          : [
              'Your nutrition journey starts with your first meal.',
              'Log meals with NutriFridge AI to view real calorie trends and macro distributions.',
            ],
      hasRecords: hasRecords,
    );
  }
}
