import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/nutrition_data.dart';
import '../../models/grocery_item.dart';
import '../../services/auth/auth_service.dart';
import '../../services/grocery/grocery_service.dart';
import '../grocery/grocery_list_screen.dart';
import 'models/user_profile_data.dart';
import 'widgets/app_preferences_card.dart';
import 'widgets/dietary_restrictions_card.dart';
import 'widgets/edit_profile_dialog.dart';
import 'widgets/nutrition_preferences_card.dart';
import 'widgets/profile_header_card.dart';
import '../saved_recipes/saved_recipes_screen.dart';
import '../../services/recipe/saved_recipes_service.dart';

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

  Future<void> _handleSignOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign Out',
          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to sign out of NutriFridge?',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.charcoalLight),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE02424),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmCream,
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

                  // 2b. Saved Recipes & Favourites Quick Tile
                  _buildSavedRecipesTile(context),

                  const SizedBox(height: 14),

                  // 2c. Grocery List Quick Tile
                  _buildGroceryListTile(context),

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

                  const SizedBox(height: 20),

                  // 6. Sign Out Action Button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.pureWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFDE8E8), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.charcoal.withAlpha(6),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextButton.icon(
                      onPressed: () => _handleSignOut(context),
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFE02424),
                        size: 20,
                      ),
                      label: Text(
                        'Sign Out',
                        style: AppTypography.bodyMedium.copyWith(
                          color: const Color(0xFFE02424),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  // Floating Bottom navigation clearance
                  const SizedBox(height: 84),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSavedRecipesTile(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 1),
        boxShadow: const [AppColors.cardShadow],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('profile_saved_recipes_tile'),
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SavedRecipesScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F7F2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFFE53935),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Saved Recipes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      ValueListenableBuilder<List<RecipeRecommendation>>(
                        valueListenable: SavedRecipesService.instance.savedRecipesNotifier,
                        builder: (context, saved, _) {
                          return Text(
                            saved.isEmpty
                                ? 'No favourites saved yet'
                                : '${saved.length} favourite ${saved.length == 1 ? 'recipe' : 'recipes'}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.mutedText,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.mutedText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroceryListTile(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 1),
        boxShadow: const [AppColors.cardShadow],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('profile_grocery_list_tile'),
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GroceryListScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF4EE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      color: AppColors.primaryForest,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Grocery List',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      ValueListenableBuilder<List<GroceryItem>>(
                        valueListenable: GroceryService.instance.groceryItemsNotifier,
                        builder: (context, items, _) {
                          final pending = items.where((it) => !it.isPurchased).length;
                          String subtitle;
                          if (items.isEmpty) {
                            subtitle = 'No items on your list';
                          } else if (pending > 0) {
                            subtitle = '$pending ${pending == 1 ? 'item' : 'items'} to buy';
                          } else {
                            subtitle = 'All items collected';
                          }
                          return Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.mutedText,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.mutedText,
                ),
              ],
            ),
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
            color: AppColors.neutralCharcoal,
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
