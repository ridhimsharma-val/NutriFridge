import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../fridge/models/category_item.dart';

/// Reusable AI Food Detection Result display and editor
class FoodDetectionResult extends StatefulWidget {
  final String foodName;
  final String initialCategory;
  final int initialQuantity;
  final String unit;
  final int stepAmount;
  final int expiryDays;
  final String? imageAsset;
  final void Function(
    String foodName,
    String category,
    String quantity,
    int expiryDays,
  ) onAddToFridge;

  const FoodDetectionResult({
    super.key,
    required this.foodName,
    required this.initialCategory,
    this.initialQuantity = 250,
    this.unit = 'g',
    this.stepAmount = 50,
    this.expiryDays = 3,
    this.imageAsset,
    required this.onAddToFridge,
  });

  @override
  State<FoodDetectionResult> createState() => _FoodDetectionResultState();
}

class _FoodDetectionResultState extends State<FoodDetectionResult> {
  late int _quantity;
  late String _selectedCategory;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity;
    _selectedCategory = widget.initialCategory;
    _nameController = TextEditingController(text: widget.foodName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _decrease() {
    if (_quantity > widget.stepAmount) {
      setState(() {
        _quantity -= widget.stepAmount;
      });
    }
  }

  void _increase() {
    setState(() {
      _quantity += widget.stepAmount;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Food Image Card
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: AppColors.tealAccent.withValues(alpha: 0.25),
                width: 2.5,
              ),
            ),
            child: ClipOval(
              child: widget.imageAsset != null
                  ? Image.asset(
                      widget.imageAsset!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.fastfood_rounded, size: 48, color: AppColors.tealPrimary),
                    )
                  : const Icon(Icons.fastfood_rounded, size: 48, color: AppColors.tealPrimary),
            ),
          ),
          const SizedBox(height: 16),

          // Food Name
          Text(
            _nameController.text.isNotEmpty ? _nameController.text : widget.foodName,
            style: AppTypography.greeting.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'AI Identified with high confidence',
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Category Editor Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder, width: 1.2),
              boxShadow: const [AppColors.cardShadow],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.category_rounded, size: 18, color: AppColors.tealPrimary),
                    const SizedBox(width: 8),
                    Text(
                      'Detected Category',
                      style: AppTypography.cardTitle.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAF8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.cardBorder,
                      width: 1,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.tealPrimary,
                      ),
                      dropdownColor: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      items: FridgeCategoryRepository.canonicalCategories.map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat,
                          child: Text(
                            cat,
                            style: AppTypography.cardTitle.copyWith(
                              fontSize: 15,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCategory = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Estimated Quantity Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder, width: 1.2),
              boxShadow: const [AppColors.cardShadow],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.scale_rounded, size: 18, color: AppColors.tealPrimary),
                    const SizedBox(width: 8),
                    Text(
                      'Estimated Quantity',
                      style: AppTypography.cardTitle.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Stepper Controls
                    _buildStepButton(
                      icon: Icons.remove_rounded,
                      onTap: _decrease,
                      enabled: _quantity > widget.stepAmount,
                    ),
                    Text(
                      '$_quantity ${widget.unit}',
                      style: AppTypography.greeting.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    _buildStepButton(
                      icon: Icons.add_rounded,
                      onTap: _increase,
                      enabled: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Primary CTA: [ Add to Fridge ]
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                widget.onAddToFridge(
                  _nameController.text.trim().isNotEmpty
                      ? _nameController.text.trim()
                      : widget.foodName,
                  _selectedCategory,
                  '$_quantity ${widget.unit}',
                  widget.expiryDays,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.tealPrimary,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: AppColors.tealPrimary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Add to Fridge',
                    style: AppTypography.cardTitle.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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

  Widget _buildStepButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return Material(
      color: enabled ? const Color(0xFFF1F6F3) : const Color(0xFFF7F8F7),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled ? AppColors.cardBorder : Colors.transparent,
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              size: 22,
              color: enabled ? AppColors.tealPrimary : Colors.grey.shade400,
            ),
          ),
        ),
      ),
    );
  }
}
