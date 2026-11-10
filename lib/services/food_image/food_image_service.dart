import 'package:flutter/foundation.dart';
import 'food_image_model.dart';
import 'food_image_repository.dart';
import 'food_image_resolver.dart';

/// Centralized food image service used throughout NutriFridge.
class FoodImageService {
  static final FoodImageService instance = FoodImageService._internal();
  FoodImageService._internal();

  /// Change notifier broadcasting when an image mapping is updated or overridden
  final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  void _notify() {
    changeNotifier.value++;
  }

  /// Resolves an image asynchronously following the 5-tier priority order.
  Future<FoodImageModel> resolveImage({
    required String name,
    required FoodEntityType type,
    String? category,
    String? cuisine,
    String? userId,
  }) async {
    final model = await FoodImageResolver.instance.resolve(
      name: name,
      type: type,
      category: category,
      cuisine: cuisine,
      userId: userId,
    );
    _notify();
    return model;
  }

  /// Fast synchronous lookup: returns cached model if available;
  /// otherwise returns a clean placeholder immediately and triggers background resolution.
  FoodImageModel getImageSync({
    required String name,
    required FoodEntityType type,
    String? category,
    String? userId,
  }) {
    final canonicalKey = FoodImageResolver.normalizeKey(name);
    final cached = FoodImageRepository.instance.getCachedMapping(
      type: type,
      entityKey: canonicalKey,
      userId: userId,
    );

    if (cached != null) return cached;

    // Trigger background resolution lazily without blocking widget build
    resolveImage(
      name: name,
      type: type,
      category: category,
      userId: userId,
    );

    return FoodImageResolver.instance.buildPlaceholder(
      name: name,
      type: type,
      category: category,
    );
  }

  /// Sets a manual image override for an ingredient or recipe for the current user.
  Future<FoodImageModel> setUserOverride({
    required String name,
    required FoodEntityType type,
    required FoodImageCandidate candidate,
    String? userId,
  }) async {
    final canonicalKey = FoodImageResolver.normalizeKey(name);
    final override = await FoodImageRepository.instance.saveUserOverride(
      type: type,
      entityKey: canonicalKey,
      displayName: name,
      candidate: candidate,
      userId: userId,
    );
    _notify();
    return override;
  }

  /// Restores the automatic image selection by removing any user override.
  Future<FoodImageModel> restoreAutomaticImage({
    required String name,
    required FoodEntityType type,
    String? category,
    String? userId,
  }) async {
    final canonicalKey = FoodImageResolver.normalizeKey(name);
    await FoodImageRepository.instance.removeUserOverride(
      type: type,
      entityKey: canonicalKey,
      userId: userId,
    );
    _notify();

    // Re-resolve automatic image
    return await resolveImage(
      name: name,
      type: type,
      category: category,
      userId: userId,
    );
  }

  /// Searches image provider candidates for manual replacement.
  Future<List<FoodImageCandidate>> searchCandidates({
    required String query,
    required FoodEntityType type,
    int perPage = 8,
  }) {
    return FoodImageResolver.instance.searchCandidates(
      query: query,
      type: type,
      perPage: perPage,
    );
  }

  /// Checks if the current entity has an active user override.
  bool hasUserOverride({
    required String name,
    required FoodEntityType type,
    String? userId,
  }) {
    final canonicalKey = FoodImageResolver.normalizeKey(name);
    final cached = FoodImageRepository.instance.getCachedMapping(
      type: type,
      entityKey: canonicalKey,
      userId: userId,
    );
    return cached?.isUserOverride == true;
  }

  /// Clears caches for testing.
  @visibleForTesting
  void resetForTesting() {
    FoodImageRepository.instance.clearMemoryCache();
    FoodImageResolver.mockHandler = null;
    _notify();
  }
}
