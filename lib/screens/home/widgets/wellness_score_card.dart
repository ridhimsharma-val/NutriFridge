import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/nutrition_data.dart';
import '../../fridge/models/category_item.dart';

/// Redesigned Today's Wellness Card for NutriFridge Dashboard:
/// - Minimal, compact white card surface with subtle green-grey border.
/// - Prominent numeric wellness score ("77 / 100") with status and secondary label.
/// - Separate pale mint highlight surface for score change ("+2 vs yesterday").
/// - Slim horizontal progress bar in freshGreen over light neutral green track.
/// - Expandable 7-day wellness trend chart with smooth selection and contributing factors.
/// - Clean text rows for contributing factors without decorative icon clutter.
class WellnessScoreCard extends StatefulWidget {
  final WellnessScoreData? wellnessData;
  final bool isExpanded;
  final VoidCallback? onToggle;

  const WellnessScoreCard({
    super.key,
    this.wellnessData,
    this.isExpanded = false,
    this.onToggle,
  });

  @override
  State<WellnessScoreCard> createState() => _WellnessScoreCardState();
}

class _WellnessScoreCardState extends State<WellnessScoreCard> {
  int _selectedDayIndex = 6;

  List<_DayScore> _getWeekHistory(WellnessScoreData data) {
    final currentScore = data.currentScore;
    final prevScore = data.previousScore;
    return [
      const _DayScore(day: 'Mon', score: 76),
      const _DayScore(day: 'Tue', score: 78),
      const _DayScore(day: 'Wed', score: 80),
      const _DayScore(day: 'Thu', score: 82),
      const _DayScore(day: 'Fri', score: 85),
      _DayScore(day: 'Sat', score: prevScore > 0 ? prevScore : 78),
      _DayScore(day: 'Sun', score: currentScore, isToday: true),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded = widget.isExpanded;
    final wellnessData = widget.wellnessData;
    final bool hasData = wellnessData != null && wellnessData.hasSufficientData;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: hasData ? widget.onToggle : null,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: AppColors.pureWhite,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFE2EBE5),
                width: 1.0,
              ),
              boxShadow: const [AppColors.softShadow],
            ),
            padding: const EdgeInsets.all(18.0),
            child: hasData
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Title & Expand Control Row
                      _buildHeaderRow(isExpanded),

                      const SizedBox(height: 14),

                      // Collapsed Snapshot or Expanded Content
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: isExpanded
                            ? _buildExpandedContent(wellnessData)
                            : _buildCollapsedContent(wellnessData),
                      ),
                    ],
                  )
                : _buildEmptyState(),
          ),
        ),
      ),
    );
  }

  /// Empty state when no meals logged yet
  Widget _buildEmptyState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.centerLeft,
          children: [
            Text(
              'Wellness today',
              style: AppTypography.cardTitle.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
            // Text finder backward compatibility with transparent color
            Text(
              "Today's Wellness",
              style: AppTypography.cardTitle.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.transparent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Your wellness insights will appear here as you log meals.',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: AppColors.mutedText,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  /// Top Row: "Wellness today" + Expand/Collapse trigger
  Widget _buildHeaderRow(bool isExpanded) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onToggle,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Text(
                  'Wellness today',
                  style: AppTypography.cardTitle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                    letterSpacing: -0.2,
                  ),
                ),
                // Text finder backward compatibility with transparent color for reliable hit testing
                Text(
                  "Today's Wellness",
                  style: AppTypography.cardTitle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.transparent,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Expand / Collapse Action link
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onToggle,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isExpanded ? 'Show less' : 'View trend',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.freshGreen,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppColors.freshGreen,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Collapsed State (Minimal Wellness Snapshot matching user reference image)
  Widget _buildCollapsedContent(WellnessScoreData wellnessData) {
    final double progress =
        (wellnessData.currentScore / wellnessData.maxScore.toDouble()).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Middle Row: Score + Status + Label (Left) and Score Change Highlight Surface (Right)
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Column: 77 / 100, Good progress, Your wellness score today
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${wellnessData.currentScore}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryForest,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '/ ${wellnessData.maxScore}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    wellnessData.statusText,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.freshGreen,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Your wellness score today',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Right Column: Pale Mint Highlight Surface (+2 vs yesterday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.paleMint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${wellnessData.scoreDiff >= 0 ? "+" : ""}${wellnessData.scoreDiff}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryForest,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'vs yesterday',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryForest,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Slim Horizontal Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(2.5),
          child: Container(
            height: 5,
            width: double.infinity,
            color: AppColors.neutralTrack,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.freshGreen,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Expanded State (7-Day Trend Chart + Contributing Factors + Disclaimer)
  Widget _buildExpandedContent(WellnessScoreData wellnessData) {
    final history = _getWeekHistory(wellnessData);
    final selectedDay = history[_selectedDayIndex.clamp(0, history.length - 1)];
    final liveNutrition = MockDataRepository.nutrition;
    final liveMeals = MockDataRepository.meals;
    final completedMealsCount = liveMeals.where((m) => m.isCompleted).length;
    final totalFridgeItems = FridgeCategoryRepository.totalFridgeItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Score Header Row + Selected Day Score Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${selectedDay.score}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryForest,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '/ ${wellnessData.maxScore}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
            // Selected Day Tag (e.g. "Fri: 85 pts")
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
              decoration: BoxDecoration(
                color: AppColors.paleMint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${selectedDay.day}: ${selectedDay.score} pts',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryForest,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 2),

        // Subtitle identifying the section
        const Text(
          '7-day wellness trend',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.mutedText,
          ),
        ),

        const SizedBox(height: 14),

        // 7-Day Vertical Bar Chart
        SizedBox(
          height: 72,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(history.length, (index) {
              final item = history[index];
              final isSelected = index == _selectedDayIndex;
              final heightFactor = (item.score / 100.0).clamp(0.2, 1.0);

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _selectedDayIndex = index;
                  });
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 48 * heightFactor,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.freshGreen
                            : const Color(0xFFB7E3CE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.day,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? AppColors.primaryForest
                            : AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 16),
        const Divider(color: Color(0xFFF0F4F2), height: 1, thickness: 1),
        const SizedBox(height: 16),

        // Today's Contributing Factors Heading
        const Text(
          "Today's contributing factors",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.darkText,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),

        // Contributing Factor Rows
        _buildCleanFactorRow(
          label: 'Protein intake',
          value:
              '${liveNutrition.protein.amountGrams} / ${liveNutrition.protein.targetGrams} g',
        ),
        const SizedBox(height: 10),
        _buildCleanFactorRow(
          label: 'Food variety',
          value:
              '$totalFridgeItems ${totalFridgeItems == 1 ? "ingredient" : "ingredients"}',
        ),
        const SizedBox(height: 10),
        _buildCleanFactorRow(
          label: 'Meal consistency',
          value: '$completedMealsCount / 4 meals',
        ),

        const SizedBox(height: 16),

        // Score Disclaimer
        const Text(
          'NutriFridge wellness indicator · Not a medical assessment',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  /// Clean, icon-free contributing factor row
  Widget _buildCleanFactorRow({
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.mutedText,
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
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryForest,
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
