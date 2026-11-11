import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/category_item.dart';
import 'animated_quantity_text.dart';
import 'food_details_sheet.dart';
import '../../food_image/widgets/food_image_view.dart';
import '../../../services/food_image/food_image_model.dart';

/// Modal bottom sheet displaying all inventory items qualifying as "Expiring Soon" (0–3 days).
/// Replicates the visual design, interactions, and layout of the category bottom sheet:
/// - Warm off-white / cream background with large rounded top corners (28 px) and drop shadow.
/// - Top drag handle, header with "⏳ Expiring Soon", item count, and circular close button.
/// - Rounded white inventory item cards with food thumbnail, name, quantity, expiry badge, and chevron.
/// - Tapping an item opens the existing FoodDetailsSheet.
/// - Real-time updates when inventory is modified, added, or deleted.
class ExpiringSoonBottomSheet extends StatefulWidget {
  final ValueChanged<CategoryFoodItem>? onItemTap;

  const ExpiringSoonBottomSheet({
    super.key,
    this.onItemTap,
  });

  /// Opens the Expiring Soon bottom sheet
  static Future<T?> show<T>({
    required BuildContext context,
    ValueChanged<CategoryFoodItem>? onItemTap,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      // Subtle dark translucent overlay keeping refrigerator visible in background
      barrierColor: const Color(0x4D0C1522),
      builder: (sheetContext) => ExpiringSoonBottomSheet(
        onItemTap: onItemTap,
      ),
    );
  }

  @override
  State<ExpiringSoonBottomSheet> createState() => _ExpiringSoonBottomSheetState();
}

class _ExpiringSoonBottomSheetState extends State<ExpiringSoonBottomSheet> {
  @override
  void initState() {
    super.initState();
    FridgeCategoryRepository.notifier.addListener(_onRepositoryChanged);
  }

  @override
  void dispose() {
    FridgeCategoryRepository.notifier.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  void _onRepositoryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleItemTap(CategoryFoodItem item) {
    if (widget.onItemTap != null) {
      widget.onItemTap!(item);
      return;
    }

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
    final items = FridgeCategoryRepository.expiringSoonItems;
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final double maxHeight = (screenHeight * 0.72).clamp(420.0, 720.0);
    final double sheetHeight = items.isEmpty
        ? 320.0
        : (140.0 + (items.length * 76.0)).clamp(340.0, maxHeight);

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F2),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
            // 1. Centered drag handle
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

            // 2. Header: Title, item count, and circular close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '⏳ Expiring Soon',
                          style: TextStyle(
                            fontSize: 19.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.neutralCharcoal,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items.isEmpty
                              ? 'No items'
                              : (items.length == 1 ? '1 item' : '${items.length} items'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: items.isEmpty
                                ? AppColors.textSecondary
                                : const Color(0xFFC85A32),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Circular Close Button matching reference design
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: InkWell(
                      key: const ValueKey('expiring_soon_close_button'),
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(7.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.cardBorder, width: 1.0),
                          boxShadow: const [AppColors.softShadow],
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

            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEBE5DC)),

            // Loading indicator if inventory is actively fetching
            if (FridgeCategoryRepository.isLoading)
              const LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.forestGreen),
              ),

            // Error banner if loading failed
            if (FridgeCategoryRepository.loadError != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBEBEA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF09995)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 18, color: Color(0xFFC53929)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        FridgeCategoryRepository.loadError!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFFC53929)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () => FridgeCategoryRepository.loadFromSupabase(force: true),
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
              ),

            // 3. Scrollable list of expiring food item cards, or clean empty state
            Expanded(
              child: items.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        for (int i = 0; i < items.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          _buildItemRow(context, items[i]),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Single Expiring Item Card matching category bottom sheet design
  Widget _buildItemRow(BuildContext context, CategoryFoodItem item) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1.0),
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
                // Food thumbnail container (~50px)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAF8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.cardBorder,
                      width: 0.8,
                    ),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Center(
                    child: FoodImageView(
                      name: item.name,
                      type: FoodEntityType.ingredient,
                      category: item.category,
                      iconEmoji: item.iconEmoji,
                      fit: BoxFit.contain,
                      fallbackWidget: Text(
                        item.iconEmoji ?? '🍽️',
                        style: const TextStyle(fontSize: 24),
                      ),
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

                // Expiry countdown pill-shaped badge
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

                const SizedBox(width: 6),

                // Right chevron icon
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

  /// Clean empty state when no items qualify as expiring soon
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  size: 32,
                  color: AppColors.forestGreen,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              "You're all set!",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.neutralCharcoal,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'No items are expiring soon.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
