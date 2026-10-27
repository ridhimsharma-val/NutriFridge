import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_typography.dart';

/// Cinematic Wellness Score Hero Section
/// Features deep navy/forest-green gradient, elegant typography, and animated circular score ring.
class WellnessScoreHero extends StatefulWidget {
  final int score;
  final int? previousScore;
  final String interpretation;

  const WellnessScoreHero({
    super.key,
    required this.score,
    this.previousScore,
    required this.interpretation,
  });

  @override
  State<WellnessScoreHero> createState() => _WellnessScoreHeroState();
}

class _WellnessScoreHeroState extends State<WellnessScoreHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scoreAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scoreAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant WellnessScoreHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int scoreDiff = widget.previousScore != null
        ? widget.score - widget.previousScore!
        : 0;
    final bool hasDiff = widget.previousScore != null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF091815), // Midnight forest
            Color(0xFF0F2620), // Deep spruce
            Color(0xFF143029), // Rich pine
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF091815).withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Section Sub-tag
          Text(
            'WELLNESS SCORE',
            style: AppTypography.subtitle.copyWith(
              color: const Color(0xFF7FA899),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),

          // Cinematic Animated Circular Score Ring
          AnimatedBuilder(
            animation: _scoreAnimation,
            builder: (context, child) {
              final double progress = (widget.score / 100.0) * _scoreAnimation.value;
              final int currentDisplayScore = (widget.score * _scoreAnimation.value).round();

              return SizedBox(
                width: 124,
                height: 124,
                child: CustomPaint(
                  painter: _WellnessRingPainter(
                    progress: progress,
                    trackColor: const Color(0xFF183B32),
                    glowColor: const Color(0xFF38B293),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$currentDisplayScore',
                          style: AppTypography.scoreLarge.copyWith(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.0,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'out of 100',
                          style: AppTypography.subtitle.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF88AF9F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // Short human-readable interpretation
          Text(
            widget.interpretation,
            textAlign: TextAlign.center,
            style: AppTypography.greeting.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),

          const SizedBox(height: 6),

          // Comparison with previous period (only if historical baseline exists)
          if (hasDiff)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.8,
                ),
              ),
              child: Text(
                '${scoreDiff >= 0 ? "+" : ""}$scoreDiff vs previous period (demo baseline)',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFA5D6C5),
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Honest editorial indicator disclaimer
          Text(
            'NutriFridge wellness indicator • Not a medical assessment',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the smooth circular wellness score ring
class _WellnessRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color glowColor;

  const _WellnessRingPainter({
    required this.progress,
    required this.trackColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;
    const strokeWidth = 8.5;

    // 1. Background full track
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0.001) return;

    // 2. Subtle soft glow behind active arc
    final glowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.28)
      ..strokeWidth = strokeWidth + 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      glowPaint,
    );

    // 3. Foreground vibrant gradient arc
    final arcPaint = Paint()
      ..shader = const SweepGradient(
        startAngle: 0.0,
        endAngle: math.pi * 2,
        colors: [
          Color(0xFF2A8B74),
          Color(0xFF4ADE80),
          Color(0xFF6EE7B7),
          Color(0xFF2A8B74),
        ],
        stops: [0.0, 0.4, 0.8, 1.0],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _WellnessRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.glowColor != glowColor;
  }
}
