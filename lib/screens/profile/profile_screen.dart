import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/nutrition_data.dart';
import 'models/user_profile_data.dart';
import 'widgets/app_preferences_card.dart';
import 'widgets/dietary_restrictions_card.dart';
import 'widgets/edit_profile_dialog.dart';
import 'widgets/nutrition_preferences_card.dart';
import 'widgets/profile_header_card.dart';

/// Complete, polished, and functional NutriFridge Profile Screen.
/// Manages user profile, nutrition preferences, dietary restrictions, app toggles, and privacy info.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _onEditProfile(BuildContext context, UserProfileData currentProfile) {
    EditProfileDialog.show(
      context,
      currentName: currentProfile.displayName,
      onSave: (newName) {
        MockDataRepository.updateProfile(
          currentProfile.copyWith(displayName: newName),
        );
      },
    );
  }

  void _onProfileChanged(UserProfileData updatedProfile) {
    MockDataRepository.updateProfile(updatedProfile);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.bgGradientTop,
            Color(0xFFF6FAF7),
            AppColors.bgGradientBottom,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: AnimatedBuilder(
            animation: MockDataRepository.notifier,
            builder: (context, _) {
              final profile = MockDataRepository.profile;

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Screen Title & Subtitle Header
                    _buildTopHeader(),

                    const SizedBox(height: 18),

                    // 2. Profile Summary Card (Avatar, Name, Edit Action)
                    ProfileHeaderCard(
                      profile: profile,
                      onEdit: () => _onEditProfile(context, profile),
                    ),

                    const SizedBox(height: 18),

                    // 3. Nutrition Preferences (Dietary pref, Goal, Calorie target)
                    NutritionPreferencesCard(
                      profile: profile,
                      onProfileChanged: _onProfileChanged,
                    ),

                    const SizedBox(height: 18),

                    // 4. Dietary Restrictions (Allergies, Avoided foods, Custom entries)
                    DietaryRestrictionsCard(
                      profile: profile,
                      onProfileChanged: _onProfileChanged,
                    ),

                    const SizedBox(height: 18),

                    // 5. App Preferences (Meal reminders, Expiry alerts)
                    AppPreferencesCard(
                      profile: profile,
                      onProfileChanged: _onProfileChanged,
                    ),

                    // Floating Bottom navigation clearance
                    const SizedBox(height: 84),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Minimal Editorial Header
  Widget _buildTopHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile',
          style: AppTypography.greeting.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Your food preferences and personal settings.',
          style: AppTypography.subtitle.copyWith(
            fontSize: 13.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
