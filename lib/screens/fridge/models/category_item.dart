import 'package:flutter/material.dart';
import '../../../../models/notification_data.dart';

/// Expiry urgency level with calm, subtle pastel status colors
enum ExpiryStatus {
  urgent, // Soft coral
  expiringSoon, // Soft peach/orange
  normal, // Subtle muted green
}

/// A food/inventory item within a category
class CategoryFoodItem {
  final String id;
  final String name;
  final String quantity;
  final int expiryDays;
  final String? imageAsset;
  final String? iconEmoji;

  const CategoryFoodItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.expiryDays,
    this.imageAsset,
    this.iconEmoji,
  });

  ExpiryStatus get status {
    if (expiryDays <= 2) return ExpiryStatus.urgent;
    if (expiryDays <= 4) return ExpiryStatus.expiringSoon;
    return ExpiryStatus.normal;
  }

  String get expiryLabel {
    if (expiryDays == 0) return 'Expires today';
    if (expiryDays == 1) return 'Expires in 1 day';
    return 'Expires in $expiryDays days';
  }

  int get numericAmount {
    final match = RegExp(r'(\d+)').firstMatch(quantity);
    return match != null ? int.tryParse(match.group(1)!) ?? 1 : 1;
  }

  String get unit {
    final match = RegExp(r'\d+\s*([a-zA-Z]+)').firstMatch(quantity);
    return match != null ? match.group(1)! : 'g';
  }

  int get stepAmount {
    final u = unit.toLowerCase();
    if (u == 'g' || u == 'ml') return 50;
    return 1;
  }

  CategoryFoodItem copyWith({
    String? id,
    String? name,
    String? quantity,
    int? expiryDays,
    String? imageAsset,
    String? iconEmoji,
  }) {
    return CategoryFoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      expiryDays: expiryDays ?? this.expiryDays,
      imageAsset: imageAsset ?? this.imageAsset,
      iconEmoji: iconEmoji ?? this.iconEmoji,
    );
  }

  /// Returns the item's specific food image asset path.
  /// If [imageAsset] was not provided or points to a category collage, resolves to its dedicated item visual.
  String? get effectiveImageAsset {
    if (imageAsset != null &&
        imageAsset!.isNotEmpty &&
        !imageAsset!.contains('categories/vegetables') &&
        !imageAsset!.contains('categories/fruits') &&
        !imageAsset!.contains('categories/dairy_products') &&
        !imageAsset!.contains('categories/non_veg') &&
        !imageAsset!.contains('categories/leftovers') &&
        !imageAsset!.contains('categories/packaged_food') &&
        !imageAsset!.contains('categories/juices') &&
        !imageAsset!.contains('categories/ice_cream') &&
        !imageAsset!.contains('categories/frozen_food') &&
        !imageAsset!.contains('categories/dry_fruits') &&
        !imageAsset!.contains('categories/others')) {
      return imageAsset;
    }
    return FoodItemAssetRegistry.getAssetForItem(name);
  }

  /// Soft background color for status tag
  Color get statusBackgroundColor {
    switch (status) {
      case ExpiryStatus.urgent:
        return const Color(0xFFFDE8E8); // Soft coral
      case ExpiryStatus.expiringSoon:
        return const Color(0xFFFFF0E0); // Soft peach
      case ExpiryStatus.normal:
        return const Color(0xFFEDF7ED); // Muted green
    }
  }

  /// Deep readable foreground color for status tag
  Color get statusTextColor {
    switch (status) {
      case ExpiryStatus.urgent:
        return const Color(0xFFD32F2F); // Soft coral red
      case ExpiryStatus.expiringSoon:
        return const Color(0xFFD96B27); // Soft warm orange
      case ExpiryStatus.normal:
        return const Color(0xFF2E7D32); // Subtle green
    }
  }
}

/// Centralized registry mapping individual food item names to dedicated realistic food images.
/// Guarantees that EVERY inventory item references its own distinct food visual,
/// and never falls back to category collages (vegetables.png, fruits.png, etc.).
class FoodItemAssetRegistry {
  static const Map<String, String> _itemAssetMap = {
    // Dairy Products
    'milk': 'assets/images/foods/milk.png',
    'paneer': 'assets/images/foods/paneer.png',
    'curd': 'assets/images/foods/curd.png',
    'yogurt': 'assets/images/foods/curd.png',
    'butter': 'assets/images/foods/butter.png',
    'cheese': 'assets/images/foods/paneer.png',

    // Vegetables
    'tomato': 'assets/images/foods/tomato.jpg',
    'tomatoes': 'assets/images/foods/tomato.jpg',
    'carrot': 'assets/images/foods/carrot.jpg',
    'carrots': 'assets/images/foods/carrot.jpg',
    'broccoli': 'assets/images/foods/broccoli.jpg',
    'capsicum': 'assets/images/foods/capsicum.jpg',
    'bell pepper': 'assets/images/foods/capsicum.jpg',
    'pepper': 'assets/images/foods/capsicum.jpg',

    // Fruits
    'apple': 'assets/images/foods/apple.jpg',
    'apples': 'assets/images/foods/apple.jpg',
    'banana': 'assets/images/foods/banana.jpg',
    'bananas': 'assets/images/foods/banana.jpg',
    'orange': 'assets/images/foods/orange.jpg',
    'oranges': 'assets/images/foods/orange.jpg',
    'grape': 'assets/images/foods/grapes.jpg',
    'grapes': 'assets/images/foods/grapes.jpg',

    // Non-Veg
    'egg': 'assets/images/foods/eggs.jpg',
    'eggs': 'assets/images/foods/eggs.jpg',
    'chicken': 'assets/images/foods/chicken.jpg',
    'fish': 'assets/images/foods/fish.jpg',
    'salmon': 'assets/images/foods/fish.jpg',

    // Meals & Leftovers
    'paneer curry': 'assets/images/foods/paneer_curry.jpg',
    'curry': 'assets/images/foods/paneer_curry.jpg',
    'dal': 'assets/images/foods/dal_rice.jpg',
    'dal rice': 'assets/images/foods/dal_rice.jpg',
    'rice': 'assets/images/foods/dal_rice.jpg',
    'pasta': 'assets/images/foods/pasta.jpg',
    'penne': 'assets/images/foods/pasta.jpg',
    'paneer rice bowl': 'assets/images/foods/paneer_curry.jpg',

    // Packaged Food
    'bread': 'assets/images/foods/bread.jpg',
    'peanut butter': 'assets/images/foods/peanut_butter.jpg',
    'jam': 'assets/images/foods/jam.jpg',

    // Drinks & Juices
    'orange juice': 'assets/images/foods/orange_juice.jpg',
    'apple juice': 'assets/images/foods/apple_juice.jpg',
    'juice': 'assets/images/foods/orange_juice.jpg',
    'water': 'assets/images/foods/water.jpg',

    // Ice Cream
    'vanilla ice cream': 'assets/images/foods/vanilla_ice_cream.jpg',
    'chocolate ice cream': 'assets/images/foods/chocolate_ice_cream.jpg',
    'ice cream': 'assets/images/foods/vanilla_ice_cream.jpg',

    // Frozen Food
    'frozen peas': 'assets/images/foods/frozen_peas.jpg',
    'peas': 'assets/images/foods/frozen_peas.jpg',
    'frozen corn': 'assets/images/foods/frozen_corn.jpg',
    'corn': 'assets/images/foods/frozen_corn.jpg',
    'french fries': 'assets/images/foods/french_fries.jpg',
    'fries': 'assets/images/foods/french_fries.jpg',

    // Dry Fruits
    'almond': 'assets/images/foods/almonds.jpg',
    'almonds': 'assets/images/foods/almonds.jpg',
    'cashew': 'assets/images/foods/cashews.jpg',
    'cashews': 'assets/images/foods/cashews.jpg',
    'raisin': 'assets/images/foods/raisins.jpg',
    'raisins': 'assets/images/foods/raisins.jpg',
    'dry fruits': 'assets/images/foods/dry_fruits_mix.jpg',
    'dry fruits mix': 'assets/images/foods/dry_fruits_mix.jpg',
    'mixed nuts': 'assets/images/foods/dry_fruits_mix.jpg',

    // Others
    'honey': 'assets/images/foods/honey.jpg',
    'chocolate': 'assets/images/foods/chocolate.jpg',
  };

  /// Resolves the dedicated asset path for an item by name and optional category.
  /// Never returns a category collage/hero image.
  static String getAssetForItem(String name, [String? category]) {
    final cleanName = name.trim().toLowerCase();

    // Direct exact lookup
    if (_itemAssetMap.containsKey(cleanName)) {
      return _itemAssetMap[cleanName]!;
    }

    // Partial/keyword match
    for (final entry in _itemAssetMap.entries) {
      if (cleanName.contains(entry.key) || entry.key.contains(cleanName)) {
        return entry.value;
      }
    }

    // Category-specific fallback item visual (individual food, not category collage)
    if (category != null) {
      final cat = category.toLowerCase();
      if (cat.contains('dairy')) return 'assets/images/foods/milk.png';
      if (cat.contains('veg')) return 'assets/images/foods/tomato.jpg';
      if (cat.contains('fruit') && !cat.contains('dry')) return 'assets/images/foods/apple.jpg';
      if (cat.contains('non-veg') || cat.contains('non veg')) return 'assets/images/foods/chicken.jpg';
      if (cat.contains('meal') || cat.contains('leftover')) return 'assets/images/foods/paneer_curry.jpg';
      if (cat.contains('package')) return 'assets/images/foods/bread.jpg';
      if (cat.contains('drink') || cat.contains('juice')) return 'assets/images/foods/orange_juice.jpg';
      if (cat.contains('ice cream')) return 'assets/images/foods/vanilla_ice_cream.jpg';
      if (cat.contains('frozen')) return 'assets/images/foods/frozen_peas.jpg';
      if (cat.contains('dry fruit')) return 'assets/images/foods/almonds.jpg';
      if (cat.contains('other')) return 'assets/images/foods/honey.jpg';
    }

    return 'assets/images/foods/apple.jpg';
  }
}

/// Data model representing a refrigerator category with its inventory
class CategoryData {
  final String id;
  final String name;
  final String iconEmoji;
  final String? imageAsset;
  final List<CategoryFoodItem> items;

  const CategoryData({
    required this.id,
    required this.name,
    required this.iconEmoji,
    this.imageAsset,
    required this.items,
  });

  int get itemCount => items.length;

  CategoryData copyWith({
    String? id,
    String? name,
    String? iconEmoji,
    String? imageAsset,
    List<CategoryFoodItem>? items,
  }) {
    return CategoryData(
      id: id ?? this.id,
      name: name ?? this.name,
      iconEmoji: iconEmoji ?? this.iconEmoji,
      imageAsset: imageAsset ?? this.imageAsset,
      items: items ?? this.items,
    );
  }
}

/// Mock repository providing food items for categories
class FridgeCategoryRepository {
  /// Canonical list of exactly the 11 Fridge categories
  static const List<String> canonicalCategories = [
    'Dairy Products',
    'Others',
    'Non-Veg',
    'Meals & Leftovers',
    'Packaged Food',
    'Drinks & Juices',
    'Vegetables',
    'Fruits',
    'Ice Cream',
    'Frozen Food',
    'Dry Fruits',
  ];

  static Map<String, List<CategoryFoodItem>> _categoryStore = _buildInitialStore();

  /// Change notifier for dynamic inventory updates across screens
  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  static void _notify() {
    notifier.value++;
  }

  static Map<String, List<CategoryFoodItem>> _buildInitialStore() {
    return {
      'Dairy Products': [
        const CategoryFoodItem(
          id: 'dairy_1',
          name: 'Milk',
          quantity: '500 ml',
          expiryDays: 2,
          imageAsset: 'assets/images/foods/milk.png',
          iconEmoji: '🥛',
        ),
        const CategoryFoodItem(
          id: 'dairy_2',
          name: 'Paneer',
          quantity: '250 g',
          expiryDays: 3,
          imageAsset: 'assets/images/foods/paneer.png',
          iconEmoji: '🧀',
        ),
        const CategoryFoodItem(
          id: 'dairy_3',
          name: 'Curd',
          quantity: '400 g',
          expiryDays: 5,
          imageAsset: 'assets/images/foods/curd.png',
          iconEmoji: '🥣',
        ),
        const CategoryFoodItem(
          id: 'dairy_4',
          name: 'Butter',
          quantity: '100 g',
          expiryDays: 8,
          imageAsset: 'assets/images/foods/butter.png',
          iconEmoji: '🧈',
        ),
      ],
      'Others': [
        const CategoryFoodItem(
          id: 'oth_1',
          name: 'Dry Fruits',
          quantity: '250 g',
          expiryDays: 30,
          imageAsset: 'assets/images/foods/dry_fruits_mix.jpg',
          iconEmoji: '🥜',
        ),
        const CategoryFoodItem(
          id: 'oth_2',
          name: 'Honey',
          quantity: '1 jar',
          expiryDays: 90,
          imageAsset: 'assets/images/foods/honey.jpg',
          iconEmoji: '🍯',
        ),
        const CategoryFoodItem(
          id: 'oth_3',
          name: 'Chocolate',
          quantity: '1 pack',
          expiryDays: 25,
          imageAsset: 'assets/images/foods/chocolate.jpg',
          iconEmoji: '🍫',
        ),
      ],
      'Non-Veg': [
        const CategoryFoodItem(
          id: 'nv_1',
          name: 'Eggs',
          quantity: '6 pieces',
          expiryDays: 10,
          imageAsset: 'assets/images/foods/eggs.jpg',
          iconEmoji: '🥚',
        ),
        const CategoryFoodItem(
          id: 'nv_2',
          name: 'Chicken',
          quantity: '500 g',
          expiryDays: 2,
          imageAsset: 'assets/images/foods/chicken.jpg',
          iconEmoji: '🍗',
        ),
        const CategoryFoodItem(
          id: 'nv_3',
          name: 'Fish',
          quantity: '400 g',
          expiryDays: 3,
          imageAsset: 'assets/images/foods/fish.jpg',
          iconEmoji: '🐟',
        ),
      ],
      'Meals & Leftovers': [
        const CategoryFoodItem(
          id: 'ml_1',
          name: 'Paneer Curry',
          quantity: '300 g',
          expiryDays: 2,
          imageAsset: 'assets/images/foods/paneer_curry.jpg',
          iconEmoji: '🍲',
        ),
        const CategoryFoodItem(
          id: 'ml_2',
          name: 'Dal Rice',
          quantity: '400 g',
          expiryDays: 1,
          imageAsset: 'assets/images/foods/dal_rice.jpg',
          iconEmoji: '🍛',
        ),
        const CategoryFoodItem(
          id: 'ml_3',
          name: 'Pasta',
          quantity: '350 g',
          expiryDays: 2,
          imageAsset: 'assets/images/foods/pasta.jpg',
          iconEmoji: '🍝',
        ),
      ],
      'Packaged Food': [
        const CategoryFoodItem(
          id: 'pkg_1',
          name: 'Bread',
          quantity: '1 pack',
          expiryDays: 4,
          imageAsset: 'assets/images/foods/bread.jpg',
          iconEmoji: '🍞',
        ),
        const CategoryFoodItem(
          id: 'pkg_2',
          name: 'Peanut Butter',
          quantity: '340 g',
          expiryDays: 60,
          imageAsset: 'assets/images/foods/peanut_butter.jpg',
          iconEmoji: '🥜',
        ),
        const CategoryFoodItem(
          id: 'pkg_3',
          name: 'Jam',
          quantity: '1 jar',
          expiryDays: 90,
          imageAsset: 'assets/images/foods/jam.jpg',
          iconEmoji: '🍓',
        ),
      ],
      'Drinks & Juices': [
        const CategoryFoodItem(
          id: 'drk_1',
          name: 'Orange Juice',
          quantity: '1 L',
          expiryDays: 5,
          imageAsset: 'assets/images/foods/orange_juice.jpg',
          iconEmoji: '🍊',
        ),
        const CategoryFoodItem(
          id: 'drk_2',
          name: 'Apple Juice',
          quantity: '1 L',
          expiryDays: 7,
          imageAsset: 'assets/images/foods/apple_juice.jpg',
          iconEmoji: '🧃',
        ),
        const CategoryFoodItem(
          id: 'drk_3',
          name: 'Water',
          quantity: '2 L',
          expiryDays: 120,
          imageAsset: 'assets/images/foods/water.jpg',
          iconEmoji: '💧',
        ),
      ],
      'Vegetables': [
        const CategoryFoodItem(
          id: 'veg_1',
          name: 'Tomato',
          quantity: '5 pieces',
          expiryDays: 3,
          imageAsset: 'assets/images/foods/tomato.jpg',
          iconEmoji: '🍅',
        ),
        const CategoryFoodItem(
          id: 'veg_2',
          name: 'Carrot',
          quantity: '500 g',
          expiryDays: 7,
          imageAsset: 'assets/images/foods/carrot.jpg',
          iconEmoji: '🥕',
        ),
        const CategoryFoodItem(
          id: 'veg_3',
          name: 'Broccoli',
          quantity: '1 piece',
          expiryDays: 4,
          imageAsset: 'assets/images/foods/broccoli.jpg',
          iconEmoji: '🥦',
        ),
        const CategoryFoodItem(
          id: 'veg_4',
          name: 'Capsicum',
          quantity: '3 pieces',
          expiryDays: 5,
          imageAsset: 'assets/images/foods/capsicum.jpg',
          iconEmoji: '🫑',
        ),
      ],
      'Fruits': [
        const CategoryFoodItem(
          id: 'frt_1',
          name: 'Apple',
          quantity: '4 pieces',
          expiryDays: 6,
          imageAsset: 'assets/images/foods/apple.jpg',
          iconEmoji: '🍎',
        ),
        const CategoryFoodItem(
          id: 'frt_2',
          name: 'Banana',
          quantity: '6 pieces',
          expiryDays: 2,
          imageAsset: 'assets/images/foods/banana.jpg',
          iconEmoji: '🍌',
        ),
        const CategoryFoodItem(
          id: 'frt_3',
          name: 'Orange',
          quantity: '3 pieces',
          expiryDays: 8,
          imageAsset: 'assets/images/foods/orange.jpg',
          iconEmoji: '🍊',
        ),
        const CategoryFoodItem(
          id: 'frt_4',
          name: 'Grapes',
          quantity: '500 g',
          expiryDays: 4,
          imageAsset: 'assets/images/foods/grapes.jpg',
          iconEmoji: '🍇',
        ),
      ],
      'Ice Cream': [
        const CategoryFoodItem(
          id: 'ice_1',
          name: 'Vanilla Ice Cream',
          quantity: '1 tub',
          expiryDays: 30,
          imageAsset: 'assets/images/foods/vanilla_ice_cream.jpg',
          iconEmoji: '🍨',
        ),
        const CategoryFoodItem(
          id: 'ice_2',
          name: 'Chocolate Ice Cream',
          quantity: '1 tub',
          expiryDays: 30,
          imageAsset: 'assets/images/foods/chocolate_ice_cream.jpg',
          iconEmoji: '🍫',
        ),
      ],
      'Frozen Food': [
        const CategoryFoodItem(
          id: 'frz_1',
          name: 'Frozen Peas',
          quantity: '500 g',
          expiryDays: 45,
          imageAsset: 'assets/images/foods/frozen_peas.jpg',
          iconEmoji: '🫛',
        ),
        const CategoryFoodItem(
          id: 'frz_2',
          name: 'Frozen Corn',
          quantity: '500 g',
          expiryDays: 45,
          imageAsset: 'assets/images/foods/frozen_corn.jpg',
          iconEmoji: '🌽',
        ),
        const CategoryFoodItem(
          id: 'frz_3',
          name: 'French Fries',
          quantity: '1 pack',
          expiryDays: 60,
          imageAsset: 'assets/images/foods/french_fries.jpg',
          iconEmoji: '🍟',
        ),
      ],
      'Dry Fruits': [
        const CategoryFoodItem(
          id: 'df_1',
          name: 'Almonds',
          quantity: '200 g',
          expiryDays: 90,
          imageAsset: 'assets/images/foods/almonds.jpg',
          iconEmoji: '🌰',
        ),
        const CategoryFoodItem(
          id: 'df_2',
          name: 'Cashews',
          quantity: '200 g',
          expiryDays: 90,
          imageAsset: 'assets/images/foods/cashews.jpg',
          iconEmoji: '🥜',
        ),
        const CategoryFoodItem(
          id: 'df_3',
          name: 'Raisins',
          quantity: '150 g',
          expiryDays: 60,
          imageAsset: 'assets/images/foods/raisins.jpg',
          iconEmoji: '🍇',
        ),
      ],
    };
  }

  /// Mock data for DAIRY PRODUCTS (for backward compatibility)
  static CategoryData get dairyProducts => getCategoryData('Dairy Products');

  /// Total count of items currently in the fridge
  static int get totalFridgeItems {
    int total = 0;
    for (final list in _categoryStore.values) {
      total += list.length;
    }
    return total;
  }

  /// Find a food item in the fridge inventory by name (case-insensitive substring or exact match)
  static CategoryFoodItem? findItemByName(String name, {bool exact = false}) {
    final lower = name.toLowerCase().trim();
    for (final list in _categoryStore.values) {
      for (final item in list) {
        final itemLower = item.name.toLowerCase().trim();
        if (itemLower == lower || (!exact && (itemLower.contains(lower) || lower.contains(itemLower)))) {
          return item;
        }
      }
    }
    return null;
  }

  /// Number of items expiring soon (expiryDays <= 3)
  static int get expiringSoonCount {
    int count = 0;
    for (final list in _categoryStore.values) {
      for (final item in list) {
        if (item.expiryDays <= 3) {
          count++;
        }
      }
    }
    return count;
  }

  /// Add a food item into a category
  static void addItemToCategory(String categoryName, CategoryFoodItem item) {
    final canonicalName = _canonicalizeCategory(categoryName);
    final resolvedImage = (item.imageAsset != null &&
            item.imageAsset!.isNotEmpty &&
            !item.imageAsset!.contains('categories/vegetables') &&
            !item.imageAsset!.contains('categories/fruits') &&
            !item.imageAsset!.contains('categories/dairy_products') &&
            !item.imageAsset!.contains('categories/non_veg') &&
            !item.imageAsset!.contains('categories/leftovers') &&
            !item.imageAsset!.contains('categories/packaged_food') &&
            !item.imageAsset!.contains('categories/juices') &&
            !item.imageAsset!.contains('categories/ice_cream') &&
            !item.imageAsset!.contains('categories/frozen_food') &&
            !item.imageAsset!.contains('categories/dry_fruits') &&
            !item.imageAsset!.contains('categories/others'))
        ? item.imageAsset
        : FoodItemAssetRegistry.getAssetForItem(item.name, canonicalName);
    final resolvedItem = (item.imageAsset == resolvedImage)
        ? item
        : item.copyWith(imageAsset: resolvedImage);
    final list = _categoryStore.putIfAbsent(canonicalName, () => []);
    list.add(resolvedItem);
    NotificationRepository.addNotification(
      title: 'Inventory update',
      description: '${resolvedItem.name} was added to your fridge.',
      type: NotificationType.inventoryUpdate,
    );
    _notify();
  }

  /// Add multiple items to categories
  static void addMultipleItems(List<MapEntry<String, CategoryFoodItem>> entries) {
    for (final entry in entries) {
      addItemToCategory(entry.key, entry.value);
    }
  }

  /// Update item quantity in mock state
  static void updateItem(String categoryIdOrName, CategoryFoodItem updatedItem) {
    final canonicalName = _canonicalizeCategory(categoryIdOrName);
    final list = _categoryStore[canonicalName];
    if (list != null) {
      final index = list.indexWhere((it) => it.id == updatedItem.id);
      if (index != -1) {
        list[index] = updatedItem;
        _notify();
        return;
      }
    }
    // Search across all categories in case categoryId was passed
    for (final l in _categoryStore.values) {
      final index = l.indexWhere((it) => it.id == updatedItem.id);
      if (index != -1) {
        l[index] = updatedItem;
        _notify();
        return;
      }
    }
  }

  /// Remove item from mock state
  static void removeItem(String categoryIdOrName, String itemId) {
    final canonicalName = _canonicalizeCategory(categoryIdOrName);
    final list = _categoryStore[canonicalName];
    if (list != null) {
      list.removeWhere((it) => it.id == itemId);
      _notify();
      return;
    }
    for (final l in _categoryStore.values) {
      l.removeWhere((it) => it.id == itemId);
    }
    _notify();
  }

  /// Remove an item by its name (case-insensitive substring or exact match) across all categories
  static bool removeItemByName(String name) {
    final lower = name.toLowerCase().trim();
    for (final list in _categoryStore.values) {
      final index = list.indexWhere((it) {
        final itemLower = it.name.toLowerCase().trim();
        return itemLower == lower ||
            itemLower.contains(lower) ||
            lower.contains(itemLower);
      });
      if (index != -1) {
        final removedItem = list.removeAt(index);
        NotificationRepository.addNotification(
          title: 'Inventory update',
          description: '${removedItem.name} was removed from your fridge.',
          type: NotificationType.inventoryUpdate,
        );
        _notify();
        return true;
      }
    }
    return false;
  }

  /// Remove multiple items by name
  static int removeMultipleItemsByName(List<String> names) {
    int count = 0;
    for (final name in names) {
      if (removeItemByName(name)) {
        count++;
      }
    }
    return count;
  }

  /// Reset to initial mock state (for tests)
  static void reset() {
    _categoryStore = _buildInitialStore();
    _notify();
  }

  /// Helper to get category data by label or id
  static CategoryData getCategoryData(String categoryLabel) {
    final canonicalName = _canonicalizeCategory(categoryLabel);
    final items = _categoryStore[canonicalName] ?? const [];

    return CategoryData(
      id: canonicalName.toLowerCase().replaceAll(RegExp(r'\s+'), '_'),
      name: canonicalName,
      iconEmoji: _categoryEmoji(canonicalName),
      imageAsset: _categoryImage(canonicalName),
      items: List.unmodifiable(items),
    );
  }

  static String _canonicalizeCategory(String name) {
    final cleaned = name.trim().replaceAll('_', ' ');
    for (final cat in canonicalCategories) {
      if (cat.equalsIgnoreCase(cleaned) || cat.equalsIgnoreCase(name.trim())) {
        return cat;
      }
    }
    final upper = cleaned.toUpperCase();
    if (upper.contains('DAIRY')) return 'Dairy Products';
    if (upper.contains('ICE CREAM')) return 'Ice Cream';
    if (upper.contains('FROZEN')) return 'Frozen Food';
    if (upper.contains('DRY FRUIT')) return 'Dry Fruits';
    if (upper.contains('NON-VEG') || upper.contains('NON VEG')) return 'Non-Veg';
    if (upper.contains('LEFTOVER') || upper.contains('MEAL')) return 'Meals & Leftovers';
    if (upper.contains('PACKAGE')) return 'Packaged Food';
    if (upper.contains('DRINK') || upper.contains('JUICE')) return 'Drinks & Juices';
    if (upper.contains('VEG')) return 'Vegetables';
    if (upper.contains('FRUIT')) return 'Fruits';
    return 'Others';
  }

  static String _categoryImage(String key) {
    final upper = key.toUpperCase();
    if (upper.contains('ICE CREAM')) return 'assets/images/categories/ice_cream.png';
    if (upper.contains('FROZEN')) return 'assets/images/categories/frozen_food.png';
    if (upper.contains('DRY FRUITS')) return 'assets/images/categories/dry_fruits.png';
    if (upper.contains('DAIRY')) return 'assets/images/categories/dairy_products.png';
    if (upper.contains('NON-VEG')) return 'assets/images/categories/non_veg.png';
    if (upper.contains('LEFTOVERS')) return 'assets/images/categories/leftovers.png';
    if (upper.contains('PACKAGED')) return 'assets/images/categories/packaged_food.png';
    if (upper.contains('JUICE') || upper.contains('DRINK')) return 'assets/images/categories/juices.png';
    if (upper.contains('VEGETABLES')) return 'assets/images/categories/vegetables.png';
    if (upper.contains('FRUITS')) return 'assets/images/categories/fruits.png';
    return 'assets/images/categories/others.png';
  }

  static String _categoryEmoji(String key) {
    final upper = key.toUpperCase();
    if (upper.contains('ICE CREAM')) return '🍦';
    if (upper.contains('FROZEN')) return '🧊';
    if (upper.contains('DRY FRUITS')) return '🥜';
    if (upper.contains('DAIRY')) return '🥛';
    if (upper.contains('NON-VEG')) return '🍗';
    if (upper.contains('LEFTOVERS')) return '🍲';
    if (upper.contains('PACKAGED')) return '📦';
    if (upper.contains('JUICE') || upper.contains('DRINK')) return '🧃';
    if (upper.contains('VEG')) return '🥦';
    if (upper.contains('FRUIT')) return '🍎';
    return '🍱';
  }
}

extension _StringCaseExtension on String {
  bool equalsIgnoreCase(String other) => toLowerCase() == other.toLowerCase();
}
