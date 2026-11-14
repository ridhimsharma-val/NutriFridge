import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/supabase_client.dart';
import '../../screens/fridge/models/category_item.dart';
import '../auth/auth_service.dart';

/// Database repository for managing user's fridge inventory in `public.fridge_items`.
class FridgeInventoryRepository {
  final SupabaseClient? _customClient;
  final AuthService? _customAuthService;

  FridgeInventoryRepository({
    SupabaseClient? client,
    AuthService? authService,
  })  : _customClient = client,
        _customAuthService = authService;

  static final FridgeInventoryRepository instance = FridgeInventoryRepository();

  SupabaseClient get _client {
    if (_customClient != null) return _customClient;
    return SupabaseManager.client;
  }

  AuthService get _authService => _customAuthService ?? AuthService.instance;

  String? get _currentUserId => _authService.currentUser?.id;

  /// Formats DateTime as PostgreSQL DATE string (YYYY-MM-DD).
  static String? formatDate(DateTime? date) {
    if (date == null) return null;
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Parses PostgreSQL DATE string into DateTime.
  static DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final str = value.toString().trim();
    if (str.isEmpty) return null;
    return DateTime.tryParse(str);
  }

  /// Fetches all inventory items belonging to the authenticated user.
  Future<List<CategoryFoodItem>> fetchItems({String? userId}) async {
    final effectiveUserId = userId ?? _currentUserId;
    if (effectiveUserId == null) {
      throw StateError('Cannot fetch inventory: User is not authenticated.');
    }

    final response = await _client
        .from('fridge_items')
        .select()
        .eq('user_id', effectiveUserId)
        .order('created_at', ascending: false);

    final List<dynamic> data = response as List<dynamic>;
    return data.map((row) {
      final map = row as Map<String, dynamic>;
      return mapRowToItem(map);
    }).toList();
  }

  /// Adds a new inventory item to `public.fridge_items`.
  Future<CategoryFoodItem> insertItem({
    required String name,
    required String category,
    required num quantity,
    required String unit,
    DateTime? expiryDate,
    int? expiryDays,
    String? imageAsset,
    String? storageImagePath,
    String? userId,
  }) async {
    final effectiveUserId = userId ?? _currentUserId;
    if (effectiveUserId == null) {
      throw StateError('Cannot add inventory item: User is not authenticated.');
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Item name cannot be empty.');
    }

    if (quantity < 0) {
      throw ArgumentError('Inventory quantity cannot be negative.');
    }

    final canonicalCategory = FridgeCategoryRepository.canonicalizeCategory(category);
    final cleanUnit = unit.trim().isNotEmpty ? unit.trim() : 'pieces';

    DateTime? effectiveExpiryDate = expiryDate;
    if (effectiveExpiryDate == null && expiryDays != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      effectiveExpiryDate = today.add(Duration(days: expiryDays));
    }

    final resolvedImage = (imageAsset != null &&
            imageAsset.isNotEmpty &&
            !imageAsset.contains('categories/'))
        ? imageAsset
        : FoodItemAssetRegistry.getAssetForItem(trimmedName, canonicalCategory);

    final row = buildInsertRow(
      userId: effectiveUserId,
      name: trimmedName,
      category: canonicalCategory,
      quantity: quantity,
      unit: cleanUnit,
      expiryDate: effectiveExpiryDate,
      imageAsset: resolvedImage,
      storageImagePath: storageImagePath,
    );

    final response = await _client
        .from('fridge_items')
        .insert(row)
        .select()
        .single();

    return mapRowToItem(response);
  }

  /// Builds an insert map for Supabase, validating non-empty name and non-negative quantity.
  static Map<String, dynamic> buildInsertRow({
    required String userId,
    required String name,
    required String category,
    required num quantity,
    required String unit,
    DateTime? expiryDate,
    int? expiryDays,
    String? imageAsset,
    String? storageImagePath,
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Item name cannot be empty.');
    }

    if (quantity < 0) {
      throw ArgumentError('Inventory quantity cannot be negative.');
    }

    final canonicalCategory = FridgeCategoryRepository.canonicalizeCategory(category);
    final cleanUnit = unit.trim().isNotEmpty ? unit.trim() : 'pieces';

    DateTime? effectiveExpiryDate = expiryDate;
    if (effectiveExpiryDate == null && expiryDays != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      effectiveExpiryDate = today.add(Duration(days: expiryDays));
    }

    final resolvedImage = (imageAsset != null &&
            imageAsset.isNotEmpty &&
            !imageAsset.contains('categories/'))
        ? imageAsset
        : FoodItemAssetRegistry.getAssetForItem(trimmedName, canonicalCategory);

    final row = <String, dynamic>{
      'user_id': userId,
      'name': trimmedName,
      'category': canonicalCategory,
      'quantity': quantity,
      'unit': cleanUnit,
      'expiry_date': formatDate(effectiveExpiryDate),
      'image_asset': resolvedImage,
    };
    if (storageImagePath != null) {
      row['storage_image_path'] = storageImagePath;
    }
    return row;
  }

  /// Updates an existing item in `public.fridge_items`.
  Future<CategoryFoodItem> updateItem({
    required String id,
    String? name,
    String? category,
    num? quantity,
    String? unit,
    DateTime? expiryDate,
    int? expiryDays,
    bool clearExpiryDate = false,
    String? imageAsset,
    String? storageImagePath,
    String? userId,
  }) async {
    final effectiveUserId = userId ?? _currentUserId;
    if (effectiveUserId == null) {
      throw StateError('Cannot update inventory item: User is not authenticated.');
    }

    if (quantity != null && quantity < 0) {
      throw ArgumentError('Inventory quantity cannot be negative.');
    }

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (name != null) {
      final trimmedName = name.trim();
      if (trimmedName.isEmpty) {
        throw ArgumentError('Item name cannot be empty.');
      }
      updates['name'] = trimmedName;
    }

    if (category != null) {
      updates['category'] = FridgeCategoryRepository.canonicalizeCategory(category);
    }

    if (quantity != null) {
      updates['quantity'] = quantity;
    }

    if (unit != null) {
      updates['unit'] = unit.trim().isNotEmpty ? unit.trim() : 'pieces';
    }

    if (clearExpiryDate) {
      updates['expiry_date'] = null;
    } else if (expiryDate != null) {
      updates['expiry_date'] = formatDate(expiryDate);
    } else if (expiryDays != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      updates['expiry_date'] = formatDate(today.add(Duration(days: expiryDays)));
    }

    if (imageAsset != null) {
      updates['image_asset'] = imageAsset;
    }

    if (storageImagePath != null) {
      updates['storage_image_path'] = storageImagePath;
    }

    final response = await _client
        .from('fridge_items')
        .update(updates)
        .eq('id', id)
        .eq('user_id', effectiveUserId)
        .select()
        .single();

    return mapRowToItem(response);
  }

  /// Deletes an inventory item from `public.fridge_items`.
  Future<void> deleteItem(String id, {String? userId}) async {
    final effectiveUserId = userId ?? _currentUserId;
    if (effectiveUserId == null) {
      throw StateError('Cannot delete inventory item: User is not authenticated.');
    }

    await _client
        .from('fridge_items')
        .delete()
        .eq('id', id)
        .eq('user_id', effectiveUserId);
  }

  /// Deletes all expired inventory items belonging to the authenticated user from `public.fridge_items`.
  ///
  /// Criteria:
  /// - Only items where `expiry_date < local_today_date` are deleted.
  /// - Items expiring today, in the future, or with missing expiry are safely preserved.
  /// - Respects user boundaries and multi-batch inventory records.
  Future<int> deleteExpiredItems({String? userId, DateTime? localNow}) async {
    final effectiveUserId = userId ?? _currentUserId;
    if (effectiveUserId == null) {
      throw StateError('Cannot delete expired inventory: User is not authenticated.');
    }

    final today = localNow ?? DateTime.now();
    final todayDateStr = formatDate(today);
    if (todayDateStr == null) return 0;

    final response = await _client
        .from('fridge_items')
        .delete()
        .eq('user_id', effectiveUserId)
        .lt('expiry_date', todayDateStr)
        .select('id');

    final List<dynamic> deleted = response as List<dynamic>;
    return deleted.length;
  }

  /// Maps a PostgreSQL database row map into [CategoryFoodItem].
  static CategoryFoodItem mapRowToItem(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final name = row['name']?.toString() ?? '';
    final num quantityNum = (row['quantity'] as num?) ?? 1;
    final unit = row['unit']?.toString() ?? 'pieces';
    final category = row['category']?.toString();
    final imageAsset = row['image_asset']?.toString();
    final storageImagePath = row['storage_image_path']?.toString();

    DateTime? expiryDate;
    if (row['expiry_date'] != null) {
      expiryDate = parseDate(row['expiry_date']);
    }

    int? expiryDays;
    if (expiryDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
      expiryDays = target.difference(today).inDays;
    }

    final quantityStr = FridgeCategoryRepository.formatQuantity(quantityNum, unit);
    final resolvedImage = (imageAsset != null && imageAsset.isNotEmpty)
        ? imageAsset
        : FoodItemAssetRegistry.getAssetForItem(name, category ?? 'Others');

    return CategoryFoodItem(
      id: id,
      name: name,
      quantity: quantityStr,
      expiryDays: expiryDays,
      expiryDate: expiryDate,
      imageAsset: resolvedImage,
      storageImagePath: storageImagePath,
      category: category,
      iconEmoji: FoodItemAssetRegistry.getEmojiForItem(name, category),
    );
  }
}
