import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'models/detected_food_item.dart';

/// Temporary placeholder screen for Screen 3: Nutrition Review.
/// Preserves the confirmed meal name, photo, and edited food items from Screen 2.
class MealNutritionReviewPlaceholderScreen extends StatelessWidget {
  final String mealName;
  final Uint8List? imageBytes;
  final XFile? imageFile;
  final List<DetectedFoodItem> detectedFoods;

  const MealNutritionReviewPlaceholderScreen({
    super.key,
    required this.mealName,
    this.imageBytes,
    this.imageFile,
    required this.detectedFoods,
  });

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
          centerTitle: true,
          title: Text(
            'Nutrition Review',
            style: AppTypography.sectionTitle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meal Header Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder, width: 1.2),
                    boxShadow: const [AppColors.softShadow],
                  ),
                  child: Row(
                    children: [
                      // Photo thumbnail
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: const Color(0xFFEAEFEA),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: imageBytes != null
                              ? Image.memory(imageBytes!, fit: BoxFit.cover)
                              : const Icon(Icons.restaurant_rounded, color: AppColors.tealPrimary),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Meal Ready for Nutrition Review',
                              style: AppTypography.subtitle.copyWith(
                                fontSize: 11.5,
                                color: AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              mealName,
                              style: AppTypography.cardTitle.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${detectedFoods.length} items reviewed',
                              style: AppTypography.subtitle.copyWith(
                                fontSize: 12,
                                color: AppColors.tealPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'Reviewed Portions',
                  style: AppTypography.cardTitle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 10),

                // List of reviewed food items
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cardBorder, width: 1.2),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: detectedFoods.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF0F3F1)),
                      itemBuilder: (context, index) {
                        final item = detectedFoods[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                item.formattedQuantity,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.tealPrimary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Note
                Center(
                  child: Text(
                    'Screen 3 (Detailed Macro & Calorie Breakdown) will connect to these reviewed portions.',
                    textAlign: TextAlign.center,
                    style: AppTypography.subtitle.copyWith(
                      fontSize: 12.5,
                      color: AppColors.textTertiary,
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Bottom Action
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.tealPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Done for now',
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
