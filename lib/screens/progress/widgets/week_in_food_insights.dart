import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Editorial-style weekly food insights
/// Natural language observations derived from recorded nutritional patterns.
/// Free of sparkles, robot emojis, or artificial badges.
class WeekInFoodInsights extends StatelessWidget {
  final List<String> insights;

  const WeekInFoodInsights({
    super.key,
    required this.insights,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.tealPrimary.withValues(alpha: 0.12),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Editorial Header
          Text(
            'Your week in food',
            style: AppTypography.greeting.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Observations from your meal recording pattern',
            style: AppTypography.subtitle.copyWith(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 18),

          // Insight Items
          ...insights.map((insight) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.tealPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      insight,
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 13.5,
                        color: AppColors.textPrimary,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 4),
          Text(
            'Prototype summary • Synthesized from logged meal entries',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: AppColors.textTertiary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
