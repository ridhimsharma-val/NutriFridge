import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/user_profile_data.dart';
import 'dietary_restrictions_popup.dart';

/// Compact Summary Card for Dietary Restrictions.
/// Tapping opens the collapsible [DietaryRestrictionsPopup] modal bottom sheet.
class DietaryRestrictionsCard extends StatelessWidget {
  final UserProfileData profile;
  final ValueChanged<UserProfileData> onProfileChanged;

  const DietaryRestrictionsCard({
    super.key,
    required this.profile,
    required this.onProfileChanged,
  });

  String get _restrictionsSummary {
    final allergyCount = profile.allergies.length;
    final avoidedCount = profile.avoidedFoods.length;
    final customCount = profile.customRestrictions.length;
    final total = allergyCount + avoidedCount + customCount;

    if (total == 0) {
      return 'No restrictions selected';
    }

    final parts = <String>[];
    if (allergyCount > 0) {
      parts.add('$allergyCount ${allergyCount == 1 ? 'allergy' : 'allergies'}');
    }
    if (avoidedCount > 0) {
      parts.add('$avoidedCount ${avoidedCount == 1 ? 'food avoided' : 'foods avoided'}');
    }
    if (customCount > 0) {
      parts.add('$customCount custom');
    }

    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          DietaryRestrictionsPopup.show(
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
                      'Dietary restrictions',
                      style: AppTypography.cardTitle.copyWith(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _restrictionsSummary,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: (profile.allergies.isNotEmpty ||
                                profile.avoidedFoods.isNotEmpty ||
                                profile.customRestrictions.isNotEmpty)
                            ? AppColors.peachPrimary
                            : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Allergies, avoided ingredients & custom exclusions',
                      style: AppTypography.subtitle.copyWith(
                        fontSize: 12,
                        color: AppColors.textTertiary,
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
