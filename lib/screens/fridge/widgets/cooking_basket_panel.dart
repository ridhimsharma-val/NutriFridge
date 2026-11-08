import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/transitions/hero_transition_route.dart';
import '../../meal_detail/meal_detail_screen.dart';
import '../services/cooking_basket_service.dart';
import '../../home/services/meal_recommendation_service.dart';

/// Persistent cooking basket bottom panel for "Use My Ingredients" mode.
/// Allows viewing selected ingredients, removing items, typing an optional dish name,
/// and triggering AI meal generation.
class CookingBasketPanel extends StatefulWidget {
  final VoidCallback? onMealGenerated;

  const CookingBasketPanel({
    super.key,
    this.onMealGenerated,
  });

  @override
  State<CookingBasketPanel> createState() => _CookingBasketPanelState();
}

class _CookingBasketPanelState extends State<CookingBasketPanel> {
  late final TextEditingController _dishNameController;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _dishNameController = TextEditingController(
      text: CookingBasketService.preferredDishName ?? '',
    );
  }

  @override
  void dispose() {
    _dishNameController.dispose();
    super.dispose();
  }

  Future<void> _handleGenerateMeal() async {
    final selected = CookingBasketService.selectedItems;
    if (selected.isEmpty || CookingBasketService.isGenerating) return;

    final dishName = _dishNameController.text.trim().isNotEmpty
        ? _dishNameController.text.trim()
        : null;

    CookingBasketService.setPreferredDishName(dishName);

    final rec = await MealRecommendationService.generateFromSelectedIngredients(
      selectedItems: selected,
      preferredDishName: dishName,
      context: context,
    );

    if (!mounted) return;

    if (rec != null) {
      widget.onMealGenerated?.call();
      await Navigator.of(context).push(
        HeroTransitionRoute(
          page: MealDetailScreen(recommendation: rec),
        ),
      );
    } else {
      final error = CookingBasketService.generationError ??
          MealRecommendationService.errorMessage ??
          'Could not generate a recipe. Please tap retry.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _handleGenerateMeal,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        CookingBasketService.selectedItemsNotifier,
        CookingBasketService.preferredDishNameNotifier,
        CookingBasketService.isGeneratingNotifier,
        CookingBasketService.generationErrorNotifier,
      ]),
      builder: (context, _) {
        final items = CookingBasketService.selectedItems;
        final count = items.length;
        final isGenerating = CookingBasketService.isGenerating;
        final error = CookingBasketService.generationError;

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F2),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x280B1522),
                blurRadius: 20,
                spreadRadius: 1,
                offset: Offset(0, -4),
              ),
            ],
            border: Border.all(
              color: AppColors.cardBorder,
              width: 1,
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            12 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Drag header / Collapsible summary
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.paleMint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shopping_basket_rounded,
                      size: 18,
                      color: AppColors.forestGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Cooking Basket',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.neutralCharcoal,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          count == 0
                              ? 'Tap ingredients to select'
                              : '$count ingredient${count == 1 ? '' : 's'} selected',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: count == 0
                                ? AppColors.neutralMedium
                                : AppColors.forestGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (count > 0 && !isGenerating)
                    TextButton(
                      onPressed: CookingBasketService.clear,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Clear all',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFC53929),
                        ),
                      ),
                    ),
                  IconButton(
                    icon: Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      color: AppColors.neutralMedium,
                    ),
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              if (_isExpanded) ...[
                const SizedBox(height: 10),

                // 2. Horizontal selected ingredient chips
                if (count == 0)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.touch_app_rounded, size: 16, color: AppColors.neutralMedium),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Open any fridge category and tap items to add them.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.neutralMedium,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: items.map((item) {
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
                          decoration: BoxDecoration(
                            color: AppColors.pureWhite,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.forestGreen.withValues(alpha: 0.35),
                              width: 1,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0C000000),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.neutralCharcoal,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${item.quantity} ${item.unit}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.forestGreen,
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: isGenerating
                                    ? null
                                    : () => CookingBasketService.removeItem(item.id),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF3F4F6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 13,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                const SizedBox(height: 12),

                // 3. Optional Dish Name Input
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What would you like to cook? (Optional)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neutralCharcoal,
                      ),
                    ),
                    const SizedBox(height: 5),
                    TextField(
                      controller: _dishNameController,
                      enabled: !isGenerating,
                      onChanged: (text) => CookingBasketService.setPreferredDishName(text),
                      textCapitalization: TextCapitalization.words,
                      maxLength: 120,
                      decoration: InputDecoration(
                        hintText: 'e.g. Chicken Curry, Fried Rice, Paneer Tikka...',
                        hintStyle: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.neutralCharcoal.withValues(alpha: 0.45),
                          fontWeight: FontWeight.w400,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        filled: true,
                        fillColor: Colors.white,
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.forestGreen, width: 1.5),
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutralCharcoal,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Leave this empty and let AI surprise you.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.neutralMedium,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),

                if (error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      error,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),
              ],

              // 4. Primary CTA: Generate My Meal
              SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: (count == 0 || isGenerating) ? null : _handleGenerateMeal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forestGreen,
                    disabledBackgroundColor: const Color(0xFFD1D5DB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  icon: isGenerating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text(
                    isGenerating
                        ? 'Creating Your Meal with AI...'
                        : (count == 0 ? 'Select Ingredients to Cook' : 'Generate My Meal ($count)'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
