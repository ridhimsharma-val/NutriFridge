import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/category_item.dart';
import '../services/cooking_basket_service.dart';
import 'animated_quantity_text.dart';
import 'food_details_sheet.dart';
import 'cooking_pan_widget.dart';
import 'cooking_pan_visual.dart';
import 'flying_ingredient_overlay.dart';
import '../../food_image/widgets/food_image_view.dart';
import '../../../services/food_image/food_image_model.dart';

/// Large reusable mobile bottom sheet for a food category
/// Features:
/// - Creamy white background with large rounded top corners and soft drop shadow.
/// - Subtle top drag handle and header with category emoji, title, item count, and close button.
/// - Compact, clean vertical inventory rows with realistic food thumbnail, name, quantity,
///   and calm pastel expiry badges (soft coral, soft peach, muted green).
/// - In normal mode: Tapping an item opens the FoodDetailsSheet layered above this category sheet.
/// - In selection mode: Tapping an item toggles selection into the Cooking Basket.
/// - Real-time local state updates when items are used or removed.
/// - Keeps the open refrigerator visible in the background via a subtle translucent backdrop.
class CategoryBottomSheet extends StatefulWidget {
  final CategoryData category;
  final ValueChanged<CategoryFoodItem>? onItemTap;
  final bool isSelectionMode;

  const CategoryBottomSheet({
    super.key,
    required this.category,
    this.onItemTap,
    this.isSelectionMode = false,
  });

  /// Opens the reusable category bottom sheet
  static Future<T?> show<T>({
    required BuildContext context,
    required CategoryData category,
    ValueChanged<CategoryFoodItem>? onItemTap,
    bool isSelectionMode = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      // Subtle dark translucent overlay so refrigerator remains visible in background
      barrierColor: const Color(0x4D0C1522),
      builder: (sheetContext) => CategoryBottomSheet(
        category: category,
        onItemTap: onItemTap,
        isSelectionMode: isSelectionMode,
      ),
    );
  }

  @override
  State<CategoryBottomSheet> createState() => _CategoryBottomSheetState();
}

class _CategoryBottomSheetState extends State<CategoryBottomSheet> {
  final GlobalKey _bottomSheetPanKey = GlobalKey();
  final Map<String, GlobalKey> _itemThumbnailKeys = {};
  late CategoryData _category;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  GlobalKey _getItemKey(String id) =>
      _itemThumbnailKeys.putIfAbsent(id, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    FridgeCategoryRepository.notifier.addListener(_onRepositoryChanged);
    if (widget.isSelectionMode) {
      CookingPanCoordinator.bottomSheetPanKey = _bottomSheetPanKey;
      CookingPanCoordinator.activeTargetKey = _bottomSheetPanKey;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    FridgeCategoryRepository.notifier.removeListener(_onRepositoryChanged);
    if (CookingPanCoordinator.activeTargetKey == _bottomSheetPanKey) {
      CookingPanCoordinator.activeTargetKey = CookingPanCoordinator.mainPanKey;
    }
    if (CookingPanCoordinator.bottomSheetPanKey == _bottomSheetPanKey) {
      CookingPanCoordinator.bottomSheetPanKey = null;
    }
    super.dispose();
  }

  void _onRepositoryChanged() {
    if (mounted) {
      setState(() {
        _category = FridgeCategoryRepository.getCategoryData(_category.name);
      });
    }
  }

  @override
  void didUpdateWidget(covariant CategoryBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.category != oldWidget.category) {
      _category = widget.category;
    }
  }

  void _handleItemTap(CategoryFoodItem item) {
    if (widget.onItemTap != null) {
      widget.onItemTap!(item);
      return;
    }

    if (widget.isSelectionMode) {
      final wasSelected = CookingBasketService.isSelected(item);
      if (wasSelected) {
        // Deselect immediately
        CookingBasketService.toggleItem(item);
        setState(() {});
      } else {
        // Select & animate flying thumbnail into pan
        final sourceKey = _itemThumbnailKeys[item.id];
        final targetKey =
            CookingPanCoordinator.activeTargetKey ?? _bottomSheetPanKey;

        if (sourceKey != null) {
          FlyingIngredientHelper.flyIngredient(
            context: context,
            sourceKey: sourceKey,
            targetKey: targetKey,
            item: item,
            onLanded: () {
              if (mounted) setState(() {});
            },
          );
        }
        CookingBasketService.toggleItem(item);
        setState(() {});
      }
      return;
    }

    // Default flow: open FoodDetailsSheet layered directly above this sheet
    FoodDetailsSheet.show(
      context: context,
      item: item,
      categoryName: _category.name,
      onUseFood: (updatedItem) {
        FridgeCategoryRepository.updateItem(_category.id, updatedItem);
        setState(() {
          _category = FridgeCategoryRepository.getCategoryData(_category.name);
        });
      },
      onAddFood: (updatedItem) {
        FridgeCategoryRepository.updateItem(_category.id, updatedItem);
        setState(() {
          _category = FridgeCategoryRepository.getCategoryData(_category.name);
        });
      },
      onRemoveFood: () {
        FridgeCategoryRepository.removeItem(_category.id, item.id);
        setState(() {
          _category = FridgeCategoryRepository.getCategoryData(_category.name);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.sizeOf(context).height;
    // Mobile bottom sheet taking ~82% in selection mode (for standalone pan + Add card) or ~72% normally
    final double sheetHeight = widget.isSelectionMode
        ? (screenHeight * 0.82).clamp(560.0, 800.0)
        : (screenHeight * 0.72).clamp(500.0, 750.0);

    final filteredItems = _category.items.where((it) {
      if (_searchQuery.isEmpty) return true;
      return it.name.toLowerCase().contains(_searchQuery);
    }).toList();

    return ListenableBuilder(
      listenable: CookingBasketService.selectedItemsNotifier,
      builder: (context, _) {
        return Container(
          height: sheetHeight,
          decoration: const BoxDecoration(
            color: Color(0xFFFAF7F2),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color(0x280B1522),
                blurRadius: 28,
                spreadRadius: 2,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Subtle drag handle
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 38,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6DDD8),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // 2. Header: Category emoji + title, item count, and Close button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              _category.iconEmoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _category.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.neutralCharcoal,
                                  letterSpacing: -0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.paleMint,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFC8E6C9), width: 1),
                              ),
                              child: Text(
                                '${_category.items.length} items',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.forestGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE9E3),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFDDD7CE), width: 1),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 19,
                              color: AppColors.neutralCharcoal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 3. Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (text) => setState(() => _searchQuery = text.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search ${_category.name}...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: AppColors.neutralCharcoal.withValues(alpha: 0.4),
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.neutralMedium),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: Colors.white,
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
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),

                const SizedBox(height: 10),
                const Divider(height: 1, thickness: 1, color: Color(0xFFEBE5DC)),

                // 4. Vertical item list
                Expanded(
                  child: filteredItems.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredItems.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) => _buildItemRow(context, filteredItems[i]),
                        ),
                ),

                // 5. Standalone Large Cooking Pan (Prominent visual element, outside any card container)
                if (widget.isSelectionMode) ...[
                  Builder(
                    builder: (context) {
                      final screenWidth = MediaQuery.sizeOf(context).width;
                      // Substantially enlarged standalone pan (~250-290px wide x 135-156px high), centered horizontally
                      final double standalonePanWidth = (screenWidth - 48.0).clamp(240.0, 290.0);
                      final double standalonePanHeight = standalonePanWidth * 0.54;

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Center(
                          child: CookingPanVisual(
                            key: _bottomSheetPanKey,
                            panKey: _bottomSheetPanKey,
                            width: standalonePanWidth,
                            height: standalonePanHeight,
                            isCompact: false,
                            showEmptyGuide: false,
                          ),
                        ),
                      );
                    },
                  ),

                  // 6. Separate Full-Width Add Action Card directly below the standalone pan
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFEBE5DC))),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 8,
                          offset: Offset(0, -3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                CookingBasketService.count == 0
                                    ? '0 items in pan'
                                    : '${CookingBasketService.count} item${CookingBasketService.count > 1 ? 's' : ''} in pan',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.neutralCharcoal,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                CookingBasketService.count == 0
                                    ? 'Tap items above to add'
                                    : 'In pan: ${CookingBasketService.selectedItems.map((e) => e.name).take(2).join(', ')}${CookingBasketService.count > 2 ? '...' : ''}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.neutralMedium,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.forestGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Add',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Single Item Row
  Widget _buildItemRow(BuildContext context, CategoryFoodItem item) {
    final isSelected = widget.isSelectionMode && CookingBasketService.isSelected(item);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEAF7EE) : AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.forestGreen : AppColors.cardBorder,
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: const [AppColors.softShadow],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleItemTap(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9.5),
            child: Row(
              children: [
                // Small realistic food visual container (~50px)
                Container(
                  key: widget.isSelectionMode ? _getItemKey(item.id) : null,
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFDDF3E7) : const Color(0xFFF7FAF8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.forestGreen.withValues(alpha: 0.35)
                          : AppColors.cardBorder,
                      width: 0.8,
                    ),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Center(
                    child: _buildItemImage(item),
                  ),
                ),

                const SizedBox(width: 12),

                // Name & Quantity
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutralCharcoal,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedQuantityText(
                        value: item.decimalAmount,
                        unit: item.unit,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Expiry Tag Badge with subtle status colors
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4.5,
                  ),
                  decoration: BoxDecoration(
                    color: item.statusBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.expiryLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: item.statusTextColor,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Trailing Action: In Selection mode, show Checkbox / checkmark icon; otherwise Chevron
                if (widget.isSelectionMode)
                  Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 22,
                    color: isSelected ? AppColors.forestGreen : const Color(0xFF9CA3AF),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 19,
                    color: AppColors.textTertiary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _category.iconEmoji,
              style: const TextStyle(fontSize: 42),
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ? 'No items match "$_searchQuery"' : 'Nothing here yet',
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try searching for another ingredient name.'
                  : 'Add food using NutriFridge AI.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemImage(CategoryFoodItem item) {
    final emoji = item.iconEmoji ?? FoodItemAssetRegistry.getEmojiForItem(item.name, item.category ?? _category.name);
    return FoodImageView(
      name: item.name,
      type: FoodEntityType.ingredient,
      category: item.category ?? _category.name,
      iconEmoji: emoji,
      fit: BoxFit.contain,
      fallbackWidget: Text(
        emoji,
        style: const TextStyle(fontSize: 24),
      ),
    );
  }
}
