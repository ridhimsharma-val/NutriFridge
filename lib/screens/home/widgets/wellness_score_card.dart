import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/nutrition_data.dart';
import '../../fridge/models/category_item.dart';

/// Expandable Today's Wellness Card.
/// Collapsed state is visually unchanged.
/// Expanding reveals a 7-day interactive wellness chart, supporting factors, and disclaimer.
class WellnessScoreCard extends StatefulWidget {
  final WellnessScoreData wellnessData;
  final bool isExpanded;
  final VoidCallback? onToggle;

  const WellnessScoreCard({
    super.key,
    required this.wellnessData,
    this.isExpanded = false,
    this.onToggle,
  });

  @override
  State<WellnessScoreCard> createState() => _WellnessScoreCardState();
}

class _WellnessScoreCardState extends State<WellnessScoreCard> {
  int _selectedDayIndex = 6; // Defaults to Today (Sunday)

  static const List<_DayScore> _sevenDayHistory = [
    _DayScore(day: 'Mon', score: 76),
    _DayScore(day: 'Tue', score: 78),
    _DayScore(day: 'Wed', score: 80),
    _DayScore(day: 'Thu', score: 82),
    _DayScore(day: 'Fri', score: 85),
    _DayScore(day: 'Sat', score: 78),
    _DayScore(day: 'Sun', score: 82, isToday: true),
  ];

  @override
  Widget build(BuildContext context) {
    final isExpanded = widget.isExpanded;
    final wellnessData = widget.wellnessData;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onToggle,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Collapsed Summary Row (Visually unchanged)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18.0,
                    vertical: 16.0,
                  ),
                  child: Row(
                    children: [
                      // Left Column: Information & Delta
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header title (Editorial typography, visually unchanged)
                            Text(
                              "Today's Wellness",
                              style: AppTypography.cardTitle.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Subtitle / qualitative feedback
                            Text(
                              wellnessData.statusText,
                              style: AppTypography.scoreSubtitle.copyWith(
                                color: AppColors.tealPrimary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Upward score comparison pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
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
                              child: Text(
                                '+${wellnessData.scoreDiff} points from yesterday',
                                style: AppTypography.badgeText.copyWith(
                                  color: AppColors.tealPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Right Column: Circular Progress Ring with Score
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
                                    color: AppColors.tealPrimary
                                        .withValues(alpha: 0.08),
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

                // Expanded Section Animated Inline
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: isExpanded
                      ? _buildExpandedContent(wellnessData)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedContent(WellnessScoreData wellnessData) {
    final selectedDay = _sevenDayHistory[_selectedDayIndex];
    final liveNutrition = MockDataRepository.nutrition;
    final liveMeals = MockDataRepository.meals;
    final completedMealsCount =
        liveMeals.where((m) => m.isCompleted).length;
    final totalFridgeItems = FridgeCategoryRepository.totalFridgeItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Divider
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 18),
          color: const Color(0xFFC7E7DA).withValues(alpha: 0.7),
        ),

        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A. Seven-Day Wellness Chart Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      '7-day wellness trend',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFBCE3D3),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '${selectedDay.day}: ${selectedDay.score} pts',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.tealPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Interactive 7-Day Bar Chart
              SizedBox(
                height: 78,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(_sevenDayHistory.length, (index) {
                    final item = _sevenDayHistory[index];
                    final isSelected = index == _selectedDayIndex;
                    final heightFactor = (item.score / 100.0).clamp(0.2, 1.0);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDayIndex = index;
                        });
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 28,
                            height: 52 * heightFactor,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.tealPrimary
                                  : (item.isToday
                                      ? AppColors.tealAccent
                                      : const Color(0xFFB5DEC9)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item.day,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? AppColors.tealPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 18),

              // B. Today's Score Breakdown Factors
              const Text(
                "Today's contributing factors",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              _buildFactorRow(
                label: 'Protein intake',
                value:
                    '${liveNutrition.protein.amountGrams}g of ${liveNutrition.protein.targetGrams}g reached',
                pct: liveNutrition.protein.progress,
              ),
              const SizedBox(height: 6),
              _buildFactorRow(
                label: 'Food variety',
                value: '$totalFridgeItems fresh ingredients in fridge',
                pct: (totalFridgeItems / 40.0).clamp(0.1, 1.0),
              ),
              const SizedBox(height: 6),
              _buildFactorRow(
                label: 'Meal consistency',
                value: '$completedMealsCount of 4 meals recorded today',
                pct: (completedMealsCount / 4.0).clamp(0.1, 1.0),
              ),

              const SizedBox(height: 14),

              // C. Comparison & D. Disclaimer
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFBCE3D3).withValues(alpha: 0.6),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Score change: +${wellnessData.scoreDiff} pts vs yesterday (${wellnessData.previousScore})',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.tealPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'NutriFridge wellness indicator · Not a medical assessment',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFactorRow({
    required String label,
    required String value,
    required double pct,
  }) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: AppColors.tealPrimary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _DayScore {
  final String day;
  final int score;
  final bool isToday;

  const _DayScore({
    required this.day,
    required this.score,
    this.isToday = false,
  });
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
