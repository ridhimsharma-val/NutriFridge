import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/nutrition_data.dart';
import '../fridge/models/category_item.dart';
import 'models/meal_detail_data.dart';
import 'widgets/ai_assistant_modal.dart';
import 'widgets/video_card.dart';

/// Cinematic Food Experience — Meal Detail Page.
/// Opens from the Dashboard recommendation card and presents immersive food
/// photography, nutrition overview, fridge ingredient matching, AI cooking handoff,
/// and YouTube recipe inspiration.
class MealDetailScreen extends StatelessWidget {
  final RecipeRecommendation recommendation;
  final String? heroTag;

  const MealDetailScreen({
    super.key,
    required this.recommendation,
    this.heroTag,
  });

  String get _heroTag =>
      heroTag ??
      'meal-hero-image-${recommendation.title.toLowerCase().replaceAll(RegExp(r'\s+'), '-')}';

  void _handleLogMeal(BuildContext context, MealDetailInfo meal) {
    MockDataRepository.logMeal(
      mealType: meal.tag.toLowerCase(),
      mealName: meal.name,
      calories: meal.calories,
      protein: meal.proteinGrams,
      carbs: meal.carbsGrams,
      fat: meal.fatGrams,
    );

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Logged ${meal.name} (+${meal.calories} kcal) to Today\'s Meals!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.forestGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FridgeCategoryRepository.notifier,
      builder: (context, _) {
        final meal = MealDetailInfo.fromRecommendation(recommendation);

        return Scaffold(
          backgroundColor: AppColors.warmCream,
          bottomNavigationBar: _buildBottomBar(context, meal),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Cinematic Food Hero
                _buildHero(context, meal),

                // Content Surface
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 18),

                      // 2. Meal Information & Nutrition Overview
                      _buildNutritionOverview(meal),

                      const SizedBox(height: 22),

                      // 3. Why This Meal?
                      _buildWhyThisMeal(meal),

                      const SizedBox(height: 22),

                      // 4. Ingredients Available in Your Fridge
                      _buildIngredientsSection(meal),

                      const SizedBox(height: 22),

                      // 5. AI Cooking Section ("Cook it your way")
                      _buildAiCookingSection(context, meal),

                      const SizedBox(height: 24),

                      // 6. Watch How It's Made — Video Carousel
                      _buildVideoCarousel(meal),

                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // 1. CINEMATIC FOOD HERO
  // ==========================================
  Widget _buildHero(BuildContext context, MealDetailInfo meal) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // Food Photograph (Hero shared-element from Design 01)
        Hero(
          tag: _heroTag,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
            child: SizedBox(
              height: 340,
              width: double.infinity,
              child: meal.imageUrl.startsWith('assets/')
                  ? Image.asset(
                      meal.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildFallbackHeroImage(),
                    )
                  : Image.network(
                      meal.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildFallbackHeroImage(),
                    ),
            ),
          ),
        ),

        // Gradient scrim overlays for readable text & back button
        Positioned.fill(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.28, 0.55, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Restrained Back Button with frosted background
        Positioned(
          top: topPadding > 0 ? topPadding + 8 : 20,
          left: 18,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.neutralCharcoal,
                  size: 20,
                ),
              ),
            ),
          ),
        ),

        // Hero Typography Overlays (Bottom)
        Positioned(
          left: 20,
          right: 20,
          bottom: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge: "Picked for your fridge"
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.paleMint.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFC8E6C9),
                    width: 1,
                  ),
                ),
                child: Text(
                  meal.tag,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: AppColors.forestGreen,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Meal Title
              Text(
                meal.name,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackHeroImage() {
    return Container(
      color: const Color(0xFFFBECE4),
      child: const Center(
        child: Icon(
          Icons.restaurant_rounded,
          size: 64,
          color: AppColors.peachAccent,
        ),
      ),
    );
  }

  // ==========================================
  // 2. MEAL INFORMATION & NUTRITION OVERVIEW
  // ==========================================
  Widget _buildNutritionOverview(MealDetailInfo meal) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.cardBorder,
          width: 1.2,
        ),
        boxShadow: const [AppColors.softShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Nutrition & prep',
                  style: AppTypography.greeting.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutralCharcoal,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.paleMint,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFD4E7D9),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: AppColors.forestGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${meal.prepTimeMinutes} mins prep',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forestGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFF0F4F2), height: 1),
          const SizedBox(height: 14),

          // Macro Grid (Clean typography inspired by the design reference)
          Row(
            children: [
              Expanded(
                child: _buildNutritionMetric(
                  label: 'Calories',
                  value: '${meal.calories}',
                  unit: 'kcal',
                  accentColor: AppColors.freshGreen,
                ),
              ),
              Container(width: 1, height: 34, color: const Color(0xFFF0F4F2)),
              Expanded(
                child: _buildNutritionMetric(
                  label: 'Protein',
                  value: '${meal.proteinGrams}',
                  unit: 'g',
                  accentColor: AppColors.freshGreen,
                ),
              ),
              Container(width: 1, height: 34, color: const Color(0xFFF0F4F2)),
              Expanded(
                child: _buildNutritionMetric(
                  label: 'Carbs',
                  value: '${meal.carbsGrams}',
                  unit: 'g',
                  accentColor: AppColors.coralPeach,
                ),
              ),
              Container(width: 1, height: 34, color: const Color(0xFFF0F4F2)),
              Expanded(
                child: _buildNutritionMetric(
                  label: 'Fat',
                  value: '${meal.fatGrams}',
                  unit: 'g',
                  accentColor: AppColors.vibrantLime,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionMetric({
    required String label,
    required String value,
    required String unit,
    required Color accentColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 3. WHY THIS MEAL?
  // ==========================================
  Widget _buildWhyThisMeal(MealDetailInfo meal) {
    if (meal.whyReasons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Why this meal?',
          style: AppTypography.sectionTitle.copyWith(fontSize: 16.5, color: AppColors.neutralCharcoal),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.cardBorder,
              width: 1.2,
            ),
            boxShadow: const [AppColors.softShadow],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: meal.whyReasons.map((reason) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6, right: 10),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.sageAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        reason,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: AppColors.neutralCharcoal,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 4. INGREDIENTS AVAILABLE IN YOUR FRIDGE
  // ==========================================
  Widget _buildIngredientsSection(MealDetailInfo meal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ingredients',
              style: AppTypography.sectionTitle.copyWith(fontSize: 16.5, color: AppColors.neutralCharcoal),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: AppColors.paleMint,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD4E7D9), width: 0.8),
              ),
              child: Text(
                '${meal.ingredients.length} items',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forestGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.cardBorder,
              width: 1.2,
            ),
            boxShadow: const [AppColors.softShadow],
          ),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: meal.ingredients.length,
            separatorBuilder: (context, index) => const Divider(
              color: Color(0xFFF4F7F5),
              height: 1,
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              final item = meal.ingredients[index];
              return _buildIngredientRow(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientRow(MealIngredientItem item) {
    Color indicatorColor;
    switch (item.availability) {
      case IngredientAvailability.available:
        indicatorColor = AppColors.forestGreen;
        break;
      case IngredientAvailability.partial:
        indicatorColor = AppColors.coralHighlight;
        break;
      case IngredientAvailability.notTracked:
        indicatorColor = const Color(0xFF94A3B8);
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Subtle Status Indicator dot
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: indicatorColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),

          // Ingredient Name & Recipe Quantity
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutralCharcoal,
                  ),
                ),
                Text(
                  item.recipeQuantity,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Inventory Status Label
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: item.availability == IngredientAvailability.partial ? 6 : 0,
                vertical: item.availability == IngredientAvailability.partial ? 2 : 0,
              ),
              decoration: item.availability == IngredientAvailability.partial
                  ? BoxDecoration(
                      color: AppColors.peachLight,
                      borderRadius: BorderRadius.circular(6),
                    )
                  : null,
              child: Text(
                item.statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: item.availability == IngredientAvailability.available
                      ? AppColors.forestGreen
                      : (item.availability == IngredientAvailability.partial
                          ? AppColors.peachText
                          : AppColors.textTertiary),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. AI COOKING SECTION — "Cook it your way"
  // ==========================================
  Widget _buildAiCookingSection(BuildContext context, MealDetailInfo meal) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2EBE5),
          width: 1.2,
        ),
        boxShadow: const [AppColors.softShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.paleMint,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD4E7D9), width: 0.8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.forestGreen),
                    SizedBox(width: 4),
                    Text(
                      'NutriFridge AI',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: AppColors.forestGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Section Title
          Text(
            'Cook it your way',
            style: AppTypography.cardTitle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.neutralCharcoal,
            ),
          ),
          const SizedBox(height: 3),

          // Supporting Text
          const Text(
            'Get a recipe tailored to your ingredients and preferences.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 14),

          // Cooking Step Cards inspired by reference design
          _buildStepCard(
            stepNumber: '1',
            text: 'Exact portion measurements for 1 serving',
            onTap: () => AiAssistantModalSheet.show(context, mealName: meal.name),
          ),
          const SizedBox(height: 8),
          _buildStepCard(
            stepNumber: '2',
            text: 'Simple stove-top preparation steps',
            onTap: () => AiAssistantModalSheet.show(context, mealName: meal.name),
          ),
          const SizedBox(height: 8),
          _buildStepCard(
            stepNumber: '3',
            text: 'Smart substitutions using available fridge items',
            onTap: () => AiAssistantModalSheet.show(context, mealName: meal.name),
          ),

          const SizedBox(height: 16),

          // Primary Button: "Get AI Recipe"
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              onPressed: () => AiAssistantModalSheet.show(
                context,
                mealName: meal.name,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Get AI Recipe',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Secondary text/link: "Ask NutriFridge AI"
          Center(
            child: GestureDetector(
              onTap: () => AiAssistantModalSheet.show(
                context,
                mealName: meal.name,
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Ask NutriFridge AI',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forestGreen,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.forestGreen,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required String stepNumber,
    required String text,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F7F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEBE6DC), width: 0.8),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: const [
                    BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
                child: Center(
                  child: Text(
                    stepNumber,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.forestGreen,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutralCharcoal,
                  ),
                ),
              ),
              const Icon(
                Icons.play_arrow_rounded,
                size: 18,
                color: AppColors.forestGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 6. WATCH HOW IT'S MADE — VIDEO CAROUSEL
  // ==========================================
  Widget _buildVideoCarousel(MealDetailInfo meal) {
    if (meal.videos.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Watch how it's made",
            style: AppTypography.sectionTitle.copyWith(fontSize: 16.5, color: AppColors.neutralCharcoal),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder, width: 1.2),
              boxShadow: const [AppColors.softShadow],
            ),
            child: Row(
              children: [
                const Icon(Icons.videocam_off_outlined, size: 22, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No video tutorials available for this recipe.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final videos = meal.videos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Watch how it's made",
          style: AppTypography.sectionTitle.copyWith(fontSize: 16.5, color: AppColors.neutralCharcoal),
        ),
        const SizedBox(height: 2),
        const Text(
          'Cooking videos for this meal.',
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 12),

        // Horizontal Video Carousel
        SizedBox(
          height: 195,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              return RecipeVideoCard(video: video);
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 7. FLOATING ACTION DOCK
  // ==========================================
  Widget _buildBottomBar(BuildContext context, MealDetailInfo meal) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 14,
            offset: Offset(0, -3),
          ),
        ],
        border: Border(
          top: BorderSide(color: AppColors.cardBorder, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Left Action: Cook with AI
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => AiAssistantModalSheet.show(context, mealName: meal.name),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: const Text(
                    'Cook with AI',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.vibrantLime,
                    foregroundColor: AppColors.primaryForest,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Right Action: Log Meal
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _handleLogMeal(context, meal),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text(
                    'Log Meal',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryForest,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
