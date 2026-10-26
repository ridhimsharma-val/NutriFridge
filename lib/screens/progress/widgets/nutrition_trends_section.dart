import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../models/progress_data.dart';

/// Nutrition Trends Section
/// Uses clean editorial typography and subtle delta indicators to show
/// Average Daily Calories, Average Protein Intake, and Logging Consistency.
class NutritionTrendsSection extends StatelessWidget {
  final ProgressAnalyticsData data;

  const NutritionTrendsSection({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
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
          Text(
            'Nutrition trends',
            style: AppTypography.cardTitle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Aggregated patterns for this ${data.period.toLowerCase()}',
            style: AppTypography.subtitle.copyWith(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 18),

          // 3 Metric Rows with Minimal Typography
          _buildTrendRow(
            label: 'Average daily calories',
            value: '${data.averageDailyCalories} kcal',
            comparison: data.calorieTrendComparison,
            isPositive: true,
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F2)),
          _buildTrendRow(
            label: 'Average protein intake',
            value: '${data.averageProteinGrams} g / day',
            comparison: data.proteinTrendComparison,
            isPositive: true,
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F2)),
          _buildTrendRow(
            label: 'Meal-logging consistency',
            value: '${data.loggingConsistencyPct.toInt()}%',
            comparison: data.consistencyTrendComparison,
            isPositive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTrendRow({
    required String label,
    required String value,
    required String comparison,
    required bool isPositive,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                comparison,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.tealAccent,
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}
