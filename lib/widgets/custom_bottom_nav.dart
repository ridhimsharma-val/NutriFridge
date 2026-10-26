import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

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
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 10,
            bottom: bottomPadding > 0 ? 4 : 10,
          ),
          child: SizedBox(
            height: 58,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.home_rounded,
                  label: 'Home',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.kitchen_rounded,
                  label: 'Fridge',
                ),
                // Center Prominent Action Button
                _buildCenterLogButton(),
                _buildNavItem(
                  index: 3,
                  icon: Icons.bar_chart_rounded,
                  label: 'Progress',
                ),
                _buildNavItem(
                  index: 4,
                  icon: Icons.person_rounded,
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool isSelected = currentIndex == index;
    final Color itemColor =
        isSelected ? AppColors.tealPrimary : AppColors.textTertiary;

    return InkWell(
      onTap: () => onItemSelected(index),
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: itemColor,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTypography.navLabel.copyWith(
                color: itemColor,
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterLogButton() {
    return Tooltip(
      message: 'Quick Actions',
      child: GestureDetector(
        onTap: onLogMealPressed,
        child: Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
            color: AppColors.tealPrimary,
            shape: BoxShape.circle,
            boxShadow: [AppColors.floatingActionShadow],
          ),
          child: const Center(
            child: Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
