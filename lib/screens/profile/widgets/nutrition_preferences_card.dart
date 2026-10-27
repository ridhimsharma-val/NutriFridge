import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/user_profile_data.dart';
import 'nutrition_preferences_popup.dart';

/// Compact Summary Card for Nutrition Preferences.
/// Tapping opens the collapsible [NutritionPreferencesPopup] modal bottom sheet.
class NutritionPreferencesCard extends StatelessWidget {
  final UserProfileData profile;
  final ValueChanged<UserProfileData> onProfileChanged;

  const NutritionPreferencesCard({
    super.key,
    required this.profile,
    required this.onProfileChanged,
  });

  String _formatCalories(int kcal) {
    return kcal.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  String get _preferenceSummary {
    final dietary = profile.dietaryPreference;
    final goal = profile.nutritionGoal;

    if (dietary != null && goal != null) {
      return '$dietary · $goal';
    } else if (dietary != null) {
      return dietary;
    } else if (goal != null) {
      return goal;
    } else {
      return 'Not set · Tap to choose preferences';
    }
  }

  String get _targetSummary {
    if (profile.dailyCalorieTarget != null) {
      return 'Daily target: ${_formatCalories(profile.dailyCalorieTarget!)} kcal';
    } else {
      return 'Daily target: None';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          NutritionPreferencesPopup.show(
            context,
            profile: profile,
            onSave: onProfileChanged,
          );
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.cardBorder, width: 1.2),
            boxShadow: const [AppColors.softShadow],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Summary Texts
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nutrition preferences',
                      style: AppTypography.cardTitle.copyWith(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _preferenceSummary,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.tealPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _targetSummary,
                      style: AppTypography.subtitle.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Subtle Right Chevron
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
