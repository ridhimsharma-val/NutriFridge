import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/nutrition_data.dart';
import '../auth/auth_service.dart';
import 'food_image_model.dart';

class _CachedSearchResults {
  final List<FoodImageCandidate> candidates;
  final DateTime cachedAt;

  _CachedSearchResults(this.candidates, this.cachedAt);

  bool get isExpired => DateTime.now().difference(cachedAt).inHours >= 24;
}

/// Central repository handling image mapping persistence and multi-level caching.
class FoodImageRepository {
  static final FoodImageRepository instance = FoodImageRepository._internal();
  FoodImageRepository._internal();

  /// In-memory cache for resolved image mappings.
  /// Keys: "entityType:entityKey" (shared) or "userId:entityType:entityKey" (user-override)
  final Map<String, FoodImageModel> _memoryCache = {};

  /// 24-hour cache for external provider search results.
  /// Key: "query:orientation"
  final Map<String, _CachedSearchResults> _searchCache = {};

  SupabaseClient? _customClient;

  @visibleForTesting
  void setCustomClient(SupabaseClient? client) {
    _customClient = client;
  }

  SupabaseClient? get _client {
    if (_customClient != null) return _customClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String _cacheKey(FoodEntityType type, String entityKey, [String? userId]) {
    final prefix = (userId != null && userId.isNotEmpty) ? '$userId:' : '';
    return '$prefix${type.name}:$entityKey';
  }

  /// Checks in-memory cache for user override first, then shared mapping.
  FoodImageModel? getCachedMapping({
    required FoodEntityType type,
    required String entityKey,
    String? userId,
  }) {
    final effectiveUserId = userId ?? AuthService.instance.currentUser?.id;
    if (effectiveUserId != null && effectiveUserId.isNotEmpty) {
      final overrideKey = _cacheKey(type, entityKey, effectiveUserId);
      if (_memoryCache.containsKey(overrideKey)) {
        return _memoryCache[overrideKey];
      }
    }
    final sharedKey = _cacheKey(type, entityKey);
    return _memoryCache[sharedKey];
  }

  /// Saves image model into in-memory cache.
  void putInMemoryCache(FoodImageModel model) {
    if (model.isUserOverride && model.userId != null) {
      _memoryCache[_cacheKey(model.entityType, model.entityKey, model.userId)] = model;
    } else {
      _memoryCache[_cacheKey(model.entityType, model.entityKey)] = model;
    }
  }

  /// Removes an override from memory cache
  void removeOverrideFromMemory({
    required FoodEntityType type,
    required String entityKey,
    required String userId,
  }) {
    _memoryCache.remove(_cacheKey(type, entityKey, userId));
  }

  /// Retrieves search results from 24h search cache if available and fresh.
  List<FoodImageCandidate>? getCachedSearch(String query, String orientation) {
    final key = '${query.toLowerCase().trim()}:$orientation';
    final cached = _searchCache[key];
    if (cached != null && !cached.isExpired) {
      return cached.candidates;
    }
    if (cached != null && cached.isExpired) {
      _searchCache.remove(key);
    }
    return null;
  }

  /// Caches search results for 24 hours.
  void cacheSearch(String query, String orientation, List<FoodImageCandidate> candidates) {
    final key = '${query.toLowerCase().trim()}:$orientation';
    _searchCache[key] = _CachedSearchResults(candidates, DateTime.now());
  }

  /// Fetches the authoritative mapping from Supabase (or in-memory cache).
  /// Checks for user override first, then shared catalog entry.
  Future<FoodImageModel?> fetchMapping({
    required FoodEntityType type,
    required String entityKey,
    String? userId,
  }) async {
    // 1. In-memory check
    final memoryHit = getCachedMapping(type: type, entityKey: entityKey, userId: userId);
    if (memoryHit != null) return memoryHit;

    final client = _client;
    final effectiveUserId = userId ?? AuthService.instance.currentUser?.id;

    if (client == null ||
        MockDataRepository.forceInMemoryForTesting ||
        !AuthService.instance.isAuthenticated ||
        effectiveUserId == null) {
      return null;
    }

    try {
      // Query both shared (user_id is null) and user's own overrides
      final response = await client
          .from('food_image_mappings')
          .select()
          .eq('entity_type', type.toDbString())
          .eq('entity_key', entityKey)
          .or('user_id.is.null,user_id.eq.$effectiveUserId')
          .order('is_user_override', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        final model = FoodImageModel.fromJson(response);
        putInMemoryCache(model);
        return model;
      }
    } catch (e) {
      debugPrint('[FoodImageRepository] fetchMapping warning: $e');
    }

    return null;
  }

  /// Persists a user-specific image override.
  Future<FoodImageModel> saveUserOverride({
    required FoodEntityType type,
    required String entityKey,
    required String displayName,
    required FoodImageCandidate candidate,
    String? userId,
  }) async {
    final effectiveUserId = userId ?? AuthService.instance.currentUser?.id ?? 'local_user';
    final existing = getCachedMapping(type: type, entityKey: entityKey, userId: effectiveUserId) ??
        getCachedMapping(type: type, entityKey: entityKey);

    final model = FoodImageModel(
      entityType: type,
      entityKey: entityKey,
      displayName: displayName,
      imageUrl: candidate.imageUrl,
      provider: candidate.provider,
      providerPhotoId: candidate.photoId,
      photographerName: candidate.photographerName,
      photographerUrl: candidate.photographerUrl,
      sourcePageUrl: candidate.sourcePageUrl,
      altDescription: candidate.altDescription,
      panCutoutUrl: existing?.panCutoutUrl,
      isPanOverride: existing?.isPanOverride ?? false,
      isUserOverride: true,
      userId: effectiveUserId,
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Save in memory
    putInMemoryCache(model);

    final client = _client;
    if (client != null &&
        !MockDataRepository.forceInMemoryForTesting &&
        AuthService.instance.isAuthenticated &&
        effectiveUserId != 'local_user') {
      try {
        await client.from('food_image_mappings').upsert(
          {
            ...model.toDbMap(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'entity_type,entity_key,user_id',
        );
      } catch (e) {
        debugPrint('[FoodImageRepository] saveUserOverride db error: $e');
      }
    }

    return model;
  }

  /// Persists a user-specific cooking pan cutout override without modifying regular photography.
  Future<FoodImageModel> savePanOverride({
    required FoodEntityType type,
    required String entityKey,
    required String displayName,
    required String panCutoutUrl,
    String? userId,
  }) async {
    final effectiveUserId = userId ?? AuthService.instance.currentUser?.id ?? 'local_user';
    final existing = getCachedMapping(type: type, entityKey: entityKey, userId: effectiveUserId) ??
        getCachedMapping(type: type, entityKey: entityKey);

    final model = FoodImageModel(
      entityType: type,
      entityKey: entityKey,
      displayName: displayName,
      imageUrl: existing?.imageUrl ?? panCutoutUrl,
      provider: existing?.provider ?? 'curated',
      providerPhotoId: existing?.providerPhotoId,
      photographerName: existing?.photographerName,
      photographerUrl: existing?.photographerUrl,
      sourcePageUrl: existing?.sourcePageUrl,
      altDescription: existing?.altDescription,
      panCutoutUrl: panCutoutUrl,
      isPanOverride: true,
      isUserOverride: existing?.isUserOverride ?? false,
      userId: effectiveUserId,
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Save in memory
    putInMemoryCache(model);

    final client = _client;
    if (client != null &&
        !MockDataRepository.forceInMemoryForTesting &&
        AuthService.instance.isAuthenticated &&
        effectiveUserId != 'local_user') {
      try {
        await client.from('food_image_mappings').upsert(
          {
            ...model.toDbMap(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'entity_type,entity_key,user_id',
        );
      } catch (e) {
        debugPrint('[FoodImageRepository] savePanOverride db error: $e');
      }
    }

    return model;
  }

  /// Reverts a user-specific image override back to the automatic / shared mapping.
  Future<void> removeUserOverride({
    required FoodEntityType type,
    required String entityKey,
    String? userId,
  }) async {
    final effectiveUserId = userId ?? AuthService.instance.currentUser?.id ?? 'local_user';
    final existing = getCachedMapping(type: type, entityKey: entityKey, userId: effectiveUserId);

    if (existing != null && existing.isPanOverride) {
      final shared = getCachedMapping(type: type, entityKey: entityKey);
      final updated = existing.copyWith(
        imageUrl: shared?.imageUrl,
        isUserOverride: false,
        provider: shared?.provider ?? 'pixabay',
        photographerName: shared?.photographerName,
        photographerUrl: shared?.photographerUrl,
        sourcePageUrl: shared?.sourcePageUrl,
      );
      putInMemoryCache(updated);

      final client = _client;
      if (client != null &&
          !MockDataRepository.forceInMemoryForTesting &&
          AuthService.instance.isAuthenticated &&
          effectiveUserId != 'local_user') {
        try {
          await client.from('food_image_mappings').upsert(
            {
              ...updated.toDbMap(),
              'updated_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'entity_type,entity_key,user_id',
          );
        } catch (_) {}
      }
    } else {
      removeOverrideFromMemory(type: type, entityKey: entityKey, userId: effectiveUserId);

      final client = _client;
      if (client != null &&
          !MockDataRepository.forceInMemoryForTesting &&
          AuthService.instance.isAuthenticated &&
          effectiveUserId != 'local_user') {
        try {
          await client
              .from('food_image_mappings')
              .delete()
              .eq('entity_type', type.toDbString())
              .eq('entity_key', entityKey)
              .eq('user_id', effectiveUserId);
        } catch (e) {
          debugPrint('[FoodImageRepository] removeUserOverride db error: $e');
        }
      }
    }
  }

  /// Reverts a user-specific cooking pan cutout override back to automatic mapping.
  Future<void> removePanOverride({
    required FoodEntityType type,
    required String entityKey,
    String? userId,
  }) async {
    final effectiveUserId = userId ?? AuthService.instance.currentUser?.id ?? 'local_user';
    final existing = getCachedMapping(type: type, entityKey: entityKey, userId: effectiveUserId);

    if (existing != null && existing.isUserOverride) {
      final shared = getCachedMapping(type: type, entityKey: entityKey);
      final updated = existing.copyWith(
        panCutoutUrl: shared?.panCutoutUrl,
        isPanOverride: false,
      );
      putInMemoryCache(updated);

      final client = _client;
      if (client != null &&
          !MockDataRepository.forceInMemoryForTesting &&
          AuthService.instance.isAuthenticated &&
          effectiveUserId != 'local_user') {
        try {
          await client.from('food_image_mappings').upsert(
            {
              ...updated.toDbMap(),
              'updated_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'entity_type,entity_key,user_id',
          );
        } catch (_) {}
      }
    } else {
      removeOverrideFromMemory(type: type, entityKey: entityKey, userId: effectiveUserId);

      final client = _client;
      if (client != null &&
          !MockDataRepository.forceInMemoryForTesting &&
          AuthService.instance.isAuthenticated &&
          effectiveUserId != 'local_user') {
        try {
          await client
              .from('food_image_mappings')
              .delete()
              .eq('entity_type', type.toDbString())
              .eq('entity_key', entityKey)
              .eq('user_id', effectiveUserId);
        } catch (e) {
          debugPrint('[FoodImageRepository] removePanOverride db error: $e');
        }
      }
    }
  }

  /// Saves a shared automatic catalog mapping in memory and optionally in DB.
  Future<void> saveSharedMapping(FoodImageModel model) async {
    putInMemoryCache(model);

    final client = _client;
    if (client != null &&
        !MockDataRepository.forceInMemoryForTesting &&
        AuthService.instance.isAuthenticated) {
      try {
        await client.from('food_image_mappings').upsert(
          model.toDbMap(),
          onConflict: 'entity_type,entity_key,user_id',
        );
      } catch (e) {
        // Can be ignored if user doesn't have direct write access to shared mappings
      }
    }
  }

  /// Clears in-memory caches (used in unit testing and sign-out)
  void clearMemoryCache() {
    _memoryCache.clear();
    _searchCache.clear();
  }
}
