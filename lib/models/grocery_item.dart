import '../screens/fridge/models/category_item.dart';

/// Represents an individual item on the user's Grocery Shopping List.
class GroceryItem {
  final String id;
  final String userId;
  final String name;
  final double quantity;
  final String unit;
  final String category;
  final bool isPurchased;
  final bool isTransferred;
  final DateTime? transferredAt;
  final String? inventoryItemId;
  final DateTime? expiryDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GroceryItem({
    required this.id,
    this.userId = '',
    required this.name,
    this.quantity = 1.0,
    this.unit = 'pieces',
    this.category = 'Others',
    this.isPurchased = false,
    this.isTransferred = false,
    this.transferredAt,
    this.inventoryItemId,
    this.expiryDate,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Canonical grocery category groupings (aligned with My Fridge categories).
  static const List<String> canonicalCategories = FridgeCategoryRepository.canonicalCategories;

  /// Common measurement units for grocery items.
  static const List<String> commonUnits = [
    'pieces',
    'kg',
    'grams',
    'litres',
    'millilitres',
    'packs',
    'bottles',
    'dozens',
    'cans',
    'bunches',
  ];

  GroceryItem copyWith({
    String? id,
    String? userId,
    String? name,
    double? quantity,
    String? unit,
    String? category,
    bool? isPurchased,
    bool? isTransferred,
    DateTime? transferredAt,
    String? inventoryItemId,
    DateTime? expiryDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GroceryItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      isPurchased: isPurchased ?? this.isPurchased,
      isTransferred: isTransferred ?? this.isTransferred,
      transferredAt: transferredAt ?? this.transferredAt,
      inventoryItemId: inventoryItemId ?? this.inventoryItemId,
      expiryDate: expiryDate ?? this.expiryDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Formatted quantity display string, e.g. "2 litres" or "1.5 kg".
  String get displayQuantity {
    final formattedQty = (quantity % 1 == 0) ? quantity.toInt().toString() : quantity.toString();
    final cleanUnit = unit.trim().isNotEmpty ? unit.trim() : 'pieces';
    return '$formattedQty $cleanUnit';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'category': category,
      'isPurchased': isPurchased,
      'isTransferred': isTransferred,
      'transferredAt': transferredAt?.toIso8601String(),
      'inventoryItemId': inventoryItemId,
      'expiryDate': expiryDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    return GroceryItem(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? json['user_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: (json['unit'] ?? 'pieces').toString(),
      category: GroceryCategoryResolver.normalizeCategory(
        (json['category'] ?? 'Others').toString(),
        (json['name'] ?? '').toString(),
      ),
      isPurchased: json['isPurchased'] == true || json['is_purchased'] == true,
      isTransferred: json['isTransferred'] == true || json['is_transferred'] == true,
      transferredAt: json['transferredAt'] != null
          ? DateTime.tryParse(json['transferredAt'].toString())
          : (json['transferred_at'] != null
              ? DateTime.tryParse(json['transferred_at'].toString())
              : null),
      inventoryItemId: (json['inventoryItemId'] ?? json['inventory_item_id'])?.toString(),
      expiryDate: json['expiryDate'] != null
          ? DateTime.tryParse(json['expiryDate'].toString())
          : (json['expiry_date'] != null
              ? DateTime.tryParse(json['expiry_date'].toString())
              : null),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : (json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
              : DateTime.now()),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : (json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
              : DateTime.now()),
    );
  }

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Converts item into PostgreSQL row payload for `public.grocery_items`.
  Map<String, dynamic> toSupabaseRow(String userUuid) {
    return {
      if (id.isNotEmpty && _uuidRegex.hasMatch(id)) 'id': id,
      'user_id': userUuid,
      'name': name.trim(),
      'quantity': quantity > 0 ? quantity : 1.0,
      'unit': unit.trim().isNotEmpty ? unit.trim() : 'pieces',
      'category': category,
      'is_purchased': isPurchased,
      'is_transferred': isTransferred,
      if (transferredAt != null) 'transferred_at': transferredAt!.toIso8601String(),
      if (inventoryItemId != null) 'inventory_item_id': inventoryItemId,
      if (expiryDate != null)
        'expiry_date':
            '${expiryDate!.year.toString().padLeft(4, '0')}-${expiryDate!.month.toString().padLeft(2, '0')}-${expiryDate!.day.toString().padLeft(2, '0')}',
    };
  }

  /// Reconstructs item from a `public.grocery_items` database row.
  factory GroceryItem.fromSupabaseRow(Map<String, dynamic> row) {
    return GroceryItem(
      id: (row['id'] ?? '').toString(),
      userId: (row['user_id'] ?? '').toString(),
      name: (row['name'] ?? '').toString(),
      quantity: (row['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: (row['unit'] ?? 'pieces').toString(),
      category: GroceryCategoryResolver.normalizeCategory(
        (row['category'] ?? 'Others').toString(),
        (row['name'] ?? '').toString(),
      ),
      isPurchased: row['is_purchased'] == true,
      isTransferred: row['is_transferred'] == true,
      transferredAt: row['transferred_at'] != null
          ? DateTime.tryParse(row['transferred_at'].toString())
          : null,
      inventoryItemId: row['inventory_item_id']?.toString(),
      expiryDate: row['expiry_date'] != null
          ? DateTime.tryParse(row['expiry_date'].toString())
          : null,
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Automatic category classifier for grocery shopping items aligned with My Fridge categories.
class GroceryCategoryResolver {
  static const Map<String, List<String>> _keywords = {
    'Drinks & Juices': [
      'orange juice', 'apple juice', 'fruit juice', 'lemon juice',
      'coffee', 'tea', 'juice', 'soda', 'water', 'sparkling water', 'beer',
      'wine', 'smoothie', 'kombucha', 'coke', 'drink', 'beverage', 'lemonade',
      'espresso', 'latte', 'cider', 'shake', 'cold drink',
    ],
    'Dairy Products': [
      'milk', 'curd', 'yogurt', 'yoghurt', 'paneer', 'cheese', 'butter', 'cream',
      'ghee', 'cheddar', 'mozzarella', 'parmesan', 'tofu', 'dairy',
    ],
    'Vegetables': [
      'spinach', 'tomato', 'potato', 'onion', 'carrot', 'garlic', 'ginger', 'lettuce',
      'cucumber', 'broccoli', 'pepper', 'capsicum', 'cilantro', 'mint', 'coriander',
      'basil', 'mushroom', 'cauliflower', 'cabbage', 'peas', 'corn', 'brinjal',
      'eggplant', 'zucchini', 'beetroot', 'pumpkin', 'chilli', 'chili', 'beans',
      'vegetable', 'veggie', 'kale', 'celery', 'radish', 'okra', 'ladyfinger',
    ],
    'Fruits': [
      'apple', 'banana', 'orange', 'mango', 'grape', 'grapes', 'strawberry', 'strawberries',
      'watermelon', 'papaya', 'pineapple', 'lemon', 'lime', 'berry', 'berries', 'avocado',
      'blueberry', 'blueberries', 'raspberry', 'raspberries', 'peach', 'plum', 'pear',
      'kiwi', 'cherry', 'cherries', 'fruit', 'guava', 'pomegranate', 'melon', 'apricot',
    ],
    'Non-Veg': [
      'chicken', 'fish', 'beef', 'mutton', 'pork', 'shrimp', 'salmon', 'tuna',
      'bacon', 'turkey', 'lamb', 'prawn', 'prawns', 'meat', 'sausage', 'egg', 'eggs',
      'crab', 'lobster', 'ham',
    ],
    'Meals & Leftovers': [
      'leftover', 'leftovers', 'curry', 'soup', 'salad', 'sabji', 'stew', 'gravy',
      'meal', 'pasta bake', 'casserole', 'cooked',
    ],
    'Packaged Food': [
      'bread', 'bagel', 'croissant', 'bun', 'buns', 'pita', 'tortilla',
      'muffin', 'toast', 'baguette', 'loaf', 'cake', 'biscuit', 'cookie', 'cookies',
      'rice', 'flour', 'atta', 'wheat', 'oats', 'pasta', 'noodle', 'noodles',
      'quinoa', 'lentil', 'lentils', 'dal', 'chickpea', 'chickpeas', 'oil',
      'olive oil', 'salt', 'sugar', 'spice', 'spices', 'turmeric', 'cumin',
      'cereal', 'chip', 'chips', 'snack', 'canned', 'sauce', 'ketchup', 'mayo', 'mayonnaise',
      'jam', 'peanut butter', 'honey', 'vinegar',
    ],
    'Ice Cream': [
      'ice cream', 'icecream', 'gelato', 'sorbet', 'popsicle', 'sundae',
    ],
    'Frozen Food': [
      'frozen', 'frozen peas', 'frozen corn', 'frozen fries', 'nuggets',
    ],
    'Dry Fruits': [
      'almond', 'almonds', 'cashew', 'cashews', 'walnut', 'walnuts', 'raisin', 'raisins',
      'pistachio', 'pistachios', 'dates', 'dry fruit', 'nuts', 'peanut', 'peanuts',
    ],
  };

  /// Normalizes any category string (including legacy ones) to canonical Fridge categories.
  static String normalizeCategory(String category, [String itemName = '']) {
    final trimmed = category.trim();
    if (trimmed.isEmpty) return 'Others';

    // Direct match with canonical categories
    for (final canonical in FridgeCategoryRepository.canonicalCategories) {
      if (canonical.toLowerCase() == trimmed.toLowerCase()) {
        return canonical;
      }
    }

    final lowerName = itemName.toLowerCase();
    final lowerCat = trimmed.toLowerCase();

    // Legacy Grocery List category migration
    if (lowerCat.contains('fruit') && lowerCat.contains('veg')) {
      const fruits = [
        'apple', 'banana', 'orange', 'mango', 'grape', 'strawberry', 'strawberries',
        'watermelon', 'papaya', 'pineapple', 'lemon', 'lime', 'berry', 'berries',
        'avocado', 'blueberry', 'blueberries', 'raspberry', 'raspberries', 'peach',
        'plum', 'pear', 'kiwi', 'cherry', 'cherries', 'guava', 'melon'
      ];
      for (final f in fruits) {
        if (lowerName.contains(f)) return 'Fruits';
      }
      return 'Vegetables';
    }

    if (lowerCat.contains('dairy') && lowerCat.contains('egg')) {
      return 'Dairy Products';
    }

    if (lowerCat.contains('meat') || lowerCat.contains('seafood')) {
      return 'Non-Veg';
    }

    if (lowerCat.contains('beverage') || lowerCat.contains('drink') || lowerCat.contains('juice')) {
      return 'Drinks & Juices';
    }

    if (lowerCat.contains('bakery') || lowerCat.contains('grain') || lowerCat.contains('staple')) {
      return 'Packaged Food';
    }

    return FridgeCategoryRepository.canonicalizeCategory(trimmed);
  }

  /// Resolves the canonical category based on item name keywords using word-boundary matching.
  /// Defaults cleanly to 'Others' if uncertain.
  static String resolveCategory(String itemName) {
    final lower = itemName.trim().toLowerCase();
    if (lower.isEmpty) return 'Others';

    for (final entry in _keywords.entries) {
      for (final keyword in entry.value) {
        final regex = RegExp(r'\b' + RegExp.escape(keyword) + r'\b');
        if (regex.hasMatch(lower)) {
          return entry.key;
        }
      }
    }
    return 'Others';
  }

  /// Maps a grocery category to the corresponding Fridge category in `FridgeCategoryRepository`.
  static String mapToFridgeCategory(String groceryCategory, String itemName) {
    return normalizeCategory(groceryCategory, itemName);
  }
}
