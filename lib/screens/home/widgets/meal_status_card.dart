import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/nutrition_data.dart';

/// Redesigned Today's Meals section inspired by the reference design:
/// - Real food photography thumbnail
/// - Meal name, meal slot & logged time
/// - Actual calorie count in bold forest green
/// - Clean empty state when no meals logged
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
    final history = MockDataRepository.loggedMealsHistory;
    final bool hasAnyLogged = meals.any((m) => m.isCompleted) || history.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            "Today's Meals",
            style: AppTypography.sectionTitle,
          ),
        ),
        const SizedBox(height: 12),

        // Meals List or Empty State
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: !hasAnyLogged || meals.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder, width: 1.0),
                    boxShadow: const [AppColors.softShadow],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: AppColors.paleMint,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.restaurant_outlined,
                          size: 20,
                          color: AppColors.forestGreen,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'No meals logged yet today',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Log meals via AI Assistant or camera',
                              style: AppTypography.subtitle.copyWith(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: meals.map((meal) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: _MealItemCard(
                        meal: meal,
                        history: history,
                        onTap: () => onMealTap?.call(meal),
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
  final List<Map<String, dynamic>> history;
  final VoidCallback? onTap;

  const _MealItemCard({
    required this.meal,
    required this.history,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = meal.isCompleted;

    // Resolve specific logged details from history if available
    Map<String, dynamic>? loggedRecord;
    for (final item in history.reversed) {
      if (item['mealType'].toString().toLowerCase() ==
          meal.name.toLowerCase()) {
        loggedRecord = item;
        break;
      }
    }

    final String displayName = isCompleted && loggedRecord != null
        ? (loggedRecord['mealName'] ?? meal.name)
        : meal.name;

    final int calories = isCompleted && loggedRecord != null
        ? (loggedRecord['calories'] as num?)?.toInt() ?? 0
        : 0;

    final String displayTime = isCompleted && loggedRecord != null
        ? (loggedRecord['time'] ?? meal.time)
        : (isCompleted ? meal.time : 'Upcoming');

    // Resolve food photography asset for the meal
    final String imageAsset = MealImageRegistry.resolveImage(
      mealName: displayName,
      imageKey: loggedRecord?['imageKey']?.toString(),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isCompleted
                  ? const Color(0xFFE2EFE7)
                  : AppColors.cardBorder,
              width: 1.0,
            ),
            boxShadow: const [AppColors.cardShadow],
          ),
          child: Row(
            children: [
              // Left: Rounded Food Image Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  width: 50,
                  height: 50,
                  color: isCompleted ? const Color(0xFFEAF5EE) : const Color(0xFFF6F8F7),
                  child: Image.asset(
                    imageAsset,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(
                        meal.iconEmoji.isNotEmpty ? meal.iconEmoji : '🍽️',
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Middle: Meal Name + Slot / Time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.name,
                      style: AppTypography.cardTitle.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isCompleted
                            ? AppColors.neutralCharcoal
                            : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          isCompleted ? 'Logged' : 'Upcoming',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isCompleted
                                ? AppColors.forestGreen
                                : AppColors.textTertiary,
                          ),
                        ),
                        if (isCompleted && displayTime.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '· $displayTime',
                              style: AppTypography.subtitle.copyWith(
                                fontSize: 11.5,
                                color: AppColors.textTertiary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Right: Actual Calories or Pending Pill
              if (isCompleted && calories > 0) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$calories',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.forestGreen,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Text(
                      'kcal',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ] else if (isCompleted) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.sageLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forestGreen,
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F5F4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
