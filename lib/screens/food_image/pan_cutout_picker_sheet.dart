import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../services/food_image/food_image_service.dart';

/// Bottom sheet for customizing the dedicated transparent ingredient cutout for the Cooking Pan.
class PanCutoutPickerSheet extends StatefulWidget {
  final String entityName;
  final String? category;

  const PanCutoutPickerSheet({
    super.key,
    required this.entityName,
    this.category,
  });

  static Future<String?> show(
    BuildContext context, {
    required String entityName,
    String? category,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PanCutoutPickerSheet(
        entityName: entityName,
        category: category,
      ),
    );
  }

  @override
  State<PanCutoutPickerSheet> createState() => _PanCutoutPickerSheetState();
}

class _PanCutoutPickerSheetState extends State<PanCutoutPickerSheet> {
  late String _currentCutout;
  late String _selectedCutout;
  bool _isLoading = false;
  bool _hasOverride = false;

  static const List<Map<String, String>> _availableCutouts = [
    {'name': 'Paneer', 'asset': 'assets/images/foods/paneer.png'},
    {'name': 'Apple', 'asset': 'assets/images/foods/apple.png'},
    {'name': 'Broccoli', 'asset': 'assets/images/foods/broccoli.png'},
    {'name': 'Eggs', 'asset': 'assets/images/foods/eggs.png'},
    {'name': 'Milk', 'asset': 'assets/images/foods/milk.png'},
    {'name': 'Chicken', 'asset': 'assets/images/foods/chicken.png'},
    {'name': 'Tomato', 'asset': 'assets/images/foods/tomato.png'},
    {'name': 'Carrot', 'asset': 'assets/images/foods/carrot.png'},
    {'name': 'Banana', 'asset': 'assets/images/foods/banana.png'},
    {'name': 'Orange', 'asset': 'assets/images/foods/orange.png'},
    {'name': 'Grapes', 'asset': 'assets/images/foods/grapes.png'},
    {'name': 'Capsicum', 'asset': 'assets/images/foods/capsicum.png'},
    {'name': 'Fish', 'asset': 'assets/images/foods/fish.png'},
    {'name': 'Bread', 'asset': 'assets/images/foods/bread.png'},
    {'name': 'Butter', 'asset': 'assets/images/foods/butter.png'},
    {'name': 'Curd', 'asset': 'assets/images/foods/curd.png'},
    {'name': 'Peas', 'asset': 'assets/images/foods/frozen_peas.png'},
    {'name': 'Corn', 'asset': 'assets/images/foods/frozen_corn.png'},
    {'name': 'Almonds', 'asset': 'assets/images/foods/almonds.png'},
    {'name': 'Cashews', 'asset': 'assets/images/foods/cashews.png'},
    {'name': 'Avocado', 'asset': 'assets/images/foods/avocado.png'},
    {'name': 'Lemon', 'asset': 'assets/images/foods/lemon.png'},
  ];

  @override
  void initState() {
    super.initState();
    _currentCutout = FoodImageService.instance.getPanCutoutSync(
      name: widget.entityName,
      category: widget.category,
    );
    _selectedCutout = _currentCutout;
    _hasOverride = FoodImageService.instance.hasPanOverride(
      name: widget.entityName,
    );
  }

  Future<void> _applySelection() async {
    setState(() => _isLoading = true);
    try {
      await FoodImageService.instance.setPanOverride(
        name: widget.entityName,
        panCutoutUrl: _selectedCutout,
      );
      if (mounted) {
        Navigator.of(context).pop(_selectedCutout);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restoreAutomatic() async {
    setState(() => _isLoading = true);
    try {
      final restored = await FoodImageService.instance.restoreAutomaticPanCutout(
        name: widget.entityName,
        category: widget.category,
      );
      if (mounted) {
        Navigator.of(context).pop(restored);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.82;

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: const BoxDecoration(
        color: AppColors.warmCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: 20 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cooking Pan Cutout',
                    style: AppTypography.heading3.copyWith(
                      color: AppColors.neutralCharcoal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Transparent cutout for ${widget.entityName}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.neutralMedium,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: AppColors.neutralMedium),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Skillet Preview Canvas
          Center(
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFF2E3842),
                    Color(0xFF14191F),
                  ],
                  stops: [0.4, 1.0],
                ),
                border: Border.all(
                  color: const Color(0xFF3F4E5D),
                  width: 2.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Contact shadow on dark skillet
                  Positioned(
                    bottom: 12,
                    child: Container(
                      width: 65,
                      height: 18,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.elliptical(32.5, 9)),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x99000000),
                            blurRadius: 5.0,
                            spreadRadius: 1.0,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Cutout Image with genuine transparency
                  _buildCutoutImage(_selectedCutout, 72),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Dark skillet surface preview',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
                fontSize: 11,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Grid of curated transparent cutouts
          Expanded(
            child: GridView.builder(
              itemCount: _availableCutouts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemBuilder: (context, index) {
                final entry = _availableCutouts[index];
                final asset = entry['asset']!;
                final name = entry['name']!;
                final isSelected = _selectedCutout == asset;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _selectedCutout = asset;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE8F3EE) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.forestGreen : AppColors.cardBorder,
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _buildCutoutImage(asset, 42),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppColors.forestGreen : AppColors.neutralCharcoal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Actions
          Row(
            children: [
              if (_hasOverride) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _restoreAutomatic,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.neutralMedium,
                      side: const BorderSide(color: AppColors.cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: (_isLoading || _selectedCutout == _currentCutout)
                      ? null
                      : _applySelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forestGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Set for Cooking Pan',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCutoutImage(String path, double size) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.restaurant_rounded,
          size: size * 0.6,
          color: AppColors.textTertiary,
        ),
      );
    }
    return Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.restaurant_rounded,
        size: size * 0.6,
        color: AppColors.textTertiary,
      ),
    );
  }
}
