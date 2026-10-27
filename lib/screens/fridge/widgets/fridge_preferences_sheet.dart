import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/fridge_preferences.dart';

/// Modal bottom sheet allowing users to personalize their Fridge finish and compartment layout.
///
/// Features:
/// - Four selectable refrigerator exterior color finishes (Midnight Navy, Matte Black, Pearl White, Sage Green).
/// - Two freezer compartment arrangements (Freezer on Top, Freezer on Bottom).
/// - Safe local draft state until user confirms with "Apply Changes".
/// - Dismissing / closing the sheet safely discards unapplied selections.
class FridgePreferencesSheet extends StatefulWidget {
  final FridgePreferences initialPreferences;

  const FridgePreferencesSheet({
    super.key,
    required this.initialPreferences,
  });

  /// Opens the Fridge Preferences bottom sheet
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x4D0C1522),
      builder: (sheetContext) => FridgePreferencesSheet(
        initialPreferences: FridgePreferencesRepository.current,
      ),
    );
  }

  @override
  State<FridgePreferencesSheet> createState() => _FridgePreferencesSheetState();
}

class _FridgePreferencesSheetState extends State<FridgePreferencesSheet> {
  late FridgeColorFinish _selectedColor;
  late FreezerPosition _selectedPosition;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialPreferences.exteriorColor;
    _selectedPosition = widget.initialPreferences.freezerPosition;
  }

  void _onApply() {
    if (_isApplying) return;
    setState(() {
      _isApplying = true;
    });

    final updated = FridgePreferences(
      exteriorColor: _selectedColor,
      freezerPosition: _selectedPosition,
    );
    FridgePreferencesRepository.update(updated);

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F2), // Creamy warm-white surface
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
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 10,
            bottom: MediaQuery.of(context).padding.bottom > 0 ? 12 : 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Subtle drag handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD3DDD7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 2. Header: Title, subtitle & close button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fridge Preferences',
                          style: AppTypography.sectionTitle.copyWith(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Make your fridge feel like yours.',
                          style: AppTypography.subtitle.copyWith(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(false),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.cardBorder,
                            width: 1,
                          ),
                          boxShadow: const [AppColors.cardShadow],
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              const Divider(color: Color(0xFFE8EDE9), height: 1),
              const SizedBox(height: 16),

              // 3. Section 1: Fridge Colour
              Text(
                'Fridge Colour',
                style: AppTypography.cardTitle.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Choose the finish for your refrigerator.',
                style: AppTypography.subtitle.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),

              // 4 Color Swatches
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: FridgeColorFinish.values.map((finish) {
                  final isSelected = finish == _selectedColor;
                  return _buildColorSwatchItem(finish, isSelected);
                }).toList(),
              ),

              const SizedBox(height: 20),
              const Divider(color: Color(0xFFE8EDE9), height: 1),
              const SizedBox(height: 16),

              // 4. Section 2: Freezer Position
              Text(
                'Freezer Position',
                style: AppTypography.cardTitle.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Choose your refrigerator layout.',
                style: AppTypography.subtitle.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),

              // 2 Segmented Layout Option Cards
              Row(
                children: [
                  Expanded(
                    child: _buildLayoutOptionCard(
                      position: FreezerPosition.top,
                      isSelected: _selectedPosition == FreezerPosition.top,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildLayoutOptionCard(
                      position: FreezerPosition.bottom,
                      isSelected: _selectedPosition == FreezerPosition.bottom,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 5. Primary "Apply Changes" Action Button
              ElevatedButton(
                key: const ValueKey('apply_fridge_preferences_button'),
                onPressed: _isApplying ? null : _onApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tealPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.tealPrimary.withValues(alpha: 0.6),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  shadowColor: AppColors.tealPrimary.withValues(alpha: 0.25),
                ),
                child: const Text(
                  'Apply Changes',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorSwatchItem(FridgeColorFinish finish, bool isSelected) {
    final checkmarkColor =
        finish.isLight ? AppColors.tealPrimary : Colors.white;

    return Expanded(
      child: InkWell(
        key: ValueKey('swatch_${finish.name}'),
        onTap: () {
          setState(() {
            _selectedColor = finish;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer ring indicator when selected
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: finish.swatchColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.tealPrimary
                            : const Color(0xFFD6DDD7),
                        width: isSelected ? 2.8 : 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isSelected ? 0.16 : 0.08,
                          ),
                          blurRadius: isSelected ? 8 : 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: isSelected
                        ? Center(
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: finish.isLight
                                    ? Colors.white.withValues(alpha: 0.85)
                                    : Colors.black.withValues(alpha: 0.40),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: checkmarkColor,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  finish.displayName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.tealPrimary
                        : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayoutOptionCard({
    required FreezerPosition position,
    required bool isSelected,
  }) {
    final bool isTop = position == FreezerPosition.top;

    return InkWell(
      key: ValueKey('layout_option_${position.name}'),
      onTap: () {
        setState(() {
          _selectedPosition = position;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.tealLight.withValues(alpha: 0.45)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.tealPrimary
                : const Color(0xFFDEE5E0),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isSelected ? 0.06 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Miniature Refrigerator Silhouette representation
            SizedBox(
              height: 44,
              width: 32,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEBE6),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.tealPrimary.withValues(alpha: 0.6)
                        : const Color(0xFFCFD8D2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Top Compartment
                    Expanded(
                      flex: isTop ? 4 : 8,
                      child: Container(
                        margin: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: isTop
                              ? AppColors.tealPrimary.withValues(alpha: 0.75)
                              : const Color(0xFFFBFBF9),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Center(
                          child: isTop
                              ? const Icon(
                                  Icons.ac_unit_rounded,
                                  size: 10,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    ),
                    // Pocket Gap
                    Container(
                      height: 1.5,
                      color: const Color(0xFFCBD6CF),
                    ),
                    // Bottom Compartment
                    Expanded(
                      flex: isTop ? 8 : 4,
                      child: Container(
                        margin: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: !isTop
                              ? AppColors.tealPrimary.withValues(alpha: 0.75)
                              : const Color(0xFFFBFBF9),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Center(
                          child: !isTop
                              ? const Icon(
                                  Icons.ac_unit_rounded,
                                  size: 10,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Option Name
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                position.displayName,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? AppColors.tealPrimary
                      : AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                isTop ? 'Freezer above' : 'Freezer below',
                style: TextStyle(
                  fontSize: 10.5,
                  color: isSelected
                      ? AppColors.tealPrimary.withValues(alpha: 0.8)
                      : AppColors.textSecondary,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
