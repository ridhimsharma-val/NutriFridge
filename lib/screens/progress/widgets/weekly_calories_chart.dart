import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../models/progress_data.dart';

/// Cinematic Weekly Calorie Bar Chart
/// Displays 7-day or 4-week rounded calorie bars with a target reference line,
/// smooth animated entrance, and interactive day selection revealing macronutrient breakdown.
class WeeklyCaloriesChart extends StatefulWidget {
  final List<DayNutritionSummary> summaries;
  final String period; // 'Week' or 'Month'

  const WeeklyCaloriesChart({
    super.key,
    required this.summaries,
    required this.period,
  });

  @override
  State<WeeklyCaloriesChart> createState() => _WeeklyCaloriesChartState();
}

class _WeeklyCaloriesChartState extends State<WeeklyCaloriesChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _barAnimation;
  int _selectedIndex = 1; // Default to today (Tuesday / current week)

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _barAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();

    // Default selected index to today if available
    final todayIdx = widget.summaries.indexWhere((s) => s.isToday);
    if (todayIdx != -1) {
      _selectedIndex = todayIdx;
    }
  }

  @override
  void didUpdateWidget(covariant WeeklyCaloriesChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period ||
        oldWidget.summaries != widget.summaries) {
      _animController.forward(from: 0.0);
      final todayIdx = widget.summaries.indexWhere((s) => s.isToday);
      setState(() {
        _selectedIndex = todayIdx != -1 ? todayIdx : 0;
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const int maxCalorieScale = 2600;
    const int targetCalories = 2200;
    const double chartHeight = 170.0;

    final selectedDay = (_selectedIndex >= 0 && _selectedIndex < widget.summaries.length)
        ? widget.summaries[_selectedIndex]
        : widget.summaries.first;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: const [AppColors.softShadow],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Heading
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.period == 'Week'
                      ? 'Calories through the week'
                      : 'Weekly averages this month',
                  style: AppTypography.cardTitle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Target: $targetCalories',
                style: AppTypography.subtitle.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.tealPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tap any day to inspect that day’s macronutrients',
            style: AppTypography.subtitle.copyWith(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 22),

          // Main Bar Chart Area with Target Guideline
          SizedBox(
            height: chartHeight,
            child: Stack(
              children: [
                // 1. Target Reference Line (Dashed / Subtle hairline)
                Positioned(
                  top: chartHeight * (1.0 - (targetCalories / maxCalorieScale)),
                  left: 0,
                  right: 0,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1.2,
                          color: AppColors.tealPrimary.withValues(alpha: 0.25),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '2,200',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.tealPrimary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Interactive Bars Row
                AnimatedBuilder(
                  animation: _barAnimation,
                  builder: (context, child) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(widget.summaries.length, (index) {
                        final summary = widget.summaries[index];
                        final bool isSelected = index == _selectedIndex;
                        final double barMaxHeight = chartHeight - 44.0;
                        final double barHeightFactor =
                            ((summary.calories / maxCalorieScale) * _barAnimation.value)
                                .clamp(0.08, 1.0);
                        final double barHeight = (barMaxHeight * barHeightFactor).clamp(6.0, barMaxHeight);

                        return Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedIndex = index;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Calorie number above bar for selected item
                                  if (isSelected)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        '${summary.calories}',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.tealPrimary,
                                        ),
                                      ),
                                    )
                                  else
                                    const SizedBox(height: 16),

                                  // Rounded Gradient Bar
                                  Container(
                                    height: barHeight,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(8),
                                        bottom: Radius.circular(4),
                                      ),
                                      gradient: isSelected
                                          ? const LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Color(0xFF2A8B74),
                                                Color(0xFF1B6A5A),
                                              ],
                                            )
                                          : LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                const Color(0xFFC7E2D8).withValues(alpha: 0.8),
                                                const Color(0xFFE4F0EB).withValues(alpha: 0.6),
                                              ],
                                            ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: AppColors.tealPrimary
                                                    .withValues(alpha: 0.25),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Day Label
                                  Text(
                                    summary.dayName,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? AppColors.tealPrimary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFF1F5F2)),
          const SizedBox(height: 14),

          // Selected Day Macronutrient Summary Pill Card
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Container(
              key: ValueKey('${selectedDay.fullDate}_${selectedDay.calories}'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6FAF8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.tealPrimary.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          selectedDay.fullDate,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (selectedDay.isToday) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.tealLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Today (Live)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.tealPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${selectedDay.calories} kcal • ${selectedDay.loggedMealsCount} meals logged',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildMacroBadge('Protein', '${selectedDay.proteinGrams}g', const Color(0xFF2A8B74)),
                      _buildMacroBadge('Carbs', '${selectedDay.carbsGrams}g', const Color(0xFFE07854)),
                      _buildMacroBadge('Fat', '${selectedDay.fatGrams}g', const Color(0xFFD4A343)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
