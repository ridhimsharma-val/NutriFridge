import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../widgets/custom_bottom_nav.dart';
import 'fridge/fridge_page.dart';
import 'home/home_screen.dart';
import 'placeholder/placeholder_screen.dart';
import 'progress/progress_screen.dart';
import 'quick_actions/widgets/quick_action_sheet.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    FridgePage(),
    SizedBox.shrink(), // Placeholder for central log action
    ProgressScreen(),
    PlaceholderScreen(
      title: 'My Profile & Goals',
      icon: Icons.person_rounded,
      description: 'Manage personal nutrition goals, preferences, and dietary needs.',
    ),
  ];

  void _onNavItemSelected(int index) {
    if (index == 2) {
      _showQuickActionsSheet();
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  void _showQuickActionsSheet() async {
    await QuickActionSheet.show(context);
    if (mounted) {
      setState(() {});
    }
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
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: CustomBottomNav(
          currentIndex: _currentIndex,
          onItemSelected: _onNavItemSelected,
          onLogMealPressed: _showQuickActionsSheet,
        ),
      ),
    );
  }
}
