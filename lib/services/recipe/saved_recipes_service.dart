import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/nutrition_data.dart';
import '../auth/auth_service.dart';

/// Central service for persisting and managing user-bookmarked AI recipes.
///
/// Guarantees that saved recipe snapshots are stored with complete ingredient,
/// instruction, timing, and nutrition fidelity, and can be retrieved without
/// triggering Gemini or network calls.
class SavedRecipesService {
  SavedRecipesService._internal();

  static final SavedRecipesService instance = SavedRecipesService._internal();

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

  /// In-memory override map for unit tests where SharedPreferences is isolated.
  final Map<String, List<RecipeRecommendation>> _inMemoryStore = {};

  bool _initialized = false;
  String? _lastLoadedUserId;

  /// Resolves the active user ID for storage scoping.
  String get effectiveUserId {
    try {
      final user = AuthService.instance.currentUser;
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
    if (targetUserId == effectiveUserId) {
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

  /// Saves a recipe snapshot persistently.
  ///
  /// Prevents duplicates, preserves all metadata, and updates the reactive notifier.
  /// Throws or returns false if persistence fails.
  Future<bool> saveRecipe(RecipeRecommendation recipe, {String? userId}) async {
    if (simulateStorageError) {
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

    // Persist to storage before updating reactive memory
    final success = await _persistToStorage(targetUserId, updatedList);
    if (!success) {
      return false;
    }

    if (targetUserId == effectiveUserId) {
      _savedRecipesNotifier.value = updatedList;
    }
    return true;
  }

  /// Removes a recipe from saved recipes by ID or title.
  Future<bool> removeRecipe(String recipeIdOrTitle, {String? userId}) async {
    if (simulateStorageError) {
      throw StateError('Simulated persistent storage failure');
    }

    final targetUserId = userId ?? effectiveUserId;
    final clean = recipeIdOrTitle.trim().toLowerCase();
    final userList = await getSavedRecipesForUser(targetUserId);

    final updatedList = userList.where((r) {
      final matchesId = r.id.trim().isNotEmpty && r.id.trim().toLowerCase() == clean;
      final matchesTitle = r.title.trim().toLowerCase() == clean;
      return !matchesId && !matchesTitle;
    }).toList();

    final success = await _persistToStorage(targetUserId, updatedList);
    if (!success) {
      return false;
    }

    if (targetUserId == effectiveUserId) {
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
    if (_inMemoryStore.containsKey(userId)) {
      return List<RecipeRecommendation>.from(_inMemoryStore[userId]!);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey(userId));
      if (raw == null || raw.trim().isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => RecipeRecommendation.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
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
      'calories': recipe.calories,
      'protein_g': recipe.proteinGrams,
      'carbs_g': recipe.carbsGrams,
      'fat_g': recipe.fatGrams,
      'prep_time_minutes': recipe.prepTimeMinutes,
      'cooking_time_minutes': recipe.cookingTimeMinutes,
      'serving_size': recipe.servingSize,
      'recipe_snapshot': snapshot,
    };
  }

  /// Reconstructs a [RecipeRecommendation] from a `public.saved_recipes` database row.
  static RecipeRecommendation fromSupabaseRow(Map<String, dynamic> row) {
    final snapshot = row['recipe_snapshot'];
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

  Future<bool> _persistToStorage(String userId, List<RecipeRecommendation> list) async {
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

  /// Resets in-memory state and mock storage for testing.
  @visibleForTesting
  void resetForTesting() {
    _savedRecipesNotifier.value = <RecipeRecommendation>[];
    _inMemoryStore.clear();
    simulateStorageError = false;
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
