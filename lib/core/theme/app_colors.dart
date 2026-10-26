import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color background = Color(0xFFF3F7F4);
  static const Color bgGradientTop = Color(0xFFEEF7F2);
  static const Color bgGradientBottom = Color(0xFFFBF8F3);

  // Cards & Surfaces
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color cardCream = Color(0xFFFDFBF7);
  static const Color cardBorder = Color(0x0F1B3B2B);

  // Primary / Action (Muted Teal & Greens)
  static const Color tealPrimary = Color(0xFF1B6A5A);
  static const Color tealAccent = Color(0xFF2A8B74);
  static const Color tealLight = Color(0xFFE4F4EE);
  static const Color tealSurface = Color(0xFFEEF8F4);

  // Soft Peach / Coral Accents
  static const Color peachPrimary = Color(0xFFFF7A5C);
  static const Color peachAccent = Color(0xFFFF967A);
  static const Color peachLight = Color(0xFFFFF2EB);
  static const Color peachCard = Color(0xFFFFF7F2);
  static const Color peachBorder = Color(0xFFFFE5DA);

  // Amber / Warm Yellow Highlights
  static const Color amberPrimary = Color(0xFFF59E0B);
  static const Color amberLight = Color(0xFFFEF3C7);

  // Text Hierarchy
  static const Color textPrimary = Color(0xFF182622); // Dark charcoal/green-black
  static const Color textSecondary = Color(0xFF6C8178); // Subtle gray-green
  static const Color textTertiary = Color(0xFF96A79F); // Muted helper text
  static const Color textOnDark = Color(0xFFFFFFFF);

  // Meal Status & Badges
  static const Color mealCompletedText = Color(0xFF1E755D);
  static const Color mealCompletedBg = Color(0xFFE6F6F0);
  static const Color mealCompletedIcon = Color(0xFF2A8B74);

  static const Color mealUpcomingText = Color(0xFF75857E);
  static const Color mealUpcomingBg = Color(0xFFF1F5F2);
  static const Color mealUpcomingIcon = Color(0xFFA1B0A8);

  // Soft Shadows
  static const BoxShadow softShadow = BoxShadow(
    color: Color(0x0C1C3529),
    blurRadius: 18,
    spreadRadius: 0,
    offset: Offset(0, 6),
  );

  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x0A183226),
    blurRadius: 14,
    spreadRadius: 0,
    offset: Offset(0, 4),
  );

  static const BoxShadow floatingActionShadow = BoxShadow(
    color: Color(0x331B6A5A),
    blurRadius: 16,
    spreadRadius: 2,
    offset: Offset(0, 6),
  );
}
