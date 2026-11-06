import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/nutrition_data.dart';
import '../ai_assistant/ai_assistant_screen.dart';
import 'models/progress_data.dart';
import 'widgets/consistency_heatmap.dart';
import 'widgets/macro_donut_chart.dart';
import 'widgets/weekly_calories_chart.dart';
import 'widgets/wellness_score_hero.dart';

/// Cinematic Nutrition Progress Screen
/// Mobile-first editorial analytics narrative replacing the placeholder Progress tab.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  String _selectedPeriod = 'Week'; // 'Week' or 'Month'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: MockDataRepository.notifier,
          builder: (context, child) {
            final analytics = ProgressDataService.computeAnalytics(
              period: _selectedPeriod,
              liveNutrition: MockDataRepository.nutrition,
              liveMeals: MockDataRepository.meals,
              loggedMealsHistory: MockDataRepository.loggedMealsHistory,
            );

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Top Header with Title & Period Selector
                  _buildTopHeader(),

                  const SizedBox(height: 20),

                  if (!analytics.hasRecords)
                    _buildEmptyState()
                  else ...[
                    // 2. Cinematic Wellness Hero
                    WellnessScoreHero(
                      score: analytics.wellnessScore,
                      previousScore: analytics.previousWellnessScore,
                      interpretation: analytics.wellnessInterpretation,
                    ),

                    const SizedBox(height: 20),

                    // 3. Macronutrient Donut Chart
                    MacroDonutChart(
                      proteinGrams: analytics.daySummaries.isNotEmpty
                          ? analytics.totalProteinGrams ~/ analytics.daySummaries.length
                          : 0,
                      carbsGrams: analytics.daySummaries.isNotEmpty
                          ? analytics.totalCarbsGrams ~/ analytics.daySummaries.length
                          : 0,
                      fatGrams: analytics.daySummaries.isNotEmpty
                          ? analytics.totalFatGrams ~/ analytics.daySummaries.length
                          : 0,
                      centerCalories: analytics.averageDailyCalories,
                      centerLabel: _selectedPeriod == 'Week' ? 'Daily avg' : 'Monthly avg',
                    ),

                    const SizedBox(height: 20),

                    // 4. Weekly Calorie Chart
                    WeeklyCaloriesChart(
                      summaries: analytics.daySummaries,
                      period: _selectedPeriod,
                    ),

                    const SizedBox(height: 20),

                    // 5. Minimal LeetCode-style Consistency Heatmap
                    ConsistencyHeatmap(
                      cells: analytics.heatmapCells,
                      factualSummary: analytics.factualConsistencySummary,
                      period: _selectedPeriod,
                    ),
                  ],

                  // Bottom navigation clearance
                  const SizedBox(height: 80),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: const [AppColors.softShadow],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.paleMint,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.forestGreen.withValues(alpha: 0.15)),
            ),
            child: const Icon(
              Icons.insights_rounded,
              size: 32,
              color: AppColors.forestGreen,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your nutrition journey starts with your first meal.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.neutralCharcoal,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Charts and insights will populate here as you log meals using NutriFridge AI.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AiAssistantScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Log a Meal with AI'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forestGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Editorial Clean Header with Week/Month Selector
  Widget _buildTopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Title & Subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Progress',
                style: AppTypography.greeting.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.neutralCharcoal,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Your nutrition, over time.',
                style: AppTypography.subtitle.copyWith(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Compact Period Selector (Week / Month)
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFE5EDE7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPeriodTab('Week'),
              _buildPeriodTab('Month'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodTab(String label) {
    final bool isSelected = _selectedPeriod == label;

    return GestureDetector(
      onTap: () {
        if (_selectedPeriod != label) {
          setState(() {
            _selectedPeriod = label;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cardWhite : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? AppColors.forestGreen : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
