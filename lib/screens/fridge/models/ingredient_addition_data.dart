import 'package:flutter/foundation.dart';

/// Single ingredient successfully added or updated in the NutriFridge inventory.
@immutable
class AddedIngredientItem {
  final String name;
  final num? quantity;
  final String? unit;
  final String? quantityDisplay;
  final String category;
  final String? imageAsset;
  final int? expiryDays;
  final DateTime? expiryDate;
  final num? addedQuantity;
  final num? totalQuantity;

  const AddedIngredientItem({
    required this.name,
    this.quantity,
    this.unit,
    this.quantityDisplay,
    this.category = 'Others',
    this.imageAsset,
    this.expiryDays,
    this.expiryDate,
    this.addedQuantity,
    this.totalQuantity,
  });

  /// Formatted quantity display string (e.g. "2 pieces", "1 carton", or "250 ml")
  String get formattedQuantity {
    if (addedQuantity != null && totalQuantity != null) {
      final unitStr = (unit != null && unit!.trim().isNotEmpty) ? ' ${unit!.trim()}' : '';
      return '+$addedQuantity (Total: $totalQuantity$unitStr)';
    }
    if (quantityDisplay != null && quantityDisplay!.trim().isNotEmpty) {
      return quantityDisplay!.trim();
    }
    if (quantity != null) {
      final qtyStr = (quantity is int || quantity == quantity!.roundToDouble())
          ? '${quantity!.toInt()}'
          : quantity!.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
      if (unit != null && unit!.trim().isNotEmpty) {
        return '$qtyStr ${unit!.trim()}';
      }
      return qtyStr;
    }
    return '1 piece';
  }

  /// Formatted expiry label, strictly returning null if no genuine expiry data is available.
  /// Never fabricates missing expiry information.
  String? get formattedExpiry {
    if (expiryDays != null) {
      if (expiryDays! < 0) return 'Expired';
      if (expiryDays == 0) return 'Expires today';
      if (expiryDays == 1) return 'Expires tomorrow';
      return 'Expires in $expiryDays days';
    }
    if (expiryDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(expiryDate!.year, expiryDate!.month, expiryDate!.day);
      final days = target.difference(today).inDays;
      if (days < 0) return 'Expired';
      if (days == 0) return 'Expires today';
      if (days == 1) return 'Expires tomorrow';
      return 'Expires in $days days';
    }
    return null;
  }
}

/// Data payload for the Cinematic Fridge Opening & Ingredient Addition Experience.
@immutable
class IngredientAdditionData {
  final List<AddedIngredientItem> items;
  final DateTime addedAt;

  const IngredientAdditionData({
    required this.items,
    required this.addedAt,
  });

  /// Factory helper for single item addition
  factory IngredientAdditionData.single({
    required AddedIngredientItem item,
    DateTime? addedAt,
  }) {
    return IngredientAdditionData(
      items: [item],
      addedAt: addedAt ?? DateTime.now(),
    );
  }

  /// Factory helper for multiple items addition
  factory IngredientAdditionData.multiple({
    required List<AddedIngredientItem> items,
    DateTime? addedAt,
  }) {
    return IngredientAdditionData(
      items: items,
      addedAt: addedAt ?? DateTime.now(),
    );
  }
}
