import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/nutrition_data.dart';
import '../../fridge/models/category_item.dart';

class RecommendationCard extends StatelessWidget {
  final RecipeRecommendation? recommendation;
  final RecommendationStatus? status;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onTap;
  final VoidCallback? onOpenAssistant;
  final String? heroTag;

  const RecommendationCard({
    super.key,
    this.recommendation,
    this.status,
    this.errorMessage,
    this.onRetry,
    this.onTap,
    this.onOpenAssistant,
    this.heroTag,
  });

  String get _heroTag =>
      heroTag ??
      'meal-hero-image-${recommendation?.title.toLowerCase().replaceAll(RegExp(r'\s+'), '-') ?? 'empty'}';

  @override
  Widget build(BuildContext context) {
    final rec = recommendation;
    final effectiveStatus = status ??
        (rec != null
            ? RecommendationStatus.loaded
            : (FridgeCategoryRepository.totalFridgeItems == 0
                ? RecommendationStatus.empty
                : RecommendationStatus.loading));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            'Suggested for you',
            style: AppTypography.sectionTitle,
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: _buildStateBody(context, effectiveStatus, rec),
        ),
      ],
    );
  }

  Widget _buildStateBody(
    BuildContext context,
    RecommendationStatus status,
    RecipeRecommendation? rec,
  ) {
    switch (status) {
      case RecommendationStatus.empty:
        return _buildEmptyState(context);
      case RecommendationStatus.loading:
        return _buildLoadingState(context);
      case RecommendationStatus.error:
        return _buildErrorState(context);
      case RecommendationStatus.noMatch:
        return _buildNoMatchState(context);
      case RecommendationStatus.loaded:
        if (rec != null) {
          return _buildCardContent(rec);
        }
        return _buildEmptyState(context);
    }
  }

  // ==========================================
  // STATE A — FRIDGE IS EMPTY
  // ==========================================
  Widget _buildEmptyState(BuildContext context) {
    return InkWell(
      onTap: onOpenAssistant ?? onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.coralPeach.withValues(alpha: 0.32),
            width: 1.2,
          ),
          boxShadow: const [AppColors.softShadow],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your fridge is waiting for its first ingredients.',
              style: AppTypography.cardTitle.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Your next meal starts with your fridge.',
              style: AppTypography.subtitle.copyWith(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Add a few ingredients and NutriFridge AI can help you decide what to cook.',
              style: AppTypography.subtitle.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ask NutriFridge AI',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.peachText,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 15,
                  color: AppColors.peachText,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STATE B — LOADING RECOMMENDATION
  // ==========================================
  Widget _buildLoadingState(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.peachCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.peachBorder,
          width: 1.2,
        ),
        boxShadow: const [AppColors.softShadow],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.peachBorder),
            ),
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.tealPrimary),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Finding something delicious with your ingredients...',
                  style: AppTypography.cardTitle.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Matching fridge stock with your nutrition preferences',
                  style: AppTypography.subtitle.copyWith(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STATE D — INVENTORY AVAILABLE BUT NO SUITABLE MEAL
  // ==========================================
  Widget _buildNoMatchState(BuildContext context) {
    return InkWell(
      onTap: onOpenAssistant ?? onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.coralPeach.withValues(alpha: 0.32),
            width: 1.2,
          ),
          boxShadow: const [AppColors.softShadow],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "We couldn't find a suitable meal with your current ingredients.",
              style: AppTypography.cardTitle.copyWith(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adding a few more ingredients or ask NutriFridge AI for customized ideas.',
              style: AppTypography.subtitle.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ask NutriFridge AI',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.peachText,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 15,
                  color: AppColors.peachText,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STATE E — BACKEND/NETWORK FAILURE
  // ==========================================
  Widget _buildErrorState(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.peachCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.peachBorder,
          width: 1.2,
        ),
        boxShadow: const [AppColors.softShadow],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.peachBorder),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 20,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Couldn't load recommendation",
                  style: AppTypography.cardTitle.copyWith(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage ??
                'Unable to reach NutriFridge AI. Please check your connection and tap retry.',
            style: AppTypography.subtitle.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: onRetry,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.tealPrimary.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: AppColors.tealPrimary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Tap to retry',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.tealPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STATE C — LOADED RECOMMENDATION CARD
  // ==========================================
  Widget _buildCardContent(RecipeRecommendation recommendation) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.coralPeach.withValues(alpha: 0.32),
            width: 1.2,
          ),
          boxShadow: const [AppColors.softShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Food Image with Badge Overlay
            Stack(
              children: [
                Hero(
                  tag: _heroTag,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(21),
                      topRight: Radius.circular(21),
                    ),
                    child: Container(
                      height: 152,
                      width: double.infinity,
                      color: const Color(0xFFFFECE2),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildFoodImage(),
                          // Subtle bottom scrim gradient for better contrast & depth
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.28),
                                ],
                                stops: const [0.55, 1.0],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Meal-Period Label overlay
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.palePeachSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.coralPeach.withValues(alpha: 0.32),
                        width: 1.0,
                      ),
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
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.coralPeach,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          recommendation.mealType.isNotEmpty
                              ? recommendation.mealType.toUpperCase()
                              : recommendation.tag,
                          style: AppTypography.badgeText.copyWith(
                            color: AppColors.darkPeachText,
                            fontWeight: FontWeight.w700,
                            fontSize: 10.5,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Prep time badge if available
                if (recommendation.prepTimeMinutes > 0)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${recommendation.prepTimeMinutes} min',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Bottom content area
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 13.0, 14.0, 14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Meal Title
                            Text(
                              recommendation.title,
                              style: AppTypography.cardTitle.copyWith(
                                fontSize: 17.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 5),
                            // Nutrition & Ingredient summary
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text:
                                        '${recommendation.calories} kcal · ${recommendation.proteinGrams}g protein',
                                    style: AppTypography.subtitle.copyWith(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (recommendation.fridgeItemsUsed > 0)
                                    TextSpan(
                                      text: ' · ${recommendation.fridgeItemsUsed} in fridge',
                                      style: AppTypography.subtitle.copyWith(
                                        fontSize: 12,
                                        color: AppColors.freshGreen,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Action arrow button
                      Container(
                        key: const ValueKey('recommendation_card_arrow'),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.cardWhite,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.coralPeach.withValues(alpha: 0.32),
                            width: 1.2,
                          ),
                          boxShadow: const [AppColors.cardShadow],
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: AppColors.coralPeach,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Explanatory Match Reasons
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.palePeachSurface,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: AppColors.palePeachBorder,
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final reason in recommendation.matchReasons) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 4.5,
                                height: 4.5,
                                decoration: const BoxDecoration(
                                  color: AppColors.coralPeach,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: AppTypography.badgeText.copyWith(
                                    color: AppColors.darkPeachText,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (reason != recommendation.matchReasons.last)
                            const SizedBox(height: 3),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodImage([RecipeRecommendation? rec]) {
    final url = rec?.imageUrl ?? recommendation?.imageUrl;
    if (url != null && url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
      );
    } else if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildImagePlaceholder();
        },
      );
    }
    return _buildFallbackImage();
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
