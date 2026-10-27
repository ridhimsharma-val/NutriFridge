import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/user_profile_data.dart';

/// App Preferences Card
/// Accessible toggle controls for Meal Reminders and Food Expiry Alerts.
class AppPreferencesCard extends StatelessWidget {
  final UserProfileData profile;
  final ValueChanged<UserProfileData> onProfileChanged;

  const AppPreferencesCard({
    super.key,
    required this.profile,
    required this.onProfileChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: const [AppColors.softShadow],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & Subtitle
          Text(
            'App preferences',
            style: AppTypography.cardTitle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Notification and alert preferences for this device.',
            style: AppTypography.subtitle.copyWith(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 18),

          // A. Meal Reminders
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Meal reminders',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Remind me to log meals.',
                      style: AppTypography.subtitle.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: profile.mealRemindersEnabled,
                activeTrackColor: AppColors.tealPrimary,
                onChanged: (val) {
                  onProfileChanged(
                    profile.copyWith(mealRemindersEnabled: val),
                  );
                },
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: Color(0xFFF0F4F2), height: 1),
          ),

          // B. Expiry Alerts
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Expiry alerts',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Notify me when tracked food is nearing expiry.',
                      style: AppTypography.subtitle.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: profile.expiryAlertsEnabled,
                activeTrackColor: AppColors.tealPrimary,
                onChanged: (val) {
                  onProfileChanged(
                    profile.copyWith(expiryAlertsEnabled: val),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
