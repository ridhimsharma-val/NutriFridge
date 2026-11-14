import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/supabase_client.dart';
import '../../models/nutrition_data.dart';
import '../auth/auth_service.dart';

/// Central database service for managing bookmarked recipes in `public.saved_recipes`.
///
/// Guarantees that saved recipe snapshots are stored with complete ingredient,
/// instruction, timing, and nutrition fidelity, and can be retrieved without
/// triggering Gemini or network regeneration.
class SavedRecipesService {
  final SupabaseClient? _customClient;
  final AuthService? _customAuthService;

  SavedRecipesService({
    SupabaseClient? client,
    AuthService? authService,
  })  : _customClient = client,
        _customAuthService = authService;

  static final SavedRecipesService instance = SavedRecipesService();

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

  AuthService get _authService => _customAuthService ?? AuthService.instance;

  /// Key prefix for SharedPreferences storage scoped by user ID.
  static const String _kStoragePrefix = 'nutrifridge_saved_recipes_';

  /// In-memory reactive state holding saved recipes for the active session.
  final ValueNotifier<List<RecipeRecommendation>> _savedRecipesNotifier =
      ValueNotifier<List<RecipeRecommendation>>(<RecipeRecommendation>[]);

  /// Public listenable for reactive UI updates across cards, buttons, and lists.
  ValueListenable<List<RecipeRecommendation>> get savedRecipesNotifier =>
      _savedRecipesNotifier;

  /// Current list of saved recipes in memory.
  List<RecipeRecommendation> get currentSavedRecipes =>
      List<RecipeRecommendation>.unmodifiable(_savedRecipesNotifier.value);

  /// Testing hook to simulate disk/storage write failure.
  @visibleForTesting
  bool simulateStorageError = false;

  /// Testing hook to simulate Supabase network or database failure.
  @visibleForTesting
  bool simulateSupabaseError = false;

  /// Optional override for testing user ID context.
  @visibleForTesting
  String? testUserIdOverride;

  /// In-memory simulated Supabase database table for testing without network.
  /// Map of table names (e.g. 'saved_recipes') to list of row maps.
  @visibleForTesting
  Map<String, List<Map<String, dynamic>>>? mockSupabaseTable;

  /// In-memory override map for unit tests where SharedPreferences is isolated.
  final Map<String, List<RecipeRecommendation>> _inMemoryStore = {};

  bool _initialized = false;
  String? _lastLoadedUserId;

  /// Resolves the active user ID for storage scoping.
  String get effectiveUserId {
    if (testUserIdOverride != null) return testUserIdOverride!;
    try {
      final user = _authService.currentUser;
      if (user != null && user.id.isNotEmpty) {
        return user.id;
      }
    } catch (_) {
      // Mock / offline fallback
    }
    return 'local_user';
  }

  String _storageKey(String userId) => '$_kStoragePrefix$userId';

  /// Initializes and loads saved recipes for the active or specified user.
  Future<void> init({String? userId, bool forceReload = false}) async {
    final targetUserId = userId ?? effectiveUserId;
    if (_initialized && _lastLoadedUserId == targetUserId && !forceReload) {
      return;
    }
    await loadSavedRecipes(userId: targetUserId);
    _initialized = true;
    _lastLoadedUserId = targetUserId;
  }

  /// Reloads saved recipes from persistent storage for the given user.
  Future<List<RecipeRecommendation>> loadSavedRecipes({String? userId}) async {
    final targetUserId = userId ?? effectiveUserId;
    final list = await getSavedRecipesForUser(targetUserId);
    if (userId != null || targetUserId == effectiveUserId) {
      _savedRecipesNotifier.value = List<RecipeRecommendation>.from(list);
    }
    return list;
  }

  /// Checks whether a recipe is already saved.
  bool isSaved(RecipeRecommendation recipe) {
    return isSavedByIdOrTitle(recipe.id, recipe.title);
  }

  /// Checks whether a recipe is saved by ID or title.
  bool isSavedByIdOrTitle(String? id, String title) {
    final cleanTitle = title.trim().toLowerCase();
    final cleanId = id?.trim() ?? '';

    for (final r in _savedRecipesNotifier.value) {
      if (cleanId.isNotEmpty && r.id.trim().isNotEmpty && r.id.trim() == cleanId) {
        return true;
      }
      if (r.title.trim().toLowerCase() == cleanTitle) {
        return true;
      }
    }
    return false;
  }

  /// Saves a recipe snapshot persistently to Supabase (or local fallback).
  ///
  /// Prevents duplicates, preserves all metadata, and updates the reactive notifier.
  /// Throws or returns false if persistence fails.
  Future<bool> saveRecipe(RecipeRecommendation recipe, {String? userId}) async {
    if (simulateStorageError || simulateSupabaseError) {
      throw StateError('Simulated persistent storage failure');
    }

    final targetUserId = userId ?? effectiveUserId;
    final userList = await getSavedRecipesForUser(targetUserId);

    // Check duplicate
    final cleanTitle = recipe.title.trim().toLowerCase();
    final cleanId = recipe.id.trim();
    final alreadyExists = userList.any((r) {
      if (cleanId.isNotEmpty && r.id.trim().isNotEmpty && r.id.trim() == cleanId) {
        return true;
      }
      return r.title.trim().toLowerCase() == cleanTitle;
    });

    if (alreadyExists) {
      return true; // Already safely preserved
    }

    // Assign a persistent ID if empty
    final effectiveRecipe = recipe.id.isNotEmpty
        ? recipe
        : recipe.copyWith(
            id: 'saved_${DateTime.now().millisecondsSinceEpoch}_${recipe.title.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}',
          );

    final updatedList = [effectiveRecipe, ...userList];

    // 1. In-memory simulated Supabase table for testing
    if (mockSupabaseTable != null && targetUserId != 'local_user') {
      final table = mockSupabaseTable!['saved_recipes'] ??= [];
      final row = toSupabaseRow(effectiveRecipe, targetUserId);
      table.removeWhere((r) =>
          r['user_id'] == targetUserId &&
          r['recipe_identifier'] == row['recipe_identifier']);
      table.insert(0, row);

      await _persistToLocalStorage(targetUserId, updatedList);
      if (userId != null || targetUserId == effectiveUserId) {
        _savedRecipesNotifier.value = updatedList;
      }
      return true;
    }

    // 2. Production Supabase client for authenticated user
    final client = _client;
    if (client != null && targetUserId != 'local_user') {
      try {
        final row = toSupabaseRow(effectiveRecipe, targetUserId);
        await client.from('saved_recipes').upsert(
          row,
          onConflict: 'user_id,recipe_identifier',
        );

        await _persistToLocalStorage(targetUserId, updatedList);
        if (userId != null || targetUserId == effectiveUserId) {
          _savedRecipesNotifier.value = updatedList;
        }
        return true;
      } catch (e) {
        debugPrint('[SavedRecipesService] Supabase save error: $e');
        return false;
      }
    }

    // 3. Fallback to local storage
    final success = await _persistToLocalStorage(targetUserId, updatedList);
    if (!success) {
      return false;
    }

    if (userId != null || targetUserId == effectiveUserId) {
      _savedRecipesNotifier.value = updatedList;
    }
    return true;
  }

  /// Removes a recipe from saved recipes by ID or title.
  Future<bool> removeRecipe(String recipeIdOrTitle, {String? userId}) async {
    if (simulateStorageError || simulateSupabaseError) {
      throw StateError('Simulated persistent storage failure');
    }

    final targetUserId = userId ?? effectiveUserId;
    final clean = recipeIdOrTitle.trim().toLowerCase();
    final userList = await getSavedRecipesForUser(targetUserId);

    final matched = userList.cast<RecipeRecommendation?>().firstWhere(
      (r) =>
          (r != null && r.id.trim().isNotEmpty && r.id.trim().toLowerCase() == clean) ||
          (r != null && r.title.trim().toLowerCase() == clean),
      orElse: () => null,
    );

    final updatedList = userList.where((r) {
      final matchesId = r.id.trim().isNotEmpty && r.id.trim().toLowerCase() == clean;
      final matchesTitle = r.title.trim().toLowerCase() == clean;
      return !matchesId && !matchesTitle;
    }).toList();

    // 1. In-memory simulated Supabase table for testing
    if (mockSupabaseTable != null && targetUserId != 'local_user') {
      final table = mockSupabaseTable!['saved_recipes'] ?? [];
      table.removeWhere((r) {
        final matchUser = r['user_id'] == targetUserId;
        final matchId = r['recipe_identifier']?.toString().toLowerCase() == clean;
        final matchTitle = r['title']?.toString().toLowerCase() == clean;
        final matchTargetId = matched != null && r['recipe_identifier'] == matched.id;
        return matchUser && (matchId || matchTitle || matchTargetId);
      });

      await _persistToLocalStorage(targetUserId, updatedList);
      if (userId != null || targetUserId == effectiveUserId) {
        _savedRecipesNotifier.value = updatedList;
      }
      return true;
    }

    // 2. Production Supabase client for authenticated user
    final client = _client;
    if (client != null && targetUserId != 'local_user') {
      try {
        if (matched != null && matched.id.trim().isNotEmpty) {
          await client
              .from('saved_recipes')
              .delete()
              .eq('user_id', targetUserId)
              .eq('recipe_identifier', matched.id.trim());
        } else {
          await client
              .from('saved_recipes')
              .delete()
              .eq('user_id', targetUserId)
              .eq('title', recipeIdOrTitle.trim());
        }

        await _persistToLocalStorage(targetUserId, updatedList);
        if (userId != null || targetUserId == effectiveUserId) {
          _savedRecipesNotifier.value = updatedList;
        }
        return true;
      } catch (e) {
        debugPrint('[SavedRecipesService] Supabase remove error: $e');
        return false;
      }
    }

    // 3. Fallback to local storage
    final success = await _persistToLocalStorage(targetUserId, updatedList);
    if (!success) {
      return false;
    }

    if (userId != null || targetUserId == effectiveUserId) {
      _savedRecipesNotifier.value = updatedList;
    }
    return true;
  }

  /// Toggles saved state: saves if unsaved, removes if saved.
  ///
  /// Returns the NEW saved state: true if now saved, false if removed.
  Future<bool> toggleSave(RecipeRecommendation recipe, {String? userId}) async {
    final saved = isSaved(recipe);
    if (saved) {
      final targetKey = recipe.id.isNotEmpty ? recipe.id : recipe.title;
      final removed = await removeRecipe(targetKey, userId: userId);
      return !removed; // If removed successfully, now false
    } else {
      final added = await saveRecipe(recipe, userId: userId);
      return added; // If added successfully, now true
    }
  }

  /// Returns saved recipes for a specific user ID directly without altering current listener state.
  Future<List<RecipeRecommendation>> getSavedRecipesForUser(String userId) async {
    // 1. Simulated Supabase database table for tests
    if (mockSupabaseTable != null && userId != 'local_user') {
      if (simulateSupabaseError || simulateStorageError) {
        debugPrint('[SavedRecipesService] Simulated database error, falling back to local store');
        return _loadFromLocalStorage(userId);
      }
      final table = mockSupabaseTable!['saved_recipes'] ?? [];
      final userRows = table.where((row) => row['user_id'] == userId).toList();
      final recipes = userRows.map((r) => fromSupabaseRow(r)).toList();
      await _persistToLocalStorage(userId, recipes);
      return recipes;
    }

    // 2. Production Supabase client
    final client = _client;
    if (client != null && userId != 'local_user') {
      try {
        if (simulateSupabaseError || simulateStorageError) {
          throw StateError('Simulated Supabase query failure');
        }

        final response = await client
            .from('saved_recipes')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        final List<dynamic> data = response as List<dynamic>;
        final recipes = data
            .map((row) => fromSupabaseRow(Map<String, dynamic>.from(row as Map)))
            .toList();

        await _persistToLocalStorage(userId, recipes);
        return recipes;
      } catch (e) {
        debugPrint('[SavedRecipesService] Supabase load error: $e. Falling back to local cache.');
        return _loadFromLocalStorage(userId);
      }
    }

    // 3. Fallback to local storage (unauthenticated or offline)
    return _loadFromLocalStorage(userId);
  }

  /// Formats a [RecipeRecommendation] into the exact column payload for table `public.saved_recipes`.
  static Map<String, dynamic> toSupabaseRow(RecipeRecommendation recipe, String userId) {
    final snapshot = recipe.toJson();
    final cleanId = recipe.id.isNotEmpty
        ? recipe.id
        : 'saved_${recipe.title.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}';

    return {
      'user_id': userId,
      'recipe_identifier': cleanId,
      'title': recipe.title,
      'meal_type': recipe.mealType.isNotEmpty ? recipe.mealType : recipe.tag,
      'image_url': recipe.imageUrl,
      'image_key': recipe.imageKey,
      'calories': recipe.calories >= 0 ? recipe.calories : 0,
      'protein_g': recipe.proteinGrams >= 0 ? recipe.proteinGrams : 0,
      'carbs_g': recipe.carbsGrams >= 0 ? recipe.carbsGrams : 0,
      'fat_g': recipe.fatGrams >= 0 ? recipe.fatGrams : 0,
      'prep_time_minutes': recipe.prepTimeMinutes >= 0 ? recipe.prepTimeMinutes : 0,
      'cooking_time_minutes': recipe.cookingTimeMinutes != null && recipe.cookingTimeMinutes! >= 0
          ? recipe.cookingTimeMinutes
          : null,
      'serving_size': recipe.servingSize,
      'recipe_snapshot': snapshot,
    };
  }

  /// Reconstructs a [RecipeRecommendation] from a `public.saved_recipes` database row.
  static RecipeRecommendation fromSupabaseRow(Map<String, dynamic> row) {
    dynamic snapshot = row['recipe_snapshot'];
    if (snapshot is String && snapshot.trim().isNotEmpty) {
      try {
        snapshot = jsonDecode(snapshot);
      } catch (_) {}
    }

    if (snapshot is Map<String, dynamic>) {
      return RecipeRecommendation.fromJson(snapshot);
    } else if (snapshot is Map) {
      return RecipeRecommendation.fromJson(Map<String, dynamic>.from(snapshot));
    }

    // Fallback: build directly from row columns if snapshot is missing
    return RecipeRecommendation(
      id: (row['recipe_identifier'] ?? row['id'] ?? '').toString(),
      title: (row['title'] ?? '').toString(),
      calories: (row['calories'] as num?)?.toInt() ?? 0,
      proteinGrams: (row['protein_g'] as num?)?.toInt() ?? 0,
      carbsGrams: (row['carbs_g'] as num?)?.toInt() ?? 0,
      fatGrams: (row['fat_g'] as num?)?.toInt() ?? 0,
      prepTimeMinutes: (row['prep_time_minutes'] as num?)?.toInt() ?? 0,
      cookingTimeMinutes: (row['cooking_time_minutes'] as num?)?.toInt(),
      servingSize: (row['serving_size'] ?? '1 serving').toString(),
      fridgeItemsUsed: 0,
      imageUrl: (row['image_url'] ?? '').toString(),
      imageKey: row['image_key']?.toString(),
      mealType: (row['meal_type'] ?? '').toString(),
      tag: (row['meal_type'] ?? 'SAVED').toString(),
    );
  }

  /// Safely synchronizes recipes saved locally under 'local_user' to the authenticated Supabase user.
  ///
  /// Safe migration rules:
  /// - Only removes local items after confirmed persistence to Supabase.
  /// - Partial uploads keep un-synced items locally for retry on next session.
  /// - Idempotent upserts prevent duplicate database rows.
  Future<int> syncLocalRecipesToSupabase({
    String? targetUserId,
    SupabaseClient? customClient,
  }) async {
    final effectiveTarget = targetUserId ?? effectiveUserId;
    if (effectiveTarget == 'local_user') {
      return 0; // Not authenticated yet
    }

    final localRecipes = await _loadFromLocalStorage('local_user');
    if (localRecipes.isEmpty) return 0;

    final List<String> successfullySyncedKeys = [];

    // 1. Mock database for tests
    if (mockSupabaseTable != null) {
      if (simulateSupabaseError || simulateStorageError) {
        debugPrint('[SavedRecipesService] Mock sync failed due to simulated error');
        return 0;
      }
      final table = mockSupabaseTable!['saved_recipes'] ??= [];
      for (final recipe in localRecipes) {
        final row = toSupabaseRow(recipe, effectiveTarget);
        table.removeWhere((r) =>
            r['user_id'] == effectiveTarget &&
            r['recipe_identifier'] == row['recipe_identifier']);
        table.insert(0, row);
        successfullySyncedKeys.add(recipe.id.isNotEmpty ? recipe.id : recipe.title);
      }
    } else {
      // 2. Real Supabase client
      SupabaseClient? client = customClient ?? _client;
      if (client == null) {
        return 0;
      }

      for (final recipe in localRecipes) {
        try {
          if (simulateSupabaseError || simulateStorageError) {
            throw StateError('Simulated sync error');
          }
          final row = toSupabaseRow(recipe, effectiveTarget);
          await client.from('saved_recipes').upsert(
            row,
            onConflict: 'user_id,recipe_identifier',
          );
          successfullySyncedKeys.add(recipe.id.isNotEmpty ? recipe.id : recipe.title);
        } catch (e) {
          debugPrint('[SavedRecipesService] Sync failed for recipe ${recipe.title}: $e');
        }
      }
    }

    // Only remove successfully synced recipes from local_user storage
    if (successfullySyncedKeys.isNotEmpty) {
      final remainingLocal = localRecipes.where((r) {
        final key = r.id.isNotEmpty ? r.id : r.title;
        return !successfullySyncedKeys.contains(key);
      }).toList();

      await _persistToLocalStorage('local_user', remainingLocal);

      // Reload current user recipes including newly synced ones
      await loadSavedRecipes(userId: effectiveTarget);
    }

    return successfullySyncedKeys.length;
  }

  Future<List<RecipeRecommendation>> _loadFromLocalStorage(String userId) async {
    if (_inMemoryStore.containsKey(userId)) {
      return List<RecipeRecommendation>.from(_inMemoryStore[userId]!);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey(userId));
      if (raw == null || raw.trim().isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = decoded
            .map((e) => RecipeRecommendation.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _inMemoryStore[userId] = list;
        return list;
      }
    } catch (_) {}
    return [];
  }

  Future<bool> _persistToLocalStorage(String userId, List<RecipeRecommendation> list) async {
    if (simulateStorageError) {
      return false;
    }

    _inMemoryStore[userId] = List<RecipeRecommendation>.from(list);

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = list.map((r) => r.toJson()).toList();
      final encoded = jsonEncode(jsonList);
      final key = _storageKey(userId);
      return await prefs.setString(key, encoded);
    } catch (e) {
      debugPrint('[SavedRecipesService] Storage error during persist: $e');
      return false;
    }
  }

  /// Clears in-memory cache and state for user logout to prevent data bleeding across accounts.
  void clearForLogout() {
    _savedRecipesNotifier.value = <RecipeRecommendation>[];
    _lastLoadedUserId = null;
    _initialized = false;
    _inMemoryStore.removeWhere((key, _) => key != 'local_user');
  }

  /// Resets in-memory state and mock storage for testing.
  @visibleForTesting
  void resetForTesting() {
    _savedRecipesNotifier.value = <RecipeRecommendation>[];
    _inMemoryStore.clear();
    mockSupabaseTable = null;
    simulateStorageError = false;
    simulateSupabaseError = false;
    testUserIdOverride = null;
    _initialized = false;
    _lastLoadedUserId = null;
  }

  /// Seeds mock storage with recipes for a given user in tests.
  @visibleForTesting
  void setMockStorage(String userId, List<RecipeRecommendation> recipes) {
    _inMemoryStore[userId] = List<RecipeRecommendation>.from(recipes);
    if (userId == effectiveUserId) {
      _savedRecipesNotifier.value = List<RecipeRecommendation>.from(recipes);
    }
  }
}
