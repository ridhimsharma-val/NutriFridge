import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/user_profile_data.dart';

/// Compact Profile Header Card
/// Displays user initials avatar, display name, and an Edit action.
class ProfileHeaderCard extends StatelessWidget {
  final UserProfileData profile;
  final VoidCallback onEdit;

  const ProfileHeaderCard({
    super.key,
    required this.profile,
    required this.onEdit,
  });

  String get _initials {
    final trimmed = profile.displayName.trim();
    if (trimmed.isEmpty) return 'U';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed[0].toUpperCase();
  }

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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          // Circular Avatar with Initials
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.tealPrimary.withValues(alpha: 0.18),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                _initials,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.tealPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // User Name & Sub-label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName.isNotEmpty ? profile.displayName : 'Food Explorer',
                  style: AppTypography.greeting.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Personal preferences & goals',
                  style: AppTypography.subtitle.copyWith(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Small Edit Action Pill
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F6F3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.tealPrimary.withValues(alpha: 0.15),
                    width: 1.0,
                  ),
                ),
                child: const Text(
                  'Edit',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tealPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
