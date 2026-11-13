import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/food_image/food_image_model.dart';
import '../../food_image/widgets/food_image_view.dart';
import '../../home/services/meal_recommendation_service.dart';
import '../../meal_detail/meal_detail_screen.dart';
import '../models/category_item.dart';
import '../services/use_soon_service.dart';
import 'expiring_soon_bottom_sheet.dart';
import 'food_details_sheet.dart';

/// Dedicated "Use Soon" section for Smart Fridge Intelligence v1.
///
/// Features:
/// - Placed below header and above refrigerator appliance.
/// - Title: "Use Soon", Subtitle: "Make the most of your fresh ingredients."
/// - "Find Meals" action button to discover recipes prioritizing expiring items.
/// - Compact horizontal cards with real food photographs via [FoodImageView], name, quantity, and urgency status.
/// - Empty state banner when all items are fresh: "Your fridge is looking fresh! Nothing needs attention right now."
class UseSoonSection extends StatefulWidget {
  final List<CategoryFoodItem>? itemsOverride;
  final VoidCallback? onFindMealsComplete;
  final Future<FreshnessCheckResult> Function()? freshnessCheckOverride;

  const UseSoonSection({
    super.key,
    this.itemsOverride,
    this.onFindMealsComplete,
    this.freshnessCheckOverride,
  });

  @override
  State<UseSoonSection> createState() => _UseSoonSectionState();
}

class _UseSoonSectionState extends State<UseSoonSection> {
  bool _isLoadingFreshness = false;
  String? _freshnessError;
  List<CategoryFoodItem> _expiringItems = [];
  bool _isFindingMeals = false;
  Future<void>? _activeFreshnessOperation;
  int _lastRepositoryVersion = -1;

  @override
  void initState() {
    super.initState();
    _lastRepositoryVersion = FridgeCategoryRepository.notifier.value;
    FridgeCategoryRepository.notifier.addListener(_handleRepositoryChange);
    _runFreshnessCheck();
  }

  @override
  void didUpdateWidget(covariant UseSoonSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.itemsOverride != oldWidget.itemsOverride) {
      _runFreshnessCheck();
    }
  }

  @override
  void dispose() {
    FridgeCategoryRepository.notifier.removeListener(_handleRepositoryChange);
    super.dispose();
  }

  void _handleRepositoryChange() {
    if (!mounted) return;
    if (_lastRepositoryVersion == FridgeCategoryRepository.notifier.value) return;
    _lastRepositoryVersion = FridgeCategoryRepository.notifier.value;
    _runFreshnessCheck();
  }

  void _runFreshnessCheck({bool force = false}) {
    if (_activeFreshnessOperation != null && !force) return;

    // Fast synchronous path 1: Explicit itemsOverride provided
    if (widget.itemsOverride != null) {
      final qualifying = UseSoonService.getUseSoonItems(sourceItems: widget.itemsOverride);
      setState(() {
        _isLoadingFreshness = false;
        _freshnessError = null;
        _expiringItems = qualifying;
      });
      return;
    }

    // Fast synchronous path 2: Local inventory already in memory and not actively loading
    if (FridgeCategoryRepository.totalFridgeItems > 0 && !FridgeCategoryRepository.isLoading) {
      final qualifying = UseSoonService.getUseSoonItems();
      setState(() {
        _isLoadingFreshness = false;
        _freshnessError = null;
        _expiringItems = qualifying;
      });
      return;
    }

    // Async path: When freshness check override is provided or inventory is actively loading
    setState(() {
      _isLoadingFreshness = true;
      _freshnessError = null;
    });

    final operation = _executeFreshnessCheck(force: force);
    _activeFreshnessOperation = operation;
  }

  Future<void> _executeFreshnessCheck({bool force = false}) async {
    try {
      FreshnessCheckResult result;
      if (widget.freshnessCheckOverride != null) {
        result = await widget.freshnessCheckOverride!();
      } else {
        result = await UseSoonService.checkFreshness(
          sourceItems: widget.itemsOverride,
          force: force,
        );
      }

      if (!mounted) return;
      setState(() {
        _isLoadingFreshness = false;
        _freshnessError = result.errorMessage;
        _expiringItems = result.expiringItems;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingFreshness = false;
        _freshnessError = 'Unable to check freshness: $e';
      });
    } finally {
      _activeFreshnessOperation = null;
    }
  }

  void _handleRetry() {
    if (FridgeCategoryRepository.loadError != null) {
      FridgeCategoryRepository.loadFromSupabase(force: true);
    }
    _runFreshnessCheck(force: true);
  }

  void _handleFindMeals(List<CategoryFoodItem> qualifyingItems) async {
    if (_isFindingMeals) return;

    // 1. Collect edible items approaching expiry (0 to 3 days)
    final expiringItems = UseSoonService.getEdibleExpiringItems(sourceItems: qualifyingItems);

    final targetItems = expiringItems.isNotEmpty
        ? expiringItems
        : qualifyingItems.where((it) => it.decimalAmount > 0).toList();

    if (targetItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active ingredients available to generate meals.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isFindingMeals = true;
    });

    try {
      final rec = await MealRecommendationService.generateFromSelectedIngredients(
        selectedItems: targetItems,
        context: context,
      );

      if (!mounted) return;

      if (rec != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MealDetailScreen(recommendation: rec),
          ),
        );
      }
      widget.onFindMealsComplete?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate meals: $e'),
            backgroundColor: const Color(0xFFC53929),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFindingMeals = false;
        });
      }
    }
  }

  void _openItemDetails(CategoryFoodItem item) {
    final categoryName = item.category ??
        FridgeCategoryRepository.getCategoryNameForItem(item.id) ??
        'Others';

    FoodDetailsSheet.show(
      context: context,
      item: item,
      categoryName: categoryName,
      onUseFood: (updatedItem) {
        FridgeCategoryRepository.updateItem(categoryName, updatedItem);
        if (mounted) setState(() {});
      },
      onAddFood: (updatedItem) {
        FridgeCategoryRepository.updateItem(categoryName, updatedItem);
        if (mounted) setState(() {});
      },
      onRemoveFood: () {
        FridgeCategoryRepository.removeItem(categoryName, item.id);
        if (mounted) setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Loading state: checking ingredient freshness
    if (_isLoadingFreshness) {
      return Container(
        key: const ValueKey('use_soon_loading_banner'),
        margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.6)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.forestGreen),
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Checking ingredient freshness...',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.neutralCharcoal,
              ),
            ),
          ],
        ),
      );
    }

    // 2. Error state: failed freshness check or network failure
    if (_freshnessError != null && _expiringItems.isEmpty) {
      return Container(
        key: const ValueKey('use_soon_error_banner'),
        margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFBEBEA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF09995)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 16, color: Color(0xFFC53929)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _freshnessError!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFC53929), fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              key: const ValueKey('use_soon_retry_button'),
              onPressed: _handleRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFC53929)),
              ),
            ),
          ],
        ),
      );
    }

    // 3. Completed state — Nothing expiring soon
    if (_expiringItems.isEmpty) {
      return Container(
        key: const ValueKey('use_soon_empty_banner'),
        margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7F4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDDE6DD)),
        ),
        child: const Row(
          children: [
            Text('🌱', style: TextStyle(fontSize: 16)),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Your fridge is looking fresh!',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forestGreen,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'Nothing needs attention right now.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF556958),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const ValueKey('use_soon_section_container'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Use Soon',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.neutralCharcoal,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.peachLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.peachBorder, width: 0.8),
                          ),
                          child: Text(
                            '${_expiringItems.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.peachText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'Make the most of your fresh ingredients.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // "Find Meals" Primary Action
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey('find_meals_use_soon_btn'),
                  onTap: _isFindingMeals ? null : () => _handleFindMeals(_expiringItems),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
                    decoration: BoxDecoration(
                      color: AppColors.forestGreen,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x221B4332),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isFindingMeals)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        else
                          const Icon(
                            Icons.auto_awesome,
                            size: 13,
                            color: Colors.white,
                          ),
                        const SizedBox(width: 5),
                        Text(
                          _isFindingMeals ? 'Finding...' : 'Find Meals',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Horizontal Ingredient Cards Carousel
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: _expiringItems.length + (_expiringItems.length > 4 ? 1 : 0),
              separatorBuilder: (context, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index < _expiringItems.length) {
                  final item = _expiringItems[index];
                  return _buildIngredientCard(item);
                }
                // "See all" card at the end when there are many items
                return _buildSeeAllCard(context, _expiringItems.length);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientCard(CategoryFoodItem item) {
    final colors = UseSoonService.getUrgencyColors(item);
    final statusLabel = UseSoonService.getExpiryLabel(item);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openItemDetails(item),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 215,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.8), width: 0.9),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 4,
                offset: Offset(0, 1.5),
              ),
            ],
          ),
          child: Row(
            children: [
              // Food image container via FoodImageView
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAF9),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: FoodImageView(
                      name: item.name,
                      type: FoodEntityType.ingredient,
                      category: item.category,
                      width: 44,
                      height: 44,
                      fit: BoxFit.contain,
                      fallbackWidget: Text(
                        item.iconEmoji ?? '🥗',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              // Name, Quantity, and Expiry Pill
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Name & available quantity: e.g. "Apple · 2 pieces"
                    RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: item.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.neutralCharcoal,
                              letterSpacing: -0.2,
                            ),
                          ),
                          TextSpan(
                            text: ' · ${item.displayQuantity}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Visual urgency indicator chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colors.border, width: 0.7),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5.5,
                            height: 5.5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.dot,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: colors.text,
                                letterSpacing: -0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeeAllCard(BuildContext context, int totalCount) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ExpiringSoonBottomSheet.show(context: context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 80,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F7F4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDDE6DD), width: 0.9),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: AppColors.forestGreen,
              ),
              const SizedBox(height: 2),
              Text(
                'See all\n($totalCount)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forestGreen,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
