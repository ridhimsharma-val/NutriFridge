// ignore_for_file: prefer_initializing_formals
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/notification_data.dart';
import '../../../../services/auth/auth_service.dart';
import '../../../../services/inventory/fridge_inventory_repository.dart';

/// Expiry urgency level with calm, subtle pastel status colors
enum ExpiryStatus {
  expired, // Warning treatment (soft red)
  urgent, // Soft peach/coral
  expiringSoon, // Soft peach/coral (AppColors.peachPrimary)
  normal, // Subtle muted green (Fresh)
  unknown, // Neutral "Expiry not set"
}

/// A food/inventory item within a category
class CategoryFoodItem {
  final String id;
  final String name;
  final String quantity;
  final int? _expiryDays;
  final DateTime? expiryDate;
  final String? imageAsset;
  final String? storageImagePath;
  final String? iconEmoji;
  final String? category;

  const CategoryFoodItem({
    required this.id,
    required this.name,
    required this.quantity,
    int? expiryDays,
    this.expiryDate,
    this.imageAsset,
    this.storageImagePath,
    this.iconEmoji,
    this.category,
  }) : _expiryDays = expiryDays;

  int? get expiryDays {
    if (_expiryDays != null) return _expiryDays;
    if (expiryDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(expiryDate!.year, expiryDate!.month, expiryDate!.day);
      return target.difference(today).inDays;
    }
    return null;
  }

  bool get isExpired => expiryDays != null && expiryDays! < 0;
  bool get isExpiringSoon => expiryDays != null && expiryDays! >= 0 && expiryDays! <= 3;
  bool get isFresh => expiryDays != null && expiryDays! > 3;
  bool get isExpiryUnknown => expiryDays == null;

  ExpiryStatus get status {
    if (expiryDays == null) return ExpiryStatus.unknown;
    if (expiryDays! < 0) return ExpiryStatus.expired;
    if (expiryDays! <= 2) return ExpiryStatus.urgent;
    if (expiryDays! <= 3) return ExpiryStatus.expiringSoon;
    return ExpiryStatus.normal;
  }

  String get expiryLabel {
    if (expiryDays == null) return 'Expiry not set';
    if (expiryDays! < 0) {
      final daysAgo = -expiryDays!;
      return daysAgo == 1 ? 'Expired 1 day ago' : 'Expired $daysAgo days ago';
    }
    if (expiryDays == 0) return 'Expires today';
    if (expiryDays == 1) return 'Expires in 1 day';
    return 'Expires in $expiryDays days';
  }

  int get numericAmount {
    final match = RegExp(r'(\d+)').firstMatch(quantity);
    return match != null ? int.tryParse(match.group(1)!) ?? 1 : 1;
  }

  num get decimalAmount {
    final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(quantity);
    return match != null ? num.tryParse(match.group(1)!) ?? 1 : 1;
  }

  String get unit {
    final match = RegExp(r'[0-9.]+\s*([a-zA-Z]+)').firstMatch(quantity);
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
    DateTime? expiryDate,
    String? imageAsset,
    String? storageImagePath,
    String? iconEmoji,
    String? category,
  }) {
    return CategoryFoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      expiryDays: expiryDays ?? _expiryDays,
      expiryDate: expiryDate ?? this.expiryDate,
      imageAsset: imageAsset ?? this.imageAsset,
      storageImagePath: storageImagePath ?? this.storageImagePath,
      iconEmoji: iconEmoji ?? this.iconEmoji,
      category: category ?? this.category,
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
      case ExpiryStatus.expired:
        return const Color(0xFFFEE2E2); // Warning soft red
      case ExpiryStatus.urgent:
      case ExpiryStatus.expiringSoon:
        return AppColors.peachLight; // const Color(0xFFFBE7DE)
      case ExpiryStatus.normal:
        return const Color(0xFFEDF7ED); // Muted green
      case ExpiryStatus.unknown:
        return const Color(0xFFF1F5F9); // Neutral slate
    }
  }

  /// Deep readable foreground color for status tag
  Color get statusTextColor {
    switch (status) {
      case ExpiryStatus.expired:
        return const Color(0xFFB91C1C); // Contrasting warning red
      case ExpiryStatus.urgent:
      case ExpiryStatus.expiringSoon:
        return AppColors.peachText; // const Color(0xFF9E4B33)
      case ExpiryStatus.normal:
        return const Color(0xFF2E7D32); // Subtle green
      case ExpiryStatus.unknown:
        return const Color(0xFF64748B); // Slate neutral
    }
  }

  /// Subtle border color for status tag
  Color get statusBorderColor {
    switch (status) {
      case ExpiryStatus.expired:
        return const Color(0xFFFCA5A5);
      case ExpiryStatus.urgent:
      case ExpiryStatus.expiringSoon:
        return AppColors.peachBorder; // const Color(0xFFF2C4B2)
      case ExpiryStatus.normal:
        return const Color(0xFFC8E6C9);
      case ExpiryStatus.unknown:
        return const Color(0xFFE2E8F0);
    }
  }

  /// Distinct accent color for edge indicator or indicator dot
  Color get statusAccentColor {
    switch (status) {
      case ExpiryStatus.expired:
        return const Color(0xFFDC2626);
      case ExpiryStatus.urgent:
      case ExpiryStatus.expiringSoon:
        return AppColors.peachPrimary; // const Color(0xFFE99A7C)
      case ExpiryStatus.normal:
        return AppColors.tealPrimary; // const Color(0xFF176D5C)
      case ExpiryStatus.unknown:
        return const Color(0xFF94A3B8);
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

  /// Returns a clean representative emoji for a canonical fridge category.
  static String getEmojiForCategory(String category) {
    switch (category) {
      case 'Dairy Products':
        return '🥛';
      case 'Vegetables':
        return '🥕';
      case 'Fruits':
        return '🍎';
      case 'Non-Veg':
        return '🍗';
      case 'Meals & Leftovers':
        return '🍲';
      case 'Packaged Food':
        return '🍞';
      case 'Drinks & Juices':
        return '🧃';
      case 'Ice Cream':
        return '🍨';
      case 'Frozen Food':
        return '🧊';
      case 'Dry Fruits':
        return '🥜';
      case 'Others':
      default:
        return '🍴';
    }
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

enum DeductionStatus {
  success,
  removed,
  overRemoval,
  incompatibleUnits,
  notFound,
  ambiguous,
}

class DeductionResult {
  final DeductionStatus status;
  final String message;
  final CategoryFoodItem? updatedItem;
  final num? remainingQuantity;
  final String? remainingUnit;

  const DeductionResult({
    required this.status,
    required this.message,
    this.updatedItem,
    this.remainingQuantity,
    this.remainingUnit,
  });

  bool get isSuccess => status == DeductionStatus.success || status == DeductionStatus.removed;
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

  static bool isLoading = false;
  static String? loadError;
  static bool isLoadedFromSupabase = false;
  static String? currentLoadedUserId;
  static bool forceInMemoryForTesting = false;

  static String canonicalizeCategory(String name) => _canonicalizeCategory(name);
  static String categoryEmoji(String key) => _categoryEmoji(key);
  static String categoryImage(String key) => _categoryImage(key);

  /// Loads all items from public.fridge_items for the authenticated user.
  static Future<void> loadFromSupabase({String? userId, bool force = false}) async {
    final effectiveUserId = userId ?? AuthService.instance.currentUser?.id;
    if (effectiveUserId == null) return;
    if (forceInMemoryForTesting) return;

    if (!force && isLoadedFromSupabase && currentLoadedUserId == effectiveUserId) {
      return;
    }

    isLoading = true;
    loadError = null;
    _notify();

    try {
      final items = await FridgeInventoryRepository.instance.fetchItems(userId: effectiveUserId);
      if (AuthService.instance.currentUser?.id != effectiveUserId) {
        // Discard stale response if active user switched during network call
        return;
      }

      final newStore = _buildInitialStore();
      for (final item in items) {
        final cat = _canonicalizeCategory(item.category ?? 'Others');
        newStore.putIfAbsent(cat, () => []).add(item);
      }

      _categoryStore = newStore;
      isLoadedFromSupabase = true;
      currentLoadedUserId = effectiveUserId;
      isLoading = false;
      loadError = null;
      _notify();
    } catch (e) {
      if (AuthService.instance.currentUser?.id == effectiveUserId) {
        isLoading = false;
        loadError = e.toString();
        _notify();
      }
    }
  }

  /// Clears inventory state upon user logout to prevent account leakage.
  static void clearForLogout() {
    currentLoadedUserId = null;
    isLoadedFromSupabase = false;
    isLoading = false;
    loadError = null;
    _categoryStore = _buildInitialStore();
    _notify();
  }

  static void _notify() {
    notifier.value++;
  }

  static Map<String, List<CategoryFoodItem>> _buildInitialStore() {
    return {
      for (final cat in canonicalCategories) cat: <CategoryFoodItem>[],
    };
  }

  /// Seeds demo fixture data for automated test suites
  static void seedSampleDataForTesting() {
    _categoryStore = _buildSampleFixtureStore();
    _notify();
  }

  static Map<String, List<CategoryFoodItem>> _buildSampleFixtureStore() {
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
    // 1. First pass: exact or plural/singular match
    for (final list in _categoryStore.values) {
      for (final item in list) {
        if (isFoodNameMatching(item.name, lower)) {
          return item;
        }
      }
    }
    if (exact) return null;

    // 2. Second pass: substring match
    for (final list in _categoryStore.values) {
      for (final item in list) {
        final itemLower = item.name.toLowerCase().trim();
        if (itemLower.contains(lower) || lower.contains(itemLower)) {
          return item;
        }
      }
    }
    return null;
  }

  /// Find a food item in the fridge inventory by its unique ID
  static CategoryFoodItem? findItemById(String id) {
    for (final list in _categoryStore.values) {
      for (final item in list) {
        if (item.id == id) {
          return item;
        }
      }
    }
    return null;
  }

  /// Number of items expiring soon (expiryDays between 0 and 3 days)
  static int get expiringSoonCount {
    int count = 0;
    for (final list in _categoryStore.values) {
      for (final item in list) {
        if (item.expiryDays != null && item.expiryDays! >= 0 && item.expiryDays! <= 3) {
          count++;
        }
      }
    }
    return count;
  }

  /// Add a food item into a category
  static Future<CategoryFoodItem> addItemToCategory(String categoryName, CategoryFoodItem item) async {
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

    if (!forceInMemoryForTesting &&
        AuthService.instance.isAuthenticated &&
        AuthService.instance.currentUser != null) {
      final savedItem = await FridgeInventoryRepository.instance.insertItem(
        name: item.name,
        category: canonicalName,
        quantity: item.decimalAmount,
        unit: item.unit,
        expiryDate: item.expiryDate,
        expiryDays: item.expiryDays,
        imageAsset: resolvedImage,
        storageImagePath: item.storageImagePath,
      );
      final list = _categoryStore.putIfAbsent(canonicalName, () => []);
      list.add(savedItem);
      NotificationRepository.addNotification(
        title: 'Inventory update',
        description: '${savedItem.name} was added to your fridge.',
        type: NotificationType.inventoryUpdate,
      );
      _notify();
      return savedItem;
    }

    final resolvedItem = (item.imageAsset == resolvedImage)
        ? item.copyWith(category: canonicalName)
        : item.copyWith(imageAsset: resolvedImage, category: canonicalName);
    final list = _categoryStore.putIfAbsent(canonicalName, () => []);
    list.add(resolvedItem);
    NotificationRepository.addNotification(
      title: 'Inventory update',
      description: '${resolvedItem.name} was added to your fridge.',
      type: NotificationType.inventoryUpdate,
    );
    _notify();
    return resolvedItem;
  }

  /// Formats quantity with clean number and plural-aware unit
  static String formatQuantity(num quantity, String unit) {
    final cleanUnit = unit.trim().toLowerCase();
    String numStr;
    if (quantity is int || quantity == quantity.roundToDouble()) {
      numStr = '${quantity.toInt()}';
    } else {
      numStr = quantity.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    }

    if (cleanUnit == 'piece' || cleanUnit == 'pieces' || cleanUnit == 'pc' || cleanUnit == 'pcs') {
      return '$numStr ${quantity == 1 ? 'piece' : 'pieces'}';
    }
    if (cleanUnit == 'pack' || cleanUnit == 'packs' || cleanUnit == 'pkt' || cleanUnit == 'pkts') {
      return '$numStr ${quantity == 1 ? 'pack' : 'packs'}';
    }
    if (cleanUnit == 'bottle' || cleanUnit == 'bottles') {
      return '$numStr ${quantity == 1 ? 'bottle' : 'bottles'}';
    }
    if (cleanUnit == 'box' || cleanUnit == 'boxes') {
      return '$numStr ${quantity == 1 ? 'box' : 'boxes'}';
    }
    if (cleanUnit == 'jar' || cleanUnit == 'jars') {
      return '$numStr ${quantity == 1 ? 'jar' : 'jars'}';
    }
    if (cleanUnit == 'tub' || cleanUnit == 'tubs') {
      return '$numStr ${quantity == 1 ? 'tub' : 'tubs'}';
    }
    if (cleanUnit == 'can' || cleanUnit == 'cans') {
      return '$numStr ${quantity == 1 ? 'can' : 'cans'}';
    }
    if (cleanUnit == 'item' || cleanUnit == 'items') {
      return '$numStr ${quantity == 1 ? 'item' : 'items'}';
    }
    if (cleanUnit == 'l' || cleanUnit == 'liter' || cleanUnit == 'liters' || cleanUnit == 'litre' || cleanUnit == 'litres') {
      return '$numStr L';
    }
    if (cleanUnit == 'ml' || cleanUnit == 'millilitre' || cleanUnit == 'millilitres') {
      return '$numStr ml';
    }
    if (cleanUnit == 'g' || cleanUnit == 'gram' || cleanUnit == 'grams') {
      return '$numStr g';
    }
    if (cleanUnit == 'kg' || cleanUnit == 'kilogram' || cleanUnit == 'kilograms') {
      return '$numStr kg';
    }
    return '$numStr $unit'.trim();
  }

  /// Normalizes units to check compatibility
  static String normalizeUnit(String unit) {
    final u = unit.trim().toLowerCase();
    if (u == 'g' || u == 'gram' || u == 'grams') return 'g';
    if (u == 'kg' || u == 'kilogram' || u == 'kilograms') return 'kg';
    if (u == 'ml' || u == 'millilitre' || u == 'millilitres') return 'ml';
    if (u == 'l' || u == 'litre' || u == 'litres' || u == 'liter' || u == 'liters') return 'l';
    if (u == 'piece' || u == 'pieces' || u == 'pc' || u == 'pcs') return 'piece';
    if (u == 'medium' || u == 'small' || u == 'large') return 'piece';
    if (u == 'pack' || u == 'packs' || u == 'pkt' || u == 'pkts') return 'pack';
    if (u == 'bottle' || u == 'bottles') return 'bottle';
    if (u == 'jar' || u == 'jars') return 'jar';
    if (u == 'tub' || u == 'tubs') return 'tub';
    if (u == 'box' || u == 'boxes') return 'box';
    if (u == 'can' || u == 'cans') return 'can';
    if (u == 'item' || u == 'items') return 'item';
    return u;
  }

  /// Checks if two units are compatible for quantity merging
  static bool areUnitsCompatible(String unitA, String unitB) {
    final a = normalizeUnit(unitA);
    final b = normalizeUnit(unitB);
    if (a == b) return true;
    const countable = {'piece', 'pack', 'bottle', 'jar', 'tub', 'box', 'can', 'item'};
    if (countable.contains(a) && countable.contains(b)) return true;
    const weight = {'g', 'kg'};
    if (weight.contains(a) && weight.contains(b)) return true;
    const volume = {'ml', 'l'};
    if (volume.contains(a) && volume.contains(b)) return true;
    return false;
  }

  /// Helper to test if two food names represent the same item (handles singular/plural)
  static bool isFoodNameMatching(String name1, String name2) {
    final a = name1.trim().toLowerCase();
    final b = name2.trim().toLowerCase();
    if (a == b) return true;
    if (a.endsWith('s') && a.substring(0, a.length - 1) == b) return true;
    if (b.endsWith('s') && b.substring(0, b.length - 1) == a) return true;
    if (a.endsWith('es') && a.substring(0, a.length - 2) == b) return true;
    if (b.endsWith('es') && b.substring(0, b.length - 2) == a) return true;
    return false;
  }

  /// Adds a food item to inventory, or if an item with the same name and compatible unit
  /// already exists, increases its quantity.
  static CategoryFoodItem addOrMergeItem({
    required String categoryName,
    required String name,
    required num quantity,
    required String unit,
    int? expiryDays,
    String? imageAsset,
  }) {
    final canonicalName = _canonicalizeCategory(categoryName);

    // 1. Look for existing item with matching name
    // Check canonical category first
    CategoryFoodItem? existingItem;
    String? foundCategory;

    final targetList = _categoryStore[canonicalName];
    if (targetList != null) {
      for (final it in targetList) {
        if (isFoodNameMatching(it.name, name)) {
          existingItem = it;
          foundCategory = canonicalName;
          break;
        }
      }
    }

    // If not found in target category, check all categories
    if (existingItem == null) {
      for (final entry in _categoryStore.entries) {
        for (final it in entry.value) {
          if (isFoodNameMatching(it.name, name)) {
            existingItem = it;
            foundCategory = entry.key;
            break;
          }
        }
        if (existingItem != null) break;
      }
    }

    // 2. If matching item exists, check unit compatibility and merge
    if (existingItem != null && foundCategory != null) {
      final existingUnit = existingItem.unit;
      if (areUnitsCompatible(existingUnit, unit)) {
        final existingQty = existingItem.decimalAmount;
        final normExisting = normalizeUnit(existingUnit);
        final normAdded = normalizeUnit(unit);

        num mergedAmount;
        String mergedUnit;

        if (normExisting == normAdded) {
          mergedAmount = existingQty + quantity;
          mergedUnit = existingUnit.isNotEmpty ? existingUnit : unit;
        } else if (normExisting == 'g' && normAdded == 'kg') {
          mergedAmount = existingQty + (quantity * 1000);
          mergedUnit = 'g';
        } else if (normExisting == 'kg' && normAdded == 'g') {
          mergedAmount = existingQty + (quantity / 1000);
          mergedUnit = 'kg';
        } else if (normExisting == 'ml' && normAdded == 'l') {
          mergedAmount = existingQty + (quantity * 1000);
          mergedUnit = 'ml';
        } else if (normExisting == 'l' && normAdded == 'ml') {
          mergedAmount = existingQty + (quantity / 1000);
          mergedUnit = 'L';
        } else {
          // Countable
          mergedAmount = existingQty + quantity;
          mergedUnit = existingUnit.isNotEmpty ? existingUnit : unit;
        }

        final newQtyStr = formatQuantity(mergedAmount, mergedUnit);
        final updatedItem = existingItem.copyWith(
          quantity: newQtyStr,
          expiryDays: expiryDays ?? existingItem.expiryDays,
        );

        if (!forceInMemoryForTesting &&
            AuthService.instance.isAuthenticated &&
            AuthService.instance.currentUser != null &&
            existingItem.id.isNotEmpty &&
            !existingItem.id.startsWith('item_') &&
            !existingItem.id.startsWith('food_') &&
            !existingItem.id.startsWith('dairy_')) {
          FridgeInventoryRepository.instance.updateItem(
            id: existingItem.id,
            quantity: mergedAmount,
            unit: mergedUnit,
            expiryDate: updatedItem.expiryDate,
            expiryDays: updatedItem.expiryDays,
          ).catchError((e) {
            debugPrint('[FridgeCategoryRepository] Failed to persist merged item: $e');
            return updatedItem;
          });
        }

        final catList = _categoryStore[foundCategory]!;
        final idx = catList.indexWhere((it) => it.id == existingItem!.id);
        if (idx != -1) {
          catList[idx] = updatedItem;
        }

        NotificationRepository.addNotification(
          title: 'Inventory update',
          description: 'Updated ${updatedItem.name} quantity to $newQtyStr.',
          type: NotificationType.inventoryUpdate,
        );
        _notify();
        return updatedItem;
      }
    }

    // 3. Brand new item (or incompatible unit)
    final resolvedImage = (imageAsset != null &&
            imageAsset.isNotEmpty &&
            !imageAsset.contains('categories/vegetables') &&
            !imageAsset.contains('categories/fruits') &&
            !imageAsset.contains('categories/dairy_products') &&
            !imageAsset.contains('categories/non_veg') &&
            !imageAsset.contains('categories/leftovers') &&
            !imageAsset.contains('categories/packaged_food') &&
            !imageAsset.contains('categories/juices') &&
            !imageAsset.contains('categories/ice_cream') &&
            !imageAsset.contains('categories/frozen_food') &&
            !imageAsset.contains('categories/dry_fruits') &&
            !imageAsset.contains('categories/others'))
        ? imageAsset
        : FoodItemAssetRegistry.getAssetForItem(name, canonicalName);

    final cleanQtyStr = formatQuantity(quantity, unit);
    final newItem = CategoryFoodItem(
      id: 'item_${DateTime.now().millisecondsSinceEpoch}_${name.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}',
      name: name,
      quantity: cleanQtyStr,
      expiryDays: expiryDays,
      imageAsset: resolvedImage,
      category: canonicalName,
    );

    final list = _categoryStore.putIfAbsent(canonicalName, () => []);
    list.add(newItem);

    if (!forceInMemoryForTesting &&
        AuthService.instance.isAuthenticated &&
        AuthService.instance.currentUser != null) {
      FridgeInventoryRepository.instance.insertItem(
        name: name,
        category: canonicalName,
        quantity: quantity,
        unit: unit,
        expiryDays: expiryDays,
        imageAsset: resolvedImage,
      ).then((savedItem) {
        final idx = list.indexWhere((it) => it.id == newItem.id);
        if (idx != -1) {
          list[idx] = savedItem;
          _notify();
        }
      }).catchError((e) {
        debugPrint('[FridgeCategoryRepository] Failed to insert new item into Supabase: $e');
      });
    }

    NotificationRepository.addNotification(
      title: 'Inventory update',
      description: '${newItem.name} was added to your fridge.',
      type: NotificationType.inventoryUpdate,
    );
    _notify();
    return newItem;
  }

  /// Add multiple items to categories
  static void addMultipleItems(List<MapEntry<String, CategoryFoodItem>> entries) {
    for (final entry in entries) {
      addItemToCategory(entry.key, entry.value);
    }
  }

  /// Update item quantity in repository
  static Future<void> updateItem(String categoryIdOrName, CategoryFoodItem updatedItem) async {
    final canonicalName = _canonicalizeCategory(categoryIdOrName);

    if (!forceInMemoryForTesting &&
        AuthService.instance.isAuthenticated &&
        AuthService.instance.currentUser != null &&
        updatedItem.id.isNotEmpty &&
        !updatedItem.id.startsWith('item_') &&
        !updatedItem.id.startsWith('food_') &&
        !updatedItem.id.startsWith('dairy_')) {
      await FridgeInventoryRepository.instance.updateItem(
        id: updatedItem.id,
        name: updatedItem.name,
        category: canonicalName,
        quantity: updatedItem.decimalAmount,
        unit: updatedItem.unit,
        expiryDate: updatedItem.expiryDate,
        expiryDays: updatedItem.expiryDays,
        imageAsset: updatedItem.imageAsset,
        storageImagePath: updatedItem.storageImagePath,
      );
    }

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

  /// Remove item from repository
  static Future<void> removeItem(String categoryIdOrName, String itemId) async {
    final canonicalName = _canonicalizeCategory(categoryIdOrName);

    if (!forceInMemoryForTesting &&
        AuthService.instance.isAuthenticated &&
        AuthService.instance.currentUser != null &&
        itemId.isNotEmpty &&
        !itemId.startsWith('item_') &&
        !itemId.startsWith('food_') &&
        !itemId.startsWith('dairy_') &&
        !itemId.startsWith('veg_')) {
      await FridgeInventoryRepository.instance.deleteItem(itemId);
    }

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

  /// Remove an item by its name (exact/plural match first, then substring) across all categories
  static bool removeItemByName(String name) {
    final lower = name.toLowerCase().trim();
    // 1. Exact or plural/singular match
    for (final list in _categoryStore.values) {
      final index = list.indexWhere((it) => isFoodNameMatching(it.name, lower));
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

    // 2. Substring fallback
    for (final list in _categoryStore.values) {
      final index = list.indexWhere((it) {
        final itemLower = it.name.toLowerCase().trim();
        return itemLower.contains(lower) || lower.contains(itemLower);
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

  /// Validates whether a proposed quantity deduction is permissible without mutating state.
  static DeductionResult checkDeduction({
    required CategoryFoodItem item,
    required num quantity,
    String? unit,
  }) {
    if (quantity <= 0) {
      return const DeductionResult(
        status: DeductionStatus.ambiguous,
        message: 'Invalid deduction quantity. Quantity must be greater than zero.',
      );
    }

    final existingUnit = item.unit;
    final deductUnit = unit != null && unit.trim().isNotEmpty ? unit.trim() : existingUnit;

    if (!areUnitsCompatible(existingUnit, deductUnit)) {
      return DeductionResult(
        status: DeductionStatus.incompatibleUnits,
        message: 'Cannot deduct $quantity $deductUnit from ${item.quantity} due to incompatible units.',
      );
    }

    final existingQty = item.decimalAmount;
    final normExisting = normalizeUnit(existingUnit);
    final normDeduct = normalizeUnit(deductUnit);

    num deductInExistingUnit;
    if (normExisting == normDeduct) {
      deductInExistingUnit = quantity;
    } else if (normExisting == 'g' && normDeduct == 'kg') {
      deductInExistingUnit = quantity * 1000;
    } else if (normExisting == 'kg' && normDeduct == 'g') {
      deductInExistingUnit = quantity / 1000;
    } else if (normExisting == 'ml' && normDeduct == 'l') {
      deductInExistingUnit = quantity * 1000;
    } else if (normExisting == 'l' && normDeduct == 'ml') {
      deductInExistingUnit = quantity / 1000;
    } else {
      deductInExistingUnit = quantity;
    }

    final remainingAmount = existingQty - deductInExistingUnit;

    if (remainingAmount < -0.0001) {
      return DeductionResult(
        status: DeductionStatus.overRemoval,
        message: 'You only have ${item.quantity} in your fridge. Please adjust the quantity.',
        remainingQuantity: remainingAmount,
      );
    }

    if (remainingAmount.abs() <= 0.0001 || remainingAmount <= 0) {
      return DeductionResult(
        status: DeductionStatus.removed,
        message: '${item.name} will be completely consumed.',
        remainingQuantity: 0,
        remainingUnit: existingUnit,
      );
    }

    return DeductionResult(
      status: DeductionStatus.success,
      message: 'Can deduct ${formatQuantity(quantity, deductUnit)}.',
      remainingQuantity: remainingAmount,
      remainingUnit: existingUnit,
    );
  }

  /// Deducts a specified quantity from an item in the fridge inventory.
  /// If stock remains, updates the item quantity and preserves all other metadata.
  /// If stock reaches zero, removes the item from the active inventory.
  /// If requested quantity exceeds available stock, rejects the operation.
  static DeductionResult deductItemQuantity({
    String? categoryIdOrName,
    String? itemId,
    String? name,
    required num quantity,
    String? unit,
  }) {
    if (quantity <= 0) {
      return const DeductionResult(
        status: DeductionStatus.ambiguous,
        message: 'Invalid deduction quantity. Quantity must be greater than zero.',
      );
    }

    CategoryFoodItem? targetItem;
    String? targetCategory;
    List<CategoryFoodItem>? targetList;
    int targetIndex = -1;

    // 1. Locate by category and itemId
    if (categoryIdOrName != null && categoryIdOrName.isNotEmpty && itemId != null && itemId.isNotEmpty) {
      final canon = _canonicalizeCategory(categoryIdOrName);
      final list = _categoryStore[canon];
      if (list != null) {
        final idx = list.indexWhere((it) => it.id == itemId);
        if (idx != -1) {
          targetItem = list[idx];
          targetCategory = canon;
          targetList = list;
          targetIndex = idx;
        }
      }
    }

    // 2. Locate by itemId across all categories
    if (targetItem == null && itemId != null && itemId.isNotEmpty) {
      for (final entry in _categoryStore.entries) {
        final idx = entry.value.indexWhere((it) => it.id == itemId);
        if (idx != -1) {
          targetItem = entry.value[idx];
          targetCategory = entry.key;
          targetList = entry.value;
          targetIndex = idx;
          break;
        }
      }
    }

    // 3. Locate by category and food name
    if (targetItem == null && name != null && name.isNotEmpty) {
      if (categoryIdOrName != null && categoryIdOrName.isNotEmpty) {
        final canon = _canonicalizeCategory(categoryIdOrName);
        final list = _categoryStore[canon];
        if (list != null) {
          final idx = list.indexWhere((it) => isFoodNameMatching(it.name, name));
          if (idx != -1) {
            targetItem = list[idx];
            targetCategory = canon;
            targetList = list;
            targetIndex = idx;
          }
        }
      }

      // 4. Locate by food name across all categories
      if (targetItem == null) {
        for (final entry in _categoryStore.entries) {
          final idx = entry.value.indexWhere((it) => isFoodNameMatching(it.name, name));
          if (idx != -1) {
            targetItem = entry.value[idx];
            targetCategory = entry.key;
            targetList = entry.value;
            targetIndex = idx;
            break;
          }
        }
      }
    }

    if (targetItem == null || targetCategory == null || targetList == null || targetIndex == -1) {
      return DeductionResult(
        status: DeductionStatus.notFound,
        message: 'Item "${name ?? itemId ?? 'Unknown'}" was not found in your fridge.',
      );
    }

    final existingUnit = targetItem.unit;
    final deductUnit = unit != null && unit.trim().isNotEmpty ? unit.trim() : existingUnit;

    if (!areUnitsCompatible(existingUnit, deductUnit)) {
      return DeductionResult(
        status: DeductionStatus.incompatibleUnits,
        message: 'Cannot deduct $quantity $deductUnit from ${targetItem.quantity} due to incompatible units.',
      );
    }

    final existingQty = targetItem.decimalAmount;
    final normExisting = normalizeUnit(existingUnit);
    final normDeduct = normalizeUnit(deductUnit);

    num deductInExistingUnit;
    if (normExisting == normDeduct) {
      deductInExistingUnit = quantity;
    } else if (normExisting == 'g' && normDeduct == 'kg') {
      deductInExistingUnit = quantity * 1000;
    } else if (normExisting == 'kg' && normDeduct == 'g') {
      deductInExistingUnit = quantity / 1000;
    } else if (normExisting == 'ml' && normDeduct == 'l') {
      deductInExistingUnit = quantity * 1000;
    } else if (normExisting == 'l' && normDeduct == 'ml') {
      deductInExistingUnit = quantity / 1000;
    } else {
      deductInExistingUnit = quantity;
    }

    final remainingAmount = existingQty - deductInExistingUnit;

    // Over-removal check
    if (remainingAmount < -0.0001) {
      return DeductionResult(
        status: DeductionStatus.overRemoval,
        message: 'You only have ${targetItem.quantity} in your fridge. Please adjust the quantity.',
        remainingQuantity: remainingAmount,
      );
    }

    // Zero remaining: remove completely from active inventory
    if (remainingAmount.abs() <= 0.0001 || remainingAmount <= 0) {
      final removed = targetList.removeAt(targetIndex);
      NotificationRepository.addNotification(
        title: 'Inventory update',
        description: '${removed.name} was removed from your fridge.',
        type: NotificationType.inventoryUpdate,
      );
      _notify();

      return DeductionResult(
        status: DeductionStatus.removed,
        message: '${targetItem.name} has been completely consumed and removed from your fridge.',
        remainingQuantity: 0,
        remainingUnit: existingUnit,
      );
    }

    // Partial deduction: subtract quantity and update item in-place
    final newQtyStr = formatQuantity(remainingAmount, existingUnit);
    final updatedItem = targetItem.copyWith(quantity: newQtyStr);
    targetList[targetIndex] = updatedItem;

    NotificationRepository.addNotification(
      title: 'Inventory update',
      description: 'Used ${formatQuantity(quantity, deductUnit)} of ${targetItem.name}. $newQtyStr remaining.',
      type: NotificationType.inventoryUpdate,
    );
    _notify();

    return DeductionResult(
      status: DeductionStatus.success,
      message: 'Deducted ${formatQuantity(quantity, deductUnit)} of ${targetItem.name}. $newQtyStr remaining.',
      updatedItem: updatedItem,
      remainingQuantity: remainingAmount,
      remainingUnit: existingUnit,
    );
  }

  /// Convenience helper to deduct by item name across all categories
  static DeductionResult deductItemQuantityByName({
    required String name,
    required num quantity,
    String? unit,
  }) {
    return deductItemQuantity(
      name: name,
      quantity: quantity,
      unit: unit,
    );
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
