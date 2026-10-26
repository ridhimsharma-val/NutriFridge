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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6.5),
                            decoration: const BoxDecoration(
                              color: AppColors.peachLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.local_fire_department_rounded,
                              size: 15,
                              color: AppColors.peachPrimary,
                            ),
                          ),
                          const SizedBox(width: 9),
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
                                  ),
                                ),
                                const SizedBox(height: 1),
                                RichText(
                                  overflow: TextOverflow.ellipsis,
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: _formatNumber(
                                            nutritionData.consumedCalories),
                                        style: AppTypography.cardTitle.copyWith(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            ' / ${_formatNumber(nutritionData.targetCalories)} kcal',
                                        style: AppTypography.subtitle.copyWith(
                                          fontSize: 12,
                                          color: AppColors.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Percentage Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.5,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.tealLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(nutritionData.calorieProgress * 100).toInt()}%',
                        style: AppTypography.badgeText.copyWith(
                          color: AppColors.tealPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                // Horizontal Clean Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 7,
                    width: double.infinity,
                    color: const Color(0xFFF1F4F2),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: nutritionData.calorieProgress,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.tealAccent,
                              Color(0xFF48B69A),
                            ],
                          ),
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
                // Three Compact Nutrition Values: Protein, Carbs, Fat
                Row(
                  children: [
                    Expanded(
                      child: _buildMacroItem(
                        label: nutritionData.protein.name,
                        value:
                            '${nutritionData.protein.amountGrams}${nutritionData.protein.unit}',
                        icon: Icons.fitness_center_rounded,
                        accentColor: AppColors.peachPrimary,
                        bgColor: AppColors.peachLight,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: const Color(0xFFF0F3F1),
                    ),
                    Expanded(
                      child: _buildMacroItem(
                        label: nutritionData.carbs.name,
                        value:
                            '${nutritionData.carbs.amountGrams}${nutritionData.carbs.unit}',
                        icon: Icons.grain_rounded,
                        accentColor: AppColors.amberPrimary,
                        bgColor: AppColors.amberLight,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: const Color(0xFFF0F3F1),
                    ),
                    Expanded(
                      child: _buildMacroItem(
                        label: nutritionData.fat.name,
                        value:
                            '${nutritionData.fat.amountGrams}${nutritionData.fat.unit}',
                        icon: Icons.water_drop_rounded,
                        accentColor: const Color(0xFF3B9EBA),
                        bgColor: const Color(0xFFE8F6FA),
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
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(3.5),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 10.5,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: AppTypography.nutritionLabel.copyWith(fontSize: 11.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.nutritionValue.copyWith(fontSize: 14.5),
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
