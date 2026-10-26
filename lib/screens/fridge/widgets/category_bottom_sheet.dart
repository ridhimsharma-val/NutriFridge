import 'package:flutter/material.dart';
import '../models/category_item.dart';
import 'food_details_sheet.dart';

/// Large reusable mobile bottom sheet for a food category
/// Features:
/// - Creamy white background with large rounded top corners and soft drop shadow.
/// - Subtle top drag handle and header with category emoji, title, item count, and close button.
/// - Compact, clean vertical inventory rows with realistic food thumbnail, name, quantity,
///   and calm pastel expiry badges (soft coral, soft peach, muted green).
/// - Tapping an item opens the FoodDetailsSheet layered above this category sheet.
/// - Real-time local state updates when items are used or removed.
/// - Secondary "+ Add Food" action button at the bottom.
/// - Keeps the open refrigerator visible in the background via a subtle translucent backdrop.
class CategoryBottomSheet extends StatefulWidget {
  final CategoryData category;
  final VoidCallback? onAddFood;
  final ValueChanged<CategoryFoodItem>? onItemTap;

  const CategoryBottomSheet({
    super.key,
    required this.category,
    this.onAddFood,
    this.onItemTap,
  });

  /// Opens the reusable category bottom sheet
  static Future<T?> show<T>({
    required BuildContext context,
    required CategoryData category,
    VoidCallback? onAddFood,
    ValueChanged<CategoryFoodItem>? onItemTap,
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
        onAddFood: onAddFood,
        onItemTap: onItemTap,
      ),
    );
  }

  @override
  State<CategoryBottomSheet> createState() => _CategoryBottomSheetState();
}

class _CategoryBottomSheetState extends State<CategoryBottomSheet> {
  late CategoryData _category;

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    FridgeCategoryRepository.notifier.addListener(_onRepositoryChanged);
  }

  @override
  void dispose() {
    FridgeCategoryRepository.notifier.removeListener(_onRepositoryChanged);
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
    // Mobile bottom sheet taking ~68% of screen height
    final double sheetHeight = (screenHeight * 0.68).clamp(500.0, 720.0);

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        // Creamy white background
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_category.iconEmoji} ${_category.name}',
                          style: const TextStyle(
                            fontSize: 19.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_category.itemCount} items',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Close Button
                  Material(
                    color: const Color(0xFFEDE8E1),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: const Padding(
                        padding: EdgeInsets.all(7.0),
                        child: Icon(
                          Icons.close_rounded,
                          size: 19,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEBE5DC)),

            // 3. Clean vertical item list
            Expanded(
              child: _category.items.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        for (int i = 0; i < _category.items.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          _buildItemRow(context, _category.items[i]),
                        ],
                      ],
                    ),
            ),

            const Divider(height: 1, thickness: 1, color: Color(0xFFEBE5DC)),

            // 4. Bottom action: "+ Add Food" secondary action
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (widget.onAddFood != null) {
                      widget.onAddFood!();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Add Food to ${_category.name} coming soon'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text(
                    'Add Food',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2C485C),
                    side: const BorderSide(
                      color: Color(0xFFCBD5E1),
                      width: 1.2,
                    ),
                    backgroundColor: Colors.white.withValues(alpha: 0.8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Single Item Row
  Widget _buildItemRow(BuildContext context, CategoryFoodItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E2D9), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _handleItemTap(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Small realistic food visual container (~50px)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F4EF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFE8E2D9),
                      width: 0.8,
                    ),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Center(
                    child: (item.effectiveImageAsset != null || item.imageAsset != null)
                        ? Image.asset(
                            item.effectiveImageAsset ?? item.imageAsset!,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (context, error, stackTrace) => Text(
                              item.iconEmoji ?? '🍽️',
                              style: const TextStyle(fontSize: 24),
                            ),
                          )
                        : Text(
                            item.iconEmoji ?? '🍽️',
                            style: const TextStyle(fontSize: 24),
                          ),
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
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.quantity,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                // Expiry Tag Badge with subtle status colors
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.5,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: item.statusBackgroundColor,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    item.expiryLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: item.statusTextColor,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // Subtle chevron arrow affordance
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: Color(0xFFA0AEC0),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _category.iconEmoji,
            style: const TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 10),
          Text(
            'No items in ${_category.name}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap "+ Add Food" below to stock this shelf',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
