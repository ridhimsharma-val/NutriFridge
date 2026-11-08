import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_typography.dart';

/// Cinematic Wellness Score Hero Section
/// Mobile-first card featuring deep midnight/pine gradient, elegant typography,
/// and smooth circular animated score ring.
class WellnessScoreHero extends StatefulWidget {
  final int score;
  final int? previousScore;
  final String interpretation;

  const WellnessScoreHero({
    super.key,
    required this.score,
    this.previousScore,
    this.interpretation = '',
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Section Heading
          Text(
            'WELLNESS SCORE',
            style: AppTypography.subtitle.copyWith(
              color: const Color(0xFF7FA899),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 16),

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
                        const SizedBox(height: 3),
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
