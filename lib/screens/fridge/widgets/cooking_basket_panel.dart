import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/transitions/hero_transition_route.dart';
import '../../meal_detail/meal_detail_screen.dart';
import '../models/category_item.dart';
import '../services/cooking_basket_service.dart';
import '../../home/services/meal_recommendation_service.dart';

/// Persistent cooking basket bottom panel for "Use My Ingredients" mode.
/// Allows viewing selected ingredients, removing items, typing an optional dish name,
/// and triggering AI meal generation with genuine loading stages and error recovery.
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

  Timer? _stageTimer;
  int _currentStageIndex = 0;
  static const List<String> _generationStages = [
    'Checking selected ingredients...',
    'Creating your recipe with AI...',
    'Preparing cooking instructions...',
  ];

  @override
  void initState() {
    super.initState();
    _dishNameController = TextEditingController(
      text: CookingBasketService.preferredDishName ?? '',
    );
    _dishNameController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    _dishNameController.dispose();
    super.dispose();
  }

  void _startStageTimer() {
    _stageTimer?.cancel();
    _currentStageIndex = 0;
    _stageTimer = Timer.periodic(const Duration(milliseconds: 2200), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _currentStageIndex = (_currentStageIndex + 1) % _generationStages.length;
      });
    });
  }

  void _stopStageTimer() {
    _stageTimer?.cancel();
    _stageTimer = null;
    _currentStageIndex = 0;
  }

  Future<void> _handleGenerateMeal() async {
    final selected = CookingBasketService.selectedItems;
    if (selected.isEmpty || CookingBasketService.isGenerating) return;

    final dishName = _dishNameController.text.trim().isNotEmpty
        ? _dishNameController.text.trim()
        : null;

    CookingBasketService.setPreferredDishName(dishName);
    _startStageTimer();

    final rec = await MealRecommendationService.generateFromSelectedIngredients(
      selectedItems: selected,
      preferredDishName: dishName,
      context: context,
    );

    _stopStageTimer();
    if (!mounted) return;

    if (rec != null) {
      widget.onMealGenerated?.call();
      await Navigator.of(context).push(
        HeroTransitionRoute(
          page: MealDetailScreen(recommendation: rec),
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

        if (isGenerating && _stageTimer == null) {
          _startStageTimer();
        } else if (!isGenerating && _stageTimer != null) {
          _stopStageTimer();
        }

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
            10,
            16,
            10 + MediaQuery.of(context).padding.bottom,
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isGenerating
                ? _buildGeneratingState(count)
                : _isExpanded
                    ? _buildExpandedContent(items, count, isGenerating, error)
                    : _buildCollapsedContent(count, isGenerating),
          ),
        );
      },
    );
  }

  // ==========================================
  // COLLAPSED STATE
  // ==========================================
  Widget _buildCollapsedContent(int count, bool isGenerating) {
    return InkWell(
      onTap: () => setState(() => _isExpanded = true),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Your Cooking Basket',
                    style: TextStyle(
                      fontSize: 14,
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
            if (count > 0) ...[
              ElevatedButton(
                onPressed: _handleGenerateMeal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      'Generate · $count',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
            ],
            IconButton(
              icon: const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: AppColors.neutralMedium,
              ),
              onPressed: () => setState(() => _isExpanded = true),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // EXPANDED STATE
  // ==========================================
  Widget _buildExpandedContent(
    List<CategoryFoodItem> items,
    int count,
    bool isGenerating,
    String? error,
  ) {
    return Column(
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
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.neutralMedium,
              ),
              onPressed: () => setState(() => _isExpanded = false),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),

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
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
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
                      // Thumbnail image or emoji
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FAF8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: (item.effectiveImageAsset != null || item.imageAsset != null)
                              ? Image.asset(
                                  item.effectiveImageAsset ?? item.imageAsset!,
                                  width: 18,
                                  height: 18,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => Text(
                                    item.iconEmoji ?? '🥗',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                )
                              : Text(
                                  item.iconEmoji ?? '🥗',
                                  style: const TextStyle(fontSize: 13),
                                ),
                        ),
                      ),
                      const SizedBox(width: 6),
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

        const SizedBox(height: 10),

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
                suffixIcon: _dishNameController.text.isNotEmpty && !isGenerating
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.neutralMedium),
                        onPressed: () {
                          _dishNameController.clear();
                          CookingBasketService.setPreferredDishName(null);
                        },
                      )
                    : null,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFCA5A5),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Color(0xFFB91C1C),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _handleGenerateMeal,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF87171)),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 10),

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
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(
              count == 0
                  ? 'Select Ingredients to Cook'
                  : 'Generate My Meal · $count',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // INTENTIONAL AI GENERATION WAITING EXPERIENCE
  // ==========================================
  Widget _buildGeneratingState(int count) {
    final currentStage = _generationStages[_currentStageIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.paleMint,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.forestGreen.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.forestGreen),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Creating your meal',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: AppColors.neutralCharcoal,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Finding the best way to combine your ingredients...',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.neutralMedium,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Container(
              key: ValueKey(currentStage),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.cardBorder,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 13,
                    color: AppColors.forestGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    currentStage,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.forestGreen,
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
}
