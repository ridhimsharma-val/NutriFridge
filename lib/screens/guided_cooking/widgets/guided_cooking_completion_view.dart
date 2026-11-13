import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../meal_detail/models/meal_detail_data.dart';

/// Screen displayed when the user finishes the final cooking step.
/// Displays the completed recipe, celebration message, primary "Log This Meal" button,
/// and secondary "Return to Recipes" option.
class GuidedCookingCompletionView extends StatelessWidget {
  final MealDetailInfo meal;
  final VoidCallback onLogMeal;
  final VoidCallback onReturnToRecipe;
  final bool isLogging;

  const GuidedCookingCompletionView({
    super.key,
    required this.meal,
    required this.onLogMeal,
    required this.onReturnToRecipe,
    this.isLogging = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // Celebration Icon Banner
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF7ED),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFC8E6C9), width: 2),
                  boxShadow: const [AppColors.softShadow],
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_rounded,
                    color: AppColors.primaryForest,
                    size: 38,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Completion Title
              const Text(
                'Cooking Complete!',
                key: ValueKey('cooking_complete_title'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryForest,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Completion Message
              Text(
                'You’ve finished preparing ${meal.name}. It’s ready to enjoy!',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // Completed Meal Hero Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2EBE5), width: 1.0),
                  boxShadow: const [AppColors.softShadow],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Meal Image
                    SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: _buildMealImage(meal),
                    ),

                    // Quick Summary Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          if (meal.calories != null && meal.calories! > 0)
                            _buildSummaryItem(
                              icon: Icons.local_fire_department_rounded,
                              label: 'Calories',
                              value: '${meal.calories} kcal',
                              color: const Color(0xFFE65100),
                            ),
                          if (meal.proteinGrams != null && meal.proteinGrams! > 0)
                            _buildSummaryItem(
                              icon: Icons.fitness_center_rounded,
                              label: 'Protein',
                              value: '${meal.proteinGrams}g',
                              color: const Color(0xFF2E7D32),
                            ),
                          if (meal.servingSize.isNotEmpty)
                            _buildSummaryItem(
                              icon: Icons.restaurant_rounded,
                              label: 'Portion',
                              value: meal.servingSize,
                              color: AppColors.primaryForest,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Primary Action: Log This Meal
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  key: const ValueKey('log_this_meal_btn'),
                  onPressed: isLogging ? null : onLogMeal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryForest,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primaryForest.withValues(alpha: 0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bookmark_added_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        isLogging ? 'Logging Meal...' : 'Log This Meal',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Secondary Action: Return to Recipes
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  key: const ValueKey('return_to_recipes_btn'),
                  onPressed: onReturnToRecipe,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Return to Recipes',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildMealImage(MealDetailInfo meal) {
    if (meal.imageUrl.isNotEmpty) {
      if (meal.imageUrl.startsWith('http://') || meal.imageUrl.startsWith('https://')) {
        return Image.network(
          meal.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      } else {
        return Image.asset(
          meal.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      }
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFFE8F2EC),
      child: const Center(
        child: Icon(Icons.restaurant_menu_rounded, size: 48, color: Color(0xFF81A68D)),
      ),
    );
  }
}
