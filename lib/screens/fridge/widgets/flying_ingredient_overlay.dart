import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/category_item.dart';
import '../services/cooking_basket_service.dart';
import 'cooking_pan_visual.dart';
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
    Duration duration = const Duration(milliseconds: 460),
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

    // Calculate reserved destination position directly inside the pan's cooking surface
    final int currentCount = CookingBasketService.selectedItems.length;
    int targetIndex = CookingBasketService.selectedItems.indexWhere((it) => it.id == item.id);
    if (targetIndex < 0) {
      targetIndex = currentCount;
    }
    final int targetTotal = math.max(currentCount, targetIndex + 1);

    final Offset targetCenter = CookingPanVisual.getReservedSlotGlobalPosition(
      panBox: targetBox,
      itemIndex: targetIndex,
      totalCount: targetTotal,
    );

    final double targetTokenSize = CookingPanVisual.getTokenSize(
      CookingPanVisual.getBasinMetrics(targetBox.size).rx,
    );

    CookingPanCoordinator.addFlyingItem(item.id);

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (ctx) => _FlyingThumbnailWidget(
        sourceCenter: sourceCenter,
        targetCenter: targetCenter,
        targetTokenSize: targetTokenSize,
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
  final double targetTokenSize;
  final CategoryFoodItem item;
  final Duration duration;
  final VoidCallback onComplete;

  const _FlyingThumbnailWidget({
    required this.sourceCenter,
    required this.targetCenter,
    required this.targetTokenSize,
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
      curve: Curves.easeOutCubic,
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

    // Bezier control point: natural upward arc trajectory
    final double dx = x2 - x1;
    final double dy = y2 - y1;
    final double distance = math.sqrt(dx * dx + dy * dy);

    // Height of arc proportional to distance
    final double arcHeight = (distance * 0.18).clamp(35.0, 85.0);
    final double xc = (x1 + x2) / 2 - (dx * 0.05); // slight natural lateral curvature
    final double yc = math.min(y1, y2) - arcHeight; // jump upwards into air

    final double startSize = 46.0;
    final double endSize = widget.targetTokenSize;

    return AnimatedBuilder(
      animation: _curveAnimation,
      builder: (context, _) {
        final double t = _curveAnimation.value;

        // Quadratic Bezier interpolation directly landing in reserved pan slot
        final double oneMinusT = 1.0 - t;
        final double x = (oneMinusT * oneMinusT * x1) +
            (2 * oneMinusT * t * xc) +
            (t * t * x2);
        final double y = (oneMinusT * oneMinusT * y1) +
            (2 * oneMinusT * t * yc) +
            (t * t * y2);

        // Size: starts at card size (~46px), expands slightly to ~50px as it lifts, shrinks to endSize on landing
        double currentSize;
        if (t < 0.25) {
          final double subT = t / 0.25;
          currentSize = startSize + (subT * 4.0);
        } else {
          final double subT = (t - 0.25) / 0.75;
          currentSize = 50.0 - (subT * (50.0 - endSize));
        }

        // Gentle rotation: 0 -> 0.18 rad (~10°) -> 0 rad on landing
        final double rotation = math.sin(t * math.pi) * 0.18;

        // Shadow elevation: expands in air, settles on landing
        final double shadowElevation = math.sin(t * math.pi) * 6.0;

        final String? imgAsset = widget.item.effectiveImageAsset ?? widget.item.imageAsset;
        final bool hasValidImage = (imgAsset != null && imgAsset.isNotEmpty);
        final bool isCutout = hasValidImage && imgAsset.toLowerCase().endsWith('.png');

        return Positioned(
          left: x - (currentSize / 2),
          top: y - (currentSize / 2),
          child: IgnorePointer(
            child: Transform.rotate(
              angle: rotation,
              child: isCutout
                  ? SizedBox(
                      width: currentSize,
                      height: currentSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            bottom: 1.0,
                            child: Container(
                              width: currentSize * 0.78,
                              height: currentSize * 0.32,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.all(
                                  Radius.elliptical(currentSize * 0.39, currentSize * 0.16),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color.fromRGBO(
                                      0, 0, 0,
                                      (0.18 + (shadowElevation * 0.03)).clamp(0.0, 0.45),
                                    ),
                                    blurRadius: 3.5 + shadowElevation,
                                    offset: Offset(0, 1.5 + (shadowElevation * 0.5)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Image.asset(
                            imgAsset,
                            width: currentSize,
                            height: currentSize,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Text(
                              widget.item.iconEmoji ?? '🥗',
                              style: TextStyle(fontSize: currentSize * 0.52),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      width: currentSize,
                      height: currentSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(currentSize * 0.28),
                        boxShadow: [
                          BoxShadow(
                            color: Color.fromRGBO(
                              0, 0, 0,
                              (0.18 + (shadowElevation * 0.03)).clamp(0.0, 0.45),
                            ),
                            blurRadius: 3.5 + shadowElevation,
                            offset: Offset(0, 1.5 + (shadowElevation * 0.5)),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(currentSize * 0.28),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(currentSize * 0.28),
                          ),
                          child: hasValidImage
                              ? Image.asset(
                                  imgAsset,
                                  width: currentSize,
                                  height: currentSize,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Center(
                                    child: Text(
                                      widget.item.iconEmoji ?? '🥗',
                                      style: TextStyle(fontSize: currentSize * 0.52),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    widget.item.iconEmoji ?? '🥗',
                                    style: TextStyle(fontSize: currentSize * 0.52),
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
