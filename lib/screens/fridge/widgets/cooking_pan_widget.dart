import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/category_item.dart';
import '../services/cooking_basket_service.dart';
import 'cooking_pan_painter.dart';

/// Global coordinator for pan target tracking, active animations, and bounce synchronization.
class CookingPanCoordinator {
  static GlobalKey? mainPanKey;
  static GlobalKey? bottomSheetPanKey;
  static GlobalKey? activeTargetKey;

  static final Set<String> _flyingItemIds = {};
  static final ValueNotifier<Set<String>> flyingItemsNotifier =
      ValueNotifier<Set<String>>({});

  static VoidCallback? onLandingCallback;

  static void addFlyingItem(String id) {
    _flyingItemIds.add(id);
    flyingItemsNotifier.value = Set<String>.from(_flyingItemIds);
  }

  static void removeFlyingItem(String id) {
    _flyingItemIds.remove(id);
    flyingItemsNotifier.value = Set<String>.from(_flyingItemIds);
  }

  static bool isFlying(String id) => _flyingItemIds.contains(id);

  static void triggerLanding() {
    onLandingCallback?.call();
  }

  static void clear() {
    _flyingItemIds.clear();
    flyingItemsNotifier.value = {};
  }
}

/// A physical-looking 2.5D interactive cooking pan widget.
///
/// Features:
/// - Custom-painted cast graphite skillet with metallic rim and ergonomic wood handle.
/// - Accumulates real selected ingredient thumbnails in its non-stick interior.
/// - Dynamic layout for 0, 1, 2, 3, 4, and 5+ items (with +N badge).
/// - Realistic landing bounce and thermal ripple reaction when ingredients land.
/// - Dual display mode: full (for main bottom panel) and compact (for bottom sheet footer).
class CookingPanWidget extends StatefulWidget {
  final double width;
  final double height;
  final bool isCompact;
  final bool showEmptyGuide;
  final VoidCallback? onTap;
  final GlobalKey? panKey;

  const CookingPanWidget({
    super.key,
    this.width = 150.0,
    this.height = 80.0,
    this.isCompact = false,
    this.showEmptyGuide = true,
    this.onTap,
    this.panKey,
  });

  @override
  State<CookingPanWidget> createState() => CookingPanWidgetState();
}

class CookingPanWidgetState extends State<CookingPanWidget>
    with TickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;

  late final AnimationController _rippleController;
  late final Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();

    // Landing bounce animation
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _bounceAnimation = CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    );

    // Landing thermal ripple
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _rippleAnimation = CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    );

    // Hook into global coordinator if this pan is active
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

  /// Triggers physical impact bounce and golden-mint thermal ripple on landing
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
        // Ingredients currently visible in pan (landed, or all selected items)
        final visibleItems = allItems;
        final count = visibleItems.length;

        final double handleRatio = widget.isCompact ? 0.28 : 0.32;
        final double panBodyWidth = widget.width * (1.0 - handleRatio);
        final double handleWidth = widget.width * handleRatio;

        // Interior floor geometry
        final double panCenterX = handleWidth + (panBodyWidth * 0.50);
        final double panCenterY = widget.height * 0.48;
        final double rx = panBodyWidth * 0.46;
        final double ry = rx * 0.62;

        return RepaintBoundary(
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. Custom-painted 2.5D Physical Skillet
                  Positioned.fill(
                    child: CustomPaint(
                      painter: CookingPanPainter(
                        bounceFactor: _bounceAnimation.value,
                        rippleProgress: _rippleAnimation.value,
                        isCompact: widget.isCompact,
                      ),
                    ),
                  ),

                  // 2. Interior Cooking Surface (Holds Ingredients or Empty Guide)
                  Positioned(
                    left: panCenterX - rx + (widget.isCompact ? 6 : 10),
                    top: panCenterY - ry + (widget.isCompact ? 4 : 6),
                    width: (rx * 2) - (widget.isCompact ? 12 : 20),
                    height: (ry * 2) - (widget.isCompact ? 8 : 12),
                    child: ClipOval(
                      child: Center(
                        child: count == 0
                            ? (widget.showEmptyGuide && !widget.isCompact
                                ? _buildEmptyGuide()
                                : const SizedBox.shrink())
                            : _buildIngredientsCluster(visibleItems),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Empty state subtle guide inside pan
  Widget _buildEmptyGuide() {
    return FittedBox(
      fit: BoxFit.contain,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.soup_kitchen_rounded,
              size: 15,
              color: Color(0x66FFFFFF),
            ),
            const SizedBox(height: 2),
            const Text(
              'Your pan is ready',
              style: TextStyle(
                color: Color(0xDDFFFFFF),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 1),
            Text(
              'Select items from fridge',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 8.5,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Arranges selected ingredient thumbnails naturally within the pan interior
  Widget _buildIngredientsCluster(List<CategoryFoodItem> items) {
    final int total = items.length;
    final double tokenSize = widget.isCompact ? 22.0 : 34.0;

    // Show up to 4 items, plus +N badge if more
    final int displayCount = total > 4 ? 3 : total;
    final List<CategoryFoodItem> displayItems = items.take(displayCount).toList();
    final int overflowCount = total - displayCount;

    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 100,
        height: 60,
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
      left: 50.0 + pos.dx - (tokenSize / 2),
      top: 30.0 + pos.dy - (tokenSize / 2),
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
                color: Colors.white.withValues(alpha: 0.90),
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
      left: 50.0 + pos.dx - (tokenSize / 2),
      top: 30.0 + pos.dy - (tokenSize / 2),
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
              fontSize: widget.isCompact ? 9.5 : 12.0,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  /// Calculates organic placement offsets for items resting in the pan
  Offset _getOffsetForIndex(int index, int total) {
    if (total == 1) return const Offset(0, 0);
    if (total == 2) {
      return index == 0 ? const Offset(-15, 0) : const Offset(15, 0);
    }
    if (total == 3) {
      switch (index) {
        case 0:
          return const Offset(-16, -6);
        case 1:
          return const Offset(16, -6);
        default:
          return const Offset(0, 10);
      }
    }
    // 4 items
    switch (index) {
      case 0:
        return const Offset(-18, -8);
      case 1:
        return const Offset(18, -8);
      case 2:
        return const Offset(-10, 10);
      default:
        return const Offset(14, 10);
    }
  }

  /// Slight rotation for resting natural kitchen look
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
