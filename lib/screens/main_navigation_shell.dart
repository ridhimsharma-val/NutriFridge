import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/transitions/hero_transition_route.dart';
import '../widgets/custom_bottom_nav.dart';
import 'ai_assistant/ai_assistant_screen.dart';
import 'fridge/fridge_page.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';
import 'progress/progress_screen.dart';

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
    SizedBox.shrink(), // Non-navigable placeholder for central AI action button
    ProgressScreen(),
    ProfileScreen(),
  ];

  void _onNavItemSelected(int index) {
    if (index == 2) {
      _openAiAssistant();
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  void _openAiAssistant() async {
    await Navigator.of(context).push(
      HeroTransitionRoute(
        page: const AiAssistantScreen(),
      ),
    );
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
          onLogMealPressed: _openAiAssistant,
        ),
      ),
    );
  }
}
