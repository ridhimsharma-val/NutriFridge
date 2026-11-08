import '../../../core/utils/date_range_utils.dart';
import '../../../models/nutrition_data.dart';

/// Represents a single day's (or week segment's) nutrition summary for charts and trends.
class DayNutritionSummary {
  final String dayName; // 'Mon', 'Tue', etc. or 'W1', 'W2', etc.
  final String fullDate; // 'Mon, Oct 26' or 'Week 2 (Current Week) • Nov 8–14'
  final int calories;
  final int targetCalories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final int loggedMealsCount;
  final bool isToday;
  final DateTime? date;

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
    this.date,
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
  final int? previousWellnessScore;
  final String wellnessInterpretation;
  final List<DayNutritionSummary> daySummaries;
  final List<HeatmapCellData> heatmapCells;
  final int averageDailyCalories;
  final int averageProteinGrams;
  final int averageCarbsGrams;
  final int averageFatGrams;
  final int macroChartProteinGrams;
  final int macroChartCarbsGrams;
  final int macroChartFatGrams;
  final int macroChartCalories;
  final int totalPeriodMealsCount;
  final int targetCalories;
  final bool hasRecords;

  const ProgressAnalyticsData({
    required this.period,
    required this.wellnessScore,
    this.previousWellnessScore,
    this.wellnessInterpretation = '',
    required this.daySummaries,
    required this.heatmapCells,
    required this.averageDailyCalories,
    required this.averageProteinGrams,
    required this.averageCarbsGrams,
    required this.averageFatGrams,
    required this.macroChartProteinGrams,
    required this.macroChartCarbsGrams,
    required this.macroChartFatGrams,
    required this.macroChartCalories,
    required this.totalPeriodMealsCount,
    required this.targetCalories,
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

/// Helper service to generate progress analytics from genuine user nutrition data.
class ProgressDataService {
  static String _monthAbbr(int month) {
    return DateRangeUtils.getMonthAbbr(month);
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
    DateTime? currentTime,
    int? targetCalories,
  }) {
    final now = (currentTime ?? MockDataRepository.currentTimeProvider()).toLocal();
    final effectiveTarget = targetCalories ??
        MockDataRepository.profile.dailyCalorieTarget ??
        liveNutrition.targetCalories;

    // Check account-level records to decide between empty onboarding state and period data
    final bool hasAccountRecords =
        loggedMealsHistory.isNotEmpty || liveNutrition.consumedCalories > 0;

    if (period == 'Week') {
      return _computeWeeklyAnalytics(
        now: now,
        liveNutrition: liveNutrition,
        liveMeals: liveMeals,
        loggedMealsHistory: loggedMealsHistory,
        effectiveTarget: effectiveTarget,
        hasAccountRecords: hasAccountRecords,
      );
    } else {
      return _computeMonthlyAnalytics(
        now: now,
        liveNutrition: liveNutrition,
        liveMeals: liveMeals,
        loggedMealsHistory: loggedMealsHistory,
        effectiveTarget: effectiveTarget,
        hasAccountRecords: hasAccountRecords,
      );
    }
  }

  static ProgressAnalyticsData _computeWeeklyAnalytics({
    required DateTime now,
    required DailyNutritionData liveNutrition,
    required List<MealItem> liveMeals,
    required List<Map<String, dynamic>> loggedMealsHistory,
    required int effectiveTarget,
    required bool hasAccountRecords,
  }) {
    final weekRange = DateRangeUtils.getCurrentWeekRange(now);
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final List<DayNutritionSummary> weekDays = [];

    int weeklyTotalCals = 0;
    int weeklyTotalProtein = 0;
    int weeklyTotalCarbs = 0;
    int weeklyTotalFat = 0;
    int weeklyTotalMeals = 0;

    for (int i = 0; i < 7; i++) {
      final date = weekRange.days[i];
      final isToday = date.day == now.day && date.month == now.month && date.year == now.year;

      int dayCals = 0;
      int dayProtein = 0;
      int dayCarbs = 0;
      int dayFat = 0;
      int dayMealCount = 0;

      for (final m in loggedMealsHistory) {
        final rawTs = m['timestamp'];
        final t = rawTs is DateTime ? rawTs.toLocal() : null;
        if (t != null && t.day == date.day && t.month == date.month && t.year == date.year) {
          dayCals += (m['calories'] as num? ?? 0).toInt();
          dayProtein += (m['protein'] as num? ?? 0).toInt();
          dayCarbs += (m['carbs'] as num? ?? 0).toInt();
          dayFat += (m['fat'] as num? ?? 0).toInt();
          dayMealCount++;
        }
      }

      // If today has live snapshot data and no history records matched yet
      if (isToday && dayMealCount == 0 && liveNutrition.consumedCalories > 0) {
        dayCals = liveNutrition.consumedCalories;
        dayProtein = liveNutrition.protein.amountGrams;
        dayCarbs = liveNutrition.carbs.amountGrams;
        dayFat = liveNutrition.fat.amountGrams;
        dayMealCount = liveMeals.where((m) => m.status == MealStatus.completed).length;
        if (dayMealCount == 0 && dayCals > 0) dayMealCount = 1;
      }

      weeklyTotalCals += dayCals;
      weeklyTotalProtein += dayProtein;
      weeklyTotalCarbs += dayCarbs;
      weeklyTotalFat += dayFat;
      weeklyTotalMeals += dayMealCount;

      final monthName = _monthAbbr(date.month);
      weekDays.add(
        DayNutritionSummary(
          dayName: dayNames[i],
          fullDate: '${_fullDayName(dayNames[i])}, $monthName ${date.day}',
          calories: dayCals,
          targetCalories: effectiveTarget,
          proteinGrams: dayProtein,
          carbsGrams: dayCarbs,
          fatGrams: dayFat,
          loggedMealsCount: dayMealCount,
          isToday: isToday,
          date: date,
        ),
      );
    }

    // Weekly consistency heatmap: 7 days of the current week (Section 10 requirement)
    final List<HeatmapCellData> heatmap = weekDays.map((d) {
      return HeatmapCellData(
        date: d.date ?? now,
        mealCount: d.loggedMealsCount,
        isCurrentDay: d.isToday,
        isPadding: false,
      );
    }).toList();

    // Wellness Score: 0/100 if no meals in this period; else (72 + meals * 5).clamp(70, 95)
    final int wellnessScore = weeklyTotalMeals > 0
        ? (72 + (weeklyTotalMeals * 5)).clamp(70, 95)
        : 0;

    // Macro distribution for Week: daily average across the 7 days of the week
    final int avgProtein = (weeklyTotalProtein / 7).round();
    final int avgCarbs = (weeklyTotalCarbs / 7).round();
    final int avgFat = (weeklyTotalFat / 7).round();
    // Mathematically consistent center calories from 4 kcal/g and 9 kcal/g
    final int macroCenterCals = (avgProtein * 4) + (avgCarbs * 4) + (avgFat * 9);
    final int avgDailyCals = (weeklyTotalCals / 7).round();

    return ProgressAnalyticsData(
      period: 'Week',
      wellnessScore: wellnessScore,
      previousWellnessScore: null,
      daySummaries: weekDays,
      heatmapCells: heatmap,
      averageDailyCalories: avgDailyCals,
      averageProteinGrams: avgProtein,
      averageCarbsGrams: avgCarbs,
      averageFatGrams: avgFat,
      macroChartProteinGrams: avgProtein,
      macroChartCarbsGrams: avgCarbs,
      macroChartFatGrams: avgFat,
      macroChartCalories: macroCenterCals,
      totalPeriodMealsCount: weeklyTotalMeals,
      targetCalories: effectiveTarget,
      hasRecords: hasAccountRecords,
    );
  }

  static ProgressAnalyticsData _computeMonthlyAnalytics({
    required DateTime now,
    required DailyNutritionData liveNutrition,
    required List<MealItem> liveMeals,
    required List<Map<String, dynamic>> loggedMealsHistory,
    required int effectiveTarget,
    required bool hasAccountRecords,
  }) {
    final monthRange = DateRangeUtils.getCalendarMonthRange(now);
    final segments = DateRangeUtils.getMonthWeekSegments(now);
    final List<DayNutritionSummary> monthWeeks = [];

    int monthlyTotalCals = 0;
    int monthlyTotalProtein = 0;
    int monthlyTotalCarbs = 0;
    int monthlyTotalFat = 0;
    int monthlyTotalMeals = 0;

    for (final seg in segments) {
      final isCurrent = seg.isCurrentWeek(now);
      final isFuture = seg.isFutureWeek(now);

      int segCals = 0;
      int segProtein = 0;
      int segCarbs = 0;
      int segFat = 0;
      int segMealCount = 0;

      if (!isFuture) {
        for (final m in loggedMealsHistory) {
          final rawTs = m['timestamp'];
          final t = rawTs is DateTime ? rawTs.toLocal() : null;
          if (t != null &&
              t.year == monthRange.year &&
              t.month == monthRange.month &&
              t.day >= seg.startDay &&
              t.day <= seg.endDay) {
            segCals += (m['calories'] as num? ?? 0).toInt();
            segProtein += (m['protein'] as num? ?? 0).toInt();
            segCarbs += (m['carbs'] as num? ?? 0).toInt();
            segFat += (m['fat'] as num? ?? 0).toInt();
            segMealCount++;
          }
        }

        // If today is in this segment and has live snapshot data
        if (isCurrent && segMealCount == 0 && liveNutrition.consumedCalories > 0) {
          segCals += liveNutrition.consumedCalories;
          segProtein += liveNutrition.protein.amountGrams;
          segCarbs += liveNutrition.carbs.amountGrams;
          segFat += liveNutrition.fat.amountGrams;
          final todayDone = liveMeals.where((m) => m.status == MealStatus.completed).length;
          segMealCount += todayDone > 0 ? todayDone : 1;
        }
      }

      monthlyTotalCals += segCals;
      monthlyTotalProtein += segProtein;
      monthlyTotalCarbs += segCarbs;
      monthlyTotalFat += segFat;
      monthlyTotalMeals += segMealCount;

      // Weekly average calories in that segment
      final int elapsedDaysInSeg = seg.elapsedDays(now);
      final int divisor = elapsedDaysInSeg > 0 ? elapsedDaysInSeg : seg.totalDaysInSegment;
      final int avgCals = segCals == 0 ? 0 : (segCals / divisor).round();
      final int avgProtein = segProtein == 0 ? 0 : (segProtein / divisor).round();
      final int avgCarbs = segCarbs == 0 ? 0 : (segCarbs / divisor).round();
      final int avgFat = segFat == 0 ? 0 : (segFat / divisor).round();

      final fullDateLabel = isCurrent
          ? 'Week ${seg.weekNumber} (Current Week) • ${seg.dateRangeLabel}'
          : 'Week ${seg.weekNumber} (${seg.dateRangeLabel})';

      monthWeeks.add(
        DayNutritionSummary(
          dayName: 'W${seg.weekNumber}',
          fullDate: fullDateLabel,
          calories: avgCals,
          targetCalories: effectiveTarget,
          proteinGrams: avgProtein,
          carbsGrams: avgCarbs,
          fatGrams: avgFat,
          loggedMealsCount: segMealCount,
          isToday: isCurrent,
          date: seg.startDate,
        ),
      );
    }

    // Monthly consistency heatmap: actual days of this month with grid alignment
    final List<HeatmapCellData> heatmap = [];
    final firstDayOfMonth = DateTime(monthRange.year, monthRange.month, 1);
    final int startOffset = firstDayOfMonth.weekday - 1; // 0 = Mon, 6 = Sun
    final int daysInMonth = monthRange.daysInMonth;
    final int totalCells = ((startOffset + daysInMonth + 6) ~/ 7) * 7;

    for (int i = 0; i < totalCells; i++) {
      if (i < startOffset) {
        final date = firstDayOfMonth.subtract(Duration(days: startOffset - i));
        heatmap.add(
          HeatmapCellData(date: date, mealCount: 0, isCurrentDay: false, isPadding: true),
        );
      } else if (i - startOffset < daysInMonth) {
        final int dayNum = (i - startOffset) + 1;
        final date = DateTime(monthRange.year, monthRange.month, dayNum);
        final bool isToday = dayNum == now.day &&
            monthRange.year == now.year &&
            monthRange.month == now.month;

        int count = 0;
        for (final m in loggedMealsHistory) {
          final rawTs = m['timestamp'];
          final t = rawTs is DateTime ? rawTs.toLocal() : null;
          if (t != null && t.day == date.day && t.month == date.month && t.year == date.year) {
            count++;
          }
        }

        if (isToday && count == 0 && liveNutrition.consumedCalories > 0) {
          final todayDone = liveMeals.where((m) => m.status == MealStatus.completed).length;
          count = todayDone > 0 ? todayDone : 1;
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
        final int daysAfter = (i - startOffset) - daysInMonth + 1;
        final date = DateTime(monthRange.year, monthRange.month + 1, daysAfter);
        heatmap.add(
          HeatmapCellData(date: date, mealCount: 0, isCurrentDay: false, isPadding: true),
        );
      }
    }

    // Monthly Wellness Score: 0/100 if no meals this month; else (72 + meals * 5).clamp(70, 95)
    final int wellnessScore = monthlyTotalMeals > 0
        ? (72 + (monthlyTotalMeals * 5)).clamp(70, 95)
        : 0;

    // Monthly Macro Donut Chart: daily average across the month
    final int daysElapsedInMonth = now.day.clamp(1, daysInMonth);
    final int avgProtein = (monthlyTotalProtein / daysElapsedInMonth).round();
    final int avgCarbs = (monthlyTotalCarbs / daysElapsedInMonth).round();
    final int avgFat = (monthlyTotalFat / daysElapsedInMonth).round();
    final int macroCenterCals = (avgProtein * 4) + (avgCarbs * 4) + (avgFat * 9);
    final int avgDailyCals = (monthlyTotalCals / daysElapsedInMonth).round();

    return ProgressAnalyticsData(
      period: 'Month',
      wellnessScore: wellnessScore,
      previousWellnessScore: null,
      daySummaries: monthWeeks,
      heatmapCells: heatmap,
      averageDailyCalories: avgDailyCals,
      averageProteinGrams: avgProtein,
      averageCarbsGrams: avgCarbs,
      averageFatGrams: avgFat,
      macroChartProteinGrams: avgProtein,
      macroChartCarbsGrams: avgCarbs,
      macroChartFatGrams: avgFat,
      macroChartCalories: macroCenterCals,
      totalPeriodMealsCount: monthlyTotalMeals,
      targetCalories: effectiveTarget,
      hasRecords: hasAccountRecords,
    );
  }
}
