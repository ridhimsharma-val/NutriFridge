import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/nutrition_data.dart';

class NutritionCard extends StatelessWidget {
  final DailyNutritionData nutritionData;
  final VoidCallback? onSeeMore;

  const NutritionCard({
    super.key,
    required this.nutritionData,
    this.onSeeMore,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Nutrition Today',
                style: AppTypography.sectionTitle,
              ),
              InkWell(
                onTap: onSeeMore,
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
                        'See',
                        style: AppTypography.actionLink,
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.arrow_forward_rounded,
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
        // Unified Cream/White Card (Refined compact height)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
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
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Calories Row
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
                // Three Clean Nutrition Values: Protein, Carbs, Fat (Typographic hierarchy)
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
              ],
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
        // Subtle restrained mini progress bar
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
