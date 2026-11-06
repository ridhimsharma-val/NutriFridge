import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  // Headings
  static TextStyle get displayLarge => GoogleFonts.plusJakartaSans(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: AppColors.neutralCharcoal,
        letterSpacing: -0.8,
      );

  static TextStyle get screenHeading => GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: AppColors.neutralCharcoal,
        letterSpacing: -0.4,
      );

  static TextStyle get sectionHeading => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.neutralCharcoal,
        letterSpacing: -0.3,
      );

  static TextStyle get greeting => GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.4,
      );

  static TextStyle get subtitle => GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        letterSpacing: -0.1,
      );

  static TextStyle get sectionTitle => GoogleFonts.plusJakartaSans(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      );

  static TextStyle get cardTitle => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
      );

  // Big Numbers / Scores / Nutrition
  static TextStyle get calorieHeroNumber => GoogleFonts.plusJakartaSans(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        color: AppColors.forestGreen,
        letterSpacing: -1.0,
      );

  static TextStyle get calorieSubLabel => GoogleFonts.plusJakartaSans(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: -0.1,
      );

  static TextStyle get macroNumber => GoogleFonts.plusJakartaSans(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: AppColors.neutralCharcoal,
        letterSpacing: -0.3,
      );

  static TextStyle get scoreLarge => GoogleFonts.plusJakartaSans(
        fontSize: 44,
        fontWeight: FontWeight.w800,
        color: AppColors.tealPrimary,
        letterSpacing: -1.0,
      );

  static TextStyle get scoreSubtitle => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.1,
      );

  // Body & Details
  static TextStyle get bodyMedium => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  static TextStyle get bodySmall => GoogleFonts.plusJakartaSans(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  static TextStyle get nutritionValue => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
      );

  static TextStyle get nutritionLabel => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  static TextStyle get badgeText => GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      );

  static TextStyle get actionLink => GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.tealAccent,
      );

  static TextStyle get navLabel => GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      );

  // Convenience aliases for backward compatibility & design system consistency
  static TextStyle get displaySmall => screenHeading;
  static TextStyle get heading1 => displayLarge;
  static TextStyle get heading2 => screenHeading;
  static TextStyle get heading3 => sectionHeading;
  static TextStyle get titleMedium => sectionTitle;
  static TextStyle get bodyText => bodyMedium;
  static TextStyle get caption => bodySmall;
}
