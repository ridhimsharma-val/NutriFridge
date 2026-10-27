import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../models/progress_data.dart';

/// Minimal LeetCode-style Meal Logging Consistency Heatmap
/// Visualizes meal logging activity with compact rounded-square cells,
/// 4 green intensity levels, day selection tooltip, factual summary, and clean legend.
class ConsistencyHeatmap extends StatefulWidget {
  final List<HeatmapCellData> cells;
  final String factualSummary;
  final String period;

  const ConsistencyHeatmap({
    super.key,
    required this.cells,
    required this.factualSummary,
    this.period = 'Week',
  });

  @override
  State<ConsistencyHeatmap> createState() => _ConsistencyHeatmapState();
}

class _ConsistencyHeatmapState extends State<ConsistencyHeatmap> {
  HeatmapCellData? _selectedCell;

  @override
  void initState() {
    super.initState();
    _initDefaultSelection();
  }

  @override
  void didUpdateWidget(covariant ConsistencyHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cells != widget.cells || oldWidget.period != widget.period) {
      _initDefaultSelection();
    }
  }

  void _initDefaultSelection() {
    // Default to today's cell, or the last non-padding cell
    if (widget.cells.isNotEmpty) {
      _selectedCell = widget.cells.firstWhere(
        (c) => c.isCurrentDay,
        orElse: () => widget.cells.lastWhere(
          (c) => !c.isPadding,
          orElse: () => widget.cells.last,
        ),
      );
    }
  }

  Color _getColorForLevel(int level, {bool isPadding = false}) {
    if (isPadding) {
      return Colors.transparent;
    }
    switch (level) {
      case 1:
        return const Color(0xFFBDE3D3); // Level 1: Light mint
      case 2:
        return const Color(0xFF5FB497); // Level 2: Medium mint / teal
      case 3:
        return const Color(0xFF1B6A5A); // Level 3: Deep teal / green
      case 0:
      default:
        return const Color(0xFFEBF1EE); // Level 0: Pale neutral empty cell
    }
  }

  String _formatDayDetail(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    const weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final int rowCount = (widget.cells.length / 7).ceil();
    final selected = _selectedCell;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: const [AppColors.softShadow],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Heading & Subtitle
          Text(
            'Meal logging consistency',
            style: AppTypography.cardTitle.copyWith(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Your meal activity',
            style: AppTypography.subtitle.copyWith(
              fontSize: 11.5,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 14),

          // 2. Weekday Column Headers (M, T, W, T, F, S, S)
          Row(
            children: weekdayLabels.map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),

          // 3. Compact Heatmap Grid of Rounded Squares
          Column(
            children: List.generate(rowCount, (row) {
              return Row(
                children: List.generate(7, (col) {
                  final index = (row * 7) + col;
                  if (index >= widget.cells.length) {
                    return const Expanded(child: SizedBox());
                  }

                  final cell = widget.cells[index];
                  final isSelected = selected != null &&
                      selected.date.year == cell.date.year &&
                      selected.date.month == cell.date.month &&
                      selected.date.day == cell.date.day;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2.5),
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: GestureDetector(
                          onTap: cell.isPadding
                              ? null
                              : () {
                                  setState(() {
                                    _selectedCell = cell;
                                  });
                                },
                          child: Container(
                            decoration: BoxDecoration(
                              color: _getColorForLevel(
                                cell.level,
                                isPadding: cell.isPadding,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              border: isSelected
                                  ? Border.all(
                                      color: AppColors.tealPrimary,
                                      width: 2.0,
                                    )
                                  : cell.isCurrentDay
                                      ? Border.all(
                                          color: const Color(0xFF1B6A5A),
                                          width: 1.8,
                                        )
                                      : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            }),
          ),

          const SizedBox(height: 12),

          // 4. Interactive Detail Row / Tooltip on Selection
          if (selected != null && !selected.isPadding)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F7F4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.tealPrimary.withValues(alpha: 0.18),
                  width: 0.8,
                ),
              ),
              child: Text(
                '${_formatDayDetail(selected.date)} • ${selected.mealCount} meal${selected.mealCount == 1 ? '' : 's'} logged',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

          const SizedBox(height: 12),

          // 5. Factual Summary Line & Simple 4-Level Legend
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              // Factual summary line
              Text(
                widget.factualSummary,
                style: AppTypography.subtitle.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.tealPrimary,
                ),
              ),

              // Simple 0, 1, 2, 3+ legend
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegendBlock(const Color(0xFFEBF1EE), '0'),
                  const SizedBox(width: 8),
                  _buildLegendBlock(const Color(0xFFBDE3D3), '1'),
                  const SizedBox(width: 8),
                  _buildLegendBlock(const Color(0xFF5FB497), '2'),
                  const SizedBox(width: 8),
                  _buildLegendBlock(const Color(0xFF1B6A5A), '3+'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendBlock(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
