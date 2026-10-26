import 'package:flutter/material.dart';
import '../models/category_item.dart';

/// Reusable Food Details Bottom Sheet
/// Layered directly above the Category Bottom Sheet.
/// Features:
/// - Centered realistic food product photograph
/// - Food name and subtle expiry status badge
/// - Interactive Quantity Stepper with circular minus (−) and plus (+) buttons
/// - Primary teal/green "✓ Use Food" action
/// - Secondary subtle coral "Remove Food" action with confirmation dialog
/// - Preserves open fridge and category sheet hierarchy
class FoodDetailsSheet extends StatefulWidget {
  final CategoryFoodItem item;
  final String categoryName;
  final ValueChanged<CategoryFoodItem>? onUseFood;
  final VoidCallback? onRemoveFood;

  const FoodDetailsSheet({
    super.key,
    required this.item,
    this.categoryName = 'Fridge',
    this.onUseFood,
    this.onRemoveFood,
  });

  /// Opens the reusable Food Details bottom sheet
  static Future<T?> show<T>({
    required BuildContext context,
    required CategoryFoodItem item,
    String categoryName = 'Fridge',
    ValueChanged<CategoryFoodItem>? onUseFood,
    VoidCallback? onRemoveFood,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      // Stronger dimming over the Category Bottom Sheet to create depth
      barrierColor: const Color(0x660B131D),
      builder: (sheetContext) => FoodDetailsSheet(
        item: item,
        categoryName: categoryName,
        onUseFood: onUseFood,
        onRemoveFood: onRemoveFood,
      ),
    );
  }

  @override
  State<FoodDetailsSheet> createState() => _FoodDetailsSheetState();
}

class _FoodDetailsSheetState extends State<FoodDetailsSheet> {
  late int _currentAmount;
  late String _unit;
  late int _step;

  @override
  void initState() {
    super.initState();
    _currentAmount = widget.item.numericAmount;
    _unit = widget.item.unit;
    _step = widget.item.stepAmount;
  }

  void _decreaseQuantity() {
    if (_currentAmount > _step) {
      setState(() {
        _currentAmount -= _step;
      });
    }
  }

  void _increaseQuantity() {
    setState(() {
      _currentAmount += _step;
    });
  }

  CategoryFoodItem get _updatedItem {
    return widget.item.copyWith(
      quantity: '$_currentAmount $_unit',
    );
  }

  void _handleUseFood() {
    widget.onUseFood?.call(_updatedItem);
    Navigator.of(context).pop();
  }

  void _showRemoveConfirmation() {
    showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFFFCFAF7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Remove ${widget.item.name}?',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        content: Text(
          'Are you sure you want to remove ${widget.item.name} from ${widget.categoryName}?',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFDE8E8),
              foregroundColor: const Color(0xFFDC2626),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text(
              'Remove',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        widget.onRemoveFood?.call();
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F2), // Creamy white background
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x330B1522),
            blurRadius: 32,
            spreadRadius: 3,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Subtle top drag handle
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

              // Header Row with Close Icon
              Align(
                alignment: Alignment.topRight,
                child: Material(
                  color: const Color(0xFFEDE8E1),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(6.0),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 2),

              // 2. Realistic Centered Food Product Visual
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFE8E2D9),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Center(
                    child: (widget.item.effectiveImageAsset != null ||
                            widget.item.imageAsset != null)
                        ? Image.asset(
                            widget.item.effectiveImageAsset ??
                                widget.item.imageAsset!,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (context, error, stackTrace) => Text(
                              widget.item.iconEmoji ?? '🍽️',
                              style: const TextStyle(fontSize: 44),
                            ),
                          )
                        : Text(
                            widget.item.iconEmoji ?? '🍽️',
                            style: const TextStyle(fontSize: 44),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 3. Food Name
              Center(
                child: Text(
                  widget.item.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.2,
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // 4. Subtle Expiry Information Badge
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4.5,
                  ),
                  decoration: BoxDecoration(
                    color: widget.item.statusBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.item.expiryLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.item.statusTextColor,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 5. Quantity Stepper Section
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8E2D9), width: 1),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Quantity',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Minus Button
                        Material(
                          color: _currentAmount > _step
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFFF8FAFC),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _currentAmount > _step ? _decreaseQuantity : null,
                            child: Padding(
                              padding: const EdgeInsets.all(9.0),
                              child: Icon(
                                Icons.remove_rounded,
                                size: 20,
                                color: _currentAmount > _step
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                          ),
                        ),

                        // Animated Quantity Display
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 150),
                            transitionBuilder: (child, anim) => ScaleTransition(
                              scale: anim,
                              child: child,
                            ),
                            child: Text(
                              '$_currentAmount $_unit',
                              key: ValueKey<int>(_currentAmount),
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),

                        // Plus Button
                        Material(
                          color: const Color(0xFFF1F5F9),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _increaseQuantity,
                            child: const Padding(
                              padding: EdgeInsets.all(9.0),
                              child: Icon(
                                Icons.add_rounded,
                                size: 20,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 6. Primary Action: "✓ Use Food" (Teal/Green treatment)
              ElevatedButton(
                onPressed: _handleUseFood,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488), // Refined teal/green
                  foregroundColor: Colors.white,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_rounded, size: 19),
                    SizedBox(width: 8),
                    Text(
                      'Use Food',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // 7. Secondary Action: "Remove Food" (Subtle Coral treatment)
              TextButton.icon(
                onPressed: _showRemoveConfirmation,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 17,
                  color: Color(0xFFE11D48),
                ),
                label: const Text(
                  'Remove Food',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE11D48), // Soft coral
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
