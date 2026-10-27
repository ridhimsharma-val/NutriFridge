import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/nutrition_data.dart';

/// Expandable Nutrition Today Card.
/// Collapsed state is visually unchanged.
/// Expanding reveals daily calorie summary, meal-by-meal breakdown, and detailed nutrient progress.
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
                        style: AppTypography.actionLink,
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.arrow_forward_rounded,
                        size: 13.5,
                        color: AppColors.tealAccent,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Unified Card with Animated Expansion
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.cardBorder,
                    width: 1,
                  ),
                  boxShadow: const [AppColors.softShadow],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18.0,
                  vertical: 15.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Calories Row (Visually unchanged in collapsed state)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Calories',
                                style: AppTypography.subtitle.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              RichText(
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: _formatNumber(
                                          nutritionData.consumedCalories),
                                      style: AppTypography.cardTitle.copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          ' / ${_formatNumber(nutritionData.targetCalories)} kcal',
                                      style: AppTypography.subtitle.copyWith(
                                        fontSize: 13,
                                        color: AppColors.textTertiary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Percentage Label
                        Text(
                          '${(nutritionData.calorieProgress * 100).toInt()}%',
                          style: AppTypography.badgeText.copyWith(
                            color: AppColors.tealPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),

                    // Horizontal Clean Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 6,
                        width: double.infinity,
                        color: const Color(0xFFF1F4F2),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: nutritionData.calorieProgress,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.tealAccent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Subtle Divider
                    Container(
                      height: 1,
                      color: const Color(0xFFF2F5F3),
                    ),
                    const SizedBox(height: 12),

                    // Three Clean Nutrition Values: Protein, Carbs, Fat
                    Row(
                      children: [
                        Expanded(
                          child: _buildMacroItem(
                            label: nutritionData.protein.name,
                            value:
                                '${nutritionData.protein.amountGrams} ${nutritionData.protein.unit}',
                            progress: nutritionData.protein.progress,
                            accentColor: AppColors.peachPrimary,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 34,
                          color: const Color(0xFFF0F3F1),
                        ),
                        Expanded(
                          child: _buildMacroItem(
                            label: nutritionData.carbs.name,
                            value:
                                '${nutritionData.carbs.amountGrams} ${nutritionData.carbs.unit}',
                            progress: nutritionData.carbs.progress,
                            accentColor: AppColors.amberPrimary,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 34,
                          color: const Color(0xFFF0F3F1),
                        ),
                        Expanded(
                          child: _buildMacroItem(
                            label: nutritionData.fat.name,
                            value:
                                '${nutritionData.fat.amountGrams} ${nutritionData.fat.unit}',
                            progress: nutritionData.fat.progress,
                            accentColor: const Color(0xFF3B9EBA),
                          ),
                        ),
                      ],
                    ),

                    // Animated Expansion Details
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

  Widget _buildExpandedNutritionContent() {
    final remainingCalories =
        nutritionData.targetCalories - nutritionData.consumedCalories;
    final isCalorieOver = remainingCalories < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          height: 1,
          color: const Color(0xFFF0F4F2),
        ),
        const SizedBox(height: 16),

        // A. Daily Calorie Summary Callout
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFF6FAF7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.tealPrimary.withValues(alpha: 0.12),
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
                      : AppColors.tealLight,
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
                        ? AppColors.peachPrimary
                        : AppColors.tealPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // B. Meal-by-Meal Breakdown ("Today's meals")
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

        // C. Nutrient Totals & Remaining Targets
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
          accentColor: AppColors.tealPrimary,
        ),
        const SizedBox(height: 9),
        _buildTargetProgressBar(
          label: 'Protein',
          consumed: nutritionData.protein.amountGrams,
          target: nutritionData.protein.targetGrams,
          unit: 'g',
          accentColor: AppColors.peachPrimary,
        ),
        const SizedBox(height: 9),
        _buildTargetProgressBar(
          label: 'Carbohydrates',
          consumed: nutritionData.carbs.amountGrams,
          target: nutritionData.carbs.targetGrams,
          unit: 'g',
          accentColor: AppColors.amberPrimary,
        ),
        const SizedBox(height: 9),
        _buildTargetProgressBar(
          label: 'Fat',
          consumed: nutritionData.fat.amountGrams,
          target: nutritionData.fat.targetGrams,
          unit: 'g',
          accentColor: const Color(0xFF3B9EBA),
        ),
      ],
    );
  }

  Widget _buildMealBreakdownList() {
    final meals = MockDataRepository.meals;
    final history = MockDataRepository.loggedMealsHistory;

    return Column(
      children: meals.map((meal) {
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

        if (isCompleted) {
          if (loggedRecord != null) {
            displayName = loggedRecord['mealName'] ?? meal.name;
            calories = loggedRecord['calories'] as int? ?? 0;
            final p = loggedRecord['protein'] ?? 0;
            final c = loggedRecord['carbs'] ?? 0;
            final f = loggedRecord['fat'] ?? 0;
            macroInfo = '${p}g P · ${c}g C · ${f}g F';
          } else if (meal.name.toLowerCase() == 'breakfast') {
            displayName = 'Oats & Banana';
            calories = 350;
            macroInfo = '18g P · 48g C · 10g F';
          } else if (meal.name.toLowerCase() == 'lunch') {
            displayName = 'Paneer Rice Bowl';
            calories = 520;
            macroInfo = '24g P · 65g C · 18g F';
          }
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
              // Meal Type Pill
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.tealLight : const Color(0xFFEFF2F0),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    meal.iconEmoji.isNotEmpty ? meal.iconEmoji : '🍽️',
                    style: const TextStyle(fontSize: 14),
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
                        color: AppColors.tealPrimary,
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
      }).toList(),
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

  Widget _buildMacroItem({
    required String label,
    required String value,
    required double progress,
    required Color accentColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.subtitle.copyWith(
            color: AppColors.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTypography.cardTitle.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Container(
            height: 3,
            width: 42,
            color: const Color(0xFFEFF2F0),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                color: accentColor.withValues(alpha: 0.75),
              ),
            ),
          ),
        ),
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
