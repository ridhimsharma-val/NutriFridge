import 'package:flutter/material.dart';

/// Represents a single tab item for Design 06: Liquid Float Navigation.
class LiquidFloatNavItem {
  final IconData icon;
  final String? tooltip;
  final bool isActionButton;

  const LiquidFloatNavItem({
    required this.icon,
    this.tooltip,
    this.isActionButton = false,
  });

  /// Default five navigation items for NutriFridge
  static const List<LiquidFloatNavItem> nutriFridgeItems = [
    LiquidFloatNavItem(
      icon: Icons.home_rounded,
      tooltip: 'Home',
    ),
    LiquidFloatNavItem(
      icon: Icons.kitchen_rounded,
      tooltip: 'Fridge',
    ),
    LiquidFloatNavItem(
      icon: Icons.add_rounded,
      tooltip: 'Quick Actions',
      isActionButton: true,
    ),
    LiquidFloatNavItem(
      icon: Icons.bar_chart_rounded,
      tooltip: 'Progress',
    ),
    LiquidFloatNavItem(
      icon: Icons.person_rounded,
      tooltip: 'Profile',
    ),
  ];
}
