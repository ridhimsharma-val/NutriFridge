import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../fridge/models/category_item.dart';
import 'widgets/manual_food_form.dart';

/// Clean mobile Manual Entry screen for adding food items
class ManualEntryPage extends StatelessWidget {
  const ManualEntryPage({super.key});

  void _handleSubmit(
    BuildContext context, {
    required String category,
    required String foodName,
    required String quantity,
    required int expiryDays,
  }) {
    // Add to mock inventory
    FridgeCategoryRepository.addItemToCategory(
      category,
      CategoryFoodItem(
        id: 'food_manual_${DateTime.now().microsecondsSinceEpoch}',
        name: foodName,
        quantity: quantity,
        expiryDays: expiryDays,
        imageAsset: FoodItemAssetRegistry.getAssetForItem(foodName, category),
        iconEmoji: _getEmojiForCategory(category),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added $foodName ($quantity) to $category!'),
        backgroundColor: AppColors.tealPrimary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String _getEmojiForCategory(String category) {
    final upper = category.toUpperCase();
    if (upper.contains('ICE CREAM')) return '🍦';
    if (upper.contains('FROZEN')) return '🧊';
    if (upper.contains('DRY FRUITS')) return '🥜';
    if (upper.contains('DAIRY')) return '🥛';
    if (upper.contains('NON-VEG')) return '🍗';
    if (upper.contains('LEFTOVERS')) return '🍲';
    if (upper.contains('PACKAGED')) return '📦';
    if (upper.contains('JUICE') || upper.contains('DRINK')) return '🧃';
    if (upper.contains('VEG')) return '🥦';
    if (upper.contains('FRUIT')) return '🍎';
    return '🍱';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.bgGradientTop,
            Color(0xFFF7FAF8),
            AppColors.bgGradientBottom,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Manual Entry',
            style: AppTypography.sectionTitle.copyWith(fontSize: 18),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter Food Details',
                  style: AppTypography.greeting.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Specify category, quantity, and optional expiry date.',
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                ManualFoodForm(
                  onSubmit: ({
                    required String category,
                    required String foodName,
                    required String quantity,
                    required int expiryDays,
                  }) {
                    _handleSubmit(
                      context,
                      category: category,
                      foodName: foodName,
                      quantity: quantity,
                      expiryDays: expiryDays,
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
