import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/category_item.dart';
import 'cooking_pan_widget.dart';

/// Helper that orchestrates the flying ingredient animation from an inventory card
/// thumbnail into the cooking pan along a smooth curved Bezier trajectory.
class FlyingIngredientHelper {
  /// Launches a flying ingredient animation above the screen UI
  static void flyIngredient({
    required BuildContext context,
    required GlobalKey sourceKey,
    required GlobalKey targetKey,
    required CategoryFoodItem item,
    VoidCallback? onLanded,
    Duration duration = const Duration(milliseconds: 500),
  }) {
    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState == null) {
      CookingPanCoordinator.triggerLanding();
      onLanded?.call();
      return;
    }

    // Resolve global screen coordinates
    final RenderBox? sourceBox =
        sourceKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? targetBox =
        targetKey.currentContext?.findRenderObject() as RenderBox?;

    if (sourceBox == null || !sourceBox.attached ||
        targetBox == null || !targetBox.attached) {
      CookingPanCoordinator.triggerLanding();
      onLanded?.call();
      return;
    }

    final Offset sourceCenter = sourceBox.localToGlobal(
      Offset(sourceBox.size.width / 2, sourceBox.size.height / 2),
    );

    // Cooking pan interior center (account for handle on left)
    final double targetCenterOffsetX = targetBox.size.width * 0.62;
    final double targetCenterOffsetY = targetBox.size.height * 0.48;
    final Offset targetCenter = targetBox.localToGlobal(
      Offset(targetCenterOffsetX, targetCenterOffsetY),
    );

    CookingPanCoordinator.addFlyingItem(item.id);

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (ctx) => _FlyingThumbnailWidget(
        sourceCenter: sourceCenter,
        targetCenter: targetCenter,
        item: item,
        duration: duration,
        onComplete: () {
          try {
            overlayEntry.remove();
          } catch (_) {}
          CookingPanCoordinator.removeFlyingItem(item.id);
          CookingPanCoordinator.triggerLanding();
          onLanded?.call();
        },
      ),
    );

    overlayState.insert(overlayEntry);
  }
}

class _FlyingThumbnailWidget extends StatefulWidget {
  final Offset sourceCenter;
  final Offset targetCenter;
  final CategoryFoodItem item;
  final Duration duration;
  final VoidCallback onComplete;

  const _FlyingThumbnailWidget({
    required this.sourceCenter,
    required this.targetCenter,
    required this.item,
    required this.duration,
    required this.onComplete,
  });

  @override
  State<_FlyingThumbnailWidget> createState() => _FlyingThumbnailWidgetState();
}

class _FlyingThumbnailWidgetState extends State<_FlyingThumbnailWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curveAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _curveAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double x1 = widget.sourceCenter.dx;
    final double y1 = widget.sourceCenter.dy;
    final double x2 = widget.targetCenter.dx;
    final double y2 = widget.targetCenter.dy;

    // Bezier control point: midpoint X, elevated Y (arc trajectory)
    final double dx = x2 - x1;
    final double dy = y2 - y1;
    final double distance = math.sqrt(dx * dx + dy * dy);

    // Height of arc proportional to distance, capped between 60 and 110 px
    final double arcHeight = (distance * 0.22).clamp(60.0, 110.0);
    final double xc = (x1 + x2) / 2 - (dx * 0.08); // subtle lateral curvature
    final double yc = math.min(y1, y2) - arcHeight; // jump upwards into air

    final double tokenBaseSize = 46.0;

    return AnimatedBuilder(
      animation: _curveAnimation,
      builder: (context, _) {
        final double t = _curveAnimation.value;

        // Quadratic Bezier interpolation
        final double oneMinusT = 1.0 - t;
        final double x = (oneMinusT * oneMinusT * x1) +
            (2 * oneMinusT * t * xc) +
            (t * t * x2);
        final double y = (oneMinusT * oneMinusT * y1) +
            (2 * oneMinusT * t * yc) +
            (t * t * y2);

        // Scale: lifts off (1.0 -> 1.25 at t=0.25), then shrinks (-> 0.68 at t=1.0)
        double scale;
        if (t < 0.25) {
          scale = 1.0 + (t / 0.25) * 0.25;
        } else {
          final double subT = (t - 0.25) / 0.75;
          scale = 1.25 - (subT * 0.57); // lands at ~0.68
        }

        // Rotation: 0 -> 0.28 rad (16°) -> 0 rad
        final double rotation = math.sin(t * math.pi) * 0.28;

        // Shadow elevation: grows as it lifts into air, diminishes on landing
        final double shadowElevation = math.sin(t * math.pi) * 8.0;

        return Positioned(
          left: x - (tokenBaseSize / 2),
          top: y - (tokenBaseSize / 2),
          child: IgnorePointer(
            child: Transform.rotate(
              angle: rotation,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: tokenBaseSize,
                  height: tokenBaseSize,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAF8),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, (0.15 + (shadowElevation * 0.025)).clamp(0.0, 0.40)),
                        blurRadius: 4.0 + shadowElevation,
                        offset: Offset(0, 2.0 + (shadowElevation * 0.6)),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Center(
                      child: ((widget.item.imageAsset != null &&
                                  widget.item.imageAsset!.isNotEmpty) ||
                              (widget.item.iconEmoji == null &&
                                  widget.item.effectiveImageAsset != null))
                          ? Image.asset(
                              widget.item.effectiveImageAsset ?? widget.item.imageAsset!,
                              width: tokenBaseSize * 0.74,
                              height: tokenBaseSize * 0.74,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Text(
                                widget.item.iconEmoji ?? '🥗',
                                style: const TextStyle(fontSize: 22),
                              ),
                            )
                          : Text(
                              widget.item.iconEmoji ?? '🥗',
                              style: const TextStyle(fontSize: 22),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
