import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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

  /// Cooldown cache for failed resolutions to avoid repeated requests on rebuilds
  final Map<String, DateTime> _failedResolutions = {};

  /// Checks whether an entity image is currently being resolved in the background
  bool isResolving({required FoodEntityType type, required String entityKey}) {
    final inFlightKey = '${type.name}:$entityKey';
    return _inFlight.containsKey(inFlightKey);
  }

  /// Clears any failed resolution cooldown to allow an immediate retry
  void clearFailedResolution({required FoodEntityType type, required String entityKey}) {
    final inFlightKey = '${type.name}:$entityKey';
    _failedResolutions.remove(inFlightKey);
  }

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

    // 4. Strip common quality/preparation adjectives for ingredients (e.g. "fresh", "organic", "raw", "sliced", "wedges")
    clean = clean.replaceAll(RegExp(r'\b(fresh|organic|raw|ripe|pure|extra|whole|chopped|diced|sliced|slices|wedges|pieces|cut|seedless)\b', caseSensitive: false), ' ');

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

  /// Builds a descriptive search query tailored for Pixabay photography (Requirement 4).
  /// E.g. "watermelon" -> "fresh watermelon fruit", "broccoli" -> "whole broccoli", "milk" -> "carton of milk".
  static String buildDescriptiveQuery(String name, FoodEntityType type, [String? category]) {
    final canonical = normalizeKey(name);
    if (type == FoodEntityType.ingredient) {
      if (canonical == 'watermelon') return 'fresh watermelon fruit';
      if (canonical == 'peach') return 'fresh peach fruit';
      if (canonical == 'blueberry') return 'fresh blueberries fruit';
      if (canonical == 'strawberry') return 'fresh strawberries fruit';
      if (canonical == 'broccoli') return 'whole broccoli';
      if (canonical == 'cauliflower') return 'fresh whole cauliflower vegetable';
      if (canonical == 'cabbage') return 'fresh cabbage vegetable';
      if (canonical == 'carrot') return 'fresh carrot vegetable';
      if (canonical == 'milk') return 'carton of milk';
      if (canonical == 'egg' || canonical == 'eggs') return 'fresh eggs';
      if (canonical == 'paneer') return 'fresh paneer';
      if (canonical == 'apple') return 'fresh red apple fruit';
      if (canonical == 'banana') return 'fresh yellow banana';
      if (canonical == 'brinjal' || canonical == 'eggplant' || canonical == 'aubergine') {
        return 'fresh purple eggplant brinjal aubergine';
      }

      if (category != null) {
        final cat = category.toLowerCase();
        if (cat.contains('fruit') && !canonical.contains('fruit')) {
          return 'fresh $canonical fruit';
        }
        if (cat.contains('veg')) {
          return 'fresh $canonical vegetable';
        }
        if (cat.contains('dairy')) {
          return 'fresh $canonical';
        }
      }
      return 'fresh $canonical food';
    } else {
      return '$canonical dish recipe';
    }
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

  /// Clean transparent PNG placeholder fallback. Never returns an unrelated specific food photograph.
  static String getCleanTransparentPlaceholder([String? category]) {
    if (category != null) {
      final cat = category.toLowerCase();
      if (cat.contains('dairy')) return 'assets/images/categories/dairy_products.png';
      if (cat.contains('veg')) return 'assets/images/categories/vegetables.png';
      if (cat.contains('fruit') && !cat.contains('dry')) return 'assets/images/categories/fruits.png';
      if (cat.contains('non-veg') || cat.contains('non veg')) return 'assets/images/categories/non_veg.png';
      if (cat.contains('juice') || cat.contains('drink')) return 'assets/images/categories/juices.png';
      if (cat.contains('ice cream')) return 'assets/images/categories/ice_cream.png';
      if (cat.contains('frozen')) return 'assets/images/categories/frozen_food.png';
      if (cat.contains('dry fruit')) return 'assets/images/categories/dry_fruits.png';
      if (cat.contains('package')) return 'assets/images/categories/packaged_food.png';
      if (cat.contains('meal') || cat.contains('leftover')) return 'assets/images/categories/leftovers.png';
    }
    return 'assets/images/categories/others.png';
  }

  /// Checks if an exact local curated asset mapping exists.
  FoodImageModel? checkCuratedAsset(String canonicalKey, String displayName, FoodEntityType type) {
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
  /// Strictly returns category-level fallbacks; NEVER substitutes an unrelated specific food photograph (e.g. never apple for watermelon).
  FoodImageModel buildPlaceholder({
    required String name,
    required FoodEntityType type,
    String? category,
  }) {
    final canonicalKey = normalizeKey(name);
    String placeholderUrl = 'assets/images/categories/others.png';

    if (type == FoodEntityType.ingredient) {
      placeholderUrl = getCleanTransparentPlaceholder(category);
    } else {
      placeholderUrl = MealImageRegistry.getFallbackAsset(name);
    }

    final panCutout = type == FoodEntityType.ingredient
        ? (findCuratedCutout(name) ?? getCleanTransparentPlaceholder(category))
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

  /// Resolves an image with the authoritative priority order (Requirement 6):
  /// 1. User-uploaded ingredient photograph / override
  /// 2. Previously verified ingredient image from persistent storage
  /// 3. Existing correct local food image (if an exact match exists)
  /// 4. Newly retrieved and verified Pixabay image
  /// 5. Correct category-level fallback image
  /// *Never silently substitute an unrelated food photograph (e.g., never apple for watermelon).*
  Future<FoodImageModel> resolve({
    required String name,
    required FoodEntityType type,
    String? category,
    String? cuisine,
    List<String>? ingredients,
    String? userId,
  }) async {
    final canonicalKey = normalizeKey(name);
    final inFlightKey = '${type.name}:$canonicalKey';

    // 1. Check in-flight deduplication
    if (_inFlight.containsKey(inFlightKey)) {
      return _inFlight[inFlightKey]!;
    }

    // Check failure cooldown (30 seconds) to avoid rapid pounding while allowing timely retry
    final lastFailure = _failedResolutions[inFlightKey];
    if (lastFailure != null && DateTime.now().difference(lastFailure).inSeconds < 30) {
      final cached = FoodImageRepository.instance.getCachedMapping(
        type: type,
        entityKey: canonicalKey,
        userId: userId,
      );
      if (cached != null) return cached;
      return buildPlaceholder(name: name, type: type, category: category);
    }

    final completer = Completer<FoodImageModel>();
    _inFlight[inFlightKey] = completer.future;

    try {
      final repo = FoodImageRepository.instance;

      // Priority 1: User-selected override & Priority 2: Saved / verified mapping from repo/DB
      final savedMapping = await repo.fetchMapping(
        type: type,
        entityKey: canonicalKey,
        userId: userId,
      );

      if (savedMapping != null) {
        _failedResolutions.remove(inFlightKey);
        completer.complete(savedMapping);
        return savedMapping;
      }

      // Priority 3: Existing correct local food image (if an exact match exists, e.g. apple, banana, broccoli, milk, eggs, paneer)
      final curated = checkCuratedAsset(canonicalKey, name, type);
      if (curated != null) {
        _failedResolutions.remove(inFlightKey);
        repo.putInMemoryCache(curated);
        completer.complete(curated);
        return curated;
      }

      // Priority 4: Search real food photography via Pixabay (through backend proxy / Edge Function)
      final descriptiveQuery = buildDescriptiveQuery(name, type, category);
      final searchResult = await _invokeEdgeFunction({
        'action': 'resolve',
        'query': canonicalKey,
        'descriptiveQuery': descriptiveQuery,
        'displayName': name,
        'entityType': type.toDbString(),
        'category': category,
        'cuisine': cuisine,
        'ingredients': ingredients,
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

        _failedResolutions.remove(inFlightKey);
        await repo.saveSharedMapping(resolvedModel);
        completer.complete(resolvedModel);
        return resolvedModel;
      }

      // Mark failure cooldown if no acceptable candidate found (do not permanently cache placeholder)
      _failedResolutions[inFlightKey] = DateTime.now();

      // Priority 5: Fallback category placeholder (never an unrelated specific food photograph)
      final placeholder = buildPlaceholder(name: name, type: type, category: category);
      completer.complete(placeholder);
      return placeholder;
    } catch (e) {
      debugPrint('[FoodImageResolver] Error resolving $name: $e');
      _failedResolutions[inFlightKey] = DateTime.now();
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

    // Priority 3: If verified Fridge photograph is already in cache, return it as fallback
    if (cached != null && !cached.isPlaceholder && cached.imageUrl.isNotEmpty) {
      return cached.imageUrl;
    }

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

    // Priority 3: Fallback to exact verified Fridge photograph if available
    if (saved != null && !saved.isPlaceholder && saved.imageUrl.isNotEmpty) {
      return saved.imageUrl;
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

  /// Mirrors a selected Pixabay image to permanent Supabase Storage via Edge Function to prevent hotlinking.
  Future<String> mirrorToStorage({
    required String photoId,
    required String imageUrl,
    required FoodEntityType type,
    required String entityKey,
  }) async {
    try {
      final res = await _invokeEdgeFunction({
        'action': 'mirror',
        'query': entityKey,
        'entityType': type.toDbString(),
        'photoId': photoId,
        'imageUrl': imageUrl,
      });
      if (res['ok'] == true && res['persistentUrl'] != null && (res['persistentUrl'] as String).isNotEmpty) {
        return res['persistentUrl'] as String;
      }
    } catch (e) {
      debugPrint('[FoodImageResolver] mirrorToStorage error: $e');
    }
    return imageUrl;
  }

  /// Dispatches the request to the `food-image` Edge Function with auth credentials or mock override.
  Future<Map<String, dynamic>> invokeEdgeFunction(Map<String, dynamic> body) =>
      _invokeEdgeFunction(body);

  Future<Map<String, dynamic>> _invokeEdgeFunction(Map<String, dynamic> body) async {
    if (mockHandler != null) {
      return await mockHandler!(body);
    }

    if (MockDataRepository.forceInMemoryForTesting) {
      return {'ok': false, 'error': 'IN_MEMORY_TESTING'};
    }

    try {
      SupabaseClient? client;
      try {
        client = Supabase.instance.client;
      } catch (_) {
        client = null;
      }

      if (client != null) {
        final session = client.auth.currentSession;
        final token = session?.accessToken;

        final headers = <String, String>{};
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        } else if (SupabaseConfig.isConfigured && SupabaseConfig.supabasePublishableKey.isNotEmpty) {
          headers['Authorization'] = 'Bearer ${SupabaseConfig.supabasePublishableKey}';
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
        } else if (data is String) {
          try {
            final decoded = jsonDecode(data);
            if (decoded is Map) {
              return Map<String, dynamic>.from(decoded);
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[FoodImageResolver] _invokeEdgeFunction warning: $e');
    }

    // Direct HTTP fallback to Supabase Edge Function URL
    if (SupabaseConfig.isConfigured && SupabaseConfig.supabasePublishableKey.isNotEmpty) {
      try {
        final uri = Uri.parse('${SupabaseConfig.supabaseUrl}/functions/v1/food-image');
        final httpHeaders = <String, String>{
          'Content-Type': 'application/json',
          'apikey': SupabaseConfig.supabasePublishableKey,
          'Authorization': 'Bearer ${SupabaseConfig.supabasePublishableKey}',
        };
        final response = await http.post(
          uri,
          headers: httpHeaders,
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map) {
            return Map<String, dynamic>.from(decoded);
          }
        }
      } catch (httpErr) {
        debugPrint('[FoodImageResolver] direct http fallback error: $httpErr');
      }
    }

    return {'ok': false, 'error': 'EDGE_FUNCTION_UNAVAILABLE'};
  }
}
