import 'package:flutter/foundation.dart';
import '../models/category_item.dart';

/// Temporary in-memory state management for the "Use My Ingredients" cooking basket.
/// Selecting ingredients does NOT mutate the user's actual fridge inventory or persist database changes.
class CookingBasketService {
  static final ValueNotifier<List<CategoryFoodItem>> selectedItemsNotifier =
      ValueNotifier<List<CategoryFoodItem>>([]);

  static final ValueNotifier<String?> preferredDishNameNotifier =
      ValueNotifier<String?>(null);

  static final ValueNotifier<bool> isGeneratingNotifier =
      ValueNotifier<bool>(false);

  static final ValueNotifier<String?> generationErrorNotifier =
      ValueNotifier<String?>(null);

  static List<CategoryFoodItem> get selectedItems => selectedItemsNotifier.value;
  static String? get preferredDishName => preferredDishNameNotifier.value;
  static bool get isGenerating => isGeneratingNotifier.value;
  static String? get generationError => generationErrorNotifier.value;
  static int get count => selectedItems.length;
  static int get itemCount => selectedItems.length;

  /// Checks whether an item is currently selected in the cooking basket
  static bool isSelected(CategoryFoodItem item) {
    return selectedItems.any(
      (it) => it.id == item.id || (it.name.toLowerCase() == item.name.toLowerCase() && it.category == item.category),
    );
  }

  /// Checks whether an item id is currently selected in the cooking basket
  static bool isSelectedId(String id) {
    return selectedItems.any((it) => it.id == id);
  }

  /// Toggles an item in or out of the cooking basket
  static void toggleItem(CategoryFoodItem item) {
    final list = List<CategoryFoodItem>.from(selectedItems);
    final index = list.indexWhere(
      (it) => it.id == item.id || (it.name.toLowerCase() == item.name.toLowerCase() && it.category == item.category),
    );

    if (index >= 0) {
      list.removeAt(index);
    } else {
      list.add(item);
    }
    selectedItemsNotifier.value = list;
    generationErrorNotifier.value = null;
  }

  /// Removes an item by its id or name
  static void removeItem(String itemIdOrName) {
    final list = List<CategoryFoodItem>.from(selectedItems);
    list.removeWhere(
      (it) => it.id == itemIdOrName || it.name.toLowerCase() == itemIdOrName.toLowerCase(),
    );
    selectedItemsNotifier.value = list;
    generationErrorNotifier.value = null;
  }

  /// Sets or updates the optional preferred dish name (e.g. "Chicken Curry")
  static void setPreferredDishName(String? name) {
    if (name == null || name.trim().isEmpty) {
      preferredDishNameNotifier.value = null;
    } else {
      final trimmed = name.trim();
      preferredDishNameNotifier.value = trimmed.length > 120 ? trimmed.substring(0, 120) : trimmed;
    }
  }

  /// Clears the cooking basket and dish name
  static void clear() {
    selectedItemsNotifier.value = [];
    preferredDishNameNotifier.value = null;
    generationErrorNotifier.value = null;
    isGeneratingNotifier.value = false;
  }
}
