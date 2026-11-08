import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../models/progress_data.dart';

/// Cinematic Weekly Calorie Bar Chart
/// Displays 7-day or monthly week segment rounded calorie bars with a dynamic target reference line,
/// smooth animated entrance, and interactive day selection revealing macronutrient breakdown.
class WeeklyCaloriesChart extends StatefulWidget {
  final List<DayNutritionSummary> summaries;
  final String period; // 'Week' or 'Month'
  final int? targetCalories;

  const WeeklyCaloriesChart({
    super.key,
    required this.summaries,
    required this.period,
    this.targetCalories,
  });

  @override
  State<WeeklyCaloriesChart> createState() => _WeeklyCaloriesChartState();
}

class _WeeklyCaloriesChartState extends State<WeeklyCaloriesChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _barAnimation;
  int _selectedIndex = 0;

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

    _updateDefaultSelection();
  }

  void _updateDefaultSelection() {
    final todayIdx = widget.summaries.indexWhere((s) => s.isToday);
    _selectedIndex = todayIdx != -1 ? todayIdx : (widget.summaries.isNotEmpty ? 0 : 0);
  }

  @override
  void didUpdateWidget(covariant WeeklyCaloriesChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period ||
        oldWidget.summaries != widget.summaries) {
      _animController.forward(from: 0.0);
      setState(() {
        _updateDefaultSelection();
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _formatNumber(int number) {
    final str = number.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.summaries.isEmpty) {
      return const SizedBox.shrink();
    }

    final int targetCalories = widget.targetCalories ??
        (widget.summaries.isNotEmpty ? widget.summaries.first.targetCalories : 2200);
    final int maxCalorieScale = math.max(2600, ((targetCalories * 1.22) / 100).ceil() * 100);
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
                  color: AppColors.forestGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.period == 'Week'
                ? 'Tap any day to inspect that day’s macronutrients'
                : 'Tap any week to inspect that week’s macronutrients',
            style: AppTypography.subtitle.copyWith(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 22),

          // Main Bar Chart Area with Dynamic Target Guideline
          SizedBox(
            height: chartHeight,
            child: Stack(
              children: [
                // 1. Target Reference Line (Subtle hairline at exact proportion)
                Positioned(
                  top: (chartHeight * (1.0 - (targetCalories / maxCalorieScale))).clamp(8.0, chartHeight - 20.0),
                  left: 0,
                  right: 0,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1.2,
                          color: AppColors.forestGreen.withValues(alpha: 0.25),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatNumber(targetCalories),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.forestGreen.withValues(alpha: 0.7),
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
                        final double barHeightFactor = summary.calories > 0
                            ? ((summary.calories / maxCalorieScale) * _barAnimation.value).clamp(0.06, 1.0)
                            : 0.035;
                        final double barHeight = (barMaxHeight * barHeightFactor).clamp(5.0, barMaxHeight);

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
                                          color: AppColors.forestGreen,
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
                                                AppColors.forestGreen,
                                                AppColors.sageAccent,
                                              ],
                                            )
                                          : (summary.calories > 0
                                              ? LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    const Color(0xFFC7E2D8).withValues(alpha: 0.8),
                                                    const Color(0xFFE4F0EB).withValues(alpha: 0.6),
                                                  ],
                                                )
                                              : LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    const Color(0xFFE8EFEA).withValues(alpha: 0.4),
                                                    const Color(0xFFEFF5F1).withValues(alpha: 0.3),
                                                  ],
                                                )),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: AppColors.forestGreen
                                                    .withValues(alpha: 0.25),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Day / Week Label (Mon..Sun or W1..W5)
                                  Text(
                                    summary.dayName,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? AppColors.forestGreen
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

          // Selected Day / Week Macronutrient Summary Pill Card
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Container(
              key: ValueKey('${selectedDay.fullDate}_${selectedDay.calories}'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.peachCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.peachBorder,
                  width: 1.2,
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
                            color: AppColors.paleMint,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.period == 'Week' ? 'Today (Live)' : 'Current Week',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.forestGreen,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.period == 'Week'
                        ? '${selectedDay.calories} kcal • ${selectedDay.loggedMealsCount} meal${selectedDay.loggedMealsCount == 1 ? '' : 's'} logged'
                        : '${selectedDay.calories} kcal/day avg • ${selectedDay.loggedMealsCount} meal${selectedDay.loggedMealsCount == 1 ? '' : 's'} logged',
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
                      _buildMacroBadge('Protein', '${selectedDay.proteinGrams}g', AppColors.freshGreen),
                      _buildMacroBadge('Carbs', '${selectedDay.carbsGrams}g', AppColors.coralPeach),
                      _buildMacroBadge('Fat', '${selectedDay.fatGrams}g', AppColors.vibrantLime),
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
