import 'package:flutter/material.dart';

class AppColors {
  // ==========================================
  // OFFICIAL FRESH HARVEST BRAND COLOUR TOKENS
  // ==========================================
  static const Color primaryForest = Color(0xFF145A42); // Primary brand colour
  static const Color freshGreen = Color(0xFF22A06B);    // Primary actions and progress
  static const Color vibrantLime = Color(0xFFB7E34B);   // Secondary highlights
  static const Color softCream = Color(0xFFF7F9F1);     // Main application background
  static const Color coralPeach = Color(0xFFFF9675);    // Secondary accent
  static const Color paleMint = Color(0xFFDDF3E7);      // Wellness and information surfaces
  static const Color darkText = Color(0xFF172E27);      // Main text
  static const Color pureWhite = Color(0xFFFFFFFF);     // Cards and surfaces

  // ==========================================
  // DERIVED SUPPORTING SEMANTIC TOKENS
  // ==========================================
  static const Color mutedText = Color(0xFF5A7269);        // Subdued green-grey text
  static const Color subtleBorder = Color(0x1F145A42);     // Low-contrast green-grey border
  static const Color neutralTrack = Color(0xFFE5EEE8);     // Very light neutral green progress track
  static const Color palePeachSurface = Color(0xFFFFF2ED); // Very light tint derived from coralPeach
  static const Color palePeachBorder = Color(0xFFFFD5C7);  // Subtle coral border for peach surfaces
  static const Color darkPeachText = Color(0xFFB34A28);    // Readable dark text for peach surfaces
  static const Color paleGreenSurface = Color(0xFFEAF7F0); // Very light tint derived from freshGreen
  static const Color limeLight = Color(0xFFF4FADF);        // Very light tint derived from vibrantLime

  // ==========================================
  // SYSTEM & BACKWARD-COMPATIBILITY ALIASES
  // ==========================================
  static const Color background = softCream;
  static const Color bgGradientTop = Color(0xFFEEF7F2);
  static const Color bgGradientBottom = softCream;

  // Cards & Surfaces
  static const Color cardWhite = pureWhite;
  static const Color cardCream = softCream;
  static const Color warmCream = softCream;
  static const Color cardBorder = subtleBorder;
  static const Color cardSurface = pureWhite;

  // Primary & Forest Green
  static const Color forestGreen = primaryForest;
  static const Color forestGreenDark = Color(0xFF0E3F2E);
  static const Color deepForest = primaryForest;
  static const Color softGreen = paleGreenSurface;

  // Fresh Green / Sage Accent
  static const Color sageAccent = freshGreen;
  static const Color sageLight = paleGreenSurface;

  // Text Hierarchy
  static const Color neutralCharcoal = darkText;
  static const Color charcoal = darkText;
  static const Color charcoalLight = mutedText;
  static const Color textPrimary = darkText;
  static const Color textSecondary = mutedText;
  static const Color textTertiary = Color(0xFF8FA499);
  static const Color textOnDark = pureWhite;

  // Secondary Peach / Coral
  static const Color coralHighlight = coralPeach;
  static const Color peachPrimary = coralPeach;
  static const Color peachAccent = Color(0xFFF27E58);
  static const Color peachLight = palePeachSurface;
  static const Color peachSoft = Color(0xFFFFE5DD);
  static const Color peachCard = palePeachSurface;
  static const Color peachBorder = palePeachBorder;
  static const Color peachText = darkPeachText;

  static const Color secondary = coralPeach;
  static const Color secondarySurface = palePeachSurface;
  static const Color secondarySoft = Color(0xFFFFE5DD);
  static const Color secondaryCard = palePeachSurface;
  static const Color secondaryBorder = palePeachBorder;
  static const Color secondaryAccent = Color(0xFFF27E58);
  static const Color secondaryText = darkPeachText;

  // Amber / Highlights
  static const Color amberPrimary = Color(0xFFF59E0B);
  static const Color amberLight = Color(0xFFFEF3C7);

  // Status & Validation
  static const Color error = Color(0xFFDC2626);
  static const Color borderGrey = Color(0xFFE2E8F0);

  // Legacy Teal aliases mapped to Fresh Harvest
  static const Color tealPrimary = primaryForest;
  static const Color tealAccent = freshGreen;
  static const Color tealLight = paleMint;
  static const Color tealSurface = paleGreenSurface;

  // Meal Status & Badges
  static const Color mealCompletedText = primaryForest;
  static const Color mealCompletedBg = paleMint;
  static const Color mealCompletedIcon = freshGreen;

  static const Color mealUpcomingText = mutedText;
  static const Color mealUpcomingBg = neutralTrack;
  static const Color mealUpcomingIcon = Color(0xFF8FA499);

  // Soft Shadows with subtle brand forest tint
  static const BoxShadow softShadow = BoxShadow(
    color: Color(0x0C145A42),
    blurRadius: 18,
    spreadRadius: 0,
    offset: Offset(0, 6),
  );

  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x0A145A42),
    blurRadius: 14,
    spreadRadius: 0,
    offset: Offset(0, 4),
  );

  static const BoxShadow floatingActionShadow = BoxShadow(
    color: Color(0x33145A42),
    blurRadius: 16,
    spreadRadius: 2,
    offset: Offset(0, 6),
  );
}
