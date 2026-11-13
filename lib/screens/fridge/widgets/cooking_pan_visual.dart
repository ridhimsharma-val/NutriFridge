import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/food_image/cooking_cutout_resolver.dart';
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
    if (total <= 1) {
      return const [Offset(0.0, 0.0)];
    } else if (total == 2) {
      return [
        Offset(-rx * 0.48, 0.0),
        Offset(rx * 0.48, 0.0),
      ];
    } else if (total == 3) {
      return [
        Offset(0.0, -ry * 0.46),
        Offset(-rx * 0.50, ry * 0.42),
        Offset(rx * 0.50, ry * 0.42),
      ];
    } else if (total == 4) {
      return [
        Offset(-rx * 0.46, -ry * 0.44),
        Offset(rx * 0.46, -ry * 0.44),
        Offset(-rx * 0.46, ry * 0.44),
        Offset(rx * 0.46, ry * 0.44),
      ];
    } else if (total == 5) {
      return [
        Offset(-rx * 0.56, -ry * 0.42),
        Offset(0.0, -ry * 0.44),
        Offset(rx * 0.56, -ry * 0.42),
        Offset(-rx * 0.32, ry * 0.44),
        Offset(rx * 0.32, ry * 0.44),
      ];
    } else {
      // 6 items (3 x 2 grid) or > 6 items (5 food items + 1 overflow badge)
      return [
        Offset(-rx * 0.56, -ry * 0.44),
        Offset(0.0, -ry * 0.44),
        Offset(rx * 0.56, -ry * 0.44),
        Offset(-rx * 0.56, ry * 0.44),
        Offset(0.0, ry * 0.44),
        Offset(rx * 0.56, ry * 0.44),
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

  /// Calculates the proportional token size for the pan.
  /// Scaled to approximately 3.5x for 1-2 items, gracefully adapting for 3..6 items
  /// to occupy the maximum available cooking basin naturally without clipping.
  static double getTokenSize(
    double rx, {
    bool isCompact = false,
    bool isExpanded = false,
    int count = 1,
  }) {
    double scale;
    if (count <= 1) {
      scale = isExpanded ? 1.55 : (isCompact ? 1.25 : 1.45);
    } else if (count == 2) {
      scale = isExpanded ? 1.30 : (isCompact ? 1.05 : 1.20);
    } else if (count == 3) {
      scale = isExpanded ? 1.10 : (isCompact ? 0.90 : 1.02);
    } else if (count == 4) {
      scale = isExpanded ? 0.98 : (isCompact ? 0.80 : 0.92);
    } else if (count == 5) {
      scale = isExpanded ? 0.88 : (isCompact ? 0.72 : 0.82);
    } else {
      scale = isExpanded ? 0.80 : (isCompact ? 0.65 : 0.75);
    }

    final double base = rx * scale;
    if (isCompact) {
      return base.clamp(28.0, 52.0);
    } else if (isExpanded) {
      return base.clamp(38.0, 84.0);
    } else {
      return base.clamp(32.0, 74.0);
    }
  }

  /// Resolves the dedicated transparent food cutout asset for cooking pan rendering.
  /// Follows the 3-tier priority:
  /// 1. Priority 1: Existing transparent PNG/WebP cutout.
  /// 2. Priority 2: Automatically generated cutout with background removed.
  /// 3. Priority 3: Exact verified Fridge photograph fallback (never an emoji or unrelated food).
  static String? resolvePanAsset(CategoryFoodItem item) {
    // 1. Dedicated transparent cutout or Fridge photograph from CookingCutoutResolver
    final cutoutResult = CookingCutoutResolver.resolveSync(item);
    if (cutoutResult.imagePath.isNotEmpty) {
      return cutoutResult.imagePath;
    }

    // 2. Fallback to explicit item asset
    final explicit = item.imageAsset;
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }

    return null;
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
          count: count,
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
                        child: Opacity(
                          opacity: widget.contentOpacity.clamp(0.0, 1.0),
                          child: _buildIngredientsCluster(allItems, rx, ry, tokenSize),
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

  /// Single ingredient thumbnail card inside the pan basin:
  /// - Transparent PNG cutouts sit directly on the dark cooking surface with a natural contact shadow.
  /// - Prepared dish JPGs (dal rice, pasta) retain rich photo appearance with subtle natural shadows and no white plates.
  /// - Emoji items fallback smoothly with soft contact depth.
  Widget _buildTokenCard(CategoryFoodItem item, double tokenSize) {
    final String? imgAsset = CookingPanVisual.resolvePanAsset(item);
    final bool hasValidImage = (imgAsset != null && imgAsset.isNotEmpty);
    final bool isNetwork = hasValidImage && (imgAsset.startsWith('http://') || imgAsset.startsWith('https://'));
    final bool isCutout = hasValidImage && CookingCutoutResolver.isCutoutAsset(imgAsset);

    if (isCutout) {
      // Natural transparent food cutout resting directly on the dark cooking surface
      return SizedBox(
        width: tokenSize,
        height: tokenSize,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Soft subtle contact shadow on dark metallic skillet surface
            Positioned(
              bottom: 1.0,
              child: Container(
                width: tokenSize * 0.76,
                height: tokenSize * 0.28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(tokenSize * 0.38, tokenSize * 0.14),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 3.5,
                      spreadRadius: 0.5,
                      offset: Offset(0, 1.5),
                    ),
                  ],
                ),
              ),
            ),
            // Transparent food cutout asset directly over dark skillet
            isNetwork
                ? Image.network(
                    imgAsset,
                    width: tokenSize,
                    height: tokenSize,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => _buildEmojiFallback(item, tokenSize),
                  )
                : Image.asset(
                    imgAsset,
                    width: tokenSize,
                    height: tokenSize,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => _buildEmojiFallback(item, tokenSize),
                  ),
          ],
        ),
      );
    } else if (hasValidImage) {
      // Prepared dish / rich photo retained appearance: natural depth shadow, no white background or plate
      return Container(
        width: tokenSize,
        height: tokenSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokenSize * 0.28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x5A000000),
              blurRadius: 3.5,
              offset: Offset(0, 1.8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(tokenSize * 0.28),
          child: isNetwork
              ? Image.network(
                  imgAsset,
                  width: tokenSize,
                  height: tokenSize,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildEmojiFallback(item, tokenSize),
                )
              : Image.asset(
                  imgAsset,
                  width: tokenSize,
                  height: tokenSize,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildEmojiFallback(item, tokenSize),
                ),
        ),
      );
    } else {
      // Emoji fallback: clean presentation with subtle shadow
      return _buildEmojiFallback(item, tokenSize);
    }
  }

  /// Clean emoji fallback with subtle contact shadow
  Widget _buildEmojiFallback(CategoryFoodItem item, double tokenSize) {
    return Container(
      width: tokenSize,
      height: tokenSize,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 3.0,
            offset: Offset(0, 1.5),
          ),
        ],
      ),
      child: Center(
        child: Text(
          item.iconEmoji ?? '🥘',
          style: TextStyle(fontSize: tokenSize * 0.60),
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
    final double badgeSize = (tokenSize * 0.74).clamp(24.0, 36.0);

    return AnimatedPositioned(
      key: const ValueKey('pan_overflow_badge'),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      left: rx + offset.dx - (badgeSize / 2),
      top: ry + offset.dy - (badgeSize / 2),
      width: badgeSize,
      height: badgeSize,
      child: Container(
        width: badgeSize,
        height: badgeSize,
        decoration: BoxDecoration(
          color: AppColors.forestGreen,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.85),
            width: 0.8,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44000000),
              blurRadius: 3.0,
              offset: Offset(0, 1.4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '+$overflowCount',
            style: TextStyle(
              color: Colors.white,
              fontSize: badgeSize * 0.46,
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
