import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../meal_detail/meal_detail_screen.dart';
import '../../../models/nutrition_data.dart';
import '../models/category_item.dart';
import '../services/cooking_basket_service.dart';
import '../widgets/cooking_pan_visual.dart';
import '../../home/services/meal_recommendation_service.dart';
import '../../food_image/widgets/food_image_view.dart';
import '../../../services/food_image/food_image_model.dart';

/// Full-screen expanded cooking workspace.
///
/// Features:
/// - Reached via a continuous shared-element `Hero` zoom transition from the collapsed pan.
/// - The cooking pan is the commanding hero element dominating the upper workspace.
/// - First form element: "What would you like to cook?" (dish name input).
/// - Second section: "Selected ingredients · N" with compact removable chips directly on cream canvas.
/// - Primary CTA: "Generate My Meal", supporting both selected ingredients and dish-name-only mode.
class CookingWorkspaceScreen extends StatefulWidget {
  const CookingWorkspaceScreen({super.key});

  @override
  State<CookingWorkspaceScreen> createState() => _CookingWorkspaceScreenState();
}

class _CookingWorkspaceScreenState extends State<CookingWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _dishNameController;
  final FocusNode _dishNameFocusNode = FocusNode();

  // Carousel interactive state (Workspace ONLY)
  late final AnimationController _carouselController;
  late final Animation<double> _carouselAnimation;
  bool _isCarouselOpen = false;
  int _focusedIndex = 0;
  PageController? _pageController;

  @override
  void initState() {
    super.initState();
    _dishNameController = TextEditingController(
      text: CookingBasketService.preferredDishName ?? '',
    );
    _dishNameController.addListener(_onDishNameChanged);

    _carouselController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _carouselAnimation = CurvedAnimation(
      parent: _carouselController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  void _onDishNameChanged() {
    CookingBasketService.setPreferredDishName(_dishNameController.text);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _dishNameController.removeListener(_onDishNameChanged);
    _dishNameController.dispose();
    _dishNameFocusNode.dispose();
    _carouselController.dispose();
    _pageController?.dispose();
    super.dispose();
  }

  void _handlePanTap(int count) {
    if (count == 0) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Your pan is empty. Add ingredients to inspect them!',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: AppColors.forestGreen,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    if (_isCarouselOpen) {
      _carouselController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isCarouselOpen = false;
          });
        }
      });
    } else {
      setState(() {
        _isCarouselOpen = true;
        _focusedIndex = 0;
        _pageController?.dispose();
        _pageController = PageController(viewportFraction: 0.58, initialPage: 0);
      });
      _carouselController.forward(from: 0.0);
    }
  }

  Future<void> _handleGenerateMeal() async {
    final selected = CookingBasketService.selectedItems;
    final dishName = _dishNameController.text.trim();

    // Prevent invocation if both are empty or already generating
    if ((selected.isEmpty && dishName.isEmpty) || CookingBasketService.isGenerating) {
      return;
    }

    _dishNameFocusNode.unfocus();

    RecipeRecommendation? rec;
    if (selected.isNotEmpty) {
      rec = await MealRecommendationService.generateFromSelectedIngredients(
        selectedItems: selected,
        preferredDishName: dishName.isNotEmpty ? dishName : null,
        context: context,
      );
    } else {
      rec = await MealRecommendationService.generateFromDishName(
        dishName: dishName,
        context: context,
      );
    }

    if (!mounted) return;

    if (rec != null) {
      // Navigate to MealDetailScreen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MealDetailScreen(recommendation: rec!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const double shiftRight = 18.0;

    return ListenableBuilder(
      listenable: Listenable.merge([
        CookingBasketService.selectedItemsNotifier,
        CookingBasketService.isGeneratingNotifier,
        CookingBasketService.generationErrorNotifier,
      ]),
      builder: (context, _) {
        final selectedItems = CookingBasketService.selectedItems;
        final count = selectedItems.length;
        final isGenerating = CookingBasketService.isGenerating;
        final error = CookingBasketService.generationError;
        final dishName = _dishNameController.text.trim();

        // Keep carousel synchronized with CookingBasketService
        if (count == 0 && _isCarouselOpen) {
          _isCarouselOpen = false;
          _carouselController.reset();
        } else if (count > 0 && _focusedIndex >= count) {
          _focusedIndex = count - 1;
        }

        final screenWidth = MediaQuery.sizeOf(context).width;
        final panWidth = (screenWidth - 32.0 - (shiftRight * 2)).clamp(300.0, 410.0);
        final panHeight = panWidth * 0.54;

        final bool canGenerate = !isGenerating && (count > 0 || dishName.isNotEmpty);

        return Scaffold(
          backgroundColor: AppColors.warmCream,
          body: SafeArea(
            child: Column(
              children: [
                // 1. Workspace Minimal Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).maybePop(),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.cardWhite,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.cardBorder, width: 1),
                              boxShadow: const [AppColors.cardShadow],
                            ),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              size: 20,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your Cooking Workspace',
                          style: AppTypography.screenHeading.copyWith(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.neutralCharcoal,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: count > 0 ? AppColors.paleMint : AppColors.sageLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: count > 0
                                ? AppColors.forestGreen.withValues(alpha: 0.35)
                                : AppColors.sageAccent.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          count > 0 ? '$count in pan' : 'Empty pan',
                          style: AppTypography.badgeText.copyWith(
                            color: count > 0 ? AppColors.forestGreen : AppColors.neutralMedium,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Scrollable Workspace Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Hero Substantially Zoomed Cooking Pan (Shifted slightly right in Workspace ONLY)
                        Transform.translate(
                          offset: const Offset(shiftRight, 0.0),
                          child: Center(
                            child: Hero(
                              tag: 'cooking_pan_hero',
                              flightShuttleBuilder: (
                                flightContext,
                                animation,
                                flightDirection,
                                fromHeroContext,
                                toHeroContext,
                              ) {
                                final Hero toHero = toHeroContext.widget as Hero;
                                return Material(
                                  color: Colors.transparent,
                                  child: toHero.child,
                                );
                              },
                              child: AnimatedBuilder(
                                animation: _carouselAnimation,
                                builder: (context, _) {
                                  return CookingPanVisual(
                                    width: panWidth,
                                    height: panHeight,
                                    isExpanded: true,
                                    onTap: () => _handlePanTap(count),
                                    contentOpacity: (1.0 - (_carouselAnimation.value * 0.88)).clamp(0.0, 1.0),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: GestureDetector(
                            onTap: () => _handlePanTap(count),
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedBuilder(
                              animation: _carouselAnimation,
                              builder: (context, _) {
                                final isCarouselVisible = _carouselAnimation.value > 0.5;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          count > 0
                                              ? (isCarouselVisible
                                                  ? 'Tap pan to hide carousel'
                                                  : '$count in pan · Tap to inspect')
                                              : 'Your pan is ready',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.forestGreen,
                                          ),
                                        ),
                                      ),
                                      if (count > 0) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          isCarouselVisible
                                              ? Icons.expand_less_rounded
                                              : Icons.touch_app_rounded,
                                          size: 15,
                                          color: AppColors.forestGreen,
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        // INTERACTIVE INGREDIENT CAROUSEL (Workspace ONLY)
                        AnimatedBuilder(
                          animation: _carouselAnimation,
                          builder: (context, child) {
                            if (_carouselAnimation.value <= 0.001) {
                              return const SizedBox.shrink();
                            }
                            return ClipRect(
                              child: Align(
                                alignment: Alignment.topCenter,
                                heightFactor: _carouselAnimation.value,
                                child: Opacity(
                                  opacity: _carouselAnimation.value.clamp(0.0, 1.0),
                                  child: child,
                                ),
                              ),
                            );
                          },
                          child: count > 0 ? _buildPanCarousel(selectedItems) : const SizedBox.shrink(),
                        ),

                        const SizedBox(height: 20),

                        // FIRST FORM ELEMENT: Dish Name Input (Directly on canvas, no heavy box)
                        _buildDishNameSection(),

                        const SizedBox(height: 20),

                        // SECOND SECTION: Selected Ingredients (Directly on canvas, no heavy box)
                        _buildSelectedIngredientsSection(selectedItems),

                        // Inline Error Message (if any)
                        if (error != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDE8E8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFF87171)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: Color(0xFFDC2626), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    error,
                                    style: const TextStyle(
                                      color: Color(0xFF991B1B),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: canGenerate ? _handleGenerateMeal : null,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Retry',
                                    style: TextStyle(
                                      color: Color(0xFFDC2626),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // 3. Bottom Primary CTA: Generate My Meal
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  decoration: BoxDecoration(
                    color: AppColors.warmCream,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isGenerating) ...[
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.forestGreen),
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Creating your meal...',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.forestGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Finding the best way to bring your ingredients together.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.neutralMedium,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: canGenerate ? _handleGenerateMeal : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.forestGreen,
                            disabledBackgroundColor: const Color(0xFFD1D5DB),
                            foregroundColor: Colors.white,
                            disabledForegroundColor: const Color(0xFF9CA3AF),
                            elevation: canGenerate ? 2 : 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Generate My Meal',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                            ),
                          ),
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
    );
  }

  /// First Form Section: Dish Name Input (Minimal, no oversized card)
  Widget _buildDishNameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'What would you like to cook?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neutralCharcoal,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Optional',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutralMedium,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _dishNameController,
          focusNode: _dishNameFocusNode,
          maxLength: 120,
          decoration: InputDecoration(
            hintText: 'e.g. Chicken Curry, Pasta, Salad...',
            hintStyle: TextStyle(
              fontSize: 13,
              color: AppColors.neutralCharcoal.withValues(alpha: 0.45),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            counterText: '',
            prefixIcon: const Icon(
              Icons.restaurant_menu_rounded,
              size: 20,
              color: AppColors.forestGreen,
            ),
            suffixIcon: _dishNameController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _dishNameController.clear();
                      CookingBasketService.setPreferredDishName(null);
                      setState(() {});
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.forestGreen, width: 1.5),
            ),
          ),
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AppColors.neutralCharcoal,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Leave empty and let AI surprise you.',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: AppColors.neutralMedium,
          ),
        ),
      ],
    );
  }

  /// Second Section: Selected Ingredients (Directly on canvas, no outer card)
  Widget _buildSelectedIngredientsSection(List<CategoryFoodItem> selectedItems) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Selected ingredients · ${selectedItems.length}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neutralCharcoal,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (selectedItems.isNotEmpty) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  CookingBasketService.clear();
                  _dishNameController.clear();
                },
                child: const Text(
                  'Clear all',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.coralPeach,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (selectedItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'No ingredients selected from fridge yet. Enter a dish name above or return to the fridge to add ingredients.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.neutralCharcoal.withValues(alpha: 0.60),
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedItems.map((item) => _buildIngredientChip(item)).toList(),
          ),
      ],
    );
  }

  /// Compact Removable Ingredient Chip
  Widget _buildIngredientChip(CategoryFoodItem item) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E4DC), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Food Thumbnail or Emoji
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 24,
              height: 24,
              color: const Color(0xFFF3F7F5),
              child: FoodImageView(
                name: item.name,
                type: FoodEntityType.ingredient,
                category: item.category,
                iconEmoji: item.iconEmoji,
                fit: BoxFit.contain,
                fallbackWidget: Center(
                  child: Text(item.iconEmoji ?? '🥘', style: const TextStyle(fontSize: 13)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Name and Unit-safe quantity
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutralCharcoal,
                ),
              ),
              Text(
                item.displayQuantity,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forestGreen,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          // Small remove button
          GestureDetector(
            onTap: () => CookingBasketService.removeItem(item.id),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(2.0),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Interactive horizontal ingredient carousel (Workspace ONLY)
  Widget _buildPanCarousel(List<CategoryFoodItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    if (_focusedIndex >= items.length) {
      _focusedIndex = items.length - 1;
    }
    _pageController ??= PageController(viewportFraction: 0.58, initialPage: _focusedIndex);

    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 78,
            child: PageView.builder(
              controller: _pageController,
              itemCount: items.length,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _focusedIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final item = items[index];
                final bool isFocused = index == _focusedIndex;

                // Staggered emergence interval
                final double start = (index * 0.12).clamp(0.0, 0.6);
                final double end = (start + 0.4).clamp(0.0, 1.0);
                final double t = Interval(start, end, curve: Curves.easeOutBack)
                    .transform(_carouselAnimation.value);

                final double scale = t.clamp(0.01, 1.0);
                final double angle = (1.0 - t) * (index.isEven ? -0.2 : 0.2);
                final double dy = (1.0 - t) * -22.0;

                return Transform.translate(
                  offset: Offset(0, dy),
                  child: Transform.rotate(
                    angle: angle,
                    child: Transform.scale(
                      scale: scale,
                      child: GestureDetector(
                        onTap: () {
                          if (_focusedIndex != index) {
                            _pageController?.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                            );
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isFocused ? Colors.white : Colors.white.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isFocused ? AppColors.forestGreen : AppColors.cardBorder,
                              width: isFocused ? 1.8 : 1.0,
                            ),
                            boxShadow: [
                              if (isFocused)
                                BoxShadow(
                                  color: AppColors.forestGreen.withValues(alpha: 0.16),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                )
                              else
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.paleMint.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.cardBorder, width: 0.8),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: FoodImageView(
                                    name: item.name,
                                    type: FoodEntityType.ingredient,
                                    category: item.category,
                                    iconEmoji: item.iconEmoji,
                                    fit: BoxFit.contain,
                                    fallbackWidget: Center(
                                      child: Text(item.iconEmoji ?? '🥘',
                                          style: const TextStyle(fontSize: 18)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isFocused ? FontWeight.w800 : FontWeight.w600,
                                        color: isFocused
                                            ? AppColors.textPrimary
                                            : AppColors.neutralCharcoal,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isFocused ? AppColors.paleMint : AppColors.sageLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.displayQuantity,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: isFocused
                                              ? AppColors.forestGreen
                                              : AppColors.neutralMedium,
                                        ),
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
                  ),
                );
              },
            ),
          ),
          if (items.length > 1) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(items.length, (idx) {
                final bool isActive = idx == _focusedIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: isActive ? 14 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.forestGreen
                        : AppColors.forestGreen.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}
