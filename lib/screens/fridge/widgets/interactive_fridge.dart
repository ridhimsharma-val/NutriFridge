import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'fridge_interior.dart';

class InteractiveFridge extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onToggle;

  const InteractiveFridge({
    super.key,
    required this.isOpen,
    required this.onToggle,
  });

  @override
  State<InteractiveFridge> createState() => _InteractiveFridgeState();
}

class _InteractiveFridgeState extends State<InteractiveFridge>
    with SingleTickerProviderStateMixin {
  late AnimationController _doorController;
  late Animation<double> _doorAngleAnimation;
  late Animation<double> _lightAnimation;
  late Animation<double> _vignetteAnimation;

  @override
  void initState() {
    super.initState();
    // Total animation: 850ms, silky smooth easing
    _doorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    // Door swing in radians (0 to ~82 degrees = 1.43 rad)
    _doorAngleAnimation = Tween<double>(begin: 0.0, end: 1.45).animate(
      CurvedAnimation(
        parent: _doorController,
        curve: const Interval(0.08, 0.95, curve: Curves.easeInOutCubic),
      ),
    );

    // Soft cool-white interior light gradually brightens
    _lightAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _doorController,
        curve: const Interval(0.18, 0.88, curve: Curves.easeOut),
      ),
    );

    // Ambient background dimming/vignette
    _vignetteAnimation = Tween<double>(begin: 0.0, end: 0.16).animate(
      CurvedAnimation(
        parent: _doorController,
        curve: const Interval(0.10, 0.90, curve: Curves.easeInOut),
      ),
    );

    if (widget.isOpen) {
      _doorController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant InteractiveFridge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      if (widget.isOpen) {
        _doorController.forward();
      } else {
        _doorController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _doorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _doorController,
      builder: (context, child) {
        final double doorAngle = _doorAngleAnimation.value;
        final double lightIntensity = _lightAnimation.value;
        final double vignetteOpacity = _vignetteAnimation.value;

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Ambient Vignette Dimming when fridge is open
            if (vignetteOpacity > 0.01)
              Positioned(
                top: -120,
                bottom: -120,
                left: -80,
                right: -80,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.85,
                        colors: [
                          Colors.transparent,
                          const Color(0xFF14241E).withValues(alpha: vignetteOpacity),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Main Refrigerator Unit
            GestureDetector(
              onTap: widget.onToggle,
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Outer Cabinet Shell
                  Container(
                    width: 220,
                    height: 350,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFEEF7F2),
                          Color(0xFFD9ECE1),
                          Color(0xFFCBE5D7),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFFBCE0CF),
                        width: 2,
                      ),
                      boxShadow: [
                        // Soft ambient elevation glow & shadow
                        BoxShadow(
                          color: AppColors.tealPrimary.withValues(
                            alpha: 0.12 + (lightIntensity * 0.05),
                          ),
                          blurRadius: 28 + (lightIntensity * 6),
                          spreadRadius: 2,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // 1. REVEALED INTERIOR (Illuminated Cavity)
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(5.0),
                            child: FridgeInterior(
                              lightIntensity: lightIntensity,
                            ),
                          ),
                        ),

                        // 2. 3D SWINGING REFRIGERATOR DOOR (Upper Door)
                        Positioned(
                          top: 5,
                          left: 5,
                          right: 5,
                          height: (350 - 10) * 0.62,
                          child: Transform(
                            alignment: Alignment.centerLeft, // Left hinge
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0016) // Perspective depth
                              ..rotateY(-doorAngle),
                            child: _buildSwingingDoor(
                              doorAngle: doorAngle,
                              lightIntensity: lightIntensity,
                            ),
                          ),
                        ),

                        // 3. LOWER FREEZER DRAWER (Stays closed/sealed with soft shadow)
                        Positioned(
                          bottom: 5,
                          left: 5,
                          right: 5,
                          height: (350 - 10) * 0.38 - 4,
                          child: _buildLowerDrawer(lightIntensity: lightIntensity),
                        ),

                        // Corner Hinge Accent (Left hinge)
                        Positioned(
                          top: 7,
                          left: 10,
                          child: Container(
                            width: 14,
                            height: 5,
                            decoration: BoxDecoration(
                              color: const Color(0xFFA8D0BD),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Floor Base Shadow (Dynamic expansion with interior light)
                  Container(
                    width: 190 + (lightIntensity * 16),
                    height: 14,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1B3B2B).withValues(
                            alpha: 0.14 + (lightIntensity * 0.03),
                          ),
                          blurRadius: 18 + (lightIntensity * 4),
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // The 3D Swinging Door Widget (handles both outer front and inner liner)
  Widget _buildSwingingDoor({
    required double doorAngle,
    required double lightIntensity,
  }) {
    // When door rotates past 90 degrees (pi/2 ~ 1.57), the inside of the door is visible
    final bool isBackVisible = doorAngle > (math.pi / 2);

    if (isBackVisible) {
      // Inner Door Panel (Visible when opened wide)
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..rotateY(math.pi),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFC7E2D5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(-4, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDoorBin(label: 'Door Tray 1'),
              _buildDoorBin(label: 'Door Tray 2'),
            ],
          ),
        ),
      );
    }

    // Outer Front Door Surface (Closed or Opening phase)
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite.withValues(alpha: 0.94),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        border: Border.all(
          color: const Color(0xFFCCE8DB),
          width: 1.2,
        ),
        boxShadow: [
          // Dynamic shadow cast onto the interior as door opens
          BoxShadow(
            color: Colors.black.withValues(
              alpha: (0.15 * math.sin(doorAngle)).clamp(0.0, 0.22),
            ),
            blurRadius: 12,
            offset: Offset(8 * math.sin(doorAngle), 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Smart Display Panel (Temperature & Eco indicator)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE2F4EC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFBCE1D1),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.ac_unit_rounded,
                    size: 13,
                    color: AppColors.tealAccent,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '3°C',
                    style: AppTypography.badgeText.copyWith(
                      color: AppColors.tealPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Color(0xFF26A69A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Optimal',
                    style: AppTypography.badgeText.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Sleek vertical recessed handle on the RIGHT (pull side)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 7,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF98CBB5),
                      Color(0xFF78B89E),
                      Color(0xFF98CBB5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 3,
                      offset: const Offset(-1, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildDoorBin({required String label}) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5F0),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFFBEE0D1),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTypography.badgeText.copyWith(
          fontSize: 8.5,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildLowerDrawer({required double lightIntensity}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite.withValues(alpha: 0.70),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border.all(
          color: const Color(0xFFCCE8DB),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 6,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF98CBB5),
                    Color(0xFF78B89E),
                    Color(0xFF98CBB5),
                  ],
                ),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'FREEZER',
              style: AppTypography.badgeText.copyWith(
                fontSize: 8.5,
                letterSpacing: 1.2,
                color: const Color(0xFF8AA89B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
