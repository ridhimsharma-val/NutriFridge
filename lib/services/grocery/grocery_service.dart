import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/supabase_client.dart';
import '../../models/grocery_item.dart';
import '../../screens/fridge/models/category_item.dart';
import '../auth/auth_service.dart';
import '../inventory/fridge_inventory_repository.dart';

/// Result type returned when attempting to add an item that may already exist.
enum GroceryAddResultType {
  added,
  updatedExisting,
  duplicateFound,
  error,
}

class GroceryAddResult {
  final GroceryAddResultType type;
  final GroceryItem? item;
  final GroceryItem? existingDuplicate;
  final String? errorMessage;

  const GroceryAddResult({
    required this.type,
    this.item,
    this.existingDuplicate,
    this.errorMessage,
  });

  bool get isSuccess =>
      type == GroceryAddResultType.added ||
      type == GroceryAddResultType.updatedExisting;

  String get id => item?.id ?? '';
  String get name => item?.name ?? '';
  double get quantity => item?.quantity ?? 0.0;
  String get unit => item?.unit ?? '';
  String get category => item?.category ?? '';
  bool get isPurchased => item?.isPurchased ?? false;
}

/// Result of transferring purchased grocery items to active fridge inventory.
class GroceryTransferResult {
  final int totalRequested;
  final int transferredCount;
  final int failedCount;
  final List<GroceryItem> transferredItems;
  final List<GroceryItem> failedItems;
  final String? errorMessage;

  const GroceryTransferResult({
    required this.totalRequested,
    required this.transferredCount,
    required this.failedCount,
    this.transferredItems = const [],
    this.failedItems = const [],
    this.errorMessage,
  });

  bool get isFullSuccess => failedCount == 0 && transferredCount > 0;
  bool get isPartialSuccess => transferredCount > 0 && failedCount > 0;
  bool get isFailure => transferredCount == 0;
}

/// Central database service for managing the user's Grocery Shopping List.
///
/// Features:
/// - Supabase primary persistence with user-scoped Row-Level Security (`public.grocery_items`).
/// - Resilient offline caching via SharedPreferences.
/// - Duplicate item detection and quantity consolidation.
/// - Transfer of completed items into Fridge inventory.
/// - Reactive state management via [groceryItemsNotifier].
class GroceryService {
  final SupabaseClient? _customClient;
  final AuthService? _customAuthService;

  GroceryService({
    SupabaseClient? client,
    AuthService? authService,
  })  : _customClient = client,
        _customAuthService = authService;

  static final GroceryService instance = GroceryService();

  SupabaseClient? get _client {
    if (_customClient != null) return _customClient;
    if (SupabaseManager.isInitialized) {
      try {
        return SupabaseManager.client;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static int _idCounter = 0;

  AuthService get _authService => _customAuthService ?? AuthService.instance;

  static const String _kStoragePrefix = 'nutrifridge_grocery_items_';

  final ValueNotifier<List<GroceryItem>> _groceryItemsNotifier =
      ValueNotifier<List<GroceryItem>>(<GroceryItem>[]);

  /// Reactive notifier for widgets observing grocery list state.
  ValueListenable<List<GroceryItem>> get groceryItemsNotifier =>
      _groceryItemsNotifier;

  /// Current in-memory list of grocery items.
  List<GroceryItem> get currentItems =>
      List<GroceryItem>.unmodifiable(_groceryItemsNotifier.value);

  /// All unpurchased (pending) grocery items.
  List<GroceryItem> get pendingItems =>
      _groceryItemsNotifier.value.where((item) => !item.isPurchased).toList();

  /// Completed items that have not yet been transferred into the fridge (eligible for transfer).
  List<GroceryItem> get completedItems =>
      _groceryItemsNotifier.value.where((item) => item.isPurchased && !item.isTransferred).toList();

  /// All completed items preserving shopping completion history.
  List<GroceryItem> get allCompletedItems =>
      _groceryItemsNotifier.value.where((item) => item.isPurchased).toList();

  /// Items that have already been transferred into the fridge.
  List<GroceryItem> get transferredItems =>
      _groceryItemsNotifier.value.where((item) => item.isTransferred).toList();

  /// Items currently eligible to be transferred to fridge inventory.
  List<GroceryItem> get eligibleForTransfer => completedItems;

  int get pendingCount => pendingItems.length;
  int get completedCount => completedItems.length;
  int get allCompletedCount => allCompletedItems.length;
  int get eligibleTransferCount => eligibleForTransfer.length;
  int get totalCount => _groceryItemsNotifier.value.length;

  /// Overall completion progress between 0.0 and 1.0 based on total shopping completion.
  double get progress {
    if (totalCount == 0) return 0.0;
    return (allCompletedItems.length / totalCount).clamp(0.0, 1.0);
  }

  bool _initialized = false;
  String? _lastLoadedUserId;
  bool _isTransferringToFridge = false;

  @visibleForTesting
  bool simulateNetworkError = false;

  @visibleForTesting
  bool simulateFridgeInventoryError = false;

  @visibleForTesting
  Map<String, List<Map<String, dynamic>>>? mockSupabaseTable;

  @visibleForTesting
  String? testUserIdOverride;

  @visibleForTesting
  void resetTestingState() {
    simulateNetworkError = false;
    simulateFridgeInventoryError = false;
    mockSupabaseTable = null;
    testUserIdOverride = null;
    _inMemoryStore.clear();
    _groceryItemsNotifier.value = [];
    _initialized = false;
    _lastLoadedUserId = null;
    _isTransferringToFridge = false;
  }

  final Map<String, List<GroceryItem>> _inMemoryStore = {};

  String get effectiveUserId {
    if (testUserIdOverride != null) return testUserIdOverride!;
    try {
      final user = _authService.currentUser;
      if (user != null && user.id.isNotEmpty) {
        return user.id;
      }
    } catch (_) {}
    return 'local_user';
  }

  String _storageKey(String userId) => '$_kStoragePrefix$userId';

  /// Initializes and loads grocery items for the specified or active user.
  Future<void> init({String? userId, bool forceReload = false}) async {
    final targetUserId = userId ?? effectiveUserId;
    if (_initialized && _lastLoadedUserId == targetUserId && !forceReload) {
      return;
    }
    await loadItems(userId: targetUserId);
    _initialized = true;
    _lastLoadedUserId = targetUserId;
  }

  /// Alias for [init]
  Future<void> initialize({String? userId, bool forceReload = false}) =>
      init(userId: userId, forceReload: forceReload);

  /// Loads grocery items from Supabase (or fallback local cache).
  Future<List<GroceryItem>> loadItems({String? userId}) async {
    final targetUserId = userId ?? effectiveUserId;
    final list = await getItemsForUser(targetUserId);
    if (userId != null || targetUserId == effectiveUserId) {
      _groceryItemsNotifier.value = List<GroceryItem>.from(list);
    }
    return list;
  }

  /// Alias for [loadItems]
  Future<List<GroceryItem>> fetchGroceryItems({String? userId, bool forceReload = false}) =>
      loadItems(userId: userId);

  /// Convenience method: adds an item with duplicate checking enabled.
  Future<GroceryAddResult> addWithDuplicateCheck({
    required String name,
    double quantity = 1.0,
    String unit = 'pieces',
    String? category,
    String? userId,
  }) =>
      addItem(
        name: name,
        quantity: quantity,
        unit: unit,
        category: category,
        checkDuplicate: true,
        userId: userId,
      );

  /// Convenience method: adds an item forcing a separate entry even if duplicate.
  Future<GroceryAddResult> forceAddItem({
    required String name,
    double quantity = 1.0,
    String unit = 'pieces',
    String? category,
    String? userId,
  }) =>
      addItem(
        name: name,
        quantity: quantity,
        unit: unit,
        category: category,
        checkDuplicate: false,
        userId: userId,
      );

  /// Increases the quantity of an existing item by [additionalQty].
  Future<bool> increaseItemQuantity(
    String itemId,
    double additionalQty, {
    String? userId,
  }) async {
    final targetUserId = userId ?? effectiveUserId;
    final userList = await getItemsForUser(targetUserId);
    final index = userList.indexWhere((it) => it.id == itemId);
    if (index == -1) return false;
    final existing = userList[index];
    final updated = existing.copyWith(
      quantity: existing.quantity + additionalQty,
      updatedAt: DateTime.now(),
    );
    return updateItem(updated, userId: targetUserId);
  }

  /// Retrieves items belonging to a specific user.
  Future<List<GroceryItem>> getItemsForUser(String userId) async {
    // 1. Mock table for tests
    if (mockSupabaseTable != null && userId != 'local_user') {
      if (simulateNetworkError) {
        return _loadFromLocalStorage(userId);
      }
      final table = mockSupabaseTable!['grocery_items'] ?? [];
      final userRows = table.where((row) => row['user_id'] == userId).toList();
      final items = userRows.map((r) => GroceryItem.fromSupabaseRow(r)).toList();
      await _persistToLocalStorage(userId, items);
      return items;
    }

    // 2. Production Supabase client
    final client = _client;
    if (client != null && userId != 'local_user') {
      try {
        if (simulateNetworkError) {
          throw StateError('Simulated network error');
        }

        final response = await client
            .from('grocery_items')
            .select()
            .eq('user_id', userId)
            .order('is_purchased', ascending: true)
            .order('created_at', ascending: false);

        final List<dynamic> data = response as List<dynamic>;
        final items = data
            .map((row) => GroceryItem.fromSupabaseRow(Map<String, dynamic>.from(row as Map)))
            .toList();

        await _persistToLocalStorage(userId, items);
        return items;
      } catch (e) {
        debugPrint('[GroceryService] Supabase load error: $e. Falling back to local cache.');
        return _loadFromLocalStorage(userId);
      }
    }

    // 3. Fallback to local storage (unauthenticated or offline)
    return _loadFromLocalStorage(userId);
  }

  /// Adds a new grocery item with input validation and duplicate detection.
  Future<GroceryAddResult> addItem({
    required String name,
    double quantity = 1.0,
    String unit = 'pieces',
    String? category,
    bool checkDuplicate = true,
    bool increaseIfDuplicate = false,
    String? userId,
  }) async {
    final targetUserId = userId ?? effectiveUserId;
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      return const GroceryAddResult(
        type: GroceryAddResultType.error,
        errorMessage: 'Item name cannot be empty.',
      );
    }

    if (quantity <= 0) {
      return const GroceryAddResult(
        type: GroceryAddResultType.error,
        errorMessage: 'Quantity must be greater than zero.',
      );
    }

    final resolvedCategory = category ?? GroceryCategoryResolver.resolveCategory(cleanName);
    final cleanUnit = unit.trim().isNotEmpty ? unit.trim().toLowerCase() : 'pieces';

    final userList = await getItemsForUser(targetUserId);

    // Duplicate detection: same normalized name and compatible unit in pending items
    final existingIndex = userList.indexWhere((it) {
      if (it.isPurchased) return false;
      final sameName = it.name.trim().toLowerCase() == cleanName.toLowerCase();
      final sameUnit = it.unit.trim().toLowerCase() == cleanUnit;
      return sameName && sameUnit;
    });

    if (existingIndex != -1) {
      final existing = userList[existingIndex];
      if (checkDuplicate && !increaseIfDuplicate) {
        return GroceryAddResult(
          type: GroceryAddResultType.duplicateFound,
          existingDuplicate: existing,
        );
      }

      if (increaseIfDuplicate) {
        final updated = existing.copyWith(
          quantity: existing.quantity + quantity,
          updatedAt: DateTime.now(),
        );
        final success = await updateItem(updated, userId: targetUserId);
        if (success) {
          return GroceryAddResult(
            type: GroceryAddResultType.updatedExisting,
            item: updated,
          );
        } else {
          return const GroceryAddResult(
            type: GroceryAddResultType.error,
            errorMessage: 'Failed to update existing item quantity.',
          );
        }
      }
    }

    final now = DateTime.now();
    final newItem = GroceryItem(
      id: 'item_${now.microsecondsSinceEpoch}_${_idCounter++}',
      userId: targetUserId,
      name: cleanName,
      quantity: quantity,
      unit: cleanUnit,
      category: resolvedCategory,
      isPurchased: false,
      createdAt: now,
      updatedAt: now,
    );

    final updatedList = [newItem, ...userList];

    // 1. Mock table for tests
    if (mockSupabaseTable != null && targetUserId != 'local_user') {
      if (simulateNetworkError) {
        return const GroceryAddResult(
          type: GroceryAddResultType.error,
          errorMessage: 'Simulated network failure.',
        );
      }
      final table = mockSupabaseTable!['grocery_items'] ??= [];
      final row = newItem.toSupabaseRow(targetUserId);
      row['id'] = newItem.id;
      row['created_at'] = now.toIso8601String();
      row['updated_at'] = now.toIso8601String();
      table.insert(0, row);

      await _persistToLocalStorage(targetUserId, updatedList);
      if (userId != null || targetUserId == effectiveUserId) {
        _groceryItemsNotifier.value = updatedList;
      }
      return GroceryAddResult(type: GroceryAddResultType.added, item: newItem);
    }

    // 2. Production Supabase client
    final client = _client;
    if (client != null && targetUserId != 'local_user') {
      try {
        if (simulateNetworkError) throw StateError('Simulated network error');

        final row = newItem.toSupabaseRow(targetUserId);
        final response = await client
            .from('grocery_items')
            .insert(row)
            .select()
            .single();

        final persistedItem = GroceryItem.fromSupabaseRow(response);
        final listWithPersisted = [
          persistedItem,
          ...userList.where((it) => it.id != newItem.id),
        ];

        await _persistToLocalStorage(targetUserId, listWithPersisted);
        if (userId != null || targetUserId == effectiveUserId) {
          _groceryItemsNotifier.value = listWithPersisted;
        }
        return GroceryAddResult(type: GroceryAddResultType.added, item: persistedItem);
      } catch (e) {
        debugPrint('[GroceryService] Supabase add error: $e');
        return GroceryAddResult(
          type: GroceryAddResultType.error,
          errorMessage: 'Failed to add item to grocery list: $e',
        );
      }
    }

    // 3. Fallback local persistence
    final success = await _persistToLocalStorage(targetUserId, updatedList);
    if (!success) {
      return const GroceryAddResult(
        type: GroceryAddResultType.error,
        errorMessage: 'Failed to save item locally.',
      );
    }

    if (userId != null || targetUserId == effectiveUserId) {
      _groceryItemsNotifier.value = updatedList;
    }
    return GroceryAddResult(type: GroceryAddResultType.added, item: newItem);
  }

  /// Updates an existing grocery item with optimistic update and rollback on failure.
  Future<bool> updateItem(GroceryItem item, {String? userId}) async {
    final targetUserId = userId ?? effectiveUserId;
    final userList = await getItemsForUser(targetUserId);
    final index = userList.indexWhere((it) => it.id == item.id);
    if (index == -1) return false;

    final previousList = List<GroceryItem>.from(userList);
    final updatedList = List<GroceryItem>.from(userList);
    updatedList[index] = item.copyWith(updatedAt: DateTime.now());

    // 1. Optimistic update to notify UI immediately
    if (userId != null || targetUserId == effectiveUserId) {
      _groceryItemsNotifier.value = updatedList;
    }

    // 2. Mock table for tests
    if (mockSupabaseTable != null && targetUserId != 'local_user') {
      if (simulateNetworkError) {
        // Roll back optimistic update
        if (userId != null || targetUserId == effectiveUserId) {
          _groceryItemsNotifier.value = previousList;
        }
        return false;
      }
      final table = mockSupabaseTable!['grocery_items'] ?? [];
      final rowIdx = table.indexWhere((r) => r['id'] == item.id);
      if (rowIdx != -1) {
        table[rowIdx] = item.toSupabaseRow(targetUserId)
          ..['id'] = item.id
          ..['updated_at'] = DateTime.now().toIso8601String();
      }
      await _persistToLocalStorage(targetUserId, updatedList);
      return true;
    }

    // 3. Production Supabase client
    final client = _client;
    if (client != null && targetUserId != 'local_user') {
      try {
        if (simulateNetworkError) throw StateError('Simulated error');
        await client
            .from('grocery_items')
            .update({
              'name': item.name.trim(),
              'quantity': item.quantity,
              'unit': item.unit,
              'category': item.category,
              'is_purchased': item.isPurchased,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', item.id)
            .eq('user_id', targetUserId);

        await _persistToLocalStorage(targetUserId, updatedList);
        return true;
      } catch (e) {
        debugPrint('[GroceryService] Supabase update error: $e');
        // Roll back optimistic update on network / database failure
        if (userId != null || targetUserId == effectiveUserId) {
          _groceryItemsNotifier.value = previousList;
        }
        return false;
      }
    }

    // 4. Fallback to local storage
    final success = await _persistToLocalStorage(targetUserId, updatedList);
    if (!success) {
      if (userId != null || targetUserId == effectiveUserId) {
        _groceryItemsNotifier.value = previousList;
      }
      return false;
    }
    return true;
  }

  /// Toggles an item's purchased status.
  Future<bool> togglePurchased(String itemId, {String? userId}) async {
    final targetUserId = userId ?? effectiveUserId;
    final userList = await getItemsForUser(targetUserId);
    final item = userList.cast<GroceryItem?>().firstWhere(
          (it) => it?.id == itemId,
          orElse: () => null,
        );
    if (item == null) return false;

    return await updateItem(
      item.copyWith(isPurchased: !item.isPurchased),
      userId: targetUserId,
    );
  }

  /// Removes an individual grocery item.
  Future<bool> deleteItem(String itemId, {String? userId}) async {
    final targetUserId = userId ?? effectiveUserId;
    final userList = await getItemsForUser(targetUserId);
    final updatedList = userList.where((it) => it.id != itemId).toList();

    // 1. Mock table for tests
    if (mockSupabaseTable != null && targetUserId != 'local_user') {
      if (simulateNetworkError) return false;
      final table = mockSupabaseTable!['grocery_items'] ?? [];
      table.removeWhere((r) => r['id'] == itemId && r['user_id'] == targetUserId);
      await _persistToLocalStorage(targetUserId, updatedList);
      if (userId != null || targetUserId == effectiveUserId) {
        _groceryItemsNotifier.value = updatedList;
      }
      return true;
    }

    // 2. Production Supabase client
    final client = _client;
    if (client != null && targetUserId != 'local_user') {
      try {
        if (simulateNetworkError) throw StateError('Simulated error');
        await client
            .from('grocery_items')
            .delete()
            .eq('id', itemId)
            .eq('user_id', targetUserId);

        await _persistToLocalStorage(targetUserId, updatedList);
        if (userId != null || targetUserId == effectiveUserId) {
          _groceryItemsNotifier.value = updatedList;
        }
        return true;
      } catch (e) {
        debugPrint('[GroceryService] Supabase delete error: $e');
        return false;
      }
    }

    // 3. Fallback to local storage
    final success = await _persistToLocalStorage(targetUserId, updatedList);
    if (success && (userId != null || targetUserId == effectiveUserId)) {
      _groceryItemsNotifier.value = updatedList;
    }
    return success;
  }

  /// Clears all purchased/completed grocery items for the user.
  Future<int> clearCompleted({String? userId}) async {
    final targetUserId = userId ?? effectiveUserId;
    final userList = await getItemsForUser(targetUserId);
    final completed = userList.where((it) => it.isPurchased).toList();
    if (completed.isEmpty) return 0;

    final remaining = userList.where((it) => !it.isPurchased).toList();

    // 1. Mock table for tests
    if (mockSupabaseTable != null && targetUserId != 'local_user') {
      if (simulateNetworkError) return 0;
      final table = mockSupabaseTable!['grocery_items'] ?? [];
      table.removeWhere((r) => r['user_id'] == targetUserId && r['is_purchased'] == true);
      await _persistToLocalStorage(targetUserId, remaining);
      if (userId != null || targetUserId == effectiveUserId) {
        _groceryItemsNotifier.value = remaining;
      }
      return completed.length;
    }

    // 2. Production Supabase client
    final client = _client;
    if (client != null && targetUserId != 'local_user') {
      try {
        if (simulateNetworkError) throw StateError('Simulated error');
        await client
            .from('grocery_items')
            .delete()
            .eq('user_id', targetUserId)
            .eq('is_purchased', true);

        await _persistToLocalStorage(targetUserId, remaining);
        if (userId != null || targetUserId == effectiveUserId) {
          _groceryItemsNotifier.value = remaining;
        }
        return completed.length;
      } catch (e) {
        debugPrint('[GroceryService] Supabase clearCompleted error: $e');
        return 0;
      }
    }

    // 3. Fallback to local storage
    final success = await _persistToLocalStorage(targetUserId, remaining);
    if (success && (userId != null || targetUserId == effectiveUserId)) {
      _groceryItemsNotifier.value = remaining;
    }
    return success ? completed.length : 0;
  }

  /// Transfers eligible purchased items to the user's active Fridge Inventory.
  ///
  /// Safe transfer rules:
  /// - Concurrency guard prevents duplicate simultaneous button taps.
  /// - Only un-transferred purchased items are eligible; pending items are NEVER transferred.
  /// - Idempotent transfer strategy tied to item IDs.
  /// - If inventory addition fails, grocery items remain un-transferred for safe retry.
  /// - Successfully transferred items are marked with isTransferred: true and linked to the created inventory record.
  /// - Preserves shopping completion history and updates fridge inventory.
  Future<GroceryTransferResult> transferPurchasedToFridge({
    List<GroceryItem>? itemsToTransfer,
    int? defaultExpiryDays,
    DateTime? customExpiryDate,
    String? userId,
  }) async {
    if (_isTransferringToFridge) {
      debugPrint('[GroceryService] Transfer already in progress; skipping duplicate call.');
      return const GroceryTransferResult(
        totalRequested: 0,
        transferredCount: 0,
        failedCount: 0,
        errorMessage: 'Transfer already in progress.',
      );
    }

    final targetUserId = userId ?? effectiveUserId;
    final candidates = (itemsToTransfer ?? eligibleForTransfer)
        .where((it) => it.isPurchased && !it.isTransferred)
        .toList();

    if (candidates.isEmpty) {
      return const GroceryTransferResult(
        totalRequested: 0,
        transferredCount: 0,
        failedCount: 0,
      );
    }

    _isTransferringToFridge = true;
    final List<GroceryItem> successfullyTransferred = [];
    final List<GroceryItem> failedTransfers = [];

    try {
      final now = DateTime.now();

      for (final item in candidates) {
        // Idempotency: verify item has not already been transferred
        if (item.isTransferred) continue;

        try {
          if (simulateFridgeInventoryError) {
            throw StateError('Simulated fridge inventory error');
          }

          final fridgeCategory = GroceryCategoryResolver.mapToFridgeCategory(
            item.category,
            item.name,
          );

          // Preserve item's existing expiryDate if available, or custom date, or default preset
          final effectiveExpiry = item.expiryDate ??
              customExpiryDate ??
              (defaultExpiryDays != null && defaultExpiryDays > 0
                  ? DateTime(now.year, now.month, now.day).add(Duration(days: defaultExpiryDays))
                  : null);

          String? createdInventoryId;

          if (FridgeCategoryRepository.forceInMemoryForTesting) {
            createdInventoryId = 'fridge_transferred_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';
            final categoryItem = CategoryFoodItem(
              id: createdInventoryId,
              name: item.name,
              quantity: item.displayQuantity,
              category: fridgeCategory,
              expiryDate: effectiveExpiry,
              expiryDays: defaultExpiryDays,
            );
            await FridgeCategoryRepository.addItemToCategory(fridgeCategory, categoryItem);
          } else if (mockSupabaseTable != null && targetUserId != 'local_user') {
            if (simulateNetworkError) throw StateError('Simulated network error');
            createdInventoryId = 'inv_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';
            final fridgeTable = mockSupabaseTable!['fridge_items'] ??= [];
            fridgeTable.add({
              'id': createdInventoryId,
              'user_id': targetUserId,
              'name': item.name,
              'category': fridgeCategory,
              'quantity': item.quantity,
              'unit': item.unit,
              'expiry_date': effectiveExpiry != null ? FridgeInventoryRepository.formatDate(effectiveExpiry) : null,
              'created_at': now.toIso8601String(),
            });
          } else {
            final inserted = await FridgeInventoryRepository.instance.insertItem(
              name: item.name,
              category: fridgeCategory,
              quantity: item.quantity,
              unit: item.unit,
              expiryDate: effectiveExpiry,
              expiryDays: defaultExpiryDays,
              userId: targetUserId != 'local_user' ? targetUserId : null,
            );
            createdInventoryId = inserted.id;
          }

          // Mark item as transferred in grocery list with reference to created inventory record
          final updated = item.copyWith(
            isTransferred: true,
            transferredAt: now,
            inventoryItemId: createdInventoryId,
            expiryDate: effectiveExpiry,
          );
          final updatedSuccess = await updateItem(updated, userId: targetUserId);
          if (updatedSuccess) {
            successfullyTransferred.add(updated);
          } else {
            failedTransfers.add(item);
          }
        } catch (itemErr) {
          debugPrint('[GroceryService] Failed to add ${item.name} to fridge: $itemErr');
          failedTransfers.add(item);
        }
      }

      // Refresh Fridge inventory from Supabase if not in-memory testing
      if (!FridgeCategoryRepository.forceInMemoryForTesting &&
          targetUserId != 'local_user' &&
          mockSupabaseTable == null) {
        try {
          await FridgeCategoryRepository.loadFromSupabase(userId: targetUserId, force: true);
        } catch (refreshErr) {
          debugPrint('[GroceryService] Error refreshing fridge repository: $refreshErr');
        }
      }

      return GroceryTransferResult(
        totalRequested: candidates.length,
        transferredCount: successfullyTransferred.length,
        failedCount: failedTransfers.length,
        transferredItems: successfullyTransferred,
        failedItems: failedTransfers,
      );
    } finally {
      _isTransferringToFridge = false;
    }
  }

  /// Backward-compatible alias returning transferred count as int.
  Future<int> addPurchasedItemsToFridge({
    List<GroceryItem>? itemsToTransfer,
    int? defaultExpiryDays,
    DateTime? customExpiryDate,
    String? userId,
  }) async {
    final result = await transferPurchasedToFridge(
      itemsToTransfer: itemsToTransfer,
      defaultExpiryDays: defaultExpiryDays,
      customExpiryDate: customExpiryDate,
      userId: userId,
    );
    return result.transferredCount;
  }

  Future<List<GroceryItem>> _loadFromLocalStorage(String userId) async {
    if (_inMemoryStore.containsKey(userId)) {
      return List<GroceryItem>.from(_inMemoryStore[userId]!);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey(userId));
      if (raw == null || raw.trim().isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = decoded
            .map((e) => GroceryItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _inMemoryStore[userId] = list;
        return list;
      }
    } catch (_) {}
    return [];
  }

  Future<bool> _persistToLocalStorage(String userId, List<GroceryItem> list) async {
    _inMemoryStore[userId] = List<GroceryItem>.from(list);

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = list.map((item) => item.toJson()).toList();
      final encoded = jsonEncode(jsonList);
      final key = _storageKey(userId);
      return await prefs.setString(key, encoded);
    } catch (e) {
      debugPrint('[GroceryService] Local storage persist error: $e');
      return false;
    }
  }

  /// Clears in-memory data when the user signs out.
  void clearForLogout() {
    _groceryItemsNotifier.value = <GroceryItem>[];
    _lastLoadedUserId = null;
    _initialized = false;
    _inMemoryStore.removeWhere((key, _) => key != 'local_user');
  }

  @visibleForTesting
  void resetForTesting() {
    _groceryItemsNotifier.value = <GroceryItem>[];
    _inMemoryStore.clear();
    mockSupabaseTable = null;
    simulateNetworkError = false;
    testUserIdOverride = null;
    _isTransferringToFridge = false;
    _initialized = false;
    _lastLoadedUserId = null;
  }
}
