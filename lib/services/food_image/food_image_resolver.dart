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

  /// Curated local transparent food cutouts for the interactive cooking pan
  static const Map<String, String> curatedCutouts = {
    'paneer': 'assets/images/foods/paneer.png',
    'apple': 'assets/images/foods/apple.png',
    'broccoli': 'assets/images/foods/broccoli.png',
    'egg': 'assets/images/foods/eggs.png',
    'milk': 'assets/images/foods/milk.png',
    'chicken': 'assets/images/foods/chicken.png',
    'tomato': 'assets/images/foods/tomato.png',
    'carrot': 'assets/images/foods/carrot.png',
    'banana': 'assets/images/foods/banana.png',
    'orange': 'assets/images/foods/orange.png',
    'grape': 'assets/images/foods/grapes.png',
    'capsicum': 'assets/images/foods/capsicum.png',
    'bell pepper': 'assets/images/foods/capsicum.png',
    'pepper': 'assets/images/foods/capsicum.png',
    'butter': 'assets/images/foods/butter.png',
    'curd': 'assets/images/foods/curd.png',
    'yogurt': 'assets/images/foods/curd.png',
    'fish': 'assets/images/foods/fish.png',
    'salmon': 'assets/images/foods/fish.png',
    'bread': 'assets/images/foods/bread.png',
    'peanut butter': 'assets/images/foods/peanut_butter.png',
    'juice': 'assets/images/foods/juice.png',
    'pea': 'assets/images/foods/frozen_peas.png',
    'peas': 'assets/images/foods/frozen_peas.png',
    'corn': 'assets/images/foods/frozen_corn.png',
    'almond': 'assets/images/foods/almonds.png',
    'cashew': 'assets/images/foods/cashews.png',
    'dry fruit': 'assets/images/foods/dry_fruits_mix.png',
    'avocado': 'assets/images/foods/avocado.png',
    'lemon': 'assets/images/foods/lemon.png',
  };

  /// Finds matching curated transparent cutout if one exists
  static String? findCuratedCutout(String rawName) {
    final canonical = normalizeKey(rawName);
    if (curatedCutouts.containsKey(canonical)) {
      return curatedCutouts[canonical];
    }
    for (final entry in curatedCutouts.entries) {
      if (canonical.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Clean transparent PNG placeholder fallback. Never returns a non-transparent photographic JPG.
  static String getCleanTransparentPlaceholder([String? category]) {
    if (category != null) {
      final cat = category.toLowerCase();
      if (cat.contains('dairy')) return 'assets/images/foods/milk.png';
      if (cat.contains('veg')) return 'assets/images/foods/broccoli.png';
      if (cat.contains('fruit')) return 'assets/images/foods/apple.png';
      if (cat.contains('non-veg')) return 'assets/images/foods/chicken.png';
      if (cat.contains('juice') || cat.contains('drink')) return 'assets/images/foods/juice.png';
    }
    return 'assets/images/foods/apple.png';
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
        final path = localAssets[canonicalKey]!;
        final cutout = (path.endsWith('.png') || path.endsWith('.webp')) ? path : findCuratedCutout(displayName);
        return FoodImageModel(
          entityType: FoodEntityType.ingredient,
          entityKey: canonicalKey,
          displayName: displayName,
          imageUrl: path,
          panCutoutUrl: cutout,
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

    final panCutout = type == FoodEntityType.ingredient
        ? (findCuratedCutout(name) ?? ((placeholderUrl.endsWith('.png') || placeholderUrl.endsWith('.webp')) ? placeholderUrl : getCleanTransparentPlaceholder(category)))
        : null;

    return FoodImageModel(
      entityType: type,
      entityKey: canonicalKey,
      displayName: name,
      imageUrl: placeholderUrl,
      panCutoutUrl: panCutout,
      provider: 'placeholder',
      altDescription: name,
    );
  }

  /// Resolves an image with the authoritative priority order:
  /// 1. User-selected image override
  /// 2. Curated / local asset mapping
  /// 3. Previously saved automatic mapping
  /// 4. Pixabay search & matching via Supabase Edge Function
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

      // Priority 4: Search real food photography via Supabase Edge Function (Pixabay)
      final searchResult = await _invokeEdgeFunction({
        'action': 'resolve',
        'query': canonicalKey,
        'entityType': type.toDbString(),
        'category': category,
        'cuisine': cuisine,
        'orientation': type == FoodEntityType.ingredient ? 'all' : 'horizontal',
      });

      if (searchResult['ok'] == true && searchResult['bestMatch'] != null) {
        final candidate = FoodImageCandidate.fromJson(
          Map<String, dynamic>.from(searchResult['bestMatch'] as Map),
        );

        final curatedCutout = findCuratedCutout(name);
        final serverCutout = searchResult['panCutoutUrl'] as String?;
        final panCutout = type == FoodEntityType.ingredient
            ? (curatedCutout ?? serverCutout ?? getCleanTransparentPlaceholder(category))
            : null;

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
          panCutoutUrl: panCutout,
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

  /// Fast synchronous lookup for transparent pan cutout asset / URL.
  /// If not cached, immediately returns clean transparent placeholder and resolves asynchronously.
  String getPanCutoutSync({
    required String name,
    String? category,
    String? userId,
  }) {
    final canonicalKey = normalizeKey(name);
    final cached = FoodImageRepository.instance.getCachedMapping(
      type: FoodEntityType.ingredient,
      entityKey: canonicalKey,
      userId: userId,
    );
    if (cached?.panCutoutUrl != null && cached!.panCutoutUrl!.isNotEmpty) {
      return cached.panCutoutUrl!;
    }

    // Curated local transparent asset
    final curated = findCuratedCutout(name);
    if (curated != null) {
      return curated;
    }

    // Trigger async cutout resolution
    resolvePanCutout(name: name, category: category, userId: userId);

    return getCleanTransparentPlaceholder(category);
  }

  /// Dedicated resolution for cooking pan transparent cutouts.
  Future<String> resolvePanCutout({
    required String name,
    String? category,
    String? userId,
  }) async {
    final canonicalKey = normalizeKey(name);
    final repo = FoodImageRepository.instance;

    // 1. Check user override for pan cutout
    final saved = await repo.fetchMapping(
      type: FoodEntityType.ingredient,
      entityKey: canonicalKey,
      userId: userId,
    );
    if (saved != null && saved.isPanOverride && saved.panCutoutUrl != null && saved.panCutoutUrl!.isNotEmpty) {
      return saved.panCutoutUrl!;
    }

    // 2. Curated local transparent cutouts
    final curated = findCuratedCutout(name);
    if (curated != null) {
      return curated;
    }

    // 3. Saved shared cutout mapping
    if (saved != null && saved.panCutoutUrl != null && saved.panCutoutUrl!.isNotEmpty) {
      return saved.panCutoutUrl!;
    }

    // 4. Background removal pipeline via Edge Function
    try {
      final res = await _invokeEdgeFunction({
        'action': 'resolve-cutout',
        'query': canonicalKey,
        'imageUrl': saved?.imageUrl,
        'category': category,
      });
      if (res['ok'] == true && res['panCutoutUrl'] != null && (res['panCutoutUrl'] as String).isNotEmpty) {
        final cutoutUrl = res['panCutoutUrl'] as String;
        if (saved != null) {
          final updated = saved.copyWith(panCutoutUrl: cutoutUrl);
          await repo.saveSharedMapping(updated);
        }
        return cutoutUrl;
      }
    } catch (e) {
      debugPrint('[FoodImageResolver] Cutout resolution error: $e');
    }

    // 5. Fallback clean transparent placeholder (never a photographic rectangular JPG)
    return getCleanTransparentPlaceholder(category);
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
