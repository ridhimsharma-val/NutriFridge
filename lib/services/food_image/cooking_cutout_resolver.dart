import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../screens/fridge/models/category_item.dart';
import 'food_image_model.dart';
import 'food_image_repository.dart';
import 'food_image_resolver.dart';
import 'food_image_service.dart';

/// The result of resolving an ingredient's imagery for the Cooking Workspace.
///
/// Follows the 3-tier priority:
/// 1. Priority 1: Existing transparent PNG/WebP cutout.
/// 2. Priority 2: Automatically generated cutout with background removed.
/// 3. Priority 3: Exact verified Fridge photograph fallback (never an emoji or unrelated food).
@immutable
class CookingCutoutResult {
  /// The local asset path or remote image URL.
  final String imagePath;

  /// True if this image is an isolated transparent cutout (.png / .webp).
  final bool isTransparentCutout;

  /// True if imagePath is a network URL.
  final bool isNetwork;

  /// Canonical key of the ingredient (e.g. 'brinjal', 'cabbage', 'apple').
  final String canonicalKey;

  /// Display name of the ingredient.
  final String displayName;

  /// True when this result is a Priority 3 fallback to the verified Fridge photograph.
  final bool isFridgePhotoFallback;

  const CookingCutoutResult({
    required this.imagePath,
    required this.isTransparentCutout,
    required this.isNetwork,
    required this.canonicalKey,
    required this.displayName,
    this.isFridgePhotoFallback = false,
  });

  @override
  String toString() =>
      'CookingCutoutResult(path: $imagePath, isCutout: $isTransparentCutout, isFallback: $isFridgePhotoFallback)';
}

/// Centralized resolver that delivers clean, isolated, transparent-background ingredient cutouts
/// wherever individual ingredients are represented in the Cooking Workspace:
/// - Inside the cooking pan basin.
/// - During flying ingredient toss animations.
/// - In the selected ingredient chips and carousel cards.
class CookingCutoutResolver {
  static final Map<String, Future<CookingCutoutResult>> _inFlight = {};
  static final Set<String> _failedCutoutAttempts = {};

  /// Optional mock cutout generator for testing or local image-processing pipelines.
  /// Signature: (canonicalKey, sourceImageUrl) -> returns transparent cutout URL/path or null if failed.
  static Future<String?> Function(String canonicalKey, String sourceImageUrl)? mockCutoutGenerator;

  /// Checks if a file path or URL points to a transparent PNG/WebP cutout asset.
  static bool isCutoutAsset(String path) {
    if (path.isEmpty) return false;
    final lower = path.toLowerCase();
    // Transparent category graphics in assets/images/categories are clean PNG cutouts
    if (lower.contains('assets/images/categories/')) return true;
    return lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.contains('.png?') ||
        lower.contains('.webp?') ||
        lower.contains('food-photos/cutouts') ||
        lower.contains('/cutouts/') ||
        lower.contains('cutout');
  }

  /// Fast synchronous resolution for UI building.
  ///
  /// Priority:
  /// 1. Dedicated transparent cutout from repository cache or curated local assets.
  /// 2. If no cutout exists, triggers asynchronous background removal generation and returns:
  /// 3. Priority 3 fallback: Exact verified Fridge photograph for this ingredient.
  static CookingCutoutResult resolveSync(CategoryFoodItem item, {String? userId}) {
    final name = item.name;
    final canonicalKey = FoodImageResolver.normalizeKey(name);

    // ─── Priority 1: Existing Cutout ──────────────────────────────
    // 1.1 Check repository cache for dedicated panCutoutUrl
    final cached = FoodImageRepository.instance.getCachedMapping(
      type: FoodEntityType.ingredient,
      entityKey: canonicalKey,
      userId: userId,
    );

    if (cached != null && cached.panCutoutUrl != null && cached.panCutoutUrl!.isNotEmpty) {
      final cutout = cached.panCutoutUrl!;
      final isCutout = isCutoutAsset(cutout);
      return CookingCutoutResult(
        imagePath: cutout,
        isTransparentCutout: isCutout,
        isNetwork: cutout.startsWith('http://') || cutout.startsWith('https://'),
        canonicalKey: canonicalKey,
        displayName: name,
        isFridgePhotoFallback: !isCutout,
      );
    }

    // 1.2 Check curated local transparent asset (e.g. apple, banana, broccoli, paneer, tomato...)
    final curated = FoodImageResolver.findCuratedCutout(name);
    if (curated != null) {
      return CookingCutoutResult(
        imagePath: curated,
        isTransparentCutout: true,
        isNetwork: false,
        canonicalKey: canonicalKey,
        displayName: name,
      );
    }

    // 1.3 Check item's explicit imageAsset if it is a transparent PNG/WebP
    if (item.imageAsset != null &&
        item.imageAsset!.isNotEmpty &&
        isCutoutAsset(item.imageAsset!)) {
      final isNet = item.imageAsset!.startsWith('http://') || item.imageAsset!.startsWith('https://');
      return CookingCutoutResult(
        imagePath: item.imageAsset!,
        isTransparentCutout: true,
        isNetwork: isNet,
        canonicalKey: canonicalKey,
        displayName: name,
      );
    }

    // ─── Priority 2: Trigger Async Background Removal Generation ──
    if (!_failedCutoutAttempts.contains(canonicalKey)) {
      resolveByNameAsync(name: name, category: item.category, userId: userId);
    }

    // ─── Priority 3: Fridge Image Fallback ─────────────────────────
    // 3.1 Check cached verified Fridge photograph
    if (cached != null && !cached.isPlaceholder && cached.imageUrl.isNotEmpty) {
      final photo = cached.imageUrl;
      final isCutout = isCutoutAsset(photo);
      return CookingCutoutResult(
        imagePath: photo,
        isTransparentCutout: isCutout,
        isNetwork: photo.startsWith('http://') || photo.startsWith('https://'),
        canonicalKey: canonicalKey,
        displayName: name,
        isFridgePhotoFallback: !isCutout,
      );
    }

    // 3.2 Check item's explicit imageAsset (e.g. cabbage.jpg)
    if (item.imageAsset != null && item.imageAsset!.isNotEmpty) {
      final photo = item.imageAsset!;
      final isCutout = isCutoutAsset(photo);
      return CookingCutoutResult(
        imagePath: photo,
        isTransparentCutout: isCutout,
        isNetwork: photo.startsWith('http://') || photo.startsWith('https://'),
        canonicalKey: canonicalKey,
        displayName: name,
        isFridgePhotoFallback: !isCutout,
      );
    }

    // 3.3 Synchronous curated asset check
    final curatedAsset = FoodImageResolver.instance.checkCuratedAsset(
      canonicalKey,
      name,
      FoodEntityType.ingredient,
    );
    if (curatedAsset != null) {
      final photo = curatedAsset.imageUrl;
      final isCutout = isCutoutAsset(photo);
      return CookingCutoutResult(
        imagePath: photo,
        isTransparentCutout: isCutout,
        isNetwork: false,
        canonicalKey: canonicalKey,
        displayName: name,
        isFridgePhotoFallback: !isCutout,
      );
    }

    // 3.4 Neutral transparent category placeholder while initial loading
    final placeholder = FoodImageResolver.getCleanTransparentPlaceholder(item.category);
    return CookingCutoutResult(
      imagePath: placeholder,
      isTransparentCutout: true,
      isNetwork: false,
      canonicalKey: canonicalKey,
      displayName: name,
      isFridgePhotoFallback: false,
    );
  }

  /// Asynchronous resolution that automatically executes background removal (Priority 2)
  /// and stores the resulting cutout for reuse across future sessions.
  static Future<CookingCutoutResult> resolveByNameAsync({
    required String name,
    String? category,
    String? userId,
  }) async {
    final canonicalKey = FoodImageResolver.normalizeKey(name);
    final inFlightKey = 'cutout:$canonicalKey';

    if (_inFlight.containsKey(inFlightKey)) {
      return await _inFlight[inFlightKey]!;
    }

    final completer = Completer<CookingCutoutResult>();
    _inFlight[inFlightKey] = completer.future;

    try {
      final repo = FoodImageRepository.instance;

      // 1. Priority 1: Check existing cutout in database / local storage
      final saved = await repo.fetchMapping(
        type: FoodEntityType.ingredient,
        entityKey: canonicalKey,
        userId: userId,
      );

      if (saved != null && saved.panCutoutUrl != null && saved.panCutoutUrl!.isNotEmpty) {
        final cutout = saved.panCutoutUrl!;
        final res = CookingCutoutResult(
          imagePath: cutout,
          isTransparentCutout: isCutoutAsset(cutout),
          isNetwork: cutout.startsWith('http://') || cutout.startsWith('https://'),
          canonicalKey: canonicalKey,
          displayName: name,
        );
        completer.complete(res);
        return res;
      }

      // Check curated local transparent cutouts
      final curated = FoodImageResolver.findCuratedCutout(name);
      if (curated != null) {
        final res = CookingCutoutResult(
          imagePath: curated,
          isTransparentCutout: true,
          isNetwork: false,
          canonicalKey: canonicalKey,
          displayName: name,
        );
        completer.complete(res);
        return res;
      }

      // 2. Priority 2: Automatically Generate Cutout via Background Removal
      // Retrieve the ingredient's verified photograph through existing FoodImageService
      final fridgeModel = saved ??
          await FoodImageService.instance.resolveImage(
            name: name,
            type: FoodEntityType.ingredient,
            category: category,
            userId: userId,
          );

      String? generatedCutout;

      // Use mock generator if set (for tests / custom pipelines)
      if (mockCutoutGenerator != null) {
        generatedCutout = await mockCutoutGenerator!(canonicalKey, fridgeModel.imageUrl);
      } else {
        // Edge Function background removal pipeline
        try {
          final res = await FoodImageResolver.instance.invokeEdgeFunction({
            'action': 'resolve-cutout',
            'query': canonicalKey,
            'imageUrl': fridgeModel.imageUrl,
            'category': category,
          });

          if (res['ok'] == true &&
              res['panCutoutUrl'] != null &&
              (res['panCutoutUrl'] as String).isNotEmpty) {
            generatedCutout = res['panCutoutUrl'] as String;
          }
        } catch (bgError) {
          debugPrint('[CookingCutoutResolver] Background removal error: $bgError');
        }
      }

      if (generatedCutout != null &&
          generatedCutout.isNotEmpty &&
          isCutoutAsset(generatedCutout)) {
        // Cutout generation succeeded! Store in panCutoutUrl on the shared mapping
        final updated = fridgeModel.copyWith(panCutoutUrl: generatedCutout);
        await repo.saveSharedMapping(updated);
        FoodImageService.instance.notifyListeners();

        final res = CookingCutoutResult(
          imagePath: generatedCutout,
          isTransparentCutout: true,
          isNetwork: generatedCutout.startsWith('http://') || generatedCutout.startsWith('https://'),
          canonicalKey: canonicalKey,
          displayName: name,
        );
        completer.complete(res);
        return res;
      }

      // Cutout generation failed or is unavailable: record in failure set to prevent hammering
      _failedCutoutAttempts.add(canonicalKey);

      // 3. Priority 3: Fridge Image Fallback
      // Use the exact verified ingredient photograph already displayed in the Fridge
      if (!fridgeModel.isPlaceholder && fridgeModel.imageUrl.isNotEmpty) {
        final photo = fridgeModel.imageUrl;
        final isCutout = isCutoutAsset(photo);
        final res = CookingCutoutResult(
          imagePath: photo,
          isTransparentCutout: isCutout,
          isNetwork: photo.startsWith('http://') || photo.startsWith('https://'),
          canonicalKey: canonicalKey,
          displayName: name,
          isFridgePhotoFallback: !isCutout,
        );
        completer.complete(res);
        return res;
      }

      // Final transparent category placeholder
      final placeholder = FoodImageResolver.getCleanTransparentPlaceholder(category);
      final res = CookingCutoutResult(
        imagePath: placeholder,
        isTransparentCutout: true,
        isNetwork: false,
        canonicalKey: canonicalKey,
        displayName: name,
        isFridgePhotoFallback: false,
      );
      completer.complete(res);
      return res;
    } catch (e) {
      _failedCutoutAttempts.add(canonicalKey);
      final fallback = FoodImageService.instance.getImageSync(
        name: name,
        type: FoodEntityType.ingredient,
        category: category,
        userId: userId,
      );
      final path = (!fallback.isPlaceholder && fallback.imageUrl.isNotEmpty)
          ? fallback.imageUrl
          : FoodImageResolver.getCleanTransparentPlaceholder(category);

      final res = CookingCutoutResult(
        imagePath: path,
        isTransparentCutout: isCutoutAsset(path),
        isNetwork: path.startsWith('http://') || path.startsWith('https://'),
        canonicalKey: canonicalKey,
        displayName: name,
        isFridgePhotoFallback: !isCutoutAsset(path),
      );
      completer.complete(res);
      return res;
    } finally {
      _inFlight.remove(inFlightKey);
    }
  }

  /// Clears in-flight and failed tracking for testing
  @visibleForTesting
  static void resetForTesting() {
    _inFlight.clear();
    _failedCutoutAttempts.clear();
    mockCutoutGenerator = null;
  }
}
