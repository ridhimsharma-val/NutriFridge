import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/category_item.dart';

/// Expiry status categories for the Use Soon section
enum UseSoonCategory {
  alreadyExpired,
  expiresToday,
  expiresTomorrow,
  expiresIn2Days,
  expiresIn3Days,
}

/// Service providing expiry prioritization logic and item collection for Smart Fridge Intelligence v1 (Use Soon).
class UseSoonService {
  static DateTime Function() _clockProvider = DateTime.now;

  /// Testable clock provider allowing controlled local calendar time injection in unit tests.
  static DateTime Function() get clockProvider => _clockProvider;

  @visibleForTesting
  static void setClockProvider(DateTime Function() provider) {
    _clockProvider = provider;
  }

  @visibleForTesting
  static void resetClock() {
    _clockProvider = DateTime.now;
  }

  /// Calculates the exact number of days remaining until expiry relative to the local calendar day.
  /// Ignores time-of-day offsets and time zone drift.
  static int calculateDaysRemaining(DateTime expiryDate, [DateTime? localNow]) {
    final now = localNow ?? _clockProvider();
    final localToday = DateTime(now.year, now.month, now.day);
    final localTarget = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return localTarget.difference(localToday).inDays;
  }

  /// Extracts the effective expiry days for an item.
  /// If the item has an explicit [expiryDate], computes local calendar days remaining.
  /// If it has an explicit integer [expiryDays] without a date, respects it.
  /// Returns null if no reliable expiry information is available (never fabricates dates).
  static int? getEffectiveExpiryDays(CategoryFoodItem item, [DateTime? localNow]) {
    if (item.expiryDate != null) {
      return calculateDaysRemaining(item.expiryDate!, localNow);
    }
    return item.expiryDays;
  }

  /// Maps an item's effective expiry days to one of the 5 canonical Use Soon categories.
  /// Returns null if the item has no reliable expiry or is fresh (> 3 days).
  static UseSoonCategory? getUseSoonCategory(CategoryFoodItem item, [DateTime? localNow]) {
    final days = getEffectiveExpiryDays(item, localNow);
    if (days == null) return null;
    if (days < 0) return UseSoonCategory.alreadyExpired;
    if (days == 0) return UseSoonCategory.expiresToday;
    if (days == 1) return UseSoonCategory.expiresTomorrow;
    if (days == 2) return UseSoonCategory.expiresIn2Days;
    if (days == 3) return UseSoonCategory.expiresIn3Days;
    return null;
  }

  /// Returns the human-readable expiry label according to the Use Soon specification.
  static String getExpiryLabel(CategoryFoodItem item, [DateTime? localNow]) {
    final days = getEffectiveExpiryDays(item, localNow);
    if (days == null) return 'Expiry not set';
    if (days < 0) return 'Already Expired';
    if (days == 0) return 'Expires today';
    if (days == 1) return 'Expires tomorrow';
    if (days == 2) return 'Expires in 2 days';
    if (days == 3) return 'Expires in 3 days';
    return 'Expires in $days days';
  }

  /// Assigns an urgency rank for sorting:
  /// 1. Expires Today (0 days) -> most urgent to use before spoiling
  /// 2. Expires Tomorrow (1 day) -> next urgent
  /// 3. Expires in 2 Days (2 days)
  /// 4. Expires in 3 Days (3 days)
  /// 5. Already Expired (< 0 days) -> distinct warning status
  static int getUrgencyRank(CategoryFoodItem item, [DateTime? localNow]) {
    final days = getEffectiveExpiryDays(item, localNow);
    if (days == null) return 999;
    if (days == 0) return 0;
    if (days == 1) return 1;
    if (days == 2) return 2;
    if (days == 3) return 3;
    if (days < 0) return 4;
    return 100 + days;
  }

  /// Returns styling colors matching the NutriFridge design system for the visual urgency indicator.
  static ({Color background, Color text, Color border, Color dot}) getUrgencyColors(
    CategoryFoodItem item, [
    DateTime? localNow,
  ]) {
    final days = getEffectiveExpiryDays(item, localNow);
    if (days == null) {
      return (
        background: const Color(0xFFF1F5F9),
        text: const Color(0xFF64748B),
        border: const Color(0xFFE2E8F0),
        dot: const Color(0xFF94A3B8),
      );
    }
    if (days < 0) {
      // Already Expired: Distinct soft red warning treatment
      return (
        background: const Color(0xFFFEE2E2),
        text: const Color(0xFFB91C1C),
        border: const Color(0xFFFCA5A5),
        dot: const Color(0xFFDC2626),
      );
    }
    if (days == 0) {
      // Expires Today: High urgency warm amber/coral
      return (
        background: const Color(0xFFFEF3C7),
        text: const Color(0xFF92400E),
        border: const Color(0xFFFDE68A),
        dot: const Color(0xFFD97706),
      );
    }
    if (days <= 2) {
      // Expires Tomorrow or in 2 Days: Soft peach/coral
      return (
        background: AppColors.peachLight,
        text: AppColors.peachText,
        border: AppColors.peachBorder,
        dot: AppColors.peachPrimary,
      );
    }
    // Expires in 3 Days: Soft muted mint/sage
    return (
      background: const Color(0xFFEDF7ED),
      text: const Color(0xFF234B34),
      border: const Color(0xFFC8E6C9),
      dot: AppColors.forestGreen,
    );
  }

  /// Collects, filters, and sorts all inventory items qualifying for the Use Soon section.
  ///
  /// Criteria:
  /// - Reliable expiry information present (never fabricated).
  /// - Available quantity > 0 (excludes 0-quantity items).
  /// - Expiry within 3 days or already expired (excludes items expiring after 3 days).
  /// - Sorted in strict urgency order (Expires Today first, then Tomorrow, then in 2-3 days, then Already Expired).
  static List<CategoryFoodItem> getUseSoonItems({
    List<CategoryFoodItem>? sourceItems,
    DateTime? localNow,
  }) {
    final items = sourceItems ?? _getAllFridgeItems();
    final qualifying = <CategoryFoodItem>[];

    for (final item in items) {
      // 1. Exclude items without reliable expiry information
      final days = getEffectiveExpiryDays(item, localNow);
      if (days == null) continue;

      // 2. Exclude zero-quantity inventory items
      if (item.decimalAmount <= 0) continue;

      // 3. Exclude items expiring after 3 days
      if (days > 3) continue;

      qualifying.add(item);
    }

    // 4. Sort by urgency, most urgent first
    qualifying.sort((a, b) {
      final rankA = getUrgencyRank(a, localNow);
      final rankB = getUrgencyRank(b, localNow);
      if (rankA != rankB) return rankA.compareTo(rankB);
      final daysA = getEffectiveExpiryDays(a, localNow) ?? 999;
      final daysB = getEffectiveExpiryDays(b, localNow) ?? 999;
      if (daysA != daysB) return daysA.compareTo(daysB);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return qualifying;
  }

  /// Collects edible items approaching expiry (0 to 3 days) to pass to the AI meal suggestion flow.
  /// Excludes already-expired items so spoiled food is never prioritized in meal generation.
  static List<CategoryFoodItem> getEdibleExpiringItems({
    List<CategoryFoodItem>? sourceItems,
    DateTime? localNow,
  }) {
    return getUseSoonItems(sourceItems: sourceItems, localNow: localNow)
        .where((it) {
          final days = getEffectiveExpiryDays(it, localNow);
          return days != null && days >= 0 && days <= 3;
        })
        .toList();
  }

  static List<CategoryFoodItem> _getAllFridgeItems() {
    return FridgeCategoryRepository.allItems;
  }
}
