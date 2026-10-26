import 'package:flutter/material.dart';
import 'food_items.dart';

/// Top Freezer Cavity Interior
/// Features:
/// - 3 Horizontal Category Zones using Authoritative Real Food Photography:
///   1. ICE CREAM (`ice cream.jpg` / `ice_cream.png`) - Upper Shelf
///   2. FROZEN FOOD (`peas.jpg` / `frozen_food.png`) - Lower Shelf
///   3. DRY FRUITS (`dry fruits.jpg` / `dry_fruits.png`) - Lower / Floor Area
/// - Prominent, recognizable real food image scale (2–3x previous thumbnail size).
/// - Clean dark muted blue/teal category text labels directly under the food (NO boxes or pills).
/// - Realistic physical shelves with depth shadows and rear air vents.
/// - Tactile interactive category zones with subtle tap scale feedback.
/// - Believable porcelain liner depth with cool-white LED lighting reacting to [lightIntensity].
class FreezerInterior extends StatelessWidget {
  final double lightIntensity;
  final ValueChanged<String>? onCategoryTap;

  const FreezerInterior({
    super.key,
    required this.lightIntensity,
    this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0C131D), // Dark unlit cavity
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // 1. Recessed porcelain / cool-white cavity liner
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFF4F8FA),
                      Color(0xFFE9F0F5),
                      Color(0xFFDEE7ED),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Physical Cavity Depth Shadows (Left, Right, Top inner wall recession)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 10,
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0x33102434),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 10,
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        Color(0x28102434),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 14,
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x380E1C28),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 3. Rear Wall Cooling Air Grille Vents
            Positioned(
              bottom: 8,
              left: 24,
              right: 24,
              height: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  8,
                  (i) => Container(
                    width: 2,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFFBACBD7),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
            ),

            // 4. Main Freezer Category Zones (3 Horizontal Levels)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Zone 1: ICE CREAM (Upper Shelf) - uses ice cream.jpg
                  Expanded(
                    flex: 34,
                    child: CategoryZone(
                      label: 'ICE CREAM',
                      onTap: () => onCategoryTap?.call('ICE CREAM'),
                      content: const RealFoodCategoryVisual(
                        imagePath: 'assets/images/categories/ice_cream.png',
                        height: 42,
                        shadowWidthFactor: 0.65,
                      ),
                    ),
                  ),

                  // Shelf 1
                  _buildFreezerShelf(),

                  // Zone 2: FROZEN FOOD (Middle Shelf) - uses peas.jpg
                  Expanded(
                    flex: 34,
                    child: CategoryZone(
                      label: 'FROZEN FOOD',
                      onTap: () => onCategoryTap?.call('FROZEN FOOD'),
                      content: const RealFoodCategoryVisual(
                        imagePath: 'assets/images/categories/frozen_food.png',
                        height: 40,
                        shadowWidthFactor: 0.75,
                      ),
                    ),
                  ),

                  // Shelf 2
                  _buildFreezerShelf(),

                  // Zone 3: DRY FRUITS (Lower Shelf / Floor Area) - uses dry fruits.jpg
                  Expanded(
                    flex: 32,
                    child: CategoryZone(
                      label: 'DRY FRUITS',
                      onTap: () => onCategoryTap?.call('DRY FRUITS'),
                      content: const RealFoodCategoryVisual(
                        imagePath: 'assets/images/categories/dry_fruits.png',
                        height: 38,
                        shadowWidthFactor: 0.85,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 5. Darkness Overlay
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: (1.0 - lightIntensity).clamp(0.0, 1.0),
                  child: Container(
                    color: const Color(0xFF090E16).withValues(alpha: 0.98),
                  ),
                ),
              ),
            ),

            // 6. Cool-White / Ice-Blue LED Illumination
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: lightIntensity.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.0, -0.7),
                        radius: 1.1,
                        colors: [
                          Colors.white.withValues(alpha: 0.42),
                          const Color(0xFFBCE3F5).withValues(alpha: 0.20),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 7. Top Ceiling LED Light Bar
            Positioned(
              top: 0,
              left: 40,
              right: 40,
              height: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(
                        alpha: (0.95 * lightIntensity).clamp(0.0, 1.0),
                      ),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: const Color(0xFF90D8F0).withValues(
                        alpha: (0.75 * lightIntensity).clamp(0.0, 1.0),
                      ),
                      blurRadius: 14,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Realistic Wall-to-Wall Wire/Glass Shelf with cast shadow
  static Widget _buildFreezerShelf() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 3.5,
          decoration: BoxDecoration(
            color: const Color(0xFFD8E7F0),
            borderRadius: BorderRadius.circular(1.5),
            border: Border.all(
              color: const Color(0xFFB5CCE0),
              width: 0.8,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.7),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Container(
          height: 2,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x1A142634),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}
