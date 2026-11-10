import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../models/nutrition_data.dart';
import 'food_image_model.dart';
import 'food_image_repository.dart';

typedef FoodImageEdgeFunctionHandler = Future<Map<String, dynamic>> Function(Map<String, dynamic> body);

/// Core resolution engine implementing normalization, prioritization, deduplication, and matching.
class FoodImageResolver {
  static final FoodImageResolver instance = FoodImageResolver._internal();
  FoodImageResolver._internal();

  /// Mock handler for unit and widget testing
  static FoodImageEdgeFunctionHandler? mockHandler;

  /// In-flight resolution deduplication map (key: "$entityType:$entityKey")
  final Map<String, Future<FoodImageModel>> _inFlight = {};

  /// Normalizes ingredient or recipe names into canonical search keys.
  /// Removes quantity strings, metric/imperial units, parenthesized comments, and special characters.
  static String normalizeKey(String rawName) {
    String clean = rawName.trim().toLowerCase();

    // 1. Remove parenthesized text (e.g., "(100g)", "(approx 2 cups)", "(fresh)")
    clean = clean.replaceAll(RegExp(r'\([^)]*\)'), ' ');

    // 2. Remove common quantity and unit prefixes or suffixes (e.g., "500g", "2.5 kg", "1 pack", "2 pieces")
    clean = clean.replaceAll(
      RegExp(r'\b\d+([.,]\d+)?\s*(g|kg|ml|l|oz|lb|cups?|tbsp|tsp|pieces?|items?|slices?|packs?|cans?|jars?|bottles?|bunches?)\b', caseSensitive: false),
      ' ',
    );

    // 3. Remove leading numbers (e.g. "2 apples" -> "apples")
    clean = clean.replaceAll(RegExp(r'^\d+\s*'), '');

    // 4. Strip common quality/preparation adjectives for ingredients (e.g. "fresh", "organic", "raw")
    clean = clean.replaceAll(RegExp(r'\b(fresh|organic|raw|ripe|pure|extra|whole|chopped|diced|sliced)\b', caseSensitive: false), ' ');

    // 5. Strip punctuation and non-alphanumeric characters
    clean = clean.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');

    // 6. Collapse extra spaces
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 7. Handle common plurals for standard ingredients (apples -> apple, tomatoes -> tomato)
    if (clean.endsWith('tomatoes')) {
      clean = clean.substring(0, clean.length - 2); // tomato
    } else if (clean.endsWith('potatoes')) {
      clean = clean.substring(0, clean.length - 2); // potato
    } else if (clean.endsWith('ies') && clean.length > 4) {
      clean = '${clean.substring(0, clean.length - 3)}y'; // berries -> berry
    } else if (clean.endsWith('es') && (clean.endsWith('ches') || clean.endsWith('shes') || clean.endsWith('xes'))) {
      clean = clean.substring(0, clean.length - 2);
    } else if (clean.endsWith('s') && !clean.endsWith('ss') && clean.length > 3) {
      clean = clean.substring(0, clean.length - 1); // apples -> apple, bananas -> banana
    }

    return clean.isEmpty ? rawName.trim().toLowerCase() : clean;
  }

  /// Checks if an exact local curated asset mapping exists.
  FoodImageModel? _checkCuratedAsset(String canonicalKey, String displayName, FoodEntityType type) {
    if (type == FoodEntityType.ingredient) {
      const Map<String, String> localAssets = {
        'milk': 'assets/images/foods/milk.png',
        'paneer': 'assets/images/foods/paneer.png',
        'curd': 'assets/images/foods/curd.png',
        'yogurt': 'assets/images/foods/curd.png',
        'butter': 'assets/images/foods/butter.png',
        'tomato': 'assets/images/foods/tomato.png',
        'carrot': 'assets/images/foods/carrot.png',
        'broccoli': 'assets/images/foods/broccoli.png',
        'capsicum': 'assets/images/foods/capsicum.png',
        'bell pepper': 'assets/images/foods/capsicum.png',
        'pepper': 'assets/images/foods/capsicum.png',
        'apple': 'assets/images/foods/apple.png',
        'banana': 'assets/images/foods/banana.png',
        'orange': 'assets/images/foods/orange.png',
        'grape': 'assets/images/foods/grapes.png',
        'egg': 'assets/images/foods/eggs.png',
        'chicken': 'assets/images/foods/chicken.png',
        'fish': 'assets/images/foods/fish.png',
        'salmon': 'assets/images/foods/fish.png',
        'bread': 'assets/images/foods/bread.png',
        'peanut butter': 'assets/images/foods/peanut_butter.png',
        'jam': 'assets/images/foods/jam.jpg',
        'juice': 'assets/images/foods/juice.png',
        'peas': 'assets/images/foods/frozen_peas.png',
        'corn': 'assets/images/foods/frozen_corn.png',
        'almond': 'assets/images/foods/almonds.png',
        'cashew': 'assets/images/foods/cashews.png',
        'dry fruit': 'assets/images/foods/dry_fruits_mix.png',
        'honey': 'assets/images/foods/honey.jpg',
      };

      if (localAssets.containsKey(canonicalKey)) {
        return FoodImageModel(
          entityType: FoodEntityType.ingredient,
          entityKey: canonicalKey,
          displayName: displayName,
          imageUrl: localAssets[canonicalKey]!,
          provider: 'curated',
          altDescription: displayName,
        );
      }
    } else {
      // Recipe local assets
      const Map<String, String> localRecipes = {
        'paneer rice bowl': 'assets/images/paneer_rice_bowl.jpg',
        'dal rice': 'assets/images/foods/dal_rice.jpg',
        'paneer curry': 'assets/images/foods/paneer_curry.jpg',
        'pasta': 'assets/images/foods/pasta.jpg',
        'veggie pasta': 'assets/images/foods/pasta.jpg',
        'grilled chicken': 'assets/images/foods/chicken.jpg',
        'pan seared fish': 'assets/images/foods/fish.jpg',
        'scrambled eggs': 'assets/images/foods/eggs.jpg',
      };

      if (localRecipes.containsKey(canonicalKey)) {
        return FoodImageModel(
          entityType: FoodEntityType.recipe,
          entityKey: canonicalKey,
          displayName: displayName,
          imageUrl: localRecipes[canonicalKey]!,
          provider: 'curated',
          altDescription: displayName,
        );
      }
    }

    return null;
  }

  /// Builds a clean fallback placeholder model when no provider match or curated asset exists.
  FoodImageModel buildPlaceholder({
    required String name,
    required FoodEntityType type,
    String? category,
  }) {
    final canonicalKey = normalizeKey(name);
    String placeholderUrl = 'assets/images/paneer_rice_bowl.jpg';

    if (type == FoodEntityType.ingredient) {
      if (category != null) {
        final cat = category.toLowerCase();
        if (cat.contains('dairy')) {
          placeholderUrl = 'assets/images/foods/milk.png';
        } else if (cat.contains('veg')) {
          placeholderUrl = 'assets/images/foods/tomato.png';
        } else if (cat.contains('fruit')) {
          placeholderUrl = 'assets/images/foods/apple.png';
        } else if (cat.contains('non-veg')) {
          placeholderUrl = 'assets/images/foods/chicken.png';
        } else if (cat.contains('drink') || cat.contains('juice')) {
          placeholderUrl = 'assets/images/foods/juice.png';
        } else {
          placeholderUrl = 'assets/images/foods/apple.png';
        }
      } else {
        placeholderUrl = 'assets/images/foods/apple.png';
      }
    } else {
      placeholderUrl = MealImageRegistry.getFallbackAsset(name);
    }

    return FoodImageModel(
      entityType: type,
      entityKey: canonicalKey,
      displayName: name,
      imageUrl: placeholderUrl,
      provider: 'placeholder',
      altDescription: name,
    );
  }

  /// Resolves an image with the authoritative priority order:
  /// 1. User-selected image override
  /// 2. Curated / local asset mapping
  /// 3. Previously saved automatic mapping
  /// 4. Pexels search & matching via Supabase Edge Function
  /// 5. Existing category placeholder
  Future<FoodImageModel> resolve({
    required String name,
    required FoodEntityType type,
    String? category,
    String? cuisine,
    String? userId,
  }) async {
    final canonicalKey = normalizeKey(name);
    final inFlightKey = '${type.name}:$canonicalKey';

    // 1. Check in-flight deduplication
    if (_inFlight.containsKey(inFlightKey)) {
      return _inFlight[inFlightKey]!;
    }

    final completer = Completer<FoodImageModel>();
    _inFlight[inFlightKey] = completer.future;

    try {
      final repo = FoodImageRepository.instance;

      // Priority 1: User-selected override & Priority 3: Saved automatic mapping from repo/DB
      final savedMapping = await repo.fetchMapping(
        type: type,
        entityKey: canonicalKey,
        userId: userId,
      );

      if (savedMapping != null) {
        completer.complete(savedMapping);
        return savedMapping;
      }

      // Priority 4: Search real food photography via Supabase Edge Function (Pexels)
      final searchResult = await _invokeEdgeFunction({
        'action': 'resolve',
        'query': canonicalKey,
        'entityType': type.toDbString(),
        'category': category,
        'cuisine': cuisine,
        'orientation': type == FoodEntityType.ingredient ? 'square' : 'landscape',
      });

      if (searchResult['ok'] == true && searchResult['bestMatch'] != null) {
        final candidate = FoodImageCandidate.fromJson(
          Map<String, dynamic>.from(searchResult['bestMatch'] as Map),
        );

        final resolvedModel = FoodImageModel(
          entityType: type,
          entityKey: canonicalKey,
          displayName: name,
          imageUrl: candidate.imageUrl,
          provider: candidate.provider,
          providerPhotoId: candidate.photoId,
          photographerName: candidate.photographerName,
          photographerUrl: candidate.photographerUrl,
          sourcePageUrl: candidate.sourcePageUrl,
          altDescription: candidate.altDescription,
          isUserOverride: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repo.saveSharedMapping(resolvedModel);
        completer.complete(resolvedModel);
        return resolvedModel;
      }

      // Priority 5: Existing curated local asset or clean category placeholder fallback
      final curated = _checkCuratedAsset(canonicalKey, name, type);
      if (curated != null) {
        repo.putInMemoryCache(curated);
        completer.complete(curated);
        return curated;
      }

      final placeholder = buildPlaceholder(name: name, type: type, category: category);
      repo.putInMemoryCache(placeholder);
      completer.complete(placeholder);
      return placeholder;
    } catch (e) {
      debugPrint('[FoodImageResolver] Error resolving $name: $e');
      final fallback = buildPlaceholder(name: name, type: type, category: category);
      completer.complete(fallback);
      return fallback;
    } finally {
      _inFlight.remove(inFlightKey);
    }
  }

  /// Searches image provider candidates for manual image selection.
  Future<List<FoodImageCandidate>> searchCandidates({
    required String query,
    required FoodEntityType type,
    int perPage = 8,
  }) async {
    final orientation = type == FoodEntityType.ingredient ? 'square' : 'landscape';
    final repo = FoodImageRepository.instance;

    // Check 24h search cache
    final cached = repo.getCachedSearch(query, orientation);
    if (cached != null) {
      return cached;
    }

    try {
      final response = await _invokeEdgeFunction({
        'action': 'search',
        'query': query,
        'entityType': type.toDbString(),
        'orientation': orientation,
        'perPage': perPage,
      });

      if (response['ok'] == true && response['candidates'] is List) {
        final list = (response['candidates'] as List)
            .map((c) => FoodImageCandidate.fromJson(Map<String, dynamic>.from(c as Map)))
            .toList();

        repo.cacheSearch(query, orientation, list);
        return list;
      }
    } catch (e) {
      debugPrint('[FoodImageResolver] searchCandidates error: $e');
    }

    return const [];
  }

  /// Dispatches the request to the `food-image` Edge Function with auth credentials or mock override.
  Future<Map<String, dynamic>> _invokeEdgeFunction(Map<String, dynamic> body) async {
    if (mockHandler != null) {
      return await mockHandler!(body);
    }

    if (MockDataRepository.forceInMemoryForTesting) {
      return {'ok': false, 'error': 'IN_MEMORY_TESTING'};
    }

    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      final token = session?.accessToken;

      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      if (SupabaseConfig.isConfigured && SupabaseConfig.supabasePublishableKey.isNotEmpty) {
        headers['apikey'] = SupabaseConfig.supabasePublishableKey;
      }

      final res = await client.functions
          .invoke('food-image', body: body, headers: headers)
          .timeout(const Duration(seconds: 10));

      final dynamic data = res.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      debugPrint('[FoodImageResolver] _invokeEdgeFunction warning: $e');
    }

    return {'ok': false, 'error': 'EDGE_FUNCTION_UNAVAILABLE'};
  }
}
