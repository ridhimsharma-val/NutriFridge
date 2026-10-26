import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/nutrition_data.dart';

class WellnessScoreCard extends StatelessWidget {
  final WellnessScoreData wellnessData;
  final VoidCallback? onTap;

  const WellnessScoreCard({
    super.key,
    required this.wellnessData,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFE7F6F0),
                Color(0xFFD8EFE6),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFC7E7DA),
              width: 1.2,
            ),
            boxShadow: const [AppColors.softShadow],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
            child: Row(
              children: [
                // Left Column: Information & Delta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header badge / title
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4.5),
                            decoration: BoxDecoration(
                              color: AppColors.tealPrimary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              size: 13,
                              color: AppColors.tealPrimary,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              "Today's Wellness",
                              style: AppTypography.cardTitle.copyWith(
                                fontSize: 15.5,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8), // Reduced vertical spacing
                      // Subtitle / qualitative feedback
                      Text(
                        wellnessData.statusText,
                        style: AppTypography.scoreSubtitle.copyWith(
                          color: AppColors.tealPrimary,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 8), // Reduced vertical spacing
                      // Upward score comparison pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardWhite.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFBCE3D3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.arrow_upward_rounded,
                              size: 12.5,
                              color: AppColors.tealAccent,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                '↑ ${wellnessData.scoreDiff} points from yesterday',
                                style: AppTypography.badgeText.copyWith(
                                  color: AppColors.tealPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Right Column: Circular Progress Ring with Score (Refined compact dimensions)
                SizedBox(
                  width: 86,
                  height: 86,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background white disk
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.cardWhite.withValues(alpha: 0.9),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.tealPrimary.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                      // Custom Circular Ring
                      CustomPaint(
                        size: const Size(86, 86),
                        painter: _ScoreRingPainter(
                          progress: wellnessData.currentScore /
                              wellnessData.maxScore.toDouble(),
                          trackColor: const Color(0xFFD4ECE2),
                          progressColor: AppColors.tealAccent,
                          strokeWidth: 6.5,
                        ),
                      ),
                      // Score Number
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${wellnessData.currentScore}',
                            style: AppTypography.scoreLarge.copyWith(
                              fontSize: 29,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            '/ 100',
                            style: AppTypography.badgeText.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _ScoreRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Active arc
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

  @override
  bool shouldRepaint(covariant _ScoreRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
