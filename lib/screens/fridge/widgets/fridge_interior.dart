import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class FridgeInterior extends StatelessWidget {
  final double lightIntensity; // 0.0 (dark) to 1.0 (fully lit)

  const FridgeInterior({
    super.key,
    required this.lightIntensity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13221C), // Deep background before light illuminates
        borderRadius: BorderRadius.circular(22),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Interior Cavity Structure (Shelves, Light, Compartments)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF6FBF9),
                    Color(0xFFEAF5F0),
                    Color(0xFFDFEFE8),
                  ],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                children: [
                  // Upper Main Compartment
                  Expanded(
                    flex: 62,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                        border: Border.all(
                          color: const Color(0xFFC8E5D7),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Ceiling LED Light Bar
                          Center(
                            child: Container(
                              width: 120,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withValues(
                                      alpha: (0.9 * lightIntensity).clamp(0.0, 1.0),
                                    ),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF9EE0C7).withValues(
                                      alpha: (0.7 * lightIntensity).clamp(0.0, 1.0),
                                    ),
                                    blurRadius: 14,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const Spacer(flex: 3),

                          // Top Glass Shelf
                          _buildGlassShelf(),

                          const Spacer(flex: 4),

                          // Middle Glass Shelf
                          _buildGlassShelf(),

                          const Spacer(flex: 3),

                          // Bottom Crisper Dual Drawers (Vegetables & Fresh produce)
                          Row(
                            children: [
                              Expanded(
                                child: _buildCrisperDrawer(label: 'Fresh'),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: _buildCrisperDrawer(label: 'Produce'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Divider Gasket Seam
                  Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB0D5C3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Lower Freezer Drawer Interior
                  Expanded(
                    flex: 38,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.55),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                        border: Border.all(
                          color: const Color(0xFFC8E5D7),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Frost zone shelf
                          _buildGlassShelf(isFrosted: true),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.ac_unit_rounded,
                                size: 10,
                                color: Color(0xFF86AA9A),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '-18°C FREEZER',
                                style: AppTypography.badgeText.copyWith(
                                  fontSize: 8,
                                  letterSpacing: 1.1,
                                  color: const Color(0xFF86AA9A),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Dynamic Ambient Illumination Light Overlay
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: (1.0 - lightIntensity).clamp(0.0, 1.0),
                  child: Container(
                    color: const Color(0xFF13221C).withValues(alpha: 0.88),
                  ),
                ),
              ),
            ),

            // Soft Cool-White Glowing Light Cones
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: lightIntensity.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.0, -0.7),
                        radius: 1.2,
                        colors: [
                          Colors.white.withValues(alpha: 0.35),
                          const Color(0xFFD8F2E7).withValues(alpha: 0.12),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassShelf({bool isFrosted = false}) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: isFrosted
            ? const Color(0xFFE4F4EC).withValues(alpha: 0.8)
            : const Color(0xFFE8F6F0),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: const Color(0xFFBCE1D0),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF193B2B).withValues(alpha: 0.06),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          height: 1.5,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildCrisperDrawer({required String label}) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFC7E4D6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Drawer pull notch
          Container(
            width: 22,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFFADCFC0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            label,
            style: AppTypography.badgeText.copyWith(
              fontSize: 8.5,
              color: AppColors.tealPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
