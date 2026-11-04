import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Specification for a single organic billow lobe within a smoke plume cluster.
class _LobeSpec {
  final double baseAngle; // Offset angle in radians
  final double distFactor; // Offset distance from cluster center (0.0 - 0.40)
  final double radiusFactor; // Lobe radius relative to cluster radius (0.45 - 0.85)
  final double rotationSpeed; // Shape evolution rotation as cloud drifts
  final double scaleX; // Horizontal elliptical stretch
  final double scaleY; // Vertical elliptical stretch
  static const double blurSigma = 8.5; // Feathered soft blur radius for localized wisps

  const _LobeSpec({
    required this.baseAngle,
    required this.distFactor,
    required this.radiusFactor,
    required this.rotationSpeed,
    this.scaleX = 1.20,
    this.scaleY = 0.88,
  });
}

/// Specification for an escaping volumetric cold-vapor smoke plume with curved airflow trajectory.
class _EscapingPlumeSpec {
  final double originU; // Normalized horizontal origin inside compartment (0.0 - 1.0)
  final double originV; // Normalized vertical origin inside compartment (0.0 - 1.0)
  final double baseRadiusRatio; // Cluster radius relative to min(width, height)
  final double expansion; // Expansion multiplier as vapor disperses outside
  final double sillDriftX; // Lateral drift at sill crossing (Zone B)
  final double endDriftX; // Final lateral drift at peak travel (Zone C)
  final double downwardSpillY; // Downward vertical travel below the compartment sill
  final double startProgress; // Progression point when plume starts emerging
  final double peakProgress; // Progression point of peak volume outside opening
  final double endProgress; // Progression point when plume has dissolved
  final double maxAlpha; // Peak opacity (soft, semi-transparent white smoke)
  final List<_LobeSpec> lobes; // Asymmetric organic billow lobes
  final bool hasTendril; // Whether a curling filamentous wispy trail weaves through
  final double tendrilCurl; // Curvature direction of the wispy tendril

  const _EscapingPlumeSpec({
    required this.originU,
    required this.originV,
    required this.baseRadiusRatio,
    required this.expansion,
    required this.sillDriftX,
    required this.endDriftX,
    required this.downwardSpillY,
    required this.startProgress,
    required this.peakProgress,
    required this.endProgress,
    required this.maxAlpha,
    required this.lobes,
    this.hasTendril = false,
    this.tendrilCurl = 0.0,
  });

  /// Calculates plume opacity across the 4 stages:
  /// - Stage 1 (Emergence: 0 - 300ms): Rapid rise from internal vents
  /// - Stage 2 (Expansion & Crossing: 300 - 750ms): Swelling across front opening boundary
  /// - Stage 3 (Outward Flow & Downward Spill: 750 - 1100ms): Peak cascading travel down exterior
  /// - Stage 4 (Dissipation: 1100 - 1500ms): Graceful thinning into pure transparency
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

  /// Calculates current cluster radius at progress [t].
  /// Expands smoothly as cold air meets ambient room air outside the fridge.
  double computeRadius(double t, double minOpeningDim) {
    final localT =
        ((t - startProgress) / (endProgress - startProgress)).clamp(0.0, 1.0);
    final expandT = Curves.easeOutQuart.transform(localT);
    final baseRadius = minOpeningDim * baseRadiusRatio;
    return baseRadius * (1.0 + (expansion - 1.0) * expandT);
  }

  /// Calculates current cluster center on the extended canvas using a smooth
  /// Cubic Bézier airflow trajectory that models cold air emerging from the interior,
  /// rolling over the bottom sill, and cascading downward across the lower door exterior.
  Offset computeCenter(double t, Rect innerRect) {
    final startX = innerRect.left + originU * innerRect.width;
    final startY = innerRect.top + originV * innerRect.height;

    final localT =
        ((t - startProgress) / (endProgress - startProgress)).clamp(0.0, 1.0);
    // Authentic fluid convection curve: smooth initial swell followed by downward gravitational roll
    final tau = Curves.easeOutCubic.transform(localT);

    // Parametric Cubic Bézier Airflow Path:
    // P0: Starting position inside compartment cavity (Zone A)
    final p0x = startX;
    final p0y = startY;

    // P1: Initial movement forward towards front opening plane
    final p1x = startX + sillDriftX * 0.45;
    final p1y = startY + (innerRect.bottom - startY) * 0.65;

    // P2: Curved trajectory rolling over the sill and plunging downward (Zone B)
    final p2x = startX + endDriftX * 0.75;
    final p2y = innerRect.bottom + downwardSpillY * 0.45;

    // P3: Downward destination on exterior door surface (Zone C)
    final p3x = startX + endDriftX;
    final p3y = innerRect.bottom + downwardSpillY;

    // Cubic Bézier calculation: B(tau) = (1-tau)^3 P0 + 3(1-tau)^2 tau P1 + 3(1-tau) tau^2 P2 + tau^3 P3
    final invTau = 1.0 - tau;
    final c0 = invTau * invTau * invTau;
    final c1 = 3.0 * invTau * invTau * tau;
    final c2 = 3.0 * invTau * tau * tau;
    final c3 = tau * tau * tau;

    final cx = c0 * p0x + c1 * p1x + c2 * p2x + c3 * p3x;
    final cy = c0 * p0y + c1 * p1y + c2 * p2y + c3 * p3y;

    return Offset(cx, cy);
  }
}

/// Realistic Refrigerator Cold-Air Vapor Effect with Escaping Outward Flow.
///
/// Features authentic, smoke-like cold vapor that originates inside the refrigerator
/// and visibly flows OUT through the front opening into the space in front of the appliance:
/// - Predominantly soft white (`#FFFFFF`) and neutral off-white (`#F8FAFC`).
/// - Very subtle light-gray volume shading (`#E2E8F0`, `#CBD5E1`) for 3D depth.
/// - NO blue tint or colored overlay.
/// - Unclipped extended rendering area allows leading wisps to cross the front boundary
///   and disperse into the surrounding space.
/// - Continuous transition from Zone A (inside vents/shelves) to Zone B (outside opening).
/// - Dissipates quickly when the compartment is closed.
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
        final doorFactor = doorAnimation?.value ?? 1.0;
        if (progress <= 0.001 || progress >= 0.999 || doorFactor <= 0.001) {
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
  // MAIN REFRIGERATOR: Directional White Vapor Wisps (Zone A -> Zone B -> Zone C)
  // Originates inside cavity, pushes forward through front opening toward viewer,
  // localized around refrigerator opening with gentle downward roll over shelf edges.
  // --------------------------------------------------------------------------
  static const List<_EscapingPlumeSpec> _fridgePlumes = [
    // 1. Upper-Left Shelf Wisp: rolls forward over left shelf lip
    _EscapingPlumeSpec(
      originU: 0.32,
      originV: 0.20,
      baseRadiusRatio: 0.15,
      expansion: 1.42,
      sillDriftX: -8.0,
      endDriftX: -16.0, // Gentle curl past the opening frame
      downwardSpillY: 48.0, // Gentle downward roll over shelf
      startProgress: 0.04,
      peakProgress: 0.36,
      endProgress: 0.88,
      maxAlpha: 0.46,
      hasTendril: true,
      tendrilCurl: -0.06,
      lobes: [
        _LobeSpec(baseAngle: 0.0, distFactor: 0.0, radiusFactor: 1.0, rotationSpeed: 0.2),
        _LobeSpec(baseAngle: -0.8, distFactor: 0.30, radiusFactor: 0.65, rotationSpeed: 0.3),
        _LobeSpec(baseAngle: 0.9, distFactor: 0.32, radiusFactor: 0.68, rotationSpeed: -0.2),
        _LobeSpec(baseAngle: -2.3, distFactor: 0.26, radiusFactor: 0.58, rotationSpeed: 0.4),
      ],
    ),
    // 2. Upper-Right Shelf Wisp: rolls forward over right shelf lip
    _EscapingPlumeSpec(
      originU: 0.68,
      originV: 0.22,
      baseRadiusRatio: 0.15,
      expansion: 1.40,
      sillDriftX: 8.0,
      endDriftX: 16.0,
      downwardSpillY: 48.0,
      startProgress: 0.07,
      peakProgress: 0.38,
      endProgress: 0.90,
      maxAlpha: 0.45,
      hasTendril: true,
      tendrilCurl: 0.06,
      lobes: [
        _LobeSpec(baseAngle: 0.0, distFactor: 0.0, radiusFactor: 0.96, rotationSpeed: -0.2),
        _LobeSpec(baseAngle: -0.9, distFactor: 0.30, radiusFactor: 0.66, rotationSpeed: -0.3),
        _LobeSpec(baseAngle: 0.8, distFactor: 0.28, radiusFactor: 0.62, rotationSpeed: 0.3),
        _LobeSpec(baseAngle: 2.5, distFactor: 0.26, radiusFactor: 0.56, rotationSpeed: 0.2),
      ],
    ),
    // 3. Center Multi-Air Core Stream (Leading Wisp): pushes forward and rolls outward
    _EscapingPlumeSpec(
      originU: 0.50,
      originV: 0.38,
      baseRadiusRatio: 0.17,
      expansion: 1.52, // Simulates forward 3D movement toward the viewer
      sillDriftX: 2.0,
      endDriftX: 4.0, // Slight realistic lateral turbulence
      downwardSpillY: 60.0, // Forward and downward cascade
      startProgress: 0.02,
      peakProgress: 0.34,
      endProgress: 0.86,
      maxAlpha: 0.50,
      hasTendril: true,
      tendrilCurl: 0.03,
      lobes: [
        _LobeSpec(baseAngle: 0.0, distFactor: 0.0, radiusFactor: 1.0, rotationSpeed: 0.2),
        _LobeSpec(baseAngle: -0.7, distFactor: 0.32, radiusFactor: 0.68, rotationSpeed: -0.3),
        _LobeSpec(baseAngle: 0.7, distFactor: 0.32, radiusFactor: 0.70, rotationSpeed: 0.3),
        _LobeSpec(baseAngle: 2.2, distFactor: 0.28, radiusFactor: 0.60, rotationSpeed: -0.4),
      ],
    ),
    // 4. Mid-Lower Shelf Wisp (Trailing Cloud): stays closer to opening
    _EscapingPlumeSpec(
      originU: 0.36,
      originV: 0.58,
      baseRadiusRatio: 0.14,
      expansion: 1.35,
      sillDriftX: -6.0,
      endDriftX: -10.0,
      downwardSpillY: 40.0,
      startProgress: 0.12,
      peakProgress: 0.44,
      endProgress: 0.94,
      maxAlpha: 0.42,
      lobes: [
        _LobeSpec(baseAngle: 0.0, distFactor: 0.0, radiusFactor: 0.95, rotationSpeed: -0.2),
        _LobeSpec(baseAngle: -0.9, distFactor: 0.28, radiusFactor: 0.64, rotationSpeed: 0.3),
        _LobeSpec(baseAngle: 1.1, distFactor: 0.30, radiusFactor: 0.66, rotationSpeed: -0.3),
      ],
    ),
    // 5. Lower Crisper Sill Roll: heavier cold vapor cascading gently forward over threshold
    _EscapingPlumeSpec(
      originU: 0.54,
      originV: 0.84,
      baseRadiusRatio: 0.16,
      expansion: 1.40,
      sillDriftX: 4.0,
      endDriftX: 8.0,
      downwardSpillY: 52.0, // Cold air weight carries it forward/downward over sill
      startProgress: 0.08,
      peakProgress: 0.40,
      endProgress: 0.92,
      maxAlpha: 0.44,
      lobes: [
        _LobeSpec(baseAngle: 0.0, distFactor: 0.0, radiusFactor: 1.0, rotationSpeed: 0.1, scaleX: 1.35, scaleY: 0.8),
        _LobeSpec(baseAngle: -0.7, distFactor: 0.32, radiusFactor: 0.66, rotationSpeed: -0.2, scaleX: 1.3, scaleY: 0.85),
        _LobeSpec(baseAngle: 0.7, distFactor: 0.32, radiusFactor: 0.68, rotationSpeed: 0.2, scaleX: 1.3, scaleY: 0.85),
        _LobeSpec(baseAngle: 2.2, distFactor: 0.26, radiusFactor: 0.58, rotationSpeed: 0.3, scaleX: 1.25, scaleY: 0.9),
      ],
    ),
  ];

  // --------------------------------------------------------------------------
  // FREEZER: Directional Frost Vapor Plumes with Downward Gravity Spill
  // Cold sub-zero vapor emerges from inside, rolls over front sill, and visibly
  // cascades DOWN across the lower refrigerator door exterior before dissipating.
  // --------------------------------------------------------------------------
  static const List<_EscapingPlumeSpec> _freezerPlumes = [
    // F1. Central Leading Plume: starts in center of freezer, crosses opening,
    // and travels furthest down the lower refrigerator door exterior (145px spill)
    _EscapingPlumeSpec(
      originU: 0.50,
      originV: 0.42,
      baseRadiusRatio: 0.16,
      expansion: 1.48, // Natural forward expansion into ambient air
      sillDriftX: 2.0,
      endDriftX: 4.0, // Slight turbulent weave
      downwardSpillY: 145.0, // Visibly cascades 145px down the lower door face!
      startProgress: 0.02,
      peakProgress: 0.34,
      endProgress: 0.88,
      maxAlpha: 0.54,
      hasTendril: true,
      tendrilCurl: 0.04,
      lobes: [
        _LobeSpec(baseAngle: 0.0, distFactor: 0.0, radiusFactor: 1.0, rotationSpeed: -0.2),
        _LobeSpec(baseAngle: -0.8, distFactor: 0.30, radiusFactor: 0.66, rotationSpeed: 0.3),
        _LobeSpec(baseAngle: 0.8, distFactor: 0.30, radiusFactor: 0.68, rotationSpeed: -0.3),
        _LobeSpec(baseAngle: 2.3, distFactor: 0.26, radiusFactor: 0.58, rotationSpeed: 0.4),
      ],
    ),
    // F2. Left Flank Plume: starts near left interior shelf and curls diagonally towards lower-left exterior
    _EscapingPlumeSpec(
      originU: 0.30,
      originV: 0.52,
      baseRadiusRatio: 0.14,
      expansion: 1.40,
      sillDriftX: -10.0,
      endDriftX: -20.0, // Curls diagonally towards lower-left exterior
      downwardSpillY: 105.0, // Cascades 105px down the lower door
      startProgress: 0.06,
      peakProgress: 0.38,
      endProgress: 0.90,
      maxAlpha: 0.48,
      hasTendril: true,
      tendrilCurl: -0.06,
      lobes: [
        _LobeSpec(baseAngle: 0.0, distFactor: 0.0, radiusFactor: 0.96, rotationSpeed: 0.2),
        _LobeSpec(baseAngle: -0.9, distFactor: 0.30, radiusFactor: 0.66, rotationSpeed: -0.3),
        _LobeSpec(baseAngle: 0.8, distFactor: 0.28, radiusFactor: 0.62, rotationSpeed: 0.3),
      ],
    ),
    // F3. Right Flank Plume: starts near right interior shelf and curls diagonally towards lower-right exterior
    _EscapingPlumeSpec(
      originU: 0.70,
      originV: 0.54,
      baseRadiusRatio: 0.14,
      expansion: 1.40,
      sillDriftX: 10.0,
      endDriftX: 20.0, // Curls diagonally towards lower-right exterior
      downwardSpillY: 110.0, // Cascades 110px down the lower door
      startProgress: 0.08,
      peakProgress: 0.40,
      endProgress: 0.92,
      maxAlpha: 0.48,
      hasTendril: true,
      tendrilCurl: 0.06,
      lobes: [
        _LobeSpec(baseAngle: 0.0, distFactor: 0.0, radiusFactor: 0.96, rotationSpeed: -0.2),
        _LobeSpec(baseAngle: -0.8, distFactor: 0.28, radiusFactor: 0.64, rotationSpeed: 0.3),
        _LobeSpec(baseAngle: 0.9, distFactor: 0.30, radiusFactor: 0.66, rotationSpeed: -0.2),
      ],
    ),
    // F4. Lower Sill Heavy Frost Plume: starts near bottom interior and rolls heavily over the front threshold
    _EscapingPlumeSpec(
      originU: 0.48,
      originV: 0.82,
      baseRadiusRatio: 0.15,
      expansion: 1.38,
      sillDriftX: 4.0,
      endDriftX: 6.0,
      downwardSpillY: 75.0, // Rolls 75px over the threshold
      startProgress: 0.04,
      peakProgress: 0.32,
      endProgress: 0.94,
      maxAlpha: 0.50,
      lobes: [
        _LobeSpec(baseAngle: 0.0, distFactor: 0.0, radiusFactor: 1.0, rotationSpeed: 0.1, scaleX: 1.35, scaleY: 0.8),
        _LobeSpec(baseAngle: -0.7, distFactor: 0.32, radiusFactor: 0.68, rotationSpeed: -0.2, scaleX: 1.3, scaleY: 0.85),
        _LobeSpec(baseAngle: 0.7, distFactor: 0.32, radiusFactor: 0.68, rotationSpeed: 0.2, scaleX: 1.3, scaleY: 0.85),
      ],
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final plumes = isFreezer ? _freezerPlumes : _fridgePlumes;

    // The inner opening rectangle defaults to the canvas center if not specified
    final effectiveInnerRect = innerRect ??
        Rect.fromLTWH(
          size.width * 0.15,
          size.height * 0.12,
          size.width * 0.70,
          size.height * 0.76,
        );

    final minOpeningDim =
        math.min(effectiveInnerRect.width, effectiveInnerRect.height);

    for (final plume in plumes) {
      final baseAlpha = plume.computeAlpha(progress);
      final alpha = (baseAlpha * doorFactor).clamp(0.0, 1.0);
      if (alpha <= 0.001) continue;

      final center = plume.computeCenter(progress, effectiveInnerRect);
      final radius = plume.computeRadius(progress, minOpeningDim);
      if (radius <= 0.5) continue;

      // 1. Draw Organic Billow Lobes (Fluffy, irregular cloud cluster)
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

        // Realistic White Smoke Vapor Palette:
        // - Pure crisp white illuminated highlight in the cloud billow crest
        // - Soft neutral off-white vapor body
        // - Subtle light-gray volume shading in denser interior (depth & substance)
        // - Delicate feathered translucent boundaries (zero blue tint)
        final coreHighlight = Color.fromARGB(
          (240 * alpha).round().clamp(0, 255),
          255,
          255,
          255,
        );

        final softWhiteBody = Color.fromARGB(
          (195 * alpha).round().clamp(0, 255),
          248,
          250,
          252,
        );

        final volumeShading = Color.fromARGB(
          (110 * alpha).round().clamp(0, 255),
          226,
          232,
          240,
        );

        final outerVeil = Color.fromARGB(
          (30 * alpha).round().clamp(0, 255),
          241,
          245,
          249,
        );

        const transparentEdge = Color.fromARGB(0, 255, 255, 255);

        final gradient = RadialGradient(
          colors: [
            coreHighlight,
            softWhiteBody,
            volumeShading,
            outerVeil,
            transparentEdge,
          ],
          stops: const [0.0, 0.28, 0.55, 0.78, 1.0],
        );

        final paint = Paint()
          ..shader = gradient.createShader(rect)
          ..maskFilter =
              const MaskFilter.blur(BlurStyle.normal, _LobeSpec.blurSigma);

        canvas.drawOval(rect, paint);
        canvas.restore();
      }

      // 2. Draw Wispy Curling Tendril (Flowing filamentous smoke trail)
      if (plume.hasTendril) {
        _drawCurlingTendril(canvas, center, radius, alpha, plume.tendrilCurl);
      }
    }
  }

  void _drawCurlingTendril(
    Canvas canvas,
    Offset center,
    double radius,
    double alpha,
    double curl,
  ) {
    final path = Path();
    final startY = center.dy + radius * 0.35; // Leading downward plume head
    final endY = center.dy - radius * 0.65; // Trailing filamentous tail lagging behind
    final startX = center.dx;
    final endX = center.dx + radius * curl * 1.5;

    final cp1 = Offset(startX + radius * curl * 0.8, startY - radius * 0.35);
    final cp2 = Offset(endX - radius * curl * 0.6, endY + radius * 0.25);

    path.moveTo(startX, startY);
    path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, endX, endY);

    final bounds = path.getBounds();
    if (bounds.width <= 0 || bounds.height <= 0) return;

    final tendrilPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (radius * 0.14).clamp(3.0, 7.0)
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0)
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color.fromARGB(0, 255, 255, 255),
          Color.fromARGB((170 * alpha).round().clamp(0, 255), 255, 255, 255),
          Color.fromARGB((125 * alpha).round().clamp(0, 255), 248, 250, 252),
          const Color.fromARGB(0, 255, 255, 255),
        ],
        stops: const [0.0, 0.25, 0.70, 1.0],
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
