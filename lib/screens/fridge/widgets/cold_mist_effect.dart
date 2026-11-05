import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Specification for a single organic billow lobe within a cold smoke cloud.
class _LobeSpec {
  final double baseAngle; // Offset angle in radians
  final double distFactor; // Offset distance from cluster center (0.0 - 0.35)
  final double radiusFactor; // Lobe radius relative to cluster radius (0.50 - 0.95)
  final double rotationSpeed; // Shape evolution rotation as smoke billows
  final double scaleX; // Horizontal elliptical stretch
  final double scaleY; // Vertical elliptical stretch
  static const double blurSigma = 13.0; // Feathered soft blur radius matching reference video

  const _LobeSpec({
    required this.baseAngle,
    required this.distFactor,
    required this.radiusFactor,
    required this.rotationSpeed,
    this.scaleX = 1.20,
    this.scaleY = 0.90,
  });
}

/// Specification for a realistic cold smoke plume flowing out of the refrigerator,
/// supporting 4-directional billowing (Down, Up, Left, Right).
class _SmokePlumeSpec {
  final double originU; // Normalized horizontal start inside opening (0.0 - 1.0)
  final double originV; // Normalized vertical start inside opening (0.0 - 1.0)
  final double baseRadius; // Smoke puff radius in pixels (30.0 - 54.0 px)
  final double expansion; // Dispersion multiplier as smoke billows outward (1.35 - 1.65)
  final double flowX; // Lateral smoke drift as it escapes (-44.0 to +44.0 px)
  final double flowY; // Vertical smoke roll as it flows out (-42.0 to +120.0 px)
  final double startProgress; // Progression point when plume starts emerging
  final double peakProgress; // Progression point of peak visibility and billowing
  final double endProgress; // Progression point when smoke completely dissipates
  final double maxAlpha; // Translucent white smoke opacity (0.24 - 0.44)
  final List<_LobeSpec> lobes; // 3-4 asymmetric irregular billow lobes
  final bool hasTendril; // Filamentous curling smoke tendril
  final double tendrilCurl; // Curvature direction of smoke trail
  final double tendrilLength; // Length factor of curling smoke trail

  const _SmokePlumeSpec({
    required this.originU,
    required this.originV,
    required this.baseRadius,
    required this.expansion,
    required this.flowX,
    required this.flowY,
    required this.startProgress,
    required this.peakProgress,
    required this.endProgress,
    required this.maxAlpha,
    required this.lobes,
    this.hasTendril = false,
    this.tendrilCurl = 0.0,
    this.tendrilLength = 1.3,
  });

  double computeAlpha(double t) {
    if (t <= startProgress || t >= endProgress) return 0.0;
    if (t < peakProgress) {
      final inT = (t - startProgress) / (peakProgress - startProgress);
      return maxAlpha * Curves.easeOutCubic.transform(inT);
    } else {
      final outT = (t - peakProgress) / (endProgress - peakProgress);
      final fade = 1.0 - Curves.easeInOutSine.transform(outT);
      return maxAlpha * fade;
    }
  }

  double computeRadius(double t) {
    final localT =
        ((t - startProgress) / (endProgress - startProgress)).clamp(0.0, 1.0);
    final expandT = Curves.easeOutQuad.transform(localT);
    return baseRadius * (1.0 + (expansion - 1.0) * expandT);
  }

  Offset computeCenter(double t, Rect innerRect) {
    final startX = innerRect.left + originU * innerRect.width;
    final startY = innerRect.top + originV * innerRect.height;

    final localT =
        ((t - startProgress) / (endProgress - startProgress)).clamp(0.0, 1.0);
    // Cold smoke drops and billows outward rapidly, then decelerates into room air
    final flowT = Curves.easeOutCubic.transform(localT);

    final cx = startX + flowX * flowT;
    final cy = startY + flowY * flowT;
    return Offset(cx, cy);
  }
}

/// Realistic Refrigerator Cold Smoke Effect.
///
/// Features 4-directional billowing (Down, Up, Left, Right) when opened:
/// 1. DOWNWARD: Sub-zero cold air sinks and spills heavily over the lower sill.
/// 2. UPWARD: Delicate cold vapor wisps billow gently upward from the top opening edge.
/// 3. LEFTWARD: Organic smoke plumes waft outward beyond the left cabinet frame.
/// 4. RIGHTWARD: Organic smoke plumes waft outward beyond the right cabinet frame.
/// 5. Strictly NO animation when closing: mist instantly disappears upon door close.
class ColdMistEffect extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double>? doorAnimation;
  final bool isFreezer;
  final Rect? innerRect; // Compartment opening bounds within the canvas

  const ColdMistEffect({
    super.key,
    required this.animation,
    this.doorAnimation,
    this.isFreezer = false,
    this.innerRect,
  });

  @override
  Widget build(BuildContext context) {
    final Listenable listenable = doorAnimation != null
        ? Listenable.merge([animation, doorAnimation!])
        : animation;

    return AnimatedBuilder(
      animation: listenable,
      builder: (context, _) {
        final progress = animation.value;
        // Strictly no animation when closing: immediately cancel if door is closing or closed
        final isDoorClosing = doorAnimation != null &&
            doorAnimation!.status == AnimationStatus.reverse;
        final doorFactor = doorAnimation?.value ?? 1.0;

        if (progress <= 0.001 || progress >= 0.999 || doorFactor <= 0.001 || isDoorClosing) {
          return const SizedBox.shrink();
        }

        return RepaintBoundary(
          child: CustomPaint(
            painter: _ColdMistPainter(
              progress: progress,
              doorFactor: doorFactor,
              isFreezer: isFreezer,
              innerRect: innerRect,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

class _ColdMistPainter extends CustomPainter {
  final double progress;
  final double doorFactor;
  final bool isFreezer;
  final Rect? innerRect;

  _ColdMistPainter({
    required this.progress,
    this.doorFactor = 1.0,
    required this.isFreezer,
    this.innerRect,
  });

  // --------------------------------------------------------------------------
  // FREEZER COLD SMOKE (4-Directional Flow: Down, Up, Left, Right)
  // --------------------------------------------------------------------------
  static const List<_SmokePlumeSpec> _freezerWisps = [
    // ------------------------------------------------------------------------
    // 1. DOWNWARD SPILL (SOUTH) - The main cold cascade spilling down the door
    // ------------------------------------------------------------------------
    _SmokePlumeSpec(
      originU: 0.50,
      originV: 0.94,
      baseRadius: 52.0,
      expansion: 1.65,
      flowX: 2.0,
      flowY: 120.0,
      startProgress: 0.02,
      peakProgress: 0.36,
      endProgress: 0.88,
      maxAlpha: 0.44,
      hasTendril: true,
      tendrilCurl: 0.05,
      tendrilLength: 1.45,
      lobes: [
        _LobeSpec(baseAngle: 0.0, distFactor: 0.0, radiusFactor: 1.0, rotationSpeed: 0.15, scaleX: 1.25, scaleY: 0.90),
        _LobeSpec(baseAngle: -0.8, distFactor: 0.32, radiusFactor: 0.78, rotationSpeed: -0.2, scaleX: 1.20, scaleY: 0.88),
        _LobeSpec(baseAngle: 1.0, distFactor: 0.30, radiusFactor: 0.74, rotationSpeed: 0.22, scaleX: 1.18, scaleY: 0.90),
        _LobeSpec(baseAngle: 2.4, distFactor: 0.28, radiusFactor: 0.64, rotationSpeed: -0.15),
      ],
    ),
    _SmokePlumeSpec(
      originU: 0.30,
      originV: 0.88,
      baseRadius: 44.0,
      expansion: 1.58,
      flowX: -16.0,
      flowY: 94.0,
      startProgress: 0.04,
      peakProgress: 0.38,
      endProgress: 0.90,
      maxAlpha: 0.38,
      hasTendril: true,
      tendrilCurl: -0.06,
      tendrilLength: 1.40,
      lobes: [
        _LobeSpec(baseAngle: 0.0, distFactor: 0.0, radiusFactor: 1.0, rotationSpeed: 0.2),
        _LobeSpec(baseAngle: -1.1, distFactor: 0.30, radiusFactor: 0.74, rotationSpeed: 0.28),
        _LobeSpec(baseAngle: 1.3, distFactor: 0.28, radiusFactor: 0.68, rotationSpeed: -0.2),
      ],
    ),
    _SmokePlumeSpec(
      originU: 0.70,
      originV: 0.88,
      baseRadius: 44.0,
      expansion: 1.55,
      flowX: 16.0,
      flowY: 92.0,
      startProgress: 0.05,
      peakProgress: 0.40,
      endProgress: 0.90,
      maxAlpha: 0.38,
      hasTendril: true,
      tendrilCurl: 0.06,
      tendrilLength: 1.35,
      lobes: [
        _LobeSpec(baseAngle: 0.0, distFactor: 0.0, radiusFactor: 0.96, rotationSpeed: -0.2),
        _LobeSpec(baseAngle: 0.9, distFactor: 0.28, radiusFactor: 0.70, rotationSpeed: 0.25),
        _LobeSpec(baseAngle: -1.2, distFactor: 0.26, radiusFactor: 0.62, rotationSpeed: -0.15),
      ],
    ),

    // ------------------------------------------------------------------------
    // 2. UPWARD BILLOW (NORTH) - Cold vapor billowing gently upward above the top
    // ------------------------------------------------------------------------
    _SmokePlumeSpec(
      originU: 0.50,
      originV: 0.08,
      baseRadius: 40.0,
      expansion: 1.48,
      flowX: 0.0,
      flowY: -40.0,
      startProgress: 0.04,
      peakProgress: 0.38,
      endProgress: 0.86,
      maxAlpha: 0.34,
      hasTendril: true,
      tendrilCurl: 0.04,
      tendrilLength: 1.30,
      lobes: [
        _LobeSpec(baseAngle: 0.0, distFactor: 0.0, radiusFactor: 1.0, rotationSpeed: -0.18, scaleX: 1.25, scaleY: 0.88),
        _LobeSpec(baseAngle: 1.1, distFactor: 0.28, radiusFactor: 0.72, rotationSpeed: 0.22, scaleX: 1.18, scaleY: 0.88),
        _LobeSpec(baseAngle: -1.2, distFactor: 0.26, radiusFactor: 0.68, rotationSpeed: -0.15),
      ],
    ),
    _SmokePlumeSpec(
      originU: 0.28,
      originV: 0.12,
      baseRadius: 34.0,
      expansion: 1.42,
      flowX: -12.0,
      flowY: -34.0,
      startProgress: 0.07,
      peakProgress: 0.40,
      endProgress: 0.88,
      maxAlpha: 0.28,
      lobes: [
        _LobeSpec(baseAngle: 0.0, distFactor: 0.0, radiusFactor: 0.92, rotationSpeed: 0.2),
        _LobeSpec(baseAngle: -0.9, distFactor: 0.26, radiusFactor: 0.65, rotationSpeed: -0.2),
      ],
    ),
    _SmokePlumeSpec(
      originU: 0.72,
      originV: 0.12,
      baseRadius: 34.0,
      expansion: 1.42,
      flowX: 12.0,
      flowY: -34.0,
      startProgress: 0.07,
      peakProgress: 0.40,
      endProgress: 0.88,
      maxAlpha: 0.28,
      lobes: [
        _LobeSpec(baseAngle: 0.0, distFactor: 0.0, radiusFactor: 0.92, rotationSpeed: -0.2),
        _LobeSpec(baseAngle: 0.9, distFactor: 0.26, radiusFactor: 0.65, rotationSpeed: 0.2),
      ],
    ),

    // ------------------------------------------------------------------------
    // 3. LEFTWARD OUTWARD WAFT (WEST) - Rolling out past the left frame
    // ------------------------------------------------------------------------
    _SmokePlumeSpec(
      originU: 0.08,
      originV: 0.48,
      baseRadius: 42.0,
      expansion: 1.50,
      flowX: -42.0,
      flowY: 10.0,
      startProgress: 0.05,
      peakProgress: 0.38,
      endProgress: 0.88,
      maxAlpha: 0.36,
      hasTendril: true,
      tendrilCurl: -0.06,
      tendrilLength: 1.35,
      lobes: [
        _LobeSpec(baseAngle: 0.0, distFactor: 0.0, radiusFactor: 1.0, rotationSpeed: 0.2, scaleX: 1.25, scaleY: 0.90),
        _LobeSpec(baseAngle: 1.2, distFactor: 0.28, radiusFactor: 0.72, rotationSpeed: -0.22, scaleX: 1.15, scaleY: 0.90),
        _LobeSpec(baseAngle: -1.0, distFactor: 0.26, radiusFactor: 0.64, rotationSpeed: 0.18),
      ],
    ),

    // ------------------------------------------------------------------------
    // 4. RIGHTWARD OUTWARD WAFT (EAST) - Rolling out past the right frame
    // ------------------------------------------------------------------------
    _SmokePlumeSpec(
      originU: 0.92,
      originV: 0.48,
      baseRadius: 42.0,
      expansion: 1.50,
      flowX: 42.0,
      flowY: 10.0,
      startProgress: 0.05,
      peakProgress: 0.38,
      endProgress: 0.88,
      maxAlpha: 0.36,
      hasTendril: true,
      tendrilCurl: 0.06,
      tendrilLength: 1.35,
      lobes: [
        _LobeSpec(baseAngle: 0.0, distFactor: 0.0, radiusFactor: 1.0, rotationSpeed: -0.2, scaleX: 1.25, scaleY: 0.90),
        _LobeSpec(baseAngle: -1.2, distFactor: 0.28, radiusFactor: 0.72, rotationSpeed: 0.22, scaleX: 1.15, scaleY: 0.90),
        _LobeSpec(baseAngle: 1.0, distFactor: 0.26, radiusFactor: 0.64, rotationSpeed: -0.18),
      ],
    ),
  ];

  // --------------------------------------------------------------------------
  // MAIN REFRIGERATOR COLD SMOKE (4-Directional Flow: Down, Up, Left, Right)
  // --------------------------------------------------------------------------
  static const List<_SmokePlumeSpec> _fridgeWisps = [
    // ------------------------------------------------------------------------
    // 1. DOWNWARD SPILL (SOUTH) - Bottom floor rolling fog blanket
    // ------------------------------------------------------------------------
    _SmokePlumeSpec(
      originU: 0.50,
      originV: 0.92,
      baseRadius: 48.0,
      expansion: 1.55,
      flowX: 2.0,
      flowY: 38.0,
      startProgress: 0.02,
      peakProgress: 0.34,
      endProgress: 0.86,
      maxAlpha: 0.42,
      hasTendril: true,
      tendrilCurl: -0.04,
      tendrilLength: 1.30,
      lobes: [
        _LobeSpec(baseAngle: 0.0, distFactor: 0.0, radiusFactor: 1.0, rotationSpeed: 0.15, scaleX: 1.30, scaleY: 0.85),
        _LobeSpec(baseAngle: -0.9, distFactor: 0.30, radiusFactor: 0.74, rotationSpeed: -0.2, scaleX: 1.25, scaleY: 0.85),
        _LobeSpec(baseAngle: 1.1, distFactor: 0.28, radiusFactor: 0.70, rotationSpeed: 0.22, scaleX: 1.20, scaleY: 0.88),
      ],
    ),
    _SmokePlumeSpec(
      originU: 0.26,
      originV: 0.90,
      baseRadius: 42.0,
      expansion: 1.50,
      flowX: -14.0,
      flowY: 30.0,
      startProgress: 0.04,
      peakProgress: 0.36,
      endProgress: 0.88,
      maxAlpha: 0.36,
      hasTendril: true,
      tendrilCurl: -0.05,
      tendrilLength: 1.25,
      lobes: [
        _LobeSpec(baseAngle: 0.0, distFactor: 0.0, radiusFactor: 1.0, rotationSpeed: 0.2),
        _LobeSpec(baseAngle: -1.0, distFactor: 0.28, radiusFactor: 0.70, rotationSpeed: 0.25),
        _LobeSpec(baseAngle: 1.2, distFactor: 0.26, radiusFactor: 0.65, rotationSpeed: -0.2),
      ],
    ),
    _SmokePlumeSpec(
      originU: 0.74,
      originV: 0.90,
      baseRadius: 42.0,
      expansion: 1.50,
      flowX: 14.0,
      flowY: 30.0,
      startProgress: 0.04,
      peakProgress: 0.36,
      endProgress: 0.88,
      maxAlpha: 0.36,
      hasTendril: true,
      tendrilCurl: 0.05,
      tendrilLength: 1.25,
      lobes: [
        _LobeSpec(baseAngle: 0.0, distFactor: 0.0, radiusFactor: 0.98, rotationSpeed: -0.2),
        _LobeSpec(baseAngle: 0.9, distFactor: 0.28, radiusFactor: 0.70, rotationSpeed: 0.25),
        _LobeSpec(baseAngle: -1.2, distFactor: 0.26, radiusFactor: 0.64, rotationSpeed: -0.15),
      ],
    ),

    // ------------------------------------------------------------------------
    // 2. UPWARD BILLOW (NORTH) - Gentle cold vapor rolling upward across top seam
    // ------------------------------------------------------------------------
    _SmokePlumeSpec(
      originU: 0.50,
      originV: 0.06,
      baseRadius: 38.0,
      expansion: 1.45,
      flowX: 0.0,
      flowY: -36.0,
      startProgress: 0.04,
      peakProgress: 0.38,
      endProgress: 0.86,
      maxAlpha: 0.32,
      hasTendril: true,
      tendrilCurl: 0.04,
      tendrilLength: 1.30,
      lobes: [
        _LobeSpec(baseAngle: 0.0, distFactor: 0.0, radiusFactor: 1.0, rotationSpeed: -0.18, scaleX: 1.25, scaleY: 0.88),
        _LobeSpec(baseAngle: 1.1, distFactor: 0.28, radiusFactor: 0.70, rotationSpeed: 0.22, scaleX: 1.18, scaleY: 0.88),
        _LobeSpec(baseAngle: -1.0, distFactor: 0.26, radiusFactor: 0.65, rotationSpeed: -0.15),
      ],
    ),
    _SmokePlumeSpec(
      originU: 0.28,
      originV: 0.10,
      baseRadius: 32.0,
      expansion: 1.38,
      flowX: -12.0,
      flowY: -30.0,
      startProgress: 0.06,
      peakProgress: 0.40,
      endProgress: 0.88,
      maxAlpha: 0.26,
      lobes: [
        _LobeSpec(baseAngle: 0.0, distFactor: 0.0, radiusFactor: 0.90, rotationSpeed: 0.2),
        _LobeSpec(baseAngle: -0.9, distFactor: 0.26, radiusFactor: 0.62, rotationSpeed: -0.2),
      ],
    ),
    _SmokePlumeSpec(
      originU: 0.72,
      originV: 0.10,
      baseRadius: 32.0,
      expansion: 1.38,
      flowX: 12.0,
      flowY: -30.0,
      startProgress: 0.06,
      peakProgress: 0.40,
      endProgress: 0.88,
      maxAlpha: 0.26,
      lobes: [
        _LobeSpec(baseAngle: 0.0, distFactor: 0.0, radiusFactor: 0.90, rotationSpeed: -0.2),
        _LobeSpec(baseAngle: 0.9, distFactor: 0.26, radiusFactor: 0.62, rotationSpeed: 0.2),
      ],
    ),

    // ------------------------------------------------------------------------
    // 3. LEFTWARD OUTWARD WAFT (WEST) - Rolling out past the left frame
    // ------------------------------------------------------------------------
    _SmokePlumeSpec(
      originU: 0.08,
      originV: 0.52,
      baseRadius: 38.0,
      expansion: 1.48,
      flowX: -40.0,
      flowY: 8.0,
      startProgress: 0.05,
      peakProgress: 0.38,
      endProgress: 0.88,
      maxAlpha: 0.34,
      hasTendril: true,
      tendrilCurl: -0.05,
      tendrilLength: 1.30,
      lobes: [
        _LobeSpec(baseAngle: 0.0, distFactor: 0.0, radiusFactor: 1.0, rotationSpeed: 0.2, scaleX: 1.22, scaleY: 0.90),
        _LobeSpec(baseAngle: 1.1, distFactor: 0.28, radiusFactor: 0.70, rotationSpeed: -0.2, scaleX: 1.15, scaleY: 0.90),
        _LobeSpec(baseAngle: -0.9, distFactor: 0.26, radiusFactor: 0.62, rotationSpeed: 0.18),
      ],
    ),

    // ------------------------------------------------------------------------
    // 4. RIGHTWARD OUTWARD WAFT (EAST) - Rolling out past the right frame
    // ------------------------------------------------------------------------
    _SmokePlumeSpec(
      originU: 0.92,
      originV: 0.52,
      baseRadius: 38.0,
      expansion: 1.48,
      flowX: 40.0,
      flowY: 8.0,
      startProgress: 0.05,
      peakProgress: 0.38,
      endProgress: 0.88,
      maxAlpha: 0.34,
      hasTendril: true,
      tendrilCurl: 0.05,
      tendrilLength: 1.30,
      lobes: [
        _LobeSpec(baseAngle: 0.0, distFactor: 0.0, radiusFactor: 1.0, rotationSpeed: -0.2, scaleX: 1.22, scaleY: 0.90),
        _LobeSpec(baseAngle: -1.1, distFactor: 0.28, radiusFactor: 0.70, rotationSpeed: 0.2, scaleX: 1.15, scaleY: 0.90),
        _LobeSpec(baseAngle: 0.9, distFactor: 0.26, radiusFactor: 0.62, rotationSpeed: -0.18),
      ],
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final plumes = isFreezer ? _freezerWisps : _fridgeWisps;

    final effectiveInnerRect = innerRect ??
        Rect.fromLTWH(
          size.width * 0.10,
          size.height * 0.10,
          size.width * 0.80,
          size.height * 0.80,
        );

    for (final plume in plumes) {
      final baseAlpha = plume.computeAlpha(progress);
      final alpha = (baseAlpha * doorFactor).clamp(0.0, 1.0);
      if (alpha <= 0.001) continue;

      final center = plume.computeCenter(progress, effectiveInnerRect);
      final radius = plume.computeRadius(progress);
      if (radius <= 0.5) continue;

      // 1. Draw Organic Billowing Smoke Lobes
      for (final lobe in plume.lobes) {
        final double lobeAngle =
            lobe.baseAngle + lobe.rotationSpeed * progress * math.pi;
        final double dist = radius * lobe.distFactor;
        final double lobeX = center.dx + dist * math.cos(lobeAngle);
        final double lobeY = center.dy + dist * math.sin(lobeAngle);
        final double lobeRadius = radius * lobe.radiusFactor;

        canvas.save();
        canvas.translate(lobeX, lobeY);
        canvas.scale(lobe.scaleX, lobe.scaleY);

        final rect =
            Rect.fromCircle(center: Offset.zero, radius: lobeRadius);

        final coreHighlight = Color.fromARGB(
          (215 * alpha).round().clamp(0, 255),
          255,
          255,
          255,
        );

        final softWhiteBody = Color.fromARGB(
          (145 * alpha).round().clamp(0, 255),
          246,
          249,
          253,
        );

        final outerVeil = Color.fromARGB(
          (35 * alpha).round().clamp(0, 255),
          236,
          243,
          250,
        );

        const transparentEdge = Color.fromARGB(0, 255, 255, 255);

        final gradient = RadialGradient(
          colors: [
            coreHighlight,
            softWhiteBody,
            outerVeil,
            transparentEdge,
          ],
          stops: const [0.0, 0.32, 0.70, 1.0],
        );

        final paint = Paint()
          ..shader = gradient.createShader(rect)
          ..maskFilter =
              const MaskFilter.blur(BlurStyle.normal, _LobeSpec.blurSigma);

        canvas.drawOval(rect, paint);
        canvas.restore();
      }

      // 2. Draw Fluid Curling Smoke Tendrils
      if (plume.hasTendril) {
        _drawCurlingTendril(
          canvas,
          center,
          radius,
          alpha,
          plume.tendrilCurl,
          plume.tendrilLength,
        );
      }
    }
  }

  void _drawCurlingTendril(
    Canvas canvas,
    Offset center,
    double radius,
    double alpha,
    double curl,
    double lengthFactor,
  ) {
    final path = Path();
    final startY = center.dy + radius * 0.30;
    final endY = center.dy - radius * 0.60 * lengthFactor;
    final startX = center.dx;
    final endX = center.dx + radius * curl * 2.0;

    final cp1 = Offset(startX + radius * curl * 1.2, startY - radius * 0.35);
    final cp2 = Offset(endX - radius * curl * 0.8, endY + radius * 0.30);

    path.moveTo(startX, startY);
    path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, endX, endY);

    final bounds = path.getBounds();
    if (bounds.width <= 0 || bounds.height <= 0) return;

    final tendrilPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5)
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color.fromARGB(0, 255, 255, 255),
          Color.fromARGB((150 * alpha).round().clamp(0, 255), 255, 255, 255),
          Color.fromARGB((85 * alpha).round().clamp(0, 255), 246, 250, 253),
          const Color.fromARGB(0, 255, 255, 255),
        ],
        stops: const [0.0, 0.28, 0.72, 1.0],
      ).createShader(bounds);

    canvas.drawPath(path, tendrilPaint);
  }

  @override
  bool shouldRepaint(covariant _ColdMistPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.doorFactor != doorFactor ||
        oldDelegate.isFreezer != isFreezer ||
        oldDelegate.innerRect != innerRect;
  }
}
