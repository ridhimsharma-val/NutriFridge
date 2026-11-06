import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Reusable circular calorie progress widget inspired by the reference design.
///
/// Features:
/// - Smooth circular progress arc with clean rounded caps
/// - Zero-consumption state with neutral empty track
/// - Over-target state with clear surplus indicator
/// - Large bold calorie count with goal & remaining callout
/// - Uses actual repository values without mock calculations
class CircularCalorieRing extends StatelessWidget {
  final int consumedCalories;
  final int targetCalories;
  final double diameter;
  final double strokeWidth;
  final Color trackColor;
  final Color progressColor;
  final VoidCallback? onTap;

  const CircularCalorieRing({
    super.key,
    required this.consumedCalories,
    required this.targetCalories,
    this.diameter = 164.0,
    this.strokeWidth = 11.0,
    this.trackColor = AppColors.neutralTrack,
    this.progressColor = AppColors.freshGreen,
    this.onTap,
  });

  double get progress {
    if (targetCalories <= 0) return 0.0;
    return (consumedCalories / targetCalories).clamp(0.0, 1.0);
  }

  int get remainingCalories => targetCalories - consumedCalories;
  bool get isOverTarget => remainingCalories < 0;
  bool get isZero => consumedCalories <= 0;

  @override
  Widget build(BuildContext context) {
    Widget ringWidget = SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Track & Active Arc Painter
          CustomPaint(
            size: Size(diameter, diameter),
            painter: _CalorieRingPainter(
              progress: progress,
              strokeWidth: strokeWidth,
              trackColor: trackColor,
              progressColor: isOverTarget ? AppColors.coralHighlight : progressColor,
            ),
          ),

          // Central Numerical Display
          Padding(
            padding: EdgeInsets.all(strokeWidth + 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _formatNumber(consumedCalories),
                    style: AppTypography.calorieHeroNumber.copyWith(
                      fontSize: 32,
                      color: AppColors.neutralCharcoal,
                    ),
                  ),
                  Text(
                    'kcal consumed',
                    style: AppTypography.calorieSubLabel.copyWith(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Remaining or Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isOverTarget
                          ? const Color(0xFFFFEDE6)
                          : (isZero ? const Color(0xFFF2F5F3) : AppColors.sageLight),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isZero
                          ? '${_formatNumber(targetCalories)} goal'
                          : (isOverTarget
                              ? '${_formatNumber(remainingCalories.abs())} over'
                              : '${_formatNumber(remainingCalories)} left'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isOverTarget
                            ? AppColors.coralHighlight
                            : (isZero ? AppColors.textSecondary : AppColors.forestGreen),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: ringWidget,
      );
    }

    return ringWidget;
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}

class _CalorieRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final Color progressColor;

  _CalorieRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 1. Full Circular Background Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // 2. Active Progress Arc (Starts from top at -90 degrees)
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CalorieRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}
