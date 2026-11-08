import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/category_item.dart';
import '../services/cooking_basket_service.dart';
import 'cooking_pan_painter.dart';
import 'cooking_pan_widget.dart';

/// Geometric metrics of the inner cooking basin for the physical pan
class BasinMetrics {
  final double panCenterX;
  final double panCenterY;
  final double rx;
  final double ry;
  final double renderedWidth;
  final double renderedHeight;

  const BasinMetrics({
    required this.panCenterX,
    required this.panCenterY,
    required this.rx,
    required this.ry,
    required this.renderedWidth,
    required this.renderedHeight,
  });
}

/// Reusable physical cooking pan visual component for NutriFridge.
///
/// Supports:
/// - Collapsed state (resting below the refrigerator on the main selection screen).
/// - Compact state (resting inside the category bottom sheet footer).
/// - Expanded state (zoomed into the full cooking workspace via Hero transition).
///
/// Renders the real high-resolution transparent PNG pan asset with physical impact
/// bounce, metallic thermal ripple, and organic cluster of selected ingredient thumbnails.
class CookingPanVisual extends StatefulWidget {
  static const String panAssetPath = 'assets/images/cooking_pan.png';

  final double width;
  final double height;
  final bool isCompact;
  final bool isExpanded;
  final bool showEmptyGuide;
  final double contentOpacity;
  final VoidCallback? onTap;
  final GlobalKey? panKey;

  const CookingPanVisual({
    super.key,
    this.width = 280.0,
    this.height = 150.0,
    this.isCompact = false,
    this.isExpanded = false,
    this.showEmptyGuide = true,
    this.contentOpacity = 1.0,
    this.onTap,
    this.panKey,
  });

  /// Calculates the exact rendered bounds and inner cooking basin parameters
  static BasinMetrics getBasinMetrics(Size size) {
    final FittedSizes fittedSizes = applyBoxFit(
      BoxFit.contain,
      const Size(825.0, 822.0),
      size,
    );
    final double renderedWidth = fittedSizes.destination.width;
    final double renderedHeight = fittedSizes.destination.height;
    final double imageLeft = (size.width - renderedWidth) / 2.0;
    final double imageTop = (size.height - renderedHeight) / 2.0;

    // Actual inner cooking surface center of the 3/4 perspective pan
    final double panCenterX = imageLeft + (renderedWidth * 0.354);
    final double panCenterY = imageTop + (renderedHeight * 0.585);
    // Safe inner cooking surface radii (stays cleanly inside the pan rim)
    final double rx = renderedWidth * 0.250;
    final double ry = renderedHeight * 0.145;

    return BasinMetrics(
      panCenterX: panCenterX,
      panCenterY: panCenterY,
      rx: rx,
      ry: ry,
      renderedWidth: renderedWidth,
      renderedHeight: renderedHeight,
    );
  }

  /// Adaptive layout offsets for ingredient count inside the pan basin:
  /// - 1 ingredient: centered.
  /// - 2 ingredients: balanced side by side.
  /// - 3 ingredients: balanced triangular arrangement.
  /// - 4 ingredients: symmetric 2 × 2 arrangement.
  /// - 5 ingredients: three in the upper row and two centered underneath.
  /// - 6 ingredients: balanced 3 × 2 arrangement.
  /// - More than 6: 5 food items + dedicated non-overlapping +N badge slot.
  static List<Offset> getAdaptiveOffsets(int total, double rx, double ry) {
    final double hStep = rx * 0.44;
    final double vStep = ry * 0.44;

    if (total <= 1) {
      return const [Offset(0.0, 0.0)];
    } else if (total == 2) {
      return [
        Offset(-hStep * 0.85, 0.0),
        Offset(hStep * 0.85, 0.0),
      ];
    } else if (total == 3) {
      return [
        Offset(0.0, -vStep * 0.90),
        Offset(-hStep * 0.85, vStep * 0.80),
        Offset(hStep * 0.85, vStep * 0.80),
      ];
    } else if (total == 4) {
      return [
        Offset(-hStep * 0.80, -vStep * 0.85),
        Offset(hStep * 0.80, -vStep * 0.85),
        Offset(-hStep * 0.80, vStep * 0.85),
        Offset(hStep * 0.80, vStep * 0.85),
      ];
    } else if (total == 5) {
      return [
        Offset(-hStep * 1.10, -vStep * 0.85),
        Offset(0.0, -vStep * 0.85),
        Offset(hStep * 1.10, -vStep * 0.85),
        Offset(-hStep * 0.65, vStep * 0.85),
        Offset(hStep * 0.65, vStep * 0.85),
      ];
    } else {
      // 6 items (3 x 2 grid) or > 6 items (5 food items + 1 overflow badge)
      return [
        Offset(-hStep * 1.10, -vStep * 0.85),
        Offset(0.0, -vStep * 0.85),
        Offset(hStep * 1.10, -vStep * 0.85),
        Offset(-hStep * 1.10, vStep * 0.85),
        Offset(0.0, vStep * 0.85),
        Offset(hStep * 1.10, vStep * 0.85),
      ];
    }
  }

  /// Calculates the exact global target screen position for a specific reserved thumbnail slot
  static Offset getReservedSlotGlobalPosition({
    required RenderBox panBox,
    required int itemIndex,
    required int totalCount,
  }) {
    final BasinMetrics m = getBasinMetrics(panBox.size);
    final effectiveCount = totalCount > 6 ? 6 : totalCount;
    final slot = itemIndex.clamp(0, effectiveCount - 1);
    final offsets = getAdaptiveOffsets(effectiveCount, m.rx, m.ry);
    final offset = slot < offsets.length ? offsets[slot] : Offset.zero;

    return panBox.localToGlobal(
      Offset(m.panCenterX + offset.dx, m.panCenterY + offset.dy),
    );
  }

  /// Calculates the proportional token size for the pan
  static double getTokenSize(double rx, {bool isCompact = false, bool isExpanded = false}) {
    if (isCompact) {
      return (rx * 0.40).clamp(15.0, 20.0);
    } else if (isExpanded) {
      return (rx * 0.42).clamp(20.0, 26.0);
    } else {
      return (rx * 0.40).clamp(18.0, 23.0);
    }
  }

  @override
  State<CookingPanVisual> createState() => CookingPanVisualState();
}

class CookingPanVisualState extends State<CookingPanVisual>
    with TickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;

  late final AnimationController _rippleController;
  late final Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _bounceAnimation = CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    );

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _rippleAnimation = CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    );

    // Register landing callback with coordinator
    CookingPanCoordinator.onLandingCallback = triggerLandingReaction;
  }

  @override
  void dispose() {
    if (CookingPanCoordinator.onLandingCallback == triggerLandingReaction) {
      CookingPanCoordinator.onLandingCallback = null;
    }
    _bounceController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  /// Triggers physical impact bounce and golden-mint thermal ripple on ingredient landing
  void triggerLandingReaction() {
    if (!mounted) return;
    _bounceController.forward(from: 0.0);
    _rippleController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        CookingBasketService.selectedItemsNotifier,
        CookingPanCoordinator.flyingItemsNotifier,
        _bounceAnimation,
        _rippleAnimation,
      ]),
      builder: (context, _) {
        final allItems = CookingBasketService.selectedItems;
        final count = allItems.length;

        // Accurate inner cooking basin coordinates and metrics
        final BasinMetrics metrics = CookingPanVisual.getBasinMetrics(
          Size(widget.width, widget.height),
        );
        final double panCenterX = metrics.panCenterX;
        final double panCenterY = metrics.panCenterY;
        final double rx = metrics.rx;
        final double ry = metrics.ry;
        final double tokenSize = CookingPanVisual.getTokenSize(
          rx,
          isCompact: widget.isCompact,
          isExpanded: widget.isExpanded,
        );

        return RepaintBoundary(
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: AnimatedBuilder(
                animation: _bounceAnimation,
                builder: (context, child) {
                  final double scaleY = 1.0 - (_bounceAnimation.value * 0.05);
                  final double scaleX = 1.0 + (_bounceAnimation.value * 0.03);
                  return Transform.scale(
                    scaleX: scaleX,
                    scaleY: scaleY,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  );
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // 1. Ambient drop shadow under the pan basin
                    Positioned(
                      left: panCenterX - rx - (widget.isCompact ? 4 : 8),
                      top: panCenterY + (ry * 0.35),
                      width: (rx * 2) + (widget.isCompact ? 8 : 16),
                      height: ry * 0.85,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.all(Radius.elliptical(rx, ry * 0.45)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0x380B120E),
                              blurRadius: widget.isCompact ? 8 : (widget.isExpanded ? 24 : 16),
                              spreadRadius: widget.isCompact ? 1 : (widget.isExpanded ? 3 : 1),
                              offset: Offset(0, widget.isCompact ? 4 : 6),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 2. High-resolution transparent Pan Image Asset with Painter Fallback
                    Positioned.fill(
                      child: Image.asset(
                        CookingPanVisual.panAssetPath,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        errorBuilder: (context, error, stackTrace) {
                          return CustomPaint(
                            painter: CookingPanPainter(
                              bounceFactor: _bounceAnimation.value,
                              rippleProgress: _rippleAnimation.value,
                              isCompact: widget.isCompact,
                            ),
                          );
                        },
                      ),
                    ),

                    // 3. Interior Cooking Basin (Holds Selected Ingredients ONLY — centered on inner cooking surface)
                    if (count > 0)
                      Positioned(
                        left: panCenterX - rx,
                        top: panCenterY - ry,
                        width: rx * 2,
                        height: ry * 2,
                        child: ClipOval(
                          child: Opacity(
                            opacity: widget.contentOpacity.clamp(0.0, 1.0),
                            child: _buildIngredientsCluster(allItems, rx, ry, tokenSize),
                          ),
                        ),
                      ),

                    // 4. Landing Ripple Glow emanating from true basin center
                    if (_rippleAnimation.value > 0.0 && _rippleAnimation.value < 1.0)
                      Positioned(
                        left: panCenterX - (rx * _rippleAnimation.value),
                        top: panCenterY - (ry * _rippleAnimation.value),
                        width: (rx * 2) * _rippleAnimation.value,
                        height: (ry * 2) * _rippleAnimation.value,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.freshGreen.withValues(
                                  alpha: (1.0 - _rippleAnimation.value) * 0.65,
                                ),
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Arranges selected ingredient thumbnails in an adaptive, balanced, centered composition
  Widget _buildIngredientsCluster(
    List<CategoryFoodItem> items,
    double rx,
    double ry,
    double tokenSize,
  ) {
    final int total = items.length;
    final bool hasOverflow = total > 6;
    final int displayItemCount = hasOverflow ? 5 : total;
    final List<CategoryFoodItem> displayItems = items.take(displayItemCount).toList();
    final int overflowCount = total - displayItemCount;

    final int layoutCount = hasOverflow ? 6 : total;
    final List<Offset> offsets = CookingPanVisual.getAdaptiveOffsets(layoutCount, rx, ry);

    return SizedBox(
      width: rx * 2,
      height: ry * 2,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < displayItems.length; i++)
            _buildAnimatedItemToken(
              item: displayItems[i],
              offset: i < offsets.length ? offsets[i] : Offset.zero,
              rx: rx,
              ry: ry,
              tokenSize: tokenSize,
              index: i,
            ),
          if (hasOverflow && offsets.length >= 6)
            _buildAnimatedOverflowBadge(
              overflowCount: overflowCount,
              offset: offsets[5],
              rx: rx,
              ry: ry,
              tokenSize: tokenSize,
            ),
        ],
      ),
    );
  }

  /// Animated single ingredient thumbnail with smooth gliding transitions and landing reveal
  Widget _buildAnimatedItemToken({
    required CategoryFoodItem item,
    required Offset offset,
    required double rx,
    required double ry,
    required double tokenSize,
    required int index,
  }) {
    final bool isFlying = CookingPanCoordinator.isFlying(item.id);
    final double angle = _getAngleForIndex(index);

    return AnimatedPositioned(
      key: ValueKey(item.id),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      left: rx + offset.dx - (tokenSize / 2),
      top: ry + offset.dy - (tokenSize / 2),
      width: tokenSize,
      height: tokenSize,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 140),
        opacity: isFlying ? 0.0 : 1.0,
        child: Transform.rotate(
          angle: angle,
          child: _buildTokenCard(item, tokenSize),
        ),
      ),
    );
  }

  /// Single ingredient thumbnail card inside the pan basin
  Widget _buildTokenCard(CategoryFoodItem item, double tokenSize) {
    final String? imgAsset = item.effectiveImageAsset ?? item.imageAsset;

    return Container(
      width: tokenSize,
      height: tokenSize,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.95),
          width: 0.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 3.0,
            offset: Offset(0, 1.2),
          ),
        ],
      ),
      child: ClipOval(
        child: Center(
          child: ((imgAsset != null && imgAsset.isNotEmpty) ||
                  (item.iconEmoji == null && item.effectiveImageAsset != null))
              ? Image.asset(
                  item.effectiveImageAsset ?? item.imageAsset!,
                  width: tokenSize * 0.86,
                  height: tokenSize * 0.86,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Text(
                    item.iconEmoji ?? '🥘',
                    style: TextStyle(fontSize: tokenSize * 0.50),
                  ),
                )
              : Text(
                  item.iconEmoji ?? '🥘',
                  style: TextStyle(fontSize: tokenSize * 0.50),
                ),
        ),
      ),
    );
  }

  /// Animated separate '+N' indicator in its own dedicated non-overlapping slot
  Widget _buildAnimatedOverflowBadge({
    required int overflowCount,
    required Offset offset,
    required double rx,
    required double ry,
    required double tokenSize,
  }) {
    return AnimatedPositioned(
      key: const ValueKey('pan_overflow_badge'),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      left: rx + offset.dx - (tokenSize / 2),
      top: ry + offset.dy - (tokenSize / 2),
      width: tokenSize,
      height: tokenSize,
      child: Container(
        width: tokenSize,
        height: tokenSize,
        decoration: BoxDecoration(
          color: AppColors.forestGreen,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.95),
            width: 1.0,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 3.0,
              offset: Offset(0, 1.2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '+$overflowCount',
            style: TextStyle(
              color: Colors.white,
              fontSize: tokenSize * 0.44,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }

  /// Subtle rotation angle for natural resting look inside pan
  double _getAngleForIndex(int index) {
    switch (index % 4) {
      case 0:
        return -0.06;
      case 1:
        return 0.08;
      case 2:
        return -0.04;
      default:
        return 0.06;
    }
  }
}
