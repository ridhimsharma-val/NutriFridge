import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/nutrition_data.dart';

/// Reusable compact macronutrient metric card for Protein, Carbs, and Fat.
class MacroMetricCard extends StatelessWidget {
  final String label;
  final int consumedAmount;
  final int targetAmount;
  final String unit;
  final Color accentColor;
  final VoidCallback? onTap;

  const MacroMetricCard({
    super.key,
    required this.label,
    required this.consumedAmount,
    required this.targetAmount,
    this.unit = 'g',
    required this.accentColor,
    this.onTap,
  });

  /// Factory from existing MacroNutrient model
  factory MacroMetricCard.fromMacro(
    MacroNutrient macro, {
    Key? key,
    required Color accentColor,
    VoidCallback? onTap,
  }) {
    return MacroMetricCard(
      key: key,
      label: macro.name,
      consumedAmount: macro.amountGrams,
      targetAmount: macro.targetGrams,
      unit: macro.unit,
      accentColor: accentColor,
      onTap: onTap,
    );
  }

  double get progress {
    if (targetAmount <= 0) return 0.0;
    return (consumedAmount / targetAmount).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.cardBorder,
          width: 1.0,
        ),
        boxShadow: const [AppColors.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Indicator Dot + Label
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.subtitle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Main Value & Unit
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$consumedAmount',
                style: AppTypography.cardTitle.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neutralCharcoal,
                  letterSpacing: -0.4,
                ),
              ),
              Text(
                ' $unit',
                style: AppTypography.subtitle.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),

          // Target Reference
          Text(
            '/ $targetAmount $unit',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),

          // Horizontal Progress Indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(2.5),
            child: Container(
              height: 5,
              width: double.infinity,
              color: AppColors.neutralTrack,
              child: progress > 0
                  ? FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(2.5),
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
}

/// Reusable horizontal layout displaying all 3 macro metric cards side-by-side
class MacroMetricRow extends StatelessWidget {
  final MacroNutrient protein;
  final MacroNutrient carbs;
  final MacroNutrient fat;
  final VoidCallback? onTap;

  const MacroMetricRow({
    super.key,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MacroMetricCard.fromMacro(
            protein,
            accentColor: AppColors.freshGreen,
            onTap: onTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MacroMetricCard.fromMacro(
            carbs,
            accentColor: AppColors.coralPeach,
            onTap: onTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MacroMetricCard.fromMacro(
            fat,
            accentColor: AppColors.vibrantLime,
            onTap: onTap,
          ),
        ),
      ],
    );
  }
}
