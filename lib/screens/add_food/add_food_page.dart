import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'manual_entry_page.dart';
import 'multiple_foods_page.dart';
import 'receipt_scan_page.dart';
import 'single_food_scan_page.dart';
import 'widgets/add_food_option_card.dart';

/// Dedicated mobile screen for choosing how to add food to the fridge
class AddFoodPage extends StatelessWidget {
  const AddFoodPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.bgGradientTop,
            Color(0xFFF7FAF8),
            AppColors.bgGradientBottom,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Add Food',
            style: AppTypography.sectionTitle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'How would you like to add food?',
                  style: AppTypography.greeting.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose a scanning method or enter food details manually.',
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // 1. Single Food
                AddFoodOptionCard(
                  title: 'Single Food',
                  subtitle: 'Scan one food item',
                  icon: Icons.camera_alt_rounded,
                  iconColor: AppColors.tealPrimary,
                  badgeBgColor: AppColors.tealLight,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SingleFoodScanPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // 2. Multiple Foods
                AddFoodOptionCard(
                  title: 'Multiple Foods',
                  subtitle: 'Detect several foods in one image',
                  icon: Icons.photo_library_rounded,
                  iconColor: AppColors.peachPrimary,
                  badgeBgColor: AppColors.peachLight,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const MultipleFoodsPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // 3. Grocery / Receipt
                AddFoodOptionCard(
                  title: 'Grocery / Receipt',
                  subtitle: 'Scan a grocery list or receipt',
                  icon: Icons.receipt_long_rounded,
                  iconColor: const Color(0xFF2563EB),
                  badgeBgColor: const Color(0xFFEFF6FF),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ReceiptScanPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // 4. Manual Entry
                AddFoodOptionCard(
                  title: 'Manual Entry',
                  subtitle: 'Enter food details yourself',
                  icon: Icons.edit_note_rounded,
                  iconColor: const Color(0xFF0D9488),
                  badgeBgColor: const Color(0xFFE6FFFA),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ManualEntryPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
