import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/fridge_preferences.dart';
import 'freezer_interior.dart';
import 'refrigerator_interior.dart';

/// Interactive Refrigerator with Refined Fade-Reveal Interaction and Personalized Finish & Layout.
///
/// Features:
/// - Selectable Exterior Color Finishes (Midnight Navy, Matte Black, Pearl White, Sage Green).
/// - Dynamic Compartment Positions (Freezer on Top or Freezer on Bottom).
/// - Closed State: Realistic appliance finish with pocket handle seam and leveling feet.
/// - Tap to Open: Door softly blurs and fades away (1.0 -> 0.0, ~500ms), revealing the fixed interior cavity
///   as the cool interior lighting smoothly brightens.
/// - Tap to Close: Tapping the open interior reverses the transition, softly focusing and fading the door back in.
/// - Two Independent Sections: Freezer and Refrigerator compartments operate independently.
/// - Interior Cavity: Always stays clean porcelain white with cool lighting, preserving all 11 food categories.
class TopFreezerRefrigerator extends StatefulWidget {
  final bool isFreezerOpen;
  final bool isFridgeOpen;
  final VoidCallback onFreezerToggle;
  final VoidCallback onFridgeToggle;
  final ValueChanged<String>? onCategoryTap;
  final FridgePreferences? preferences;

  const TopFreezerRefrigerator({
    super.key,
    required this.isFreezerOpen,
    required this.isFridgeOpen,
    required this.onFreezerToggle,
    required this.onFridgeToggle,
    this.onCategoryTap,
    this.preferences,
  });

  @override
  State<TopFreezerRefrigerator> createState() => _TopFreezerRefrigeratorState();
}

class _TopFreezerRefrigeratorState extends State<TopFreezerRefrigerator>
    with TickerProviderStateMixin {
  late AnimationController _freezerController;
  late Animation<double> _freezerAnimation;

  late AnimationController _fridgeController;
  late Animation<double> _fridgeAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Freezer Controller (~500ms smooth cubic easing)
    _freezerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _freezerAnimation = CurvedAnimation(
      parent: _freezerController,
      curve: Curves.easeInOutCubic,
    );

    // 2. Main Refrigerator Controller (~500ms smooth cubic easing)
    _fridgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fridgeAnimation = CurvedAnimation(
      parent: _fridgeController,
      curve: Curves.easeInOutCubic,
    );

    if (widget.isFreezerOpen) _freezerController.value = 1.0;
    if (widget.isFridgeOpen) _fridgeController.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant TopFreezerRefrigerator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFreezerOpen != oldWidget.isFreezerOpen) {
      if (widget.isFreezerOpen) {
        _freezerController.forward();
      } else {
        _freezerController.reverse();
      }
    }
    if (widget.isFridgeOpen != oldWidget.isFridgeOpen) {
      if (widget.isFridgeOpen) {
        _fridgeController.forward();
      } else {
        _fridgeController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _freezerController.dispose();
    _fridgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = widget.preferences ?? FridgePreferencesRepository.current;
    final finish = prefs.exteriorColor;
    final isFreezerOnTop = prefs.freezerPosition == FreezerPosition.top;

    // Refrigerator Dimensions
    const double cabinetWidth = 272.0;
    const double freezerHeight = 164.0;
    const double pocketGapHeight = 14.0;
    const double fridgeHeight = 376.0;
    const double totalCabinetHeight =
        freezerHeight + pocketGapHeight + fridgeHeight;

    final double topCompartmentHeight =
        isFreezerOnTop ? freezerHeight : fridgeHeight;
    final double bottomCompartmentHeight =
        isFreezerOnTop ? fridgeHeight : freezerHeight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ============================================================
        // 1. PHYSICAL REFRIGERATOR CABINET BODY
        // ============================================================
        Container(
          width: cabinetWidth,
          height: totalCabinetHeight,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: finish.bodyGradient,
            ),
            border: Border.all(
              color: finish.borderColor,
              width: 1.6,
            ),
            boxShadow: [
              // Broad physical appliance shadow
              BoxShadow(
                color: finish.shadowColor.withValues(alpha: 0.38),
                blurRadius: 36,
                spreadRadius: 4,
                offset: const Offset(0, 20),
              ),
              // Top specular highlight on metal casing
              BoxShadow(
                color: Colors.white
                    .withValues(alpha: finish.sheenOpacity * 1.6),
                blurRadius: 3,
                offset: const Offset(-1, -1),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.antiAlias,
            children: [
              // Vertical specular metallic sheen along cabinet body
              Positioned(
                left: 14,
                top: 6,
                bottom: 6,
                width: 20,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white
                              .withValues(alpha: finish.sheenOpacity),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              // ============================================================
              // 2. UPPER COMPARTMENT (Freezer if top, Refrigerator if bottom)
              // ============================================================
              Positioned(
                top: 4,
                left: 4,
                right: 4,
                height: topCompartmentHeight,
                child: isFreezerOnTop
                    ? _buildFreezerSection(
                        cabinetWidth - 8,
                        topCompartmentHeight,
                        isTopPosition: true,
                        finish: finish,
                      )
                    : _buildFridgeSection(
                        cabinetWidth - 8,
                        topCompartmentHeight,
                        isTopPosition: true,
                        finish: finish,
                      ),
              ),

              // Horizontal Recessed Pocket Handle Seam between Compartments
              Positioned(
                top: topCompartmentHeight + 4,
                left: 0,
                right: 0,
                height: pocketGapHeight,
                child: _buildPocketHandleSeam(finish),
              ),

              // ============================================================
              // 3. LOWER COMPARTMENT (Refrigerator if top, Freezer if bottom)
              // ============================================================
              Positioned(
                top: topCompartmentHeight + pocketGapHeight + 4,
                left: 4,
                right: 4,
                bottom: 4,
                child: isFreezerOnTop
                    ? _buildFridgeSection(
                        cabinetWidth - 8,
                        bottomCompartmentHeight,
                        isTopPosition: false,
                        finish: finish,
                      )
                    : _buildFreezerSection(
                        cabinetWidth - 8,
                        bottomCompartmentHeight,
                        isTopPosition: false,
                        finish: finish,
                      ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // Heavy-Duty Appliance Leveling Base Feet
        SizedBox(
          width: cabinetWidth - 36,
          height: 10,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLevelingFoot(finish),
              _buildLevelingFoot(finish),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // Realistic Ambient Contact Floor Shadow
        Container(
          width: cabinetWidth + 20,
          height: 14,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: finish.shadowColor.withValues(alpha: 0.35),
                blurRadius: 20,
                spreadRadius: 3,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: finish.shadowColor.withValues(alpha: 0.20),
                blurRadius: 38,
                spreadRadius: 8,
                offset: const Offset(0, 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // FREEZER SECTION: Cavity + Smooth Soft-Blur Fade Door
  // --------------------------------------------------------------------------
  Widget _buildFreezerSection(
    double width,
    double height, {
    required bool isTopPosition,
    required FridgeColorFinish finish,
  }) {
    final BorderRadius borderRadius = isTopPosition
        ? const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          );

    return GestureDetector(
      key: const ValueKey('freezer_door_touch_target'),
      onTap: widget.onFreezerToggle,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _freezerController,
        builder: (context, _) {
          final double t = _freezerAnimation.value;
          final double doorOpacity = (1.0 - t).clamp(0.0, 1.0);
          final double blurSigma = t * 3.5;

          return ClipRRect(
            borderRadius: borderRadius,
            child: Stack(
              children: [
                // Fixed Freezer Interior Cavity (Illuminates softly as door fades)
                Positioned.fill(
                  child: FreezerInterior(
                    lightIntensity: t,
                    onCategoryTap: widget.onCategoryTap,
                  ),
                ),

                // Freezer Door Overlay (Soft-focus blur + fade opacity)
                if (doorOpacity > 0.001)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: t > 0.5,
                      child: Opacity(
                        opacity: doorOpacity,
                        child: blurSigma > 0.1
                            ? ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: blurSigma,
                                  sigmaY: blurSigma,
                                  tileMode: TileMode.decal,
                                ),
                                child: _buildClosedFreezerDoor(
                                  width,
                                  height,
                                  borderRadius: borderRadius,
                                  isTopPosition: isTopPosition,
                                  finish: finish,
                                ),
                              )
                            : _buildClosedFreezerDoor(
                                width,
                                height,
                                borderRadius: borderRadius,
                                isTopPosition: isTopPosition,
                                finish: finish,
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Closed Freezer Door Face
  Widget _buildClosedFreezerDoor(
    double width,
    double height, {
    required BorderRadius borderRadius,
    required bool isTopPosition,
    required FridgeColorFinish finish,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: finish.bodyGradient,
        ),
        border: Border.all(color: finish.borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: finish.shadowColor.withValues(alpha: 0.24),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Stack(
        children: [
          // Top edge specular sheen (for upper door)
          if (isTopPosition)
            Positioned(
              left: 6,
              right: 6,
              top: 4,
              height: 1,
              child: Container(
                color: Colors.white
                    .withValues(alpha: finish.sheenOpacity * 1.6),
              ),
            ),
          // Pocket handle grip indentation (facing towards middle seam)
          Positioned(
            top: isTopPosition ? null : 2,
            bottom: isTopPosition ? 2 : null,
            left: 24,
            right: 24,
            height: 4,
            child: Container(
              decoration: BoxDecoration(
                color: finish.gripIndentationColor,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: finish.gripIndentationBorder,
                  width: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // MAIN REFRIGERATOR SECTION: Cavity + Smooth Soft-Blur Fade Door
  // --------------------------------------------------------------------------
  Widget _buildFridgeSection(
    double width,
    double height, {
    required bool isTopPosition,
    required FridgeColorFinish finish,
  }) {
    final BorderRadius borderRadius = isTopPosition
        ? const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          );

    return GestureDetector(
      key: const ValueKey('fridge_door_touch_target'),
      onTap: widget.onFridgeToggle,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _fridgeController,
        builder: (context, _) {
          final double t = _fridgeAnimation.value;
          final double doorOpacity = (1.0 - t).clamp(0.0, 1.0);
          final double blurSigma = t * 3.5;

          return ClipRRect(
            borderRadius: borderRadius,
            clipBehavior: Clip.antiAlias,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // Fixed Main Refrigerator Interior Cavity (Illuminates softly as door fades)
                Positioned.fill(
                  child: RefrigeratorInterior(
                    lightIntensity: t,
                    onCategoryTap: widget.onCategoryTap,
                  ),
                ),

                // Main Refrigerator Door Overlay (Soft-focus blur + fade opacity)
                if (doorOpacity > 0.001)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: t > 0.5,
                      child: Opacity(
                        opacity: doorOpacity,
                        child: blurSigma > 0.1
                            ? ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: blurSigma,
                                  sigmaY: blurSigma,
                                  tileMode: TileMode.decal,
                                ),
                                child: _buildClosedFridgeDoor(
                                  width,
                                  height,
                                  borderRadius: borderRadius,
                                  isTopPosition: isTopPosition,
                                  finish: finish,
                                ),
                              )
                            : _buildClosedFridgeDoor(
                                width,
                                height,
                                borderRadius: borderRadius,
                                isTopPosition: isTopPosition,
                                finish: finish,
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Closed Main Refrigerator Door Face
  Widget _buildClosedFridgeDoor(
    double width,
    double height, {
    required BorderRadius borderRadius,
    required bool isTopPosition,
    required FridgeColorFinish finish,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: finish.bodyGradient,
        ),
        border: Border.all(color: finish.borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: finish.shadowColor.withValues(alpha: 0.26),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Stack(
        children: [
          // Top edge specular sheen (for upper door)
          if (isTopPosition)
            Positioned(
              left: 6,
              right: 6,
              top: 4,
              height: 1,
              child: Container(
                color: Colors.white
                    .withValues(alpha: finish.sheenOpacity * 1.6),
              ),
            ),
          // Pocket handle grip indentation (facing towards middle seam)
          Positioned(
            top: isTopPosition ? null : 2,
            bottom: isTopPosition ? 2 : null,
            left: 24,
            right: 24,
            height: 4,
            child: Container(
              decoration: BoxDecoration(
                color: finish.gripIndentationColor,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: finish.gripIndentationBorder,
                  width: 0.6,
                ),
              ),
            ),
          ),
          // Vertical specular hairline sheen
          Positioned(
            left: 6,
            top: 14,
            bottom: 14,
            width: 14,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white
                        .withValues(alpha: finish.sheenOpacity * 0.8),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Horizontal Recessed Pocket Handle Seam between Compartments
  Widget _buildPocketHandleSeam(FridgeColorFinish finish) {
    return IgnorePointer(
      child: Container(
        color: finish.handleSeamColor,
        child: Stack(
          children: [
            // Center recessed cavity groove
            Center(
              child: Container(
                height: 3,
                color: finish.handleSeamGroove,
              ),
            ),
            // Brushed silver accent line in pocket handle
            Positioned(
              top: 2,
              left: 24,
              right: 24,
              height: 1.5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0x33B8C9DC),
                      Color(0xFFD2DFEC),
                      Color(0x33B8C9DC),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
            // Right Hinge Bracket
            Positioned(
              right: 6,
              top: 2,
              bottom: 2,
              width: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: finish.hingeColor,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: finish.hingeBorder, width: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelingFoot(FridgeColorFinish finish) {
    return Container(
      width: 22,
      height: 8,
      decoration: BoxDecoration(
        color: finish.levelingFootColor,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: finish.levelingFootBorder, width: 1),
      ),
    );
  }
}
