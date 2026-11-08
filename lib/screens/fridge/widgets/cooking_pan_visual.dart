import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/category_item.dart';
import '../services/cooking_basket_service.dart';
import 'cooking_pan_painter.dart';
import 'cooking_pan_widget.dart';

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
  final VoidCallback? onTap;
  final GlobalKey? panKey;

  const CookingPanVisual({
    super.key,
    this.width = 280.0,
    this.height = 150.0,
    this.isCompact = false,
    this.isExpanded = false,
    this.showEmptyGuide = true,
    this.onTap,
    this.panKey,
  });

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

        // Interior basin coordinates for the user-supplied 3/4 angle pan image:
        // Center: X ≈ 36.2% of width, Y ≈ 58.0% of height
        // Radius: Rx ≈ 28.0% of width, Ry ≈ 16.0% of height
        final double panCenterX = widget.width * 0.362;
        final double panCenterY = widget.height * 0.580;
        final double rx = widget.width * 0.280;
        final double ry = widget.height * 0.160;

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
                    // 1. Ambient drop shadow under the pan
                    Positioned(
                      left: panCenterX - rx - (widget.isCompact ? 4 : 10),
                      top: panCenterY + (ry * 0.35),
                      width: (rx * 2) + (widget.isCompact ? 8 : 20),
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

                    // 3. Interior Cooking Basin (Holds Selected Ingredients ONLY — NO embedded text)
                    if (count > 0)
                      Positioned(
                        left: (panCenterX - rx).clamp(0.0, widget.width),
                        top: (panCenterY - ry).clamp(0.0, widget.height),
                        width: (rx * 2).clamp(10.0, widget.width),
                        height: (ry * 2).clamp(10.0, widget.height),
                        child: ClipOval(
                          child: Center(
                            child: _buildIngredientsCluster(allItems),
                          ),
                        ),
                      ),

                    // 4. Landing Ripple Glow
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

  /// Arranges selected ingredient thumbnails naturally within the pan interior
  Widget _buildIngredientsCluster(List<CategoryFoodItem> items) {
    final int total = items.length;
    final double tokenSize = widget.isCompact
        ? 20.0
        : (widget.isExpanded ? 42.0 : 32.0);

    // Show up to 3 items in compact, 4 in collapsed, 5 in expanded
    final int maxVisible = widget.isCompact ? 3 : (widget.isExpanded ? 5 : 4);
    final int displayCount = total > maxVisible ? (maxVisible - 1) : total;
    final List<CategoryFoodItem> displayItems = items.take(displayCount).toList();
    final int overflowCount = total - displayCount;

    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 120,
        height: 70,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (int i = 0; i < displayItems.length; i++)
              _buildPositionedToken(
                item: displayItems[i],
                index: i,
                total: displayCount + (overflowCount > 0 ? 1 : 0),
                tokenSize: tokenSize,
              ),
            if (overflowCount > 0)
              _buildOverflowToken(
                count: overflowCount,
                index: displayCount,
                total: displayCount + 1,
                tokenSize: tokenSize,
              ),
          ],
        ),
      ),
    );
  }

  /// Single ingredient thumbnail token inside the pan
  Widget _buildPositionedToken({
    required CategoryFoodItem item,
    required int index,
    required int total,
    required double tokenSize,
  }) {
    final Offset pos = _getOffsetForIndex(index, total);
    final double angle = _getAngleForIndex(index);

    return Positioned(
      left: 60.0 + pos.dx - (tokenSize / 2),
      top: 35.0 + pos.dy - (tokenSize / 2),
      child: Transform.rotate(
        angle: angle,
        child: AnimatedScale(
          scale: 1.0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.elasticOut,
          child: Container(
            width: tokenSize,
            height: tokenSize,
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAF8),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.95),
                width: widget.isCompact ? 1.0 : 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x44000000),
                  blurRadius: 4.0,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Center(
                child: ((item.imageAsset != null && item.imageAsset!.isNotEmpty) ||
                        (item.iconEmoji == null && item.effectiveImageAsset != null))
                    ? Image.asset(
                        item.effectiveImageAsset ?? item.imageAsset!,
                        width: tokenSize * 0.72,
                        height: tokenSize * 0.72,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Text(
                          item.iconEmoji ?? '🥘',
                          style: TextStyle(fontSize: tokenSize * 0.45),
                        ),
                      )
                    : Text(
                        item.iconEmoji ?? '🥘',
                        style: TextStyle(fontSize: tokenSize * 0.45),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Overflow '+N' token
  Widget _buildOverflowToken({
    required int count,
    required int index,
    required int total,
    required double tokenSize,
  }) {
    final Offset pos = _getOffsetForIndex(index, total);

    return Positioned(
      left: 60.0 + pos.dx - (tokenSize / 2),
      top: 35.0 + pos.dy - (tokenSize / 2),
      child: Container(
        width: tokenSize,
        height: tokenSize,
        decoration: BoxDecoration(
          color: AppColors.forestGreen,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: widget.isCompact ? 1.0 : 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44000000),
              blurRadius: 4.0,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '+$count',
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.isCompact ? 9.0 : (widget.isExpanded ? 13.0 : 11.0),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  /// Organic placement offsets inside the basin
  Offset _getOffsetForIndex(int index, int total) {
    if (total == 1) return const Offset(0, 0);
    if (total == 2) {
      return index == 0 ? const Offset(-18, 0) : const Offset(18, 0);
    }
    if (total == 3) {
      switch (index) {
        case 0:
          return const Offset(-18, -6);
        case 1:
          return const Offset(18, -6);
        default:
          return const Offset(0, 10);
      }
    }
    if (total == 4) {
      switch (index) {
        case 0:
          return const Offset(-20, -8);
        case 1:
          return const Offset(20, -8);
        case 2:
          return const Offset(-12, 10);
        default:
          return const Offset(16, 10);
      }
    }
    // 5 items
    switch (index) {
      case 0:
        return const Offset(-22, -9);
      case 1:
        return const Offset(22, -9);
      case 2:
        return const Offset(0, -12);
      case 3:
        return const Offset(-14, 11);
      default:
        return const Offset(16, 11);
    }
  }

  /// Slight rotation for resting natural look
  double _getAngleForIndex(int index) {
    switch (index % 4) {
      case 0:
        return -0.08;
      case 1:
        return 0.12;
      case 2:
        return -0.05;
      default:
        return 0.09;
    }
  }
}
