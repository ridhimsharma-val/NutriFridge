import '../../fridge/models/category_item.dart';
import '../models/detected_food_item.dart';

/// Represents the fridge inventory tracking status of a detected meal ingredient.
class IngredientInventoryStatus {
  final DetectedFoodItem ingredient;
  final CategoryFoodItem? matchingItem;
  final String? categoryName;
  final bool isAvailableInFridge;
  final bool hasSufficientQuantity;
  final double availableAmount;
  final String availableUnit;
  final String statusExplanation;
  bool isSelected;

  IngredientInventoryStatus({
    required this.ingredient,
    this.matchingItem,
    this.categoryName,
    required this.isAvailableInFridge,
    required this.hasSufficientQuantity,
    required this.availableAmount,
    required this.availableUnit,
    required this.statusExplanation,
    this.isSelected = false,
  });

  /// Whether this ingredient can be safely deducted from fridge stock
  bool get canDeduct => isAvailableInFridge && hasSufficientQuantity;

  /// Remaining amount string preview if deducted
  String get remainingPreview {
    if (!canDeduct) return '';
    final remaining = (availableAmount - ingredient.amount).round();
    return '$remaining $availableUnit remaining';
  }
}

/// Service that matches detected meal ingredients against fridge inventory,
/// verifies available quantities, and safely deducts only confirmed items.
/// Kept modular so it can be connected to Supabase or a persistent backend later.
class FridgeInventoryService {
  /// Inspects a list of detected food items and evaluates their availability in the fridge.
  static List<IngredientInventoryStatus> inspectIngredients(List<DetectedFoodItem> ingredients) {
    return ingredients.map((ingredient) => inspectSingle(ingredient)).toList();
  }

  /// Inspects a single ingredient against all categories in [FridgeCategoryRepository].
  static IngredientInventoryStatus inspectSingle(DetectedFoodItem ingredient) {
    final cleanName = ingredient.name.trim().toLowerCase();

    CategoryFoodItem? foundItem;
    String? foundCategory;

    // Exact name match across all fridge categories
    for (final category in FridgeCategoryRepository.canonicalCategories) {
      final categoryData = FridgeCategoryRepository.getCategoryData(category);
      for (final item in categoryData.items) {
        final itemName = item.name.trim().toLowerCase();
        if (itemName == cleanName) {
          foundItem = item;
          foundCategory = category;
          break;
        }
      }
      if (foundItem != null) break;
    }

    // If not found in fridge inventory
    if (foundItem == null || foundCategory == null) {
      return IngredientInventoryStatus(
        ingredient: ingredient,
        matchingItem: null,
        categoryName: null,
        isAvailableInFridge: false,
        hasSufficientQuantity: false,
        availableAmount: 0,
        availableUnit: '',
        statusExplanation: 'Not tracked in fridge inventory',
        isSelected: false,
      );
    }

    // Found matching item - parse quantity and unit
    final double availableAmount = foundItem.numericAmount.toDouble();
    final String availableUnit = foundItem.unit.trim().toLowerCase();
    final String ingredientUnit = ingredient.unit.trim().toLowerCase();

    // Check unit compatibility (e.g. g vs g, ml vs ml, pieces vs pieces)
    final bool unitsCompatible = availableUnit == ingredientUnit ||
        (availableUnit.contains('g') && ingredientUnit.contains('g')) ||
        (availableUnit.contains('ml') && ingredientUnit.contains('ml'));

    if (!unitsCompatible) {
      return IngredientInventoryStatus(
        ingredient: ingredient,
        matchingItem: foundItem,
        categoryName: foundCategory,
        isAvailableInFridge: true,
        hasSufficientQuantity: false,
        availableAmount: availableAmount,
        availableUnit: foundItem.unit,
        statusExplanation: 'Unit mismatch (${foundItem.quantity} in fridge vs ${ingredient.formattedQuantity})',
        isSelected: false,
      );
    }

    // Verify sufficient stock (prevent negative stock)
    if (availableAmount >= ingredient.amount) {
      return IngredientInventoryStatus(
        ingredient: ingredient,
        matchingItem: foundItem,
        categoryName: foundCategory,
        isAvailableInFridge: true,
        hasSufficientQuantity: true,
        availableAmount: availableAmount,
        availableUnit: foundItem.unit,
        statusExplanation: 'Available in fridge: ${foundItem.quantity}',
        isSelected: true, // Default opt-in enabled for reliable matches
      );
    } else {
      return IngredientInventoryStatus(
        ingredient: ingredient,
        matchingItem: foundItem,
        categoryName: foundCategory,
        isAvailableInFridge: true,
        hasSufficientQuantity: false,
        availableAmount: availableAmount,
        availableUnit: foundItem.unit,
        statusExplanation: 'Only ${foundItem.quantity} in fridge. Insufficient stock to deduct ${ingredient.formattedQuantity}.',
        isSelected: false,
      );
    }
  }

  /// Deducts only the selected, matching inventory items from [FridgeCategoryRepository].
  /// Prevents duplicate deductions and strictly enforces non-negative stock.
  /// Returns a summary list of successful deductions.
  static List<String> deductSelected(List<IngredientInventoryStatus> statuses) {
    final List<String> deductionSummaries = [];
    final Set<String> processedItemIds = {};

    for (final status in statuses) {
      if (!status.isSelected || !status.canDeduct) continue;
      if (status.matchingItem == null || status.categoryName == null) continue;

      final itemId = status.matchingItem!.id;
      if (processedItemIds.contains(itemId)) {
        // Prevent deducting the same inventory item multiple times in a single meal log
        continue;
      }
      processedItemIds.add(itemId);

      // Fetch the latest fresh item from the repository to prevent stale stock calculation
      final currentCategory = FridgeCategoryRepository.getCategoryData(status.categoryName!);
      final currentItem = currentCategory.items.where((it) => it.id == itemId).firstOrNull;
      if (currentItem == null) continue;

      final currentAmount = currentItem.numericAmount.toDouble();
      final deductAmount = status.ingredient.amount;

      // Prevent negative stock
      if (currentAmount < deductAmount) {
        continue;
      }

      final remaining = (currentAmount - deductAmount).round();
      if (remaining <= 0) {
        // Entire stock consumed
        FridgeCategoryRepository.removeItem(status.categoryName!, itemId);
        deductionSummaries.add('${status.ingredient.name}: all ${currentItem.quantity} consumed');
      } else {
        // Partial stock deducted
        final updated = currentItem.copyWith(
          quantity: '$remaining ${status.availableUnit}',
        );
        FridgeCategoryRepository.updateItem(status.categoryName!, updated);
        deductionSummaries.add('${status.ingredient.name}: deducted ${status.ingredient.formattedQuantity} ($remaining ${status.availableUnit} remaining)');
      }
    }

    return deductionSummaries;
  }
}
