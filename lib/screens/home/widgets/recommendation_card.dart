import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/nutrition_data.dart';

class RecommendationCard extends StatelessWidget {
  final RecipeRecommendation recommendation;
  final VoidCallback? onTap;

  const RecommendationCard({
    super.key,
    required this.recommendation,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            'Suggested for you ✨',
            style: AppTypography.sectionTitle,
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.peachCard,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.peachBorder,
                  width: 1.2,
                ),
                boxShadow: const [AppColors.softShadow],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Food Image with Badge Overlay (Refined compact height)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(21),
                          topRight: Radius.circular(21),
                        ),
                        child: Container(
                          height: 138, // Optimized: ~15% more compact, food still prominent
                          width: double.infinity,
                          color: const Color(0xFFFFECE2),
                          child: _buildFoodImage(),
                        ),
                      ),
                      // AI Badge overlay
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                size: 12.5,
                                color: AppColors.peachPrimary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                recommendation.tag,
                                style: AppTypography.badgeText.copyWith(
                                  color: AppColors.peachPrimary,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Bottom content area (Refined vertical spacing)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 11.0, 14.0, 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Meal Title
                              Text(
                                recommendation.title,
                                style: AppTypography.cardTitle.copyWith(
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 3),
                              // Nutrition summary
                              Row(
                                children: [
                                  const Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 14.5,
                                    color: AppColors.peachPrimary,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '${recommendation.calories} kcal • ${recommendation.proteinGrams}g protein',
                                      style: AppTypography.subtitle.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // AI Match Reasons (Explaining why meal was recommended)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.5,
                                  vertical: 4.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.tealLight.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '🧊 Uses 4 items from your fridge',
                                      style: AppTypography.badgeText.copyWith(
                                        color: AppColors.tealPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2.5),
                                    Text(
                                      "💪 Helps complete today's protein goal",
                                      style: AppTypography.badgeText.copyWith(
                                        color: AppColors.tealPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Action arrow button
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.cardWhite,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.peachBorder,
                              width: 1,
                            ),
                            boxShadow: const [AppColors.cardShadow],
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 17,
                            color: AppColors.tealPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFoodImage() {
    if (recommendation.imageUrl.startsWith('assets/')) {
      return Image.asset(
        recommendation.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
      );
    }
    return Image.network(
      recommendation.imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildImagePlaceholder();
      },
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      color: const Color(0xFFFBECE4),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.restaurant_rounded,
              size: 38,
              color: AppColors.peachAccent,
            ),
            const SizedBox(height: 4),
            Text(
              'NutriFridge Kitchen',
              style: AppTypography.badgeText.copyWith(
                color: AppColors.peachPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: const Color(0xFFFBECE4),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.peachAccent),
          ),
        ),
      ),
    );
  }
}
