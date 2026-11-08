import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/transitions/hero_transition_route.dart';
import '../../models/nutrition_data.dart';
import '../../services/auth/auth_service.dart';
import '../../services/meals/meal_tracking_service.dart';
import '../../services/meals/models/meal_models.dart';
import '../ai_assistant/ai_assistant_screen.dart';
import '../fridge/models/category_item.dart';
import '../home/services/meal_recommendation_service.dart';
import 'models/meal_ai_context.dart';
import 'models/meal_detail_data.dart';
import 'widgets/video_card.dart';

/// Comprehensive, Data-Driven Recipe Experience — Meal Detail Page.
/// Features authentic food photography, per-serving nutrition with transparent provenance,
/// dynamic fact-based recommendation reasons, inventory-checked ingredients,
/// recipe-specific preparation instructions, YouTube carousel integration,
/// and contextual Cook with AI / direct Log Meal actions positioned at the end of the scroll.
class MealDetailScreen extends StatefulWidget {
  final RecipeRecommendation recommendation;
  final String? heroTag;

  const MealDetailScreen({
    super.key,
    required this.recommendation,
    this.heroTag,
  });

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  bool _isLogging = false;

  String get _heroTag =>
      widget.heroTag ??
      'meal-hero-image-${widget.recommendation.title.toLowerCase().replaceAll(RegExp(r'\s+'), '-')}';

  String? _idempotencyKey;

  /// Directly logs the displayed meal with ingredient deductions and updates reactive repositories
  void _handleLogMeal(MealDetailInfo meal) async {
    if (_isLogging) return;
    setState(() {
      _isLogging = true;
    });

    _idempotencyKey ??= MealTrackingService.generateIdempotencyKey();

    try {
      // 1. Gather available ingredients for record
      final availableIngredients = meal.ingredients
          .where((i) => i.availability == IngredientAvailability.available)
          .map((i) => i.name)
          .toList();

      // 2. Build structured ingredient deductions for Supabase RPC
      final deductions = <MealIngredientDeduction>[];
      for (final ing in meal.ingredients) {
        final matched = FridgeCategoryRepository.findItemByName(ing.name);
        final isAvail = ing.availability == IngredientAvailability.available && matched != null;
        final isRealUuid = matched != null &&
            matched.id.isNotEmpty &&
            !matched.id.startsWith('item_') &&
            !matched.id.startsWith('food_') &&
            !matched.id.startsWith('dairy_');
        final isUnitCompatible = matched != null &&
            FridgeCategoryRepository.areUnitsCompatible(matched.unit, ing.requiredUnit);
        final doDeduct = isAvail && isRealUuid && ing.requiredQuantity > 0 && isUnitCompatible;

        deductions.add(MealIngredientDeduction(
          name: ing.name,
          requiredQuantity: ing.requiredQuantity,
          requiredUnit: ing.requiredUnit,
          matchedFridgeItemId: doDeduct ? matched.id : null,
          deductQuantity: doDeduct ? ing.requiredQuantity : null,
          deductUnit: doDeduct ? ing.requiredUnit : null,
          doDeduct: doDeduct,
        ));
      }

      // 3. Record meal via MockDataRepository (invoking Supabase RPC when authenticated)
      final result = await MockDataRepository.logMeal(
        mealType: meal.tag.isNotEmpty ? meal.tag.toLowerCase() : 'lunch',
        mealName: meal.name,
        calories: meal.calories ?? 0,
        protein: meal.proteinGrams ?? 0,
        carbs: meal.carbsGrams ?? 0,
        fat: meal.fatGrams ?? 0,
        ingredients: availableIngredients,
        idempotencyKey: _idempotencyKey,
        ingredientDeductions: deductions,
        recipeId: widget.recommendation.id.isNotEmpty && !widget.recommendation.id.startsWith('recipe_')
            ? widget.recommendation.id
            : null,
        imageUrl: meal.imageUrl,
      );

      // In unauthenticated / test mode only, deduct in-memory
      if (!AuthService.instance.isAuthenticated || AuthService.instance.currentUser == null) {
        for (final ing in meal.ingredients) {
          if (ing.availability == IngredientAvailability.available) {
            FridgeCategoryRepository.deductItemQuantityByName(
              name: ing.name,
              quantity: ing.requiredQuantity,
              unit: ing.requiredUnit,
            );
          }
        }
      }

      // 4. Invalidate recommendation and advance to next unlogged slot (only for new non-duplicate meals)
      final isDuplicate = result?.alreadyProcessed == true;
      if (!isDuplicate) {
        MealRecommendationService.advanceAfterMealLogged(
          loggedSlot: MealRecommendationService.parseMealSlot(meal.tag),
        );
      }

      // Clear idempotency key on successful confirmation
      _idempotencyKey = null;

      if (!mounted) return;

      // 5. Show clear success confirmation
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isDuplicate
                      ? 'Meal was already logged with this transaction.'
                      : 'Logged ${meal.name}${meal.calories != null ? " (+${meal.calories} kcal)" : ""} to Today\'s Meals!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primaryForest,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );

      // 6. Navigate back
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLogging = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to log meal: ${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _handleLogMeal(meal),
          ),
        ),
      );
    }
  }

  /// Opens the AI Assistant passing a complete structured meal context
  void _handleCookWithAi(BuildContext context, MealDetailInfo meal) {
    final availableFridgeMap = <String, String>{};
    for (final ing in meal.ingredients) {
      if (ing.availability == IngredientAvailability.available && ing.availableQuantityInFridge != null) {
        availableFridgeMap[ing.name] = ing.availableQuantityInFridge!;
      }
    }

    final missingIngList = meal.ingredients
        .where((i) => i.availability == IngredientAvailability.missing)
        .map((i) => i.name)
        .toList();

    final nutritionSummary = (meal.calories != null)
        ? '${meal.calories} kcal, ${meal.proteinGrams ?? "--"}g protein, ${meal.carbsGrams ?? "--"}g carbs, ${meal.fatGrams ?? "--"}g fat'
        : 'Nutrition unavailable';

    final mealContext = MealAiContext(
      mealId: widget.recommendation.id.isNotEmpty
          ? widget.recommendation.id
          : 'meal_${meal.name.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}',
      mealTitle: meal.name,
      mealDescription: widget.recommendation.explanation ?? 'Recipe recommendation based on available ingredients.',
      mealType: meal.tag,
      nutritionSummary: nutritionSummary,
      servingSize: meal.servingSize,
      prepTimeMinutes: meal.prepTimeMinutes,
      cookingTimeMinutes: meal.cookingTimeMinutes,
      requiredIngredients: meal.ingredients.map((i) => '${i.name} (${i.recipeQuantityText})').toList(),
      availableFridgeQuantities: availableFridgeMap,
      missingIngredients: missingIngList,
      preparationSteps: meal.preparationSteps.map((s) => s.instruction).toList(),
      cookingTips: meal.cookingTips,
      substitutions: meal.substitutions,
      recommendationReasons: meal.whyReasons,
    );

    final prompt =
        'I want to cook ${meal.name}. Please give me the complete recipe with ingredients from my fridge and step-by-step cooking instructions.';

    Navigator.of(context).push(
      HeroTransitionRoute(
        page: AiAssistantScreen(
          initialPrompt: prompt,
          mealContext: mealContext,
        ),
      ),
    );
  }

  void _launchVideoSearch(MealDetailInfo meal) async {
    final query = Uri.encodeComponent(meal.videoSearchQuery ?? '${meal.name} recipe');
    final uri = Uri.parse('https://www.youtube.com/results?search_query=$query');
    await _launchVideoUrl(uri.toString(), meal.name);
  }

  Future<void> _launchVideoUrl(String urlString, String title) async {
    final uri = Uri.tryParse(urlString);
    if (uri == null) return;
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening tutorial for $title...'),
            backgroundColor: AppColors.primaryForest,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening tutorial for $title...'),
            backgroundColor: AppColors.primaryForest,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FridgeCategoryRepository.notifier,
      builder: (context, _) {
        final meal = MealDetailInfo.fromRecommendation(widget.recommendation);

        return Scaffold(
          backgroundColor: AppColors.softCream,
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Food Photograph & Hero
                _buildHero(context, meal),

                // Content Surface
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 18),

                      // 1. Meal Information & Nutrition Overview
                      _buildNutritionOverview(meal),

                      const SizedBox(height: 22),

                      // 2. Why This Meal?
                      _buildWhyThisMeal(meal),

                      const SizedBox(height: 22),

                      // 3. Ingredients Section
                      _buildIngredientsSection(meal),

                      const SizedBox(height: 22),

                      // 4. Recipe-Specific Preparation Instructions
                      _buildPreparationSection(meal),

                      const SizedBox(height: 24),

                      // 5. Watch How It's Made — YouTube Video Recommendations
                      _buildVideoCarousel(meal),

                      const SizedBox(height: 28),

                      // 6. Action Buttons positioned at the very end of the scrollable content
                      _buildActionButtons(context, meal),

                      const SizedBox(height: 32),
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
  // FOOD HERO
  // ==========================================
  Widget _buildHero(BuildContext context, MealDetailInfo meal) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // Food Photograph
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
                      errorBuilder: (context, error, stackTrace) => _buildFallbackHeroImage(),
                    )
                  : Image.network(
                      meal.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildFallbackHeroImage(),
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
                  color: AppColors.darkText,
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
                    color: AppColors.primaryForest,
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
          color: AppColors.coralPeach,
        ),
      ),
    );
  }

  // ==========================================
  // 1. MEAL INFORMATION & NUTRITION OVERVIEW
  // ==========================================
  Widget _buildNutritionOverview(MealDetailInfo meal) {
    final bool hasNutrition = meal.calories != null ||
        meal.proteinGrams != null ||
        meal.carbsGrams != null ||
        meal.fatGrams != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2EBE5),
          width: 1.0,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nutrition & prep',
                      style: AppTypography.greeting.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Per ${meal.servingSize} · ${meal.nutritionSourceLabel}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              if (meal.prepTimeMinutes != null)
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
                  child: Text(
                    '${meal.prepTimeMinutes} mins prep',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryForest,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFF0F4F2), height: 1),
          const SizedBox(height: 14),

          if (hasNutrition)
            Row(
              children: [
                Expanded(
                  child: _buildNutritionMetric(
                    label: 'Calories',
                    value: meal.calories != null ? '${meal.calories}' : '--',
                    unit: 'kcal',
                    accentColor: AppColors.primaryForest,
                  ),
                ),
                Container(width: 1, height: 34, color: const Color(0xFFF0F4F2)),
                Expanded(
                  child: _buildNutritionMetric(
                    label: 'Protein',
                    value: meal.proteinGrams != null ? '${meal.proteinGrams}' : '--',
                    unit: 'g',
                    accentColor: AppColors.freshGreen,
                  ),
                ),
                Container(width: 1, height: 34, color: const Color(0xFFF0F4F2)),
                Expanded(
                  child: _buildNutritionMetric(
                    label: 'Carbs',
                    value: meal.carbsGrams != null ? '${meal.carbsGrams}' : '--',
                    unit: 'g',
                    accentColor: AppColors.coralPeach,
                  ),
                ),
                Container(width: 1, height: 34, color: const Color(0xFFF0F4F2)),
                Expanded(
                  child: _buildNutritionMetric(
                    label: 'Fat',
                    value: meal.fatGrams != null ? '${meal.fatGrams}' : '--',
                    unit: 'g',
                    accentColor: AppColors.freshGreen,
                  ),
                ),
                if (meal.fiberGrams != null) ...[
                  Container(width: 1, height: 34, color: const Color(0xFFF0F4F2)),
                  Expanded(
                    child: _buildNutritionMetric(
                      label: 'Fiber',
                      value: '${meal.fiberGrams}',
                      unit: 'g',
                      accentColor: AppColors.primaryForest,
                    ),
                  ),
                ],
              ],
            )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Nutritional information is currently unavailable for this recipe.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
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
            color: AppColors.mutedText,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 2. WHY THIS MEAL? (DYNAMIC RECOMMENDATION REASONS)
  // ==========================================
  Widget _buildWhyThisMeal(MealDetailInfo meal) {
    if (meal.whyReasons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Why this meal?',
          style: AppTypography.sectionTitle.copyWith(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            color: AppColors.darkText,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.pureWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE2EBE5),
              width: 1.0,
            ),
            boxShadow: const [AppColors.softShadow],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: meal.whyReasons.map((reason) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6, right: 10),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.freshGreen,
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
                          color: AppColors.darkText,
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
  // 3. INGREDIENTS SECTION (MATCHING INVENTORY)
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
              style: AppTypography.sectionTitle.copyWith(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
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
                  color: AppColors.primaryForest,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.pureWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE2EBE5),
              width: 1.0,
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
        indicatorColor = AppColors.freshGreen;
        break;
      case IngredientAvailability.partial:
        indicatorColor = AppColors.coralPeach;
        break;
      case IngredientAvailability.missing:
        indicatorColor = const Color(0xFF94A3B8);
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Availability dot
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
                    color: AppColors.darkText,
                  ),
                ),
                Text(
                  'Required: ${item.recipeQuantityText}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: AppColors.mutedText,
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
                horizontal: item.availability == IngredientAvailability.partial ? 8 : 0,
                vertical: item.availability == IngredientAvailability.partial ? 2.5 : 0,
              ),
              decoration: item.availability == IngredientAvailability.partial
                  ? BoxDecoration(
                      color: const Color(0xFFFFECE5),
                      borderRadius: BorderRadius.circular(6),
                    )
                  : null,
              child: Text(
                item.statusLabel,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: item.availability == IngredientAvailability.available
                      ? AppColors.primaryForest
                      : (item.availability == IngredientAvailability.partial
                          ? const Color(0xFFD35400)
                          : AppColors.mutedText),
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
  // 4. RECIPE-SPECIFIC PREPARATION SECTION
  // ==========================================
  Widget _buildPreparationSection(MealDetailInfo meal) {
    final steps = meal.preparationSteps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Preparation',
              style: AppTypography.sectionTitle.copyWith(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
            if (steps.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppColors.paleMint,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD4E7D9), width: 0.8),
                ),
                child: Text(
                  '${steps.length} steps',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryForest,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        if (steps.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.pureWhite,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2EBE5), width: 1.0),
              boxShadow: const [AppColors.softShadow],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.paleMint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.primaryForest,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Step-by-step instructions available via AI',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkText,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Tap "Cook with AI" to generate full preparation steps, timings, and heat levels tailored to your fridge.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedText,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _handleCookWithAi(context, meal),
                    icon: const Icon(Icons.restaurant_menu_rounded, size: 16),
                    label: const Text('Cook with AI'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryForest,
                      backgroundColor: AppColors.paleMint,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.pureWhite,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFE2EBE5),
                width: 1.0,
              ),
              boxShadow: const [AppColors.softShadow],
            ),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: steps.length,
              separatorBuilder: (context, index) => const Divider(
                color: Color(0xFFF4F7F5),
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                final step = steps[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Step Number Circle
                      Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                          color: AppColors.paleMint,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFC8E6C9),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${step.stepNumber}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryForest,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Step Instruction & Metadata
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.instruction,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                                color: AppColors.darkText,
                              ),
                            ),
                            if (step.time != null || step.tip != null || step.temperature != null) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (step.time != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F7F4),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '⏱ ${step.time}',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryForest,
                                        ),
                                      ),
                                    ),
                                  if (step.temperature != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F7F4),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '🔥 ${step.temperature}',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.coralPeach,
                                        ),
                                      ),
                                    ),
                                  if (step.tip != null)
                                    Text(
                                      'Tip: ${step.tip}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        color: AppColors.mutedText,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ==========================================
  // 5. WATCH HOW IT'S MADE — VIDEO CAROUSEL
  // ==========================================
  Widget _buildVideoCarousel(MealDetailInfo meal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Watch how it's made",
          style: AppTypography.sectionTitle.copyWith(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            color: AppColors.darkText,
          ),
        ),
        const SizedBox(height: 8),

        if (meal.videos.isEmpty)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.pureWhite,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFE2EBE5),
                width: 1.0,
              ),
              boxShadow: const [AppColors.softShadow],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _launchVideoSearch(meal),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFECE5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            color: AppColors.coralPeach,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Find cooking videos',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkText,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Watch tutorials for this recipe.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.open_in_new_rounded,
                        color: AppColors.primaryForest,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 195,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: meal.videos.length,
              itemBuilder: (context, index) {
                final video = meal.videos[index];
                return RecipeVideoCard(
                  video: video,
                  onTap: () => _launchVideoUrl(video.videoUrl, meal.name),
                );
              },
            ),
          ),
      ],
    );
  }

  // ==========================================
  // 6. ACTION BUTTONS AT END OF SCROLL
  // ==========================================
  Widget _buildActionButtons(BuildContext context, MealDetailInfo meal) {
    return SafeArea(
      top: false,
      child: Row(
        children: [
          // Left Action: Cook with AI
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: () => _handleCookWithAi(context, meal),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.vibrantLime,
                  foregroundColor: AppColors.primaryForest,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'Cook with AI',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Right Action: Log Meal
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLogging ? null : () => _handleLogMeal(meal),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryForest,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primaryForest.withValues(alpha: 0.6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  _isLogging ? 'Logging...' : 'Log Meal',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
