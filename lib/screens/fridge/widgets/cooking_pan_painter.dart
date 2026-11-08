import 'package:flutter/material.dart';

/// CustomPainter that renders a realistic 2.5D physical cooking pan (skillet).
///
/// Features:
/// - 2.5D perspective with deep charcoal/graphite non-stick interior.
/// - Raised circular/oval metallic rim with specular edge highlights.
/// - Realistic ergonomic wooden handle with metallic bolster, rivets, and hanging hole.
/// - Outer body depth wall with directional shading.
/// - Soft ambient drop shadow underneath for elevation.
/// - Concentric thermal rings on cooking floor.
/// - Landing ripple and bounce effects.
class CookingPanPainter extends CustomPainter {
  final double bounceFactor; // 0.0 = rest, up to 1.0 for bounce deformation
  final double rippleProgress; // 0.0 = none, 0.0 -> 1.0 expanding ripple
  final bool isCompact;

  const CookingPanPainter({
    this.bounceFactor = 0.0,
    this.rippleProgress = 0.0,
    this.isCompact = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Pan geometry relative to widget size
    // Layout: Handle on the left ~32% of total width, pan body takes right ~68%
    final double handleRatio = isCompact ? 0.28 : 0.32;
    final double panBodyWidth = size.width * (1.0 - handleRatio);
    final double handleWidth = size.width * handleRatio;

    // Center of pan body
    final double panCenterX = handleWidth + (panBodyWidth * 0.50);
    final double panCenterY = size.height * 0.48;

    // Radius of outer rim ellipse (2.5D perspective aspect ratio ~0.60)
    final double rx = (panBodyWidth * 0.46);
    final double ry = rx * 0.62;

    // Outer pan depth (wall thickness/drop)
    final double depth = isCompact ? 7.0 : 12.0;

    // Apply subtle vertical squash & stretch from bounceFactor
    final double squashY = 1.0 - (bounceFactor * 0.06);
    final double stretchX = 1.0 + (bounceFactor * 0.04);

    canvas.save();
    canvas.translate(panCenterX, panCenterY);
    canvas.scale(stretchX, squashY);
    canvas.translate(-panCenterX, -panCenterY);

    // ========================================================
    // 1. AMBIENT DROP SHADOW UNDER PAN & HANDLE
    // ========================================================
    final shadowPaint = Paint()
      ..color = const Color(0x380A0D11)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isCompact ? 6.0 : 12.0);

    // Body shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(panCenterX + 2, panCenterY + depth + (isCompact ? 4 : 7)),
        width: rx * 2.05,
        height: ry * 1.9,
      ),
      shadowPaint,
    );

    // Handle shadow
    final handleShadowPath = Path()
      ..moveTo(handleWidth + 4, panCenterY + 4)
      ..lineTo(6, panCenterY + 12)
      ..quadraticBezierTo(2, panCenterY + 15, 6, panCenterY + 18)
      ..lineTo(handleWidth + 4, panCenterY + 14)
      ..close();
    canvas.drawPath(handleShadowPath, shadowPaint);

    // ========================================================
    // 2. ERGONOMIC WOODEN HANDLE
    // ========================================================
    _paintHandle(canvas, size, handleWidth, panCenterX, panCenterY, rx, ry);

    // ========================================================
    // 3. PAN BODY OUTER WALL (DEPTH)
    // ========================================================
    final outerWallPath = Path()
      ..moveTo(panCenterX - rx, panCenterY)
      ..arcToPoint(
        Offset(panCenterX + rx, panCenterY),
        radius: Radius.elliptical(rx, ry),
        largeArc: false,
        clockwise: false,
      )
      ..lineTo(panCenterX + rx, panCenterY + depth)
      ..arcToPoint(
        Offset(panCenterX - rx, panCenterY + depth),
        radius: Radius.elliptical(rx, ry),
        largeArc: false,
        clockwise: true,
      )
      ..close();

    final outerWallGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFF32363E), // Cast graphite top edge
        Color(0xFF22252B), // Mid matte
        Color(0xFF14161A), // Deep base shadow
      ],
      stops: const [0.0, 0.45, 1.0],
    );

    final wallPaint = Paint()
      ..shader = outerWallGradient.createShader(
        Rect.fromLTRB(panCenterX - rx, panCenterY, panCenterX + rx, panCenterY + depth),
      );
    canvas.drawPath(outerWallPath, wallPaint);

    // Bottom edge specular rim reflection
    final bottomRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isCompact ? 0.8 : 1.2
      ..shader = const LinearGradient(
        colors: [Color(0x00FFFFFF), Color(0x33FFFFFF), Color(0x00FFFFFF)],
        stops: [0.1, 0.5, 0.9],
      ).createShader(
        Rect.fromLTWH(panCenterX - rx, panCenterY + depth - 2, rx * 2, 4),
      );

    final bottomRimPath = Path()
      ..moveTo(panCenterX - (rx * 0.85), panCenterY + depth + (ry * 0.85))
      ..arcToPoint(
        Offset(panCenterX + (rx * 0.85), panCenterY + depth + (ry * 0.85)),
        radius: Radius.elliptical(rx, ry),
        clockwise: true,
      );
    canvas.drawPath(bottomRimPath, bottomRimPaint);

    // ========================================================
    // 4. PAN OUTER METALLIC RIM
    // ========================================================
    final rimRect = Rect.fromCenter(
      center: Offset(panCenterX, panCenterY),
      width: rx * 2,
      height: ry * 2,
    );

    // Rim base
    final rimGradient = SweepGradient(
      center: Alignment.center,
      colors: const [
        Color(0xFF4C525E), // Top left light
        Color(0xFF6B7483), // Specular gleam
        Color(0xFF383D46), // Shadow right
        Color(0xFF21242A), // Deep bottom
        Color(0xFF4C525E),
      ],
      stops: const [0.0, 0.25, 0.6, 0.85, 1.0],
    );

    final rimPaint = Paint()
      ..shader = rimGradient.createShader(rimRect)
      ..style = PaintingStyle.fill;
    canvas.drawOval(rimRect, rimPaint);

    // Top-left metallic specular highlight line
    final specPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isCompact ? 1.0 : 1.6
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xBBFFFFFF), Color(0x22FFFFFF), Color(0x00FFFFFF)],
        stops: [0.0, 0.35, 0.7],
      ).createShader(rimRect);
    canvas.drawOval(rimRect, specPaint);

    // ========================================================
    // 5. INNER NON-STICK COOKING INTERIOR
    // ========================================================
    final double innerMargin = isCompact ? 3.0 : 5.0;
    final double innerRx = rx - innerMargin;
    final double innerRy = ry - (innerMargin * 0.75);

    final interiorRect = Rect.fromCenter(
      center: Offset(panCenterX, panCenterY + (isCompact ? 0.5 : 1.0)),
      width: innerRx * 2,
      height: innerRy * 2,
    );

    // Non-stick interior floor (Deep charcoal radial sheen)
    final interiorGradient = RadialGradient(
      center: const Alignment(-0.25, -0.3),
      radius: 0.85,
      colors: const [
        Color(0xFF2C3038), // Center warm graphite sheen
        Color(0xFF202329), // Mid charcoal non-stick
        Color(0xFF14161A), // Deep edge recession
      ],
      stops: const [0.0, 0.55, 1.0],
    );

    final interiorPaint = Paint()
      ..shader = interiorGradient.createShader(interiorRect)
      ..style = PaintingStyle.fill;
    canvas.drawOval(interiorRect, interiorPaint);

    // Subtle concentric thermal induction rings
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0x18FFFFFF);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(panCenterX, panCenterY + 1),
        width: innerRx * 1.35,
        height: innerRy * 1.35,
      ),
      ringPaint,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(panCenterX, panCenterY + 1),
        width: innerRx * 0.75,
        height: innerRy * 0.75,
      ),
      ringPaint,
    );

    // Inner rim depth bevel (Top inner rim casts a soft shadow downward)
    final innerShadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isCompact ? 1.5 : 2.5
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x88000000), Color(0x00000000)],
        stops: [0.0, 0.4],
      ).createShader(interiorRect);
    canvas.drawOval(interiorRect, innerShadowPaint);

    // ========================================================
    // 6. LANDING RIPPLE / IMPACT REACTION
    // ========================================================
    if (rippleProgress > 0.0 && rippleProgress < 1.0) {
      final double rippleRx = innerRx * (0.2 + 0.75 * rippleProgress);
      final double rippleRy = innerRy * (0.2 + 0.75 * rippleProgress);
      final double rippleAlpha = (1.0 - rippleProgress).clamp(0.0, 1.0);

      final ripplePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isCompact ? 1.2 : 2.0
        ..color = const Color(0xFFB7E34B).withValues(alpha: 0.55 * rippleAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(panCenterX, panCenterY + 1),
          width: rippleRx * 2,
          height: rippleRy * 2,
        ),
        ripplePaint,
      );
    }

    canvas.restore();
  }

  /// Paints the ergonomic wooden handle with metallic neck bracket and rivets.
  void _paintHandle(
    Canvas canvas,
    Size size,
    double handleWidth,
    double panCenterX,
    double panCenterY,
    double rx,
    double ry,
  ) {
    final double attachX = panCenterX - (rx * 0.94);
    final double attachY = panCenterY;

    // 1. Metal connector bracket (bolster)
    final double bracketWidth = isCompact ? 10.0 : 16.0;
    final double bracketHeight = isCompact ? 8.0 : 13.0;
    final bracketRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(attachX - (bracketWidth * 0.35), attachY),
        width: bracketWidth,
        height: bracketHeight,
      ),
      Radius.circular(isCompact ? 2.5 : 4.0),
    );

    final bracketGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF6B7280), Color(0xFF374151), Color(0xFF1F2937)],
      stops: [0.0, 0.5, 1.0],
    );

    canvas.drawRRect(
      bracketRect,
      Paint()..shader = bracketGradient.createShader(bracketRect.outerRect),
    );

    // Two small metallic rivets on bracket
    final rivetPaint = Paint()..color = const Color(0xFFD1D5DB);
    final rivetShadow = Paint()..color = const Color(0xFF111827);
    final double rivetRadius = isCompact ? 1.0 : 1.6;

    final Offset r1 = Offset(attachX - (bracketWidth * 0.45), attachY - (bracketHeight * 0.22));
    final Offset r2 = Offset(attachX - (bracketWidth * 0.45), attachY + (bracketHeight * 0.22));
    canvas.drawCircle(r1 + const Offset(0, 0.6), rivetRadius, rivetShadow);
    canvas.drawCircle(r1, rivetRadius, rivetPaint);
    canvas.drawCircle(r2 + const Offset(0, 0.6), rivetRadius, rivetShadow);
    canvas.drawCircle(r2, rivetRadius, rivetPaint);

    // 2. Wooden Handle Shaft
    final double tipX = isCompact ? 6.0 : 10.0;
    final double tipY = attachY;
    final double handleLen = (attachX - bracketWidth * 0.7) - tipX;
    if (handleLen <= 0) return;

    final double startY = attachY;
    final double thickMid = isCompact ? 7.0 : 11.0;
    final double thickEnd = isCompact ? 5.5 : 8.5;

    final handlePath = Path()
      // Top contour
      ..moveTo(attachX - (bracketWidth * 0.7), startY - (thickMid * 0.6))
      ..quadraticBezierTo(
        tipX + (handleLen * 0.5),
        startY - (thickMid * 0.95), // Ergonomic upper swell
        tipX + (thickEnd * 0.5),
        tipY - (thickEnd * 0.5),
      )
      // Rounded handle tip
      ..arcToPoint(
        Offset(tipX + (thickEnd * 0.5), tipY + (thickEnd * 0.5)),
        radius: Radius.circular(thickEnd * 0.5),
        clockwise: false,
      )
      // Bottom contour
      ..quadraticBezierTo(
        tipX + (handleLen * 0.5),
        startY + (thickMid * 0.95), // Ergonomic lower swell
        attachX - (bracketWidth * 0.7),
        startY + (thickMid * 0.6),
      )
      ..close();

    // Warm natural walnut / acacia wood grain gradient
    final woodGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFFA56635), // Top light grain highlight
        Color(0xFF824B20), // Rich acacia midtone
        Color(0xFF5A3112), // Deep shadow underside
      ],
      stops: const [0.0, 0.45, 1.0],
    );

    final woodPaint = Paint()
      ..shader = woodGradient.createShader(
        Rect.fromLTRB(tipX, startY - thickMid, attachX, startY + thickMid),
      );
    canvas.drawPath(handlePath, woodPaint);

    // Subtle woodgrain longitudinal striation
    final grainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0x28000000);

    canvas.drawLine(
      Offset(tipX + (handleLen * 0.25), startY),
      Offset(attachX - (bracketWidth * 0.8), startY),
      grainPaint,
    );

    // 3. Hanging Hole at Tip
    final double holeRadius = isCompact ? 1.8 : 3.0;
    final Offset holeCenter = Offset(tipX + (thickEnd * 0.9), tipY);

    // Metallic eyelet rim
    canvas.drawCircle(
      holeCenter,
      holeRadius + (isCompact ? 0.8 : 1.2),
      Paint()..color = const Color(0xFF4B5563),
    );
    // Dark hole opening
    canvas.drawCircle(
      holeCenter,
      holeRadius,
      Paint()..color = const Color(0xFF1E242C),
    );
  }

  @override
  bool shouldRepaint(covariant CookingPanPainter oldDelegate) {
    return oldDelegate.bounceFactor != bounceFactor ||
        oldDelegate.rippleProgress != rippleProgress ||
        oldDelegate.isCompact != isCompact;
  }
}
