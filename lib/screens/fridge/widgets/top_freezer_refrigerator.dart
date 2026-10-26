import 'dart:ui';
import 'package:flutter/material.dart';
import 'freezer_interior.dart';
import 'refrigerator_interior.dart';

/// Top-Freezer Refrigerator with Refined Fade-Reveal Interaction
///
/// Features:
/// - Closed State: Realistic deep navy / midnight-blue appliance finish with pocket handle seam.
/// - Tap to Open: Door softly blurs and fades away (1.0 -> 0.0, ~500ms), revealing the fixed interior cavity
///   as the cool interior lighting smoothly brightens.
/// - Tap to Close: Tapping the open interior reverses the transition, softly focusing and fading the door
///   back in while interior lighting dims.
/// - Two Independent Sections: Top Freezer and Lower Refrigerator operate independently.
/// - Zero translation / zero rotation: Polished, intentional, mobile-native fade reveal.
class TopFreezerRefrigerator extends StatefulWidget {
  final bool isFreezerOpen;
  final bool isFridgeOpen;
  final VoidCallback onFreezerToggle;
  final VoidCallback onFridgeToggle;
  final ValueChanged<String>? onCategoryTap;

  const TopFreezerRefrigerator({
    super.key,
    required this.isFreezerOpen,
    required this.isFridgeOpen,
    required this.onFreezerToggle,
    required this.onFridgeToggle,
    this.onCategoryTap,
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

    // 1. Top Freezer Controller (~500ms smooth cubic easing)
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
    // Refrigerator Dimensions
    const double cabinetWidth = 272.0;
    const double freezerHeight = 164.0;
    const double pocketGapHeight = 14.0;
    const double fridgeHeight = 376.0;
    const double totalCabinetHeight =
        freezerHeight + pocketGapHeight + fridgeHeight;

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
            // Premium Deep Navy / Midnight Blue Enamel
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF263448), // Top-left specular sheen
                Color(0xFF1D2737), // Midnight body
                Color(0xFF141C28), // Deep shadow navy
              ],
            ),
            border: Border.all(
              color: const Color(0xFF384A62),
              width: 1.6,
            ),
            boxShadow: [
              // Broad physical appliance shadow
              BoxShadow(
                color: const Color(0xFF090E17).withValues(alpha: 0.38),
                blurRadius: 36,
                spreadRadius: 4,
                offset: const Offset(0, 20),
              ),
              // Subtle top specular highlight on metal casing
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.16),
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
                          Colors.white.withValues(alpha: 0.10),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              // ============================================================
              // 2. TOP FREEZER SECTION (INTERIOR CAVITY + FADE DOOR)
              // ============================================================
              Positioned(
                top: 4,
                left: 4,
                right: 4,
                height: freezerHeight,
                child: _buildFreezerSection(cabinetWidth - 8, freezerHeight),
              ),

              // Horizontal Recessed Pocket Handle Seam between Compartments
              Positioned(
                top: freezerHeight + 4,
                left: 0,
                right: 0,
                height: pocketGapHeight,
                child: _buildPocketHandleSeam(),
              ),

              // ============================================================
              // 3. MAIN REFRIGERATOR SECTION (INTERIOR CAVITY + FADE DOOR)
              // ============================================================
              Positioned(
                top: freezerHeight + pocketGapHeight + 4,
                left: 4,
                right: 4,
                bottom: 4,
                child: _buildFridgeSection(
                  cabinetWidth - 8,
                  totalCabinetHeight - (freezerHeight + pocketGapHeight + 8),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // Heavy-Duty Appliance Leveling Base Feet (Graphite + Chrome)
        SizedBox(
          width: cabinetWidth - 36,
          height: 10,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLevelingFoot(),
              _buildLevelingFoot(),
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
                color: const Color(0xFF090F18).withValues(alpha: 0.35),
                blurRadius: 20,
                spreadRadius: 3,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: const Color(0xFF090F18).withValues(alpha: 0.20),
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
  // TOP FREEZER SECTION: Cavity + Smooth Soft-Blur Fade Door
  // --------------------------------------------------------------------------
  Widget _buildFreezerSection(double width, double height) {
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
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(4),
            ),
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
                                child: _buildClosedFreezerDoor(width, height),
                              )
                            : _buildClosedFreezerDoor(width, height),
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
  Widget _buildClosedFreezerDoor(double width, double height) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF263348),
            Color(0xFF1D2737),
            Color(0xFF141C28),
          ],
        ),
        border: Border.all(color: const Color(0xFF384A62), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Stack(
        children: [
          // Top edge specular sheen
          Positioned(
            left: 6,
            right: 6,
            top: 4,
            height: 1,
            child: Container(
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          // Bottom pocket handle grip indentation
          Positioned(
            bottom: 2,
            left: 24,
            right: 24,
            height: 4,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F1520),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: const Color(0xFF35465C), width: 0.6),
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
  Widget _buildFridgeSection(double width, double height) {
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
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
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
                                child: _buildClosedFridgeDoor(width, height),
                              )
                            : _buildClosedFridgeDoor(width, height),
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
  Widget _buildClosedFridgeDoor(double width, double height) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(4),
          bottomLeft: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF263348),
            Color(0xFF1D2737),
            Color(0xFF141C28),
          ],
        ),
        border: Border.all(color: const Color(0xFF384A62), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.26),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Stack(
        children: [
          // Top pocket handle grip indentation
          Positioned(
            top: 2,
            left: 24,
            right: 24,
            height: 4,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F1520),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: const Color(0xFF35465C), width: 0.6),
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
                    Colors.white.withValues(alpha: 0.08),
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
  Widget _buildPocketHandleSeam() {
    return IgnorePointer(
      child: Container(
        color: const Color(0xFF0F1520),
        child: Stack(
          children: [
            // Center recessed cavity groove
            Center(
              child: Container(
                height: 3,
                color: const Color(0xFF080C12),
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
                  color: const Color(0xFF2B384B),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: const Color(0xFF485C76), width: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelingFoot() {
    return Container(
      width: 22,
      height: 8,
      decoration: BoxDecoration(
        color: const Color(0xFF141C28),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFF4D6076), width: 1),
      ),
    );
  }
}
