import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/nutrition_data.dart';

/// Redesigned Daily Nutrition Card featuring:
/// - Prominent circular calorie progress visualization inspired by reference design
/// - Compact macronutrient cards for Protein, Carbs, and Fat
/// - Expandable detailed meal and nutrient breakdown
/// - Clean zero-consumption state and over-target handling
class NutritionCard extends StatelessWidget {
  final DailyNutritionData nutritionData;
  final bool isExpanded;
  final VoidCallback? onToggle;

  const NutritionCard({
    super.key,
    required this.nutritionData,
    this.isExpanded = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final consumed = nutritionData.consumedCalories;
    final target = nutritionData.targetCalories;
    final calorieProgress = nutritionData.calorieProgress;
    final remaining = target - consumed;
    final isOver = remaining < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header (Tappable to expand/collapse)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onToggle,
                  child: Text(
                    'Nutrition Today',
                    style: AppTypography.sectionTitle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6.0,
                    vertical: 3.0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isExpanded ? 'Collapse' : 'See',
                        style: AppTypography.actionLink.copyWith(
                          color: AppColors.forestGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.forestGreen,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Main White Card with Calorie Ring & Compact Macro Cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.cardBorder,
                    width: 1.0,
                  ),
                  boxShadow: const [AppColors.softShadow],
                ),
                padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 18.0),
                child: Column(
                  children: [
                    // ==========================================
                    // 1. Prominent Calorie Ring Hero Display
                    // ==========================================
                    Center(
                      child: SizedBox(
                        width: 172,
                        height: 172,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Background Track & Calorie Arc
                            CustomPaint(
                              size: const Size(172, 172),
                              painter: _DashboardCalorieArcPainter(
                                progress: calorieProgress,
                                strokeWidth: 12.0,
                                trackColor: AppColors.neutralTrack,
                                progressColor: isOver
                                    ? AppColors.coralPeach
                                    : AppColors.freshGreen,
                              ),
                            ),
                            // Central Numerical Content
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Today',
                                      style: AppTypography.subtitle.copyWith(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    // Big Consumed Calorie Number
                                    Text(
                                      _formatNumber(consumed),
                                      style: AppTypography.calorieHeroNumber.copyWith(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.neutralCharcoal,
                                        letterSpacing: -0.8,
                                      ),
                                    ),
                                    Text(
                                      'kcal',
                                      style: AppTypography.subtitle.copyWith(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    // Goal / Remaining Subtitle
                                    Text(
                                      isOver
                                          ? '${_formatNumber(remaining.abs())} kcal over'
                                          : 'Goal ${_formatNumber(target)} kcal',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isOver
                                            ? AppColors.coralPeach
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==========================================
                    // 2. Three Compact Macronutrient Cards
                    // ==========================================
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactMacroCard(
                            label: 'Protein',
                            amount: nutritionData.protein.amountGrams,
                            target: nutritionData.protein.targetGrams,
                            progress: nutritionData.protein.progress,
                            accentColor: AppColors.freshGreen,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCompactMacroCard(
                            label: 'Carbs',
                            amount: nutritionData.carbs.amountGrams,
                            target: nutritionData.carbs.targetGrams,
                            progress: nutritionData.carbs.progress,
                            accentColor: AppColors.coralPeach,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCompactMacroCard(
                            label: 'Fat',
                            amount: nutritionData.fat.amountGrams,
                            target: nutritionData.fat.targetGrams,
                            progress: nutritionData.fat.progress,
                            accentColor: AppColors.vibrantLime,
                          ),
                        ),
                      ],
                    ),

                    // ==========================================
                    // 3. Animated Detailed Expansion
                    // ==========================================
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: isExpanded
                          ? _buildExpandedNutritionContent()
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactMacroCard({
    required String label,
    required int amount,
    required int target,
    required double progress,
    required Color accentColor,
  }) {
    final pctInt = (progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE8ECE9),
          width: 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label
          Text(
            label,
            style: AppTypography.subtitle.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          // Amount
          Text(
            '${amount}g',
            style: AppTypography.cardTitle.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.neutralCharcoal,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          // Percentage
          Text(
            '$pctInt%',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          // Mini Horizontal Progress Indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(
              height: 3.5,
              width: double.infinity,
              color: AppColors.neutralTrack,
              child: progress > 0
                  ? FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedNutritionContent() {
    final remainingCalories =
        nutritionData.targetCalories - nutritionData.consumedCalories;
    final isCalorieOver = remainingCalories < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Container(
          height: 1,
          color: const Color(0xFFF0F4F2),
        ),
        const SizedBox(height: 16),

        // Daily Calorie Summary Callout
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFF6FAF7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.forestGreen.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily calorie summary',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatNumber(nutritionData.consumedCalories)} of ${_formatNumber(nutritionData.targetCalories)} kcal',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isCalorieOver
                      ? const Color(0xFFFFF2EB)
                      : AppColors.sageLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isCalorieOver
                      ? '${_formatNumber(remainingCalories.abs())} kcal over'
                      : '${_formatNumber(remainingCalories)} kcal remaining',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isCalorieOver
                        ? AppColors.coralHighlight
                        : AppColors.forestGreen,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Meal-by-Meal Breakdown ("Today's meals")
        const Text(
          "Today's meals",
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),

        _buildMealBreakdownList(),

        const SizedBox(height: 18),

        // Target Progress & Remaining Bars
        const Text(
          'Target progress & remaining',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),

        _buildTargetProgressBar(
          label: 'Calories',
          consumed: nutritionData.consumedCalories,
          target: nutritionData.targetCalories,
          unit: 'kcal',
          accentColor: AppColors.forestGreen,
        ),
        const SizedBox(height: 9),
        _buildTargetProgressBar(
          label: 'Protein',
          consumed: nutritionData.protein.amountGrams,
          target: nutritionData.protein.targetGrams,
          unit: 'g',
          accentColor: AppColors.forestGreen,
        ),
        const SizedBox(height: 9),
        _buildTargetProgressBar(
          label: 'Carbohydrates',
          consumed: nutritionData.carbs.amountGrams,
          target: nutritionData.carbs.targetGrams,
          unit: 'g',
          accentColor: AppColors.coralHighlight,
        ),
        const SizedBox(height: 9),
        _buildTargetProgressBar(
          label: 'Fat',
          consumed: nutritionData.fat.amountGrams,
          target: nutritionData.fat.targetGrams,
          unit: 'g',
          accentColor: AppColors.amberPrimary,
        ),
      ],
    );
  }

  Widget _buildTargetProgressBar({
    required String label,
    required int consumed,
    required int target,
    required String unit,
    required Color accentColor,
  }) {
    final double progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    final int remaining = target - consumed;
    final bool isOver = remaining < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                isOver
                    ? '${_formatNumber(consumed)} / ${_formatNumber(target)} $unit (${_formatNumber(remaining.abs())} $unit over)'
                    : '${_formatNumber(consumed)} / ${_formatNumber(target)} $unit (${_formatNumber(remaining)} $unit left)',
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 5,
            width: double.infinity,
            color: const Color(0xFFF0F4F2),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMealBreakdownList() {
    final meals = MockDataRepository.meals;
    final history = MockDataRepository.loggedMealsHistory;
    final unknownCount = MockDataRepository.mealsWithUnknownNutrition;

    if (meals.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FBF9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFECEFEA), width: 0.8),
        ),
        child: const Text(
          'No meals logged yet today',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (unknownCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '$unknownCount meal(s) logged with estimated nutrition',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ...meals.map((meal) {
        final isCompleted = meal.isCompleted;

        // Find details from logged history if available
        Map<String, dynamic>? loggedRecord;
        for (final item in history.reversed) {
          if (item['mealType'].toString().toLowerCase() ==
              meal.name.toLowerCase()) {
            loggedRecord = item;
            break;
          }
        }

        String displayName = meal.name;
        int calories = 0;
        String macroInfo = '';

        if (isCompleted && loggedRecord != null) {
          displayName = loggedRecord['mealName'] ?? meal.name;
          calories = (loggedRecord['calories'] as num?)?.toInt() ?? 0;
          final p = loggedRecord['protein'] ?? 0;
          final c = loggedRecord['carbs'] ?? 0;
          final f = loggedRecord['fat'] ?? 0;
          macroInfo = '${p}g P · ${c}g C · ${f}g F';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isCompleted ? const Color(0xFFFAFDFB) : const Color(0xFFF9FBF9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCompleted
                  ? const Color(0xFFE2EFE7)
                  : const Color(0xFFECEFEA),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              // Meal Slot Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.paleMint : const Color(0xFFEFF2F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  meal.name.substring(0, meal.name.length > 3 ? 3 : meal.name.length).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isCompleted ? AppColors.primaryForest : AppColors.textSecondary,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.name,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      isCompleted ? displayName : 'Not logged yet',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isCompleted
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Right side Calories or Status
              if (isCompleted) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$calories kcal',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forestGreen,
                      ),
                    ),
                    if (macroInfo.isNotEmpty)
                      Text(
                        macroInfo,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ] else ...[
                const Text(
                  'Upcoming',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        );
      }),
      ],
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}

/// Circular arc painter for the dashboard hero calorie visualization
class _DashboardCalorieArcPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final Color progressColor;

  _DashboardCalorieArcPainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Full 360-degree background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Active progress arc starting from top (-90 deg)
    if (progress > 0) {
      final arcRect = Rect.fromCircle(center: center, radius: radius);
      final progressPaint = Paint()
        ..shader = (progressColor == AppColors.freshGreen && progress > 0.05)
            ? SweepGradient(
                startAngle: -math.pi / 2,
                endAngle: -math.pi / 2 + (2 * math.pi * progress.clamp(0.0, 1.0)),
                colors: const [AppColors.freshGreen, AppColors.vibrantLime],
                transform: const GradientRotation(-math.pi / 2),
              ).createShader(arcRect)
            : null
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);

      canvas.drawArc(
        arcRect,
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashboardCalorieArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}
