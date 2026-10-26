import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../models/progress_data.dart';

/// Cinematic Nutrition Consistency Heatmap
/// Visualizes meal logging frequency over a 28-day window (4 weeks x 7 days)
/// using a muted cream, pale mint, and teal progression.
class ConsistencyHeatmap extends StatelessWidget {
  final List<HeatmapCellData> cells;

  const ConsistencyHeatmap({
    super.key,
    required this.cells,
  });

  Color _getColorForLevel(int level) {
    switch (level) {
      case 1:
        return const Color(0xFFC7E6D9); // Light mint
      case 2:
        return const Color(0xFF70BFA5); // Medium mint
      case 3:
        return const Color(0xFF1B6A5A); // Deep teal
      case 0:
      default:
        return const Color(0xFFEBF1EE); // Muted neutral cream
    }
  }

  @override
  Widget build(BuildContext context) {
    const daysOfWeek = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: const [AppColors.softShadow],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Text(
            'Meal logging consistency',
            style: AppTypography.cardTitle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Past 28 days of nutritional recording activity',
            style: AppTypography.subtitle.copyWith(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 18),

          // Day of week column headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: daysOfWeek.map((day) {
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
          const SizedBox(height: 8),

          // 4 Rows x 7 Columns Heatmap Grid
          Column(
            children: List.generate(4, (row) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (col) {
                    final index = (row * 7) + col;
                    if (index >= cells.length) {
                      return const Expanded(child: SizedBox());
                    }

                    final cell = cells[index];
                    final color = _getColorForLevel(cell.level);

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6),
                              border: cell.isCurrentDay
                                  ? Border.all(
                                      color: AppColors.tealPrimary,
                                      width: 2.0,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),

          const SizedBox(height: 16),

          // Clean Responsive Legend
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                'Today is highlighted',
                style: AppTypography.subtitle.copyWith(
                  fontSize: 11.5,
                  color: AppColors.textTertiary,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegendBlock(const Color(0xFFEBF1EE), '0'),
                  const SizedBox(width: 6),
                  _buildLegendBlock(const Color(0xFFC7E6D9), '1'),
                  const SizedBox(width: 6),
                  _buildLegendBlock(const Color(0xFF70BFA5), '2'),
                  const SizedBox(width: 6),
                  _buildLegendBlock(const Color(0xFF1B6A5A), '3+ meals'),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Editorial note
          Text(
            'Reflects recording frequency • Does not assess nutritional quality',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: AppColors.textTertiary.withValues(alpha: 0.8),
            ),
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
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
