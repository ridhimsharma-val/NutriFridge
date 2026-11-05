import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color background = Color(0xFFF3F7F4);
  static const Color bgGradientTop = Color(0xFFEEF7F2);
  static const Color bgGradientBottom = Color(0xFFFBF8F3);

  // Cards & Surfaces
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color cardCream = Color(0xFFFDFBF7);
  static const Color warmCream = Color(0xFFFAF7F2); // Primary app background & warm surfaces
  static const Color cardBorder = Color(0x0F1B3B2B);

  // New Redesign Primary Tokens (Deep Forest Green & Fresh Sage)
  static const Color forestGreen = Color(0xFF143D30); // Deep forest green primary
  static const Color forestGreenDark = Color(0xFF0D2B22);
  static const Color sageAccent = Color(0xFF4FA878); // Fresh lime/sage green secondary accent
  static const Color sageLight = Color(0xFFE8F4EC);
  static const Color paleMint = Color(0xFFEAF5EE); // Pale mint subtle backgrounds
  static const Color neutralCharcoal = Color(0xFF16231E); // Neutral dark charcoal primary text
  static const Color neutralTrack = Color(0xFFEFF2F0); // Clean neutral progress track
  static const Color coralHighlight = Color(0xFFE89073); // Soft peach/coral highlights

  // Primary / Action (Muted Teal & Greens - Preserved for full backward compatibility)
  static const Color tealPrimary = Color(0xFF176D5C);
  static const Color tealAccent = Color(0xFF2A8B74);
  static const Color tealLight = Color(0xFFE4F4EE);
  static const Color tealSurface = Color(0xFFEEF8F4);

  // Secondary Peach / Coral (Balanced 60:40 Visual Hierarchy)
  static const Color peachPrimary = Color(0xFFE99A7C);
  static const Color peachAccent = Color(0xFFE07E5B);
  static const Color peachLight = Color(0xFFFBE7DE);
  static const Color peachSoft = Color(0xFFF5D1C1);
  static const Color peachCard = Color(0xFFFDF5F0);
  static const Color peachBorder = Color(0xFFF2C4B2);
  static const Color peachText = Color(0xFF9E4B33);

  // Semantic Secondary Tokens (Aligned with Peach / Coral Palette)
  static const Color secondary = peachPrimary;
  static const Color secondarySurface = peachLight;
  static const Color secondarySoft = peachSoft;
  static const Color secondaryCard = peachCard;
  static const Color secondaryBorder = peachBorder;
  static const Color secondaryAccent = peachAccent;
  static const Color secondaryText = peachText;

  // Amber / Warm Yellow Highlights
  static const Color amberPrimary = Color(0xFFF59E0B);
  static const Color amberLight = Color(0xFFFEF3C7);

  // Status & Validation
  static const Color error = Color(0xFFDC2626);
  static const Color borderGrey = Color(0xFFE2E8F0);

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
