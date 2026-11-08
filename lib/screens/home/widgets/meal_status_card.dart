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
    final history = MockDataRepository.todayLoggedMealsHistory;
    // Display only genuine logged meals for today. No fake upcoming placeholder cards.
    final loggedMeals = meals.where((m) => m.isCompleted).toList();

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

        // Meals List or Clean Empty State
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: loggedMeals.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder, width: 1.0),
                    boxShadow: const [AppColors.softShadow],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        alignment: Alignment.centerLeft,
                        children: const [
                          Text(
                            'No meals logged today',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'No meals logged yet today',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Your logged meals will appear here.',
                        style: AppTypography.subtitle.copyWith(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: loggedMeals.map((meal) {
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
      final t = item['mealType']?.toString().toLowerCase() ?? '';
      final n = item['mealName']?.toString().toLowerCase() ?? '';
      final mn = meal.name.toLowerCase();
      final mt = meal.mealType.toLowerCase();
      if (t == mn || t == mt || n == mn) {
        loggedRecord = item;
        break;
      }
    }

    final String displayName = meal.name.isNotEmpty
        ? meal.name
        : (loggedRecord != null ? (loggedRecord['mealName'] ?? meal.name) : 'Logged Meal');

    final int calories = meal.calories > 0
        ? meal.calories
        : (loggedRecord != null ? (loggedRecord['calories'] as num?)?.toInt() ?? 0 : 0);

    final String displayTime = (meal.time != null && meal.time!.isNotEmpty)
        ? meal.time!
        : (loggedRecord != null ? (loggedRecord['time'] ?? 'Logged') : 'Logged');

    final String displaySlot = meal.mealType.isNotEmpty ? meal.mealType : 'Logged';

    // Resolve food photography asset for the meal
    final String imageAsset = MealImageRegistry.resolveImage(
      mealName: displayName,
      imageKey: meal.imageUrl ?? loggedRecord?['imageKey']?.toString(),
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
                      displayName,
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
                          displaySlot,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.forestGreen,
                          ),
                        ),
                        if (displayTime.isNotEmpty) ...[
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

              // Right: Actual Calories or Done Pill
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
