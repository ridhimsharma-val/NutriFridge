import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../meal_detail/models/meal_detail_data.dart';
import '../../../services/food_image/food_image_model.dart';
import '../../../services/food_image/food_image_service.dart';

/// Screen displayed before cooking begins.
/// Shows recipe information, meal image, timings, required ingredients,
/// and an interactive checklist allowing users to tick ingredients as they prep.
class GuidedCookingPreparationView extends StatefulWidget {
  final MealDetailInfo meal;
  final VoidCallback onBeginCooking;
  final VoidCallback onClose;

  const GuidedCookingPreparationView({
    super.key,
    required this.meal,
    required this.onBeginCooking,
    required this.onClose,
  });

  @override
  State<GuidedCookingPreparationView> createState() => _GuidedCookingPreparationViewState();
}

class _GuidedCookingPreparationViewState extends State<GuidedCookingPreparationView> {
  final Set<String> _checkedIngredients = {};

  @override
  void initState() {
    super.initState();
  }

  void _toggleIngredient(String ingredientName) {
    setState(() {
      if (_checkedIngredients.contains(ingredientName)) {
        _checkedIngredients.remove(ingredientName);
      } else {
        _checkedIngredients.add(ingredientName);
      }
    });
  }

  void _toggleAll() {
    setState(() {
      if (_checkedIngredients.length == widget.meal.ingredients.length) {
        _checkedIngredients.clear();
      } else {
        _checkedIngredients.addAll(widget.meal.ingredients.map((i) => i.name));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    final totalIngredients = meal.ingredients.length;
    final checkedCount = _checkedIngredients.length;
    final allChecked = totalIngredients > 0 && checkedCount == totalIngredients;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.primaryForest, size: 24),
          onPressed: widget.onClose,
          tooltip: 'Exit Guided Cooking',
        ),
        title: const Text(
          'Preparation Checklist',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryForest,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Recipe Header Card
                    _buildRecipeHeaderCard(meal),

                    const SizedBox(height: 20),

                    // 2. Checklist Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ingredients to Prepare',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryForest,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$checkedCount of $totalIngredients ready',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: checkedCount == totalIngredients && totalIngredients > 0
                                    ? AppColors.primaryForest
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        if (totalIngredients > 0)
                          TextButton(
                            onPressed: _toggleAll,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primaryForest,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            child: Text(
                              allChecked ? 'Uncheck All' : 'Check All',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 3. Checklist Items
                    if (meal.ingredients.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2EBE5)),
                        ),
                        child: const Center(
                          child: Text(
                            'No specific ingredients listed. Ready to cook!',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2EBE5), width: 1.0),
                          boxShadow: const [AppColors.softShadow],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: meal.ingredients.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFF1F5F2),
                            indent: 52,
                            endIndent: 16,
                          ),
                          itemBuilder: (context, index) {
                            final ing = meal.ingredients[index];
                            final isChecked = _checkedIngredients.contains(ing.name);

                            return InkWell(
                              onTap: () => _toggleIngredient(ing.name),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    // Custom Circular Checkbox
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: isChecked ? AppColors.primaryForest : Colors.transparent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isChecked ? AppColors.primaryForest : const Color(0xFFCBD5E1),
                                          width: 1.8,
                                        ),
                                      ),
                                      child: isChecked
                                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                                          : null,
                                    ),
                                    const SizedBox(width: 14),
                                    // Ingredient Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ing.name,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: isChecked ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                                              decoration: isChecked ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            ing.recipeQuantityText,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: isChecked ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // 4. Prominent Begin Cooking Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(
                  top: BorderSide(color: Color(0xFFE2EBE5), width: 1),
                ),
                boxShadow: [
                  BoxKeyShadows.subtleTop,
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  key: const ValueKey('begin_cooking_btn'),
                  onPressed: widget.onBeginCooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryForest,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow_rounded, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        meal.preparationSteps.isNotEmpty
                            ? 'Begin Cooking (${meal.preparationSteps.length} Steps)'
                            : 'Begin Cooking',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeHeaderCard(MealDetailInfo meal) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EBE5), width: 1.0),
        boxShadow: const [AppColors.softShadow],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meal Image
          SizedBox(
            height: 160,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildMealImage(meal),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 16,
                  right: 16,
                  child: Text(
                    meal.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.4,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          offset: Offset(0, 1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Time & Servings Badges
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (meal.prepTimeMinutes != null && meal.prepTimeMinutes! > 0)
                  _buildMetaBadge(
                    icon: Icons.timer_outlined,
                    label: 'Prep: ${meal.prepTimeMinutes} mins',
                  ),
                if (meal.cookingTimeMinutes != null && meal.cookingTimeMinutes! > 0)
                  _buildMetaBadge(
                    icon: Icons.outdoor_grill_outlined,
                    label: 'Cook: ${meal.cookingTimeMinutes} mins',
                  ),
                if (meal.servingSize.isNotEmpty)
                  _buildMetaBadge(
                    icon: Icons.restaurant_outlined,
                    label: meal.servingSize,
                  ),
                if (meal.calories != null && meal.calories! > 0)
                  _buildMetaBadge(
                    icon: Icons.local_fire_department_outlined,
                    label: '${meal.calories} kcal',
                  ),
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildMetaBadge({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC8E6C9), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryForest),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryForest,
            ),
          ),
        ],
      ),
    );
  }
}

class BoxKeyShadows {
  static BoxShadow subtleTop = BoxShadow(
    color: Colors.black.withValues(alpha: 0.04),
    offset: const Offset(0, -3),
    blurRadius: 10,
  );
}
