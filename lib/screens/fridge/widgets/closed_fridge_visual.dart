import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class ClosedFridgeVisual extends StatefulWidget {
  final VoidCallback? onTap;

  const ClosedFridgeVisual({
    super.key,
    this.onTap,
  });

  @override
  State<ClosedFridgeVisual> createState() => _ClosedFridgeVisualState();
}

class _ClosedFridgeVisualState extends State<ClosedFridgeVisual>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _pulseController.forward().then((_) {
      _pulseController.reverse();
    });
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Refrigerator Body
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
                  // Subtle ambient edge shadow
                  BoxShadow(
                    color: AppColors.tealPrimary.withValues(alpha: 0.12),
                    blurRadius: 28,
                    spreadRadius: 2,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Subtle vertical gloss sheen
                  Positioned(
                    left: 20,
                    top: 10,
                    bottom: 10,
                    width: 32,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.35),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),

                  // Interior compartments structure (Upper Fridge & Lower Freezer)
                  Padding(
                    padding: const EdgeInsets.all(7.0),
                    child: Column(
                      children: [
                        // UPPER MAIN FRIDGE DOOR
                        Expanded(
                          flex: 62,
                          child: _buildUpperDoor(),
                        ),

                        // Door Seam / Gasket Divider
                        Container(
                          height: 4,
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB0D5C3),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),

                        // LOWER FREEZER DRAWER
                        Expanded(
                          flex: 38,
                          child: _buildLowerDrawer(),
                        ),
                      ],
                    ),
                  ),

                  // Top right hinge detail
                  Positioned(
                    top: 8,
                    right: 12,
                    child: Container(
                      width: 14,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFA8D0BD),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),

                  // Bottom right hinge detail
                  Positioned(
                    bottom: 8,
                    right: 12,
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

            // Floor Base Shadow (gives 3D grounding to the fridge)
            Container(
              width: 190,
              height: 14,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1B3B2B).withValues(alpha: 0.14),
                    blurRadius: 18,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Upper Main Refrigerator Door
  Widget _buildUpperDoor() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite.withValues(alpha: 0.75),
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
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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

          // Sleek vertical recessed handle on left
          Row(
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
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),

          const Spacer(),
        ],
      ),
    );
  }

  // Lower Freezer Drawer
  Widget _buildLowerDrawer() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite.withValues(alpha: 0.65),
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
            // Horizontal drawer pull handle
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
