import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/nutrition_data.dart';

class MealStatusCardSection extends StatelessWidget {
  final List<MealItem> meals;
  final ValueChanged<MealItem>? onMealTap;

  const MealStatusCardSection({
    super.key,
    required this.meals,
    this.onMealTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            "Today's Meals",
            style: AppTypography.sectionTitle,
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: meals.map((meal) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: meal == meals.last ? 0 : 8.0,
                  ),
                  child: _MealItemCard(
                    meal: meal,
                    onTap: () => onMealTap?.call(meal),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _MealItemCard extends StatelessWidget {
  final MealItem meal;
  final VoidCallback? onTap;

  const _MealItemCard({
    required this.meal,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = meal.isCompleted;

    // Completed: subtle positive mint treatment
    // Upcoming: soft neutral / peach treatment
    final Color backgroundColor = isCompleted
        ? AppColors.mealCompletedBg
        : const Color(0xFFFBF8F5);

    final Color borderColor = isCompleted
        ? const Color(0xFFC7EBDD)
        : const Color(0xFFEDE7DF);

    final Color checkColor = isCompleted
        ? AppColors.tealAccent
        : const Color(0xFFAEBAB3);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status Icon: Checkmark or Hollow Circle
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? AppColors.cardWhite
                    : Colors.white.withValues(alpha: 0.8),
                border: Border.all(
                  color: isCompleted
                      ? AppColors.tealAccent.withValues(alpha: 0.5)
                      : const Color(0xFFD3DCD6),
                  width: 1.4,
                ),
              ),
              child: Center(
                child: isCompleted
                    ? Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: checkColor,
                      )
                    : Container(
                        width: 5.5,
                        height: 5.5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: checkColor,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            // Meal Name
            Text(
              meal.name,
              style: AppTypography.badgeText.copyWith(
                fontSize: 11.5,
                fontWeight: isCompleted ? FontWeight.w700 : FontWeight.w600,
                color: isCompleted
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Status text or symbol
            Text(
              isCompleted ? 'Done' : 'Pending',
              style: AppTypography.badgeText.copyWith(
                fontSize: 9.5,
                color: isCompleted
                    ? AppColors.tealPrimary
                    : AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
