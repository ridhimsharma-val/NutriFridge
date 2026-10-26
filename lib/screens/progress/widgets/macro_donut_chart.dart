import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Cinematic Macronutrient Calorie Donut Chart
/// Visualizes the proportional calorie contributions from Protein (4 kcal/g),
/// Carbohydrates (4 kcal/g), and Fat (9 kcal/g) with animated arc segments and clear center metrics.
class MacroDonutChart extends StatefulWidget {
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final int centerCalories;
  final String centerLabel;

  const MacroDonutChart({
    super.key,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.centerCalories,
    this.centerLabel = 'Daily average',
  });

  @override
  State<MacroDonutChart> createState() => _MacroDonutChartState();
}

class _MacroDonutChartState extends State<MacroDonutChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;

  static const Color proteinColor = Color(0xFF2A8B74); // Teal / Green
  static const Color carbsColor = Color(0xFFE07854); // Soft Peach / Coral
  static const Color fatColor = Color(0xFFD4A343); // Muted Golden Yellow

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant MacroDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.proteinGrams != widget.proteinGrams ||
        oldWidget.carbsGrams != widget.carbsGrams ||
        oldWidget.fatGrams != widget.fatGrams) {
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
    // 1. Calorie calculations based on grams
    final int proteinKcal = widget.proteinGrams * 4;
    final int carbsKcal = widget.carbsGrams * 4;
    final int fatKcal = widget.fatGrams * 9;
    final int totalMacroKcal = proteinKcal + carbsKcal + fatKcal;

    // 2. Calorie percentage distribution
    final double proteinPct =
        totalMacroKcal > 0 ? (proteinKcal / totalMacroKcal) * 100 : 0.0;
    final double carbsPct =
        totalMacroKcal > 0 ? (carbsKcal / totalMacroKcal) * 100 : 0.0;
    final double fatPct =
        totalMacroKcal > 0 ? (fatKcal / totalMacroKcal) * 100 : 0.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: const [AppColors.softShadow],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Text(
            'Calorie distribution by macro',
            style: AppTypography.cardTitle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Calculated from 4 kcal/g (protein, carbs) and 9 kcal/g (fat)',
            style: AppTypography.subtitle.copyWith(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 24),

          // Centered Donut Visualization
          Center(
            child: SizedBox(
              width: 190,
              height: 190,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _MacroDonutPainter(
                      progress: _animation.value,
                      proteinPct: proteinPct,
                      carbsPct: carbsPct,
                      fatPct: fatPct,
                      proteinColor: proteinColor,
                      carbsColor: carbsColor,
                      fatColor: fatColor,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${widget.centerCalories}',
                            style: AppTypography.cardTitle.copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                              color: AppColors.textPrimary,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'kcal',
                            style: AppTypography.subtitle.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.centerLabel,
                            style: AppTypography.subtitle.copyWith(
                              fontSize: 10.5,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Compact Macro Legend (with grams & calorie percentages)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroLegendItem(
                label: 'Protein',
                color: proteinColor,
                percentage: proteinPct.round(),
                grams: widget.proteinGrams,
              ),
              _buildMacroLegendItem(
                label: 'Carbs',
                color: carbsColor,
                percentage: carbsPct.round(),
                grams: widget.carbsGrams,
              ),
              _buildMacroLegendItem(
                label: 'Fat',
                color: fatColor,
                percentage: fatPct.round(),
                grams: widget.fatGrams,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroLegendItem({
    required String label,
    required Color color,
    required int percentage,
    required int grams,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$percentage%',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          '$grams g',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Custom painter for the 3-segment macronutrient donut chart
class _MacroDonutPainter extends CustomPainter {
  final double progress;
  final double proteinPct;
  final double carbsPct;
  final double fatPct;
  final Color proteinColor;
  final Color carbsColor;
  final Color fatColor;

  const _MacroDonutPainter({
    required this.progress,
    required this.proteinPct,
    required this.carbsPct,
    required this.fatPct,
    required this.proteinColor,
    required this.carbsColor,
    required this.fatColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;
    const strokeWidth = 14.0;

    // Background track if empty
    final bgPaint = Paint()
      ..color = const Color(0xFFF1F5F2)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, bgPaint);

    if (progress <= 0.001) return;

    final double totalPct = proteinPct + carbsPct + fatPct;
    if (totalPct <= 0.0) return;

    // Angles: start at top (-pi / 2)
    const double gapAngle = 0.05; // Subtle gap between segments
    double currentAngle = -math.pi / 2;

    void drawSegment(double pct, Color color) {
      if (pct <= 0) return;
      final sweepAngle = (2 * math.pi * (pct / totalPct) * progress) - gapAngle;
      if (sweepAngle <= 0) return;

      final paint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle + (gapAngle / 2),
        sweepAngle,
        false,
        paint,
      );

      currentAngle += (2 * math.pi * (pct / totalPct) * progress);
    }

    drawSegment(proteinPct, proteinColor);
    drawSegment(carbsPct, carbsColor);
    drawSegment(fatPct, fatColor);
  }

  @override
  bool shouldRepaint(covariant _MacroDonutPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.proteinPct != proteinPct ||
        oldDelegate.carbsPct != carbsPct ||
        oldDelegate.fatPct != fatPct;
  }
}
