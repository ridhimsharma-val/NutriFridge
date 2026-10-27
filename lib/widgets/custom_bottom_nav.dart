import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'navigation/liquid_float_navigation.dart';

/// NutriFridge bottom navigation using Design 06: Liquid Float Navigation.
///
/// Features:
/// - Floating raised circular active icon with soft glow shadow
/// - Symmetrical fluid wave notch along the bar surface
/// - Icons only, no text labels
/// - Clean white/cream surface with rounded top corners
/// - Dedicated central '+' action button that triggers Quick Actions without tab mutation
class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onLogMealPressed;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
    required this.onLogMealPressed,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidFloatNavigationBar(
      currentIndex: currentIndex,
      onItemSelected: onItemSelected,
      onActionPressed: onLogMealPressed,
      items: LiquidFloatNavItem.nutriFridgeItems,
      backgroundColor: AppColors.cardWhite,
      activeColor: AppColors.tealPrimary,
      inactiveColor: const Color(0xFF7E978B),
    );
  }
}
