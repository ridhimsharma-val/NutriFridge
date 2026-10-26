import 'package:flutter/material.dart';
import 'food_items.dart';

/// Physical Refrigerator Cavity Interior
/// Features:
/// - 4 Horizontal Category Levels using Authoritative Real Food Photography:
///   1. DAIRY PRODUCTS (`dairy products.jpg`) + OTHERS (`others.jpg`) - Top Shelf
///   2. NON-VEG (`non veg.jpg`) + MEALS & LEFTOVERS (`leftovers.jpg`) - Second Shelf
///   3. PACKAGED FOOD (`packaged food.jpg`) + DRINKS & JUICES (`juices.jpg`) - Third Shelf
///   4. VEGETABLES (`vegetables.jpg`) + FRUITS (`fruits.jpg`) - Bottom Produce Drawers
/// - Prominent, recognizable real food image scale (2–3x previous thumbnail size).
/// - Clean dark muted blue/teal category text labels directly under the food (NO boxes or pills).
/// - Believable 3D cavity depth: side-wall shadows, top ceiling drop shadow,
///   recessed Multi-Air Flow back wall column.
/// - 3 Physical tempered glass shelves with edge trim and under-shelf cast shadows.
/// - Tactile interactive category zones with subtle scale feedback on tap.
/// - Cool-white / ice-blue LED ceiling lighting reacting to [lightIntensity].
class RefrigeratorInterior extends StatelessWidget {
  final double lightIntensity;
  final ValueChanged<String>? onCategoryTap;

  const RefrigeratorInterior({
    super.key,
    required this.lightIntensity,
    this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0C131D), // Dark unlit cavity base
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
                      Color(0xFFF6FAFC), // Ceiling highlight
                      Color(0xFFEAF1F6), // Mid cavity
                      Color(0xFFDEE9EF), // Floor depth
                    ],
                  ),
                ),
              ),
            ),

            // 2. Physical Cavity Depth Shadows (Left, Right, and Top inner wall recession)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 12,
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0x33102434),
                        Color(0x12102434),
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
              width: 12,
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        Color(0x28102434),
                        Color(0x0E102434),
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
              height: 16,
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

            // 3. Rear Wall Multi-Air Flow Cooling Column
            Positioned(
              top: 14,
              bottom: 74,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFFD6E2EB),
                        Color(0xFFEAF1F6),
                        Color(0xFFD6E2EB),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: const Color(0xFFC0D2DF),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildAirVentGrille(),
                      _buildAirVentGrille(),
                      _buildAirVentGrille(),
                    ],
                  ),
                ),
              ),
            ),

            // 4. Molded Shelf Support Rails on Side Walls (Left & Right)
            Positioned(
              left: 0,
              top: 24,
              bottom: 78,
              width: 5,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  8,
                  (i) => Container(
                    width: 5,
                    height: 3,
                    decoration: const BoxDecoration(
                      color: Color(0xFFABC0CE),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(1.5),
                        bottomRight: Radius.circular(1.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 24,
              bottom: 78,
              width: 5,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  8,
                  (i) => Container(
                    width: 5,
                    height: 3,
                    decoration: const BoxDecoration(
                      color: Color(0xFFABC0CE),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(1.5),
                        bottomLeft: Radius.circular(1.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 5. Interior Shelving & Category Levels
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 5, 4, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),

                  // ----------------------------------------------------------
                  // Level 1: DAIRY PRODUCTS + OTHERS (Top Shelf)
                  // ----------------------------------------------------------
                  Expanded(
                    flex: 25,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left: DAIRY PRODUCTS - uses dairy products.jpg
                        Expanded(
                          child: CategoryZone(
                            label: 'DAIRY PRODUCTS',
                            onTap: () => onCategoryTap?.call('DAIRY PRODUCTS'),
                            content: const RealFoodCategoryVisual(
                              imagePath: 'assets/images/categories/dairy_products.png',
                              height: 54,
                              shadowWidthFactor: 0.78,
                            ),
                          ),
                        ),

                        // Subtle transparent zone separator
                        Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          color: const Color(0x33A0B8C8),
                        ),

                        // Right: OTHERS - uses others.jpg
                        Expanded(
                          child: CategoryZone(
                            label: 'OTHERS',
                            onTap: () => onCategoryTap?.call('OTHERS'),
                            content: const RealFoodCategoryVisual(
                              imagePath: 'assets/images/categories/others.png',
                              height: 54,
                              shadowWidthFactor: 0.72,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildTemperedGlassShelf(),

                  // ----------------------------------------------------------
                  // Level 2: NON-VEG + MEALS & LEFTOVERS (Second Shelf)
                  // ----------------------------------------------------------
                  Expanded(
                    flex: 25,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left: NON-VEG - uses non veg.jpg
                        Expanded(
                          child: CategoryZone(
                            label: 'NON-VEG',
                            onTap: () => onCategoryTap?.call('NON-VEG'),
                            content: const RealFoodCategoryVisual(
                              imagePath: 'assets/images/categories/non_veg.png',
                              height: 52,
                              shadowWidthFactor: 0.76,
                            ),
                          ),
                        ),

                        // Subtle transparent zone separator
                        Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          color: const Color(0x33A0B8C8),
                        ),

                        // Right: MEALS & LEFTOVERS - uses leftovers.jpg
                        Expanded(
                          child: CategoryZone(
                            label: 'MEALS & LEFTOVERS',
                            onTap: () => onCategoryTap?.call('MEALS & LEFTOVERS'),
                            content: const RealFoodCategoryVisual(
                              imagePath: 'assets/images/categories/leftovers.png',
                              height: 52,
                              shadowWidthFactor: 0.76,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildTemperedGlassShelf(),

                  // ----------------------------------------------------------
                  // Level 3: PACKAGED FOOD + DRINKS & JUICES (Third Shelf)
                  // ----------------------------------------------------------
                  Expanded(
                    flex: 25,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left: PACKAGED FOOD - uses packaged food.jpg
                        Expanded(
                          child: CategoryZone(
                            label: 'PACKAGED FOOD',
                            onTap: () => onCategoryTap?.call('PACKAGED FOOD'),
                            content: const RealFoodCategoryVisual(
                              imagePath: 'assets/images/categories/packaged_food.png',
                              height: 54,
                              shadowWidthFactor: 0.80,
                            ),
                          ),
                        ),

                        // Subtle transparent zone separator
                        Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          color: const Color(0x33A0B8C8),
                        ),

                        // Right: DRINKS & JUICES - uses juices.jpg
                        Expanded(
                          child: CategoryZone(
                            label: 'DRINKS & JUICES',
                            onTap: () => onCategoryTap?.call('DRINKS & JUICES'),
                            content: const RealFoodCategoryVisual(
                              imagePath: 'assets/images/categories/juices.png',
                              height: 54,
                              shadowWidthFactor: 0.80,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildCrisperCoverShelf(),

                  const SizedBox(height: 3),

                  // ----------------------------------------------------------
                  // Level 4: VEGETABLES + FRUITS (Bottom Produce Drawers)
                  // ----------------------------------------------------------
                  Expanded(
                    flex: 25,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left Drawer: VEGETABLES - uses vegetables.jpg
                        Expanded(
                          child: _CrisperDrawerWidget(
                            label: 'VEGETABLES',
                            imageAsset: 'assets/images/categories/vegetables.png',
                            imageHeight: 44,
                            onTap: () => onCategoryTap?.call('VEGETABLES'),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Right Drawer: FRUITS - uses fruits.jpg
                        Expanded(
                          child: _CrisperDrawerWidget(
                            label: 'FRUITS',
                            imageAsset: 'assets/images/categories/fruits.png',
                            imageHeight: 44,
                            onTap: () => onCategoryTap?.call('FRUITS'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
              ),
            ),

            // 6. Darkness Overlay (Fades out smoothly as door opens)
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

            // 7. Interior Cool-White / Ice-Blue LED Illumination Floodlight
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: lightIntensity.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.0, -0.85),
                        radius: 1.25,
                        colors: [
                          Colors.white.withValues(alpha: 0.42),
                          const Color(0xFFBEE4F6).withValues(alpha: 0.20),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 8. Overhead LED Fixture Bar (Top Ceiling Light Lens)
            Positioned(
              top: 0,
              left: 36,
              right: 36,
              height: 4.5,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(
                        alpha: (0.95 * lightIntensity).clamp(0.0, 1.0),
                      ),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: const Color(0xFF88D4F2).withValues(
                        alpha: (0.80 * lightIntensity).clamp(0.0, 1.0),
                      ),
                      blurRadius: 18,
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

  // Realistic Tempered Glass Shelf: Full wall-to-wall with edge trim and drop shadow
  static Widget _buildTemperedGlassShelf() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Glass Slab with aqua-cool transparent tint
        Container(
          height: 4.5,
          decoration: BoxDecoration(
            color: const Color(0x3878D0F5),
            borderRadius: BorderRadius.circular(1.5),
            border: Border.all(
              color: const Color(0x55A8DEF6),
              width: 0.6,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.6),
                blurRadius: 1.5,
                offset: const Offset(0, -0.5),
              ),
            ],
          ),
        ),

        // Front Protective White/Silver Edge Trim Profile
        Container(
          height: 2.5,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFE2ECF3),
                Color(0xFFFFFFFF),
                Color(0xFFD0DFEA),
              ],
            ),
            borderRadius: BorderRadius.circular(1),
          ),
        ),

        // Realistic Cast Shadow underneath the glass shelf onto back wall
        Container(
          height: 3,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x1F162A38),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildCrisperCoverShelf() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 2),
        Container(
          height: 3.5,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFB0C6D5),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        Container(
          height: 2,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x18162A38),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildAirVentGrille() {
    return Container(
      width: 32,
      height: 13,
      decoration: BoxDecoration(
        color: const Color(0xFFC8DAE6),
        borderRadius: BorderRadius.circular(1.5),
        border: Border.all(color: const Color(0xFFB0C6D5), width: 0.6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          5,
          (i) => Container(
            width: 1.5,
            height: 7.5,
            color: const Color(0xFF96AFC0),
          ),
        ),
      ),
    );
  }
}

/// Interactive Crisper Drawer Widget with Real Food Image inside and Clean Text Label
class _CrisperDrawerWidget extends StatefulWidget {
  final String label;
  final String imageAsset;
  final double imageHeight;
  final VoidCallback? onTap;

  const _CrisperDrawerWidget({
    required this.label,
    required this.imageAsset,
    required this.imageHeight,
    this.onTap,
  });

  @override
  State<_CrisperDrawerWidget> createState() => _CrisperDrawerWidgetState();
}

class _CrisperDrawerWidgetState extends State<_CrisperDrawerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _animController.forward(),
        onTapUp: (_) => _animController.reverse(),
        onTapCancel: () => _animController.reverse(),
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, _) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _isHovered
                          ? Colors.white.withValues(alpha: 0.78)
                          : Colors.white.withValues(alpha: 0.65),
                      _isHovered
                          ? const Color(0xFFE4F0F8).withValues(alpha: 0.92)
                          : const Color(0xFFDFEAF2).withValues(alpha: 0.88),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: _isHovered
                        ? const Color(0xFF8BB5CC)
                        : const Color(0xFFB2C8DA),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E3544).withValues(alpha: 0.08),
                      blurRadius: 3,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: Stack(
                  children: [
                    // Real food photo placed inside the transparent drawer
                    Positioned(
                      left: 1,
                      right: 1,
                      bottom: 12,
                      child: Center(
                        child: RealFoodCategoryVisual(
                          imagePath: widget.imageAsset,
                          height: widget.imageHeight,
                          shadowWidthFactor: 0.75,
                        ),
                      ),
                    ),
                    // Acrylic drawer pull grip scoop at top
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: 38,
                        height: 3.5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB4C8D7),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Clean category label at bottom (NO box, NO pill, NO border)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: Text(
                          widget.label,
                          style: const TextStyle(
                            fontSize: 7.4,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2C485C), // Dark muted blue/teal
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
