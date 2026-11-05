import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/notification_data.dart';
import '../models/category_item.dart';
import 'animated_quantity_text.dart';

/// Reusable Food Details Bottom Sheet
/// Layered directly above the Category Bottom Sheet.
/// Features:
/// - Realistic food product visual
/// - Food name and subtle expiry status badge
/// - Distinct Available Quantity display ("Available in fridge: X")
/// - Interactive Quantity Stepper for operation quantity ("Quantity to use or add")
/// - Primary teal/green "Use Food" action (subtracts selected quantity from available stock)
/// - Secondary outlined "+ Add Food" action (increases available stock by selected quantity)
/// - Rejects operation with validation feedback if attempting to use more than available
/// - Removes item from active inventory if remaining quantity reaches zero
/// - Immediately synchronizes with FridgeCategoryRepository and NotificationRepository
class FoodDetailsSheet extends StatefulWidget {
  final CategoryFoodItem item;
  final String categoryName;
  final ValueChanged<CategoryFoodItem>? onUseFood;
  final ValueChanged<CategoryFoodItem>? onAddFood;
  final VoidCallback? onRemoveFood;
  final VoidCallback? onInventoryChanged;

  const FoodDetailsSheet({
    super.key,
    required this.item,
    this.categoryName = 'Fridge',
    this.onUseFood,
    this.onAddFood,
    this.onRemoveFood,
    this.onInventoryChanged,
  });

  /// Opens the reusable Food Details bottom sheet
  static Future<T?> show<T>({
    required BuildContext context,
    required CategoryFoodItem item,
    String categoryName = 'Fridge',
    ValueChanged<CategoryFoodItem>? onUseFood,
    ValueChanged<CategoryFoodItem>? onAddFood,
    VoidCallback? onRemoveFood,
    VoidCallback? onInventoryChanged,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x660B131D),
      builder: (sheetContext) => FoodDetailsSheet(
        item: item,
        categoryName: categoryName,
        onUseFood: onUseFood,
        onAddFood: onAddFood,
        onRemoveFood: onRemoveFood,
        onInventoryChanged: onInventoryChanged,
      ),
    );
  }

  @override
  State<FoodDetailsSheet> createState() => _FoodDetailsSheetState();
}

class _FoodDetailsSheetState extends State<FoodDetailsSheet> {
  late CategoryFoodItem _item;
  late int _availableAmount;
  late int _selectedAmount;
  late String _unit;
  late int _step;
  String? _errorMessage;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _availableAmount = widget.item.numericAmount;
    _unit = widget.item.unit;
    _step = widget.item.stepAmount;
    _selectedAmount = _computeSensibleDefault(_availableAmount, _unit, _step);
  }

  static int _computeSensibleDefault(int available, String unit, int step) {
    final u = unit.toLowerCase();
    if (u == 'g' || u == 'ml') {
      if (available >= 100) return 100;
      if (available >= 50) return 50;
      return available > 0 ? available : 50;
    }
    // For pieces, pack, bottle, jar, tub, box, L, etc.:
    // Never automatically select the entire available stock as the amount to use.
    if (available > 1) {
      return 1;
    }
    return available > 0 ? 1 : 1;
  }

  static String _formatAmount(int amount, String unit) {
    return '$amount $unit'.trim();
  }

  String _formatActionDescription(int amount, String unit, String name, bool isAdd) {
    final action = isAdd ? 'added successfully.' : 'used successfully.';
    final uLower = unit.toLowerCase();
    if (uLower == 'pieces' || uLower == 'piece') {
      final displayName = (amount > 1 && !name.toLowerCase().endsWith('s')) ? '${name}s' : name;
      return '$amount $displayName $action';
    }
    return '$amount $unit $name $action';
  }

  void _decreaseQuantity() {
    if (_selectedAmount > _step) {
      setState(() {
        _selectedAmount -= _step;
        _errorMessage = null;
      });
    }
  }

  void _increaseQuantity() {
    setState(() {
      _selectedAmount += _step;
      _errorMessage = null;
    });
  }

  void _handleUseFood() {
    if (_isProcessing) return;

    if (_selectedAmount > _availableAmount) {
      final msg =
          'Cannot use ${_formatAmount(_selectedAmount, _unit)}. Only ${_formatAmount(_availableAmount, _unit)} available in fridge.';
      setState(() {
        _errorMessage = msg;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final usedAmount = _selectedAmount;
    final remaining = _availableAmount - usedAmount;
    final successMsg = _formatActionDescription(usedAmount, _unit, _item.name, false);

    final result = FridgeCategoryRepository.deductItemQuantity(
      itemId: _item.id,
      categoryIdOrName: widget.categoryName,
      quantity: usedAmount,
      unit: _unit,
    );

    if (result.status == DeductionStatus.removed) {
      widget.onRemoveFood?.call();
      widget.onInventoryChanged?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMsg),
          backgroundColor: const Color(0xFF0D9488),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pop();
    } else if (result.status == DeductionStatus.success) {
      final updatedItem = result.updatedItem ?? _item.copyWith(
        quantity: _formatAmount(remaining, _unit),
      );
      widget.onUseFood?.call(updatedItem);
      widget.onInventoryChanged?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMsg),
          backgroundColor: const Color(0xFF0D9488),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );

      // Update in-place so user immediately sees remaining stock
      setState(() {
        _availableAmount = remaining;
        _item = updatedItem;
        _selectedAmount = _computeSensibleDefault(remaining, _unit, _step);
        _isProcessing = false;
      });
    } else {
      setState(() {
        _isProcessing = false;
        _errorMessage = result.message;
      });
      return;
    }
  }

  void _handleAddFood() {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final addedAmount = _selectedAmount;
    final newTotal = _availableAmount + addedAmount;
    final successMsg = _formatActionDescription(addedAmount, _unit, _item.name, true);

    final updatedItem = _item.copyWith(
      quantity: _formatAmount(newTotal, _unit),
    );

    FridgeCategoryRepository.updateItem(widget.categoryName, updatedItem);
    NotificationRepository.addNotification(
      title: 'Inventory update',
      description: '${_formatAmount(addedAmount, _unit)} ${_item.name} added to fridge.',
      type: NotificationType.inventoryUpdate,
    );

    widget.onAddFood?.call(updatedItem);
    widget.onInventoryChanged?.call();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(successMsg),
        backgroundColor: const Color(0xFF0D9488),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );

    // Update in-place so user immediately sees increased stock
    setState(() {
      _availableAmount = newTotal;
      _item = updatedItem;
      _isProcessing = false;
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
                    child: (_item.effectiveImageAsset != null || _item.imageAsset != null)
                        ? Image.asset(
                            _item.effectiveImageAsset ?? _item.imageAsset!,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (context, error, stackTrace) => Text(
                              _item.iconEmoji ?? '🍽️',
                              style: const TextStyle(fontSize: 44),
                            ),
                          )
                        : Text(
                            _item.iconEmoji ?? '🍽️',
                            style: const TextStyle(fontSize: 44),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 3. Food Name
              Center(
                child: Text(
                  _item.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.neutralCharcoal,
                    letterSpacing: -0.3,
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
                    color: _item.statusBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _item.statusBorderColor,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5.5,
                        height: 5.5,
                        margin: const EdgeInsets.only(right: 5.5),
                        decoration: BoxDecoration(
                          color: _item.statusAccentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        _item.expiryLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _item.statusTextColor,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // 5. Distinct Available Quantity in Fridge Display
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
                  decoration: BoxDecoration(
                    color: AppColors.paleMint,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.sageAccent.withValues(alpha: 0.35),
                      width: 1.0,
                    ),
                  ),
                  child: AnimatedQuantityText(
                    value: _availableAmount,
                    unit: _unit,
                    prefix: 'Available in fridge: ',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forestGreen,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 6. Quantity Stepper Section (Quantity to use or add)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder, width: 1),
                  boxShadow: const [AppColors.softShadow],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Quantity to use or add',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Minus Button
                        Material(
                          color: _selectedAmount > _step
                              ? AppColors.paleMint
                              : const Color(0xFFF3F5F4),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _selectedAmount > _step ? _decreaseQuantity : null,
                            child: Padding(
                              padding: const EdgeInsets.all(9.0),
                              child: Icon(
                                Icons.remove_rounded,
                                size: 20,
                                color: _selectedAmount > _step
                                    ? AppColors.forestGreen
                                    : AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ),

                        // Animated Selected Quantity Display
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 150),
                            transitionBuilder: (child, anim) => ScaleTransition(
                              scale: anim,
                              child: child,
                            ),
                            child: Text(
                              _formatAmount(_selectedAmount, _unit),
                              key: ValueKey<int>(_selectedAmount),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.neutralCharcoal,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ),

                        // Plus Button
                        Material(
                          color: AppColors.paleMint,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _increaseQuantity,
                            child: const Padding(
                              padding: EdgeInsets.all(9.0),
                              child: Icon(
                                Icons.add_rounded,
                                size: 20,
                                color: AppColors.forestGreen,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Inline Validation Message for Excess Use
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE8E8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF87171), width: 0.8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // 7. Action 1: Primary "Use Food" (Teal/Green filled button)
              ElevatedButton(
                onPressed: _isProcessing ? null : _handleUseFood,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Use Food',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // 8. Action 2: Secondary "+ Add Food" (Outlined button)
              OutlinedButton(
                onPressed: _isProcessing ? null : _handleAddFood,
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.sageLight,
                  foregroundColor: AppColors.forestGreen,
                  side: BorderSide(
                    color: AppColors.sageAccent.withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  '+ Add Food',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
