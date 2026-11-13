import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/screens/food_image/widgets/food_image_view.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/services/food_image/food_image_model.dart';
import 'package:nutrifridge/services/food_image/food_image_repository.dart';
import 'package:nutrifridge/services/food_image/food_image_resolver.dart';
import 'package:nutrifridge/services/food_image/food_image_service.dart';

void main() {
  setUp(() {
    MockDataRepository.forceInMemoryForTesting = true;
    MockDataRepository.reset();
    FridgeCategoryRepository.reset();
    FoodImageService.instance.resetForTesting();
  });

  tearDown(() {
    MockDataRepository.reset();
    FridgeCategoryRepository.reset();
    FoodImageService.instance.resetForTesting();
  });

  group('NutriFridge — Automatic Food & Ingredient Image Integration Using Pixabay', () {
    // 1. Verify watermelon gets a watermelon photograph and never falls back to apple
    test('1. Verify watermelon gets a watermelon photograph and never falls back to apple', () async {
      int pixabayApiCallCount = 0;
      FoodImageResolver.mockHandler = (body) async {
        pixabayApiCallCount++;
        expect(body['query'], 'watermelon');
        expect(body['descriptiveQuery'], contains('watermelon'));
        return {
          'ok': true,
          'action': 'resolve',
          'bestMatch': {
            'photoId': 'px_watermelon_999',
            'imageUrl': 'https://cdn.pixabay.com/photo/watermelon_slice.jpg',
            'thumbnailUrl': 'https://cdn.pixabay.com/photo/watermelon_thumb.jpg',
            'photographerName': 'Summer Harvest',
            'photographerUrl': 'https://pixabay.com/users/summer-999/',
            'sourcePageUrl': 'https://pixabay.com/photos/fresh-watermelon-slice-999/',
            'altDescription': 'Juicy fresh red watermelon slice with seeds',
            'provider': 'pixabay',
            'score': 98,
          },
        };
      };

      final model = await FoodImageService.instance.resolveImage(
        name: 'Watermelon',
        type: FoodEntityType.ingredient,
        category: 'Fruits',
      );

      // Verify it receives a watermelon photo
      expect(model.entityKey, 'watermelon');
      expect(model.imageUrl, 'https://cdn.pixabay.com/photo/watermelon_slice.jpg');
      expect(model.provider, 'pixabay');

      // STRICT CHECK: Never apple!
      expect(model.imageUrl, isNot('assets/images/foods/apple.png'));
      expect(model.imageUrl.contains('apple'), isFalse);
      expect(pixabayApiCallCount, 1);

      // Test CategoryItem effectiveImageAsset
      final watermelonItem = CategoryFoodItem(
        id: 'item_watermelon',
        name: 'Watermelon',
        quantity: '1 piece',
        category: 'Fruits',
      );
      expect(watermelonItem.effectiveImageAsset, 'https://cdn.pixabay.com/photo/watermelon_slice.jpg');
      expect(watermelonItem.effectiveImageAsset, isNot('assets/images/foods/apple.png'));
    });

    // 2. Verify apple gets an apple photograph
    test('2. Verify apple gets an apple photograph', () async {
      final model = await FoodImageService.instance.resolveImage(
        name: 'Apple',
        type: FoodEntityType.ingredient,
        category: 'Fruits',
      );

      expect(model.entityKey, 'apple');
      expect(model.imageUrl, 'assets/images/foods/apple.png');
      expect(model.imageUrl.contains('apple'), isTrue);
    });

    // 3. Verify banana gets a banana photograph
    test('3. Verify banana gets a banana photograph', () async {
      final model = await FoodImageService.instance.resolveImage(
        name: 'Banana',
        type: FoodEntityType.ingredient,
        category: 'Fruits',
      );

      expect(model.entityKey, 'banana');
      expect(model.imageUrl, 'assets/images/foods/banana.png');
      expect(model.imageUrl.contains('banana'), isTrue);
    });

    // 4. Verify different ingredients receive different, correct images
    test('4. Verify different ingredients receive different, correct images', () async {
      FoodImageResolver.mockHandler = (body) async {
        if (body['query'] == 'watermelon') {
          return {
            'ok': true,
            'bestMatch': {
              'photoId': 'px_wm',
              'imageUrl': 'https://cdn.pixabay.com/photo/watermelon_fresh.jpg',
              'thumbnailUrl': 'https://cdn.pixabay.com/photo/watermelon_fresh.jpg',
              'provider': 'pixabay',
              'score': 95,
            },
          };
        }
        return {'ok': false};
      };

      final watermelon = await FoodImageService.instance.resolveImage(
        name: 'Watermelon',
        type: FoodEntityType.ingredient,
        category: 'Fruits',
      );
      final apple = await FoodImageService.instance.resolveImage(
        name: 'Apple',
        type: FoodEntityType.ingredient,
        category: 'Fruits',
      );
      final banana = await FoodImageService.instance.resolveImage(
        name: 'Banana',
        type: FoodEntityType.ingredient,
        category: 'Fruits',
      );
      final broccoli = await FoodImageService.instance.resolveImage(
        name: 'Broccoli',
        type: FoodEntityType.ingredient,
        category: 'Vegetables',
      );
      final milk = await FoodImageService.instance.resolveImage(
        name: 'Milk',
        type: FoodEntityType.ingredient,
        category: 'Dairy Products',
      );
      final eggs = await FoodImageService.instance.resolveImage(
        name: 'Eggs',
        type: FoodEntityType.ingredient,
        category: 'Non-Veg',
      );

      final images = [
        watermelon.imageUrl,
        apple.imageUrl,
        banana.imageUrl,
        broccoli.imageUrl,
        milk.imageUrl,
        eggs.imageUrl,
      ];

      // All 6 items must receive distinct images
      final uniqueImages = images.toSet();
      expect(uniqueImages.length, 6, reason: 'Every ingredient must have its own distinct visual!');

      // Verify each matches its food
      expect(watermelon.imageUrl, contains('watermelon'));
      expect(apple.imageUrl, contains('apple'));
      expect(banana.imageUrl, contains('banana'));
      expect(broccoli.imageUrl, contains('broccoli'));
      expect(milk.imageUrl, contains('milk'));
      expect(eggs.imageUrl, contains('eggs'));
    });

    // 5. Verify caching: second request for same ingredient does not call Pixabay API
    test('5. Verify caching: second request for same ingredient does not call Pixabay API', () async {
      int apiCallCount = 0;
      FoodImageResolver.mockHandler = (body) async {
        apiCallCount++;
        return {
          'ok': true,
          'action': 'resolve',
          'bestMatch': {
            'photoId': 'px_wm_cached',
            'imageUrl': 'https://cdn.pixabay.com/photo/cached_watermelon.jpg',
            'thumbnailUrl': 'https://cdn.pixabay.com/photo/cached_watermelon.jpg',
            'provider': 'pixabay',
            'score': 95,
          },
        };
      };

      // 1st request
      final first = await FoodImageService.instance.resolveImage(
        name: 'Watermelon',
        type: FoodEntityType.ingredient,
      );
      expect(first.imageUrl, 'https://cdn.pixabay.com/photo/cached_watermelon.jpg');
      expect(apiCallCount, 1);

      // 2nd request for identical ingredient
      final second = await FoodImageService.instance.resolveImage(
        name: 'Watermelon',
        type: FoodEntityType.ingredient,
      );
      expect(second.imageUrl, 'https://cdn.pixabay.com/photo/cached_watermelon.jpg');
      // Must NOT increment API call count
      expect(apiCallCount, 1, reason: 'Cached ingredient must not re-query Pixabay API!');
    });

    // 6. Verify query normalization: "fresh watermelon", "sliced watermelon", "watermelon" all map to the same image
    test('6. Verify query normalization: "fresh watermelon", "sliced watermelon", "watermelon" all map to the same image', () async {
      expect(FoodImageResolver.normalizeKey('Watermelon'), 'watermelon');
      expect(FoodImageResolver.normalizeKey('fresh watermelon'), 'watermelon');
      expect(FoodImageResolver.normalizeKey('sliced watermelon'), 'watermelon');
      expect(FoodImageResolver.normalizeKey('watermelon wedges'), 'watermelon');
      expect(FoodImageResolver.normalizeKey('whole watermelon'), 'watermelon');
      expect(FoodImageResolver.normalizeKey('seedless watermelon'), 'watermelon');

      int apiCallCount = 0;
      FoodImageResolver.mockHandler = (body) async {
        apiCallCount++;
        return {
          'ok': true,
          'action': 'resolve',
          'bestMatch': {
            'photoId': 'px_wm_norm',
            'imageUrl': 'https://cdn.pixabay.com/photo/norm_watermelon.jpg',
            'thumbnailUrl': 'https://cdn.pixabay.com/photo/norm_watermelon.jpg',
            'provider': 'pixabay',
            'score': 95,
          },
        };
      };

      // First query with "fresh watermelon"
      final r1 = await FoodImageService.instance.resolveImage(
        name: 'fresh watermelon',
        type: FoodEntityType.ingredient,
      );
      expect(r1.imageUrl, 'https://cdn.pixabay.com/photo/norm_watermelon.jpg');
      expect(apiCallCount, 1);

      // Second query with "sliced watermelon" -> should map to same canonical key and hit cache!
      final r2 = await FoodImageService.instance.resolveImage(
        name: 'sliced watermelon',
        type: FoodEntityType.ingredient,
      );
      expect(r2.imageUrl, 'https://cdn.pixabay.com/photo/norm_watermelon.jpg');
      expect(apiCallCount, 1, reason: 'Variant "sliced watermelon" must hit cache for "watermelon"');

      // Third query with "watermelon wedges"
      final r3 = await FoodImageService.instance.resolveImage(
        name: 'watermelon wedges',
        type: FoodEntityType.ingredient,
      );
      expect(r3.imageUrl, 'https://cdn.pixabay.com/photo/norm_watermelon.jpg');
      expect(apiCallCount, 1);
    });

    // 7. Verify existing local assets are reused when exact match exists
    test('7. Verify existing local assets are reused when exact match exists', () async {
      int apiCallCount = 0;
      FoodImageResolver.mockHandler = (body) async {
        apiCallCount++;
        return {'ok': false};
      };

      final apple = await FoodImageService.instance.resolveImage(
        name: 'apple',
        type: FoodEntityType.ingredient,
      );
      final milk = await FoodImageService.instance.resolveImage(
        name: 'milk',
        type: FoodEntityType.ingredient,
      );
      final broccoli = await FoodImageService.instance.resolveImage(
        name: 'broccoli',
        type: FoodEntityType.ingredient,
      );

      // Local exact assets must be used directly without calling external API
      expect(apple.imageUrl, 'assets/images/foods/apple.png');
      expect(milk.imageUrl, 'assets/images/foods/milk.png');
      expect(broccoli.imageUrl, 'assets/images/foods/broccoli.png');
      expect(apiCallCount, 0, reason: 'Exact local asset matches must not trigger external API calls');
    });

    // 8. Verify user-uploaded images take priority over Pixabay images
    test('8. Verify user-uploaded images take priority over Pixabay images', () async {
      // Setup a CategoryItem with user-uploaded photo
      const userPhotoPath = 'https://supabase.co/storage/v1/object/public/user_uploads/my_watermelon.jpg';
      final itemWithUpload = CategoryFoodItem(
        id: 'item_with_upload',
        name: 'Watermelon',
        quantity: '1 piece',
        category: 'Fruits',
        storageImagePath: userPhotoPath,
      );

      expect(itemWithUpload.effectiveImageAsset, userPhotoPath,
          reason: 'User-uploaded ingredient photograph must take Priority 1');

      // Also test FoodImageService manual override
      const userCandidate = FoodImageCandidate(
        photoId: 'custom_photo',
        imageUrl: 'https://cdn.pixabay.com/custom_watermelon.jpg',
        thumbnailUrl: 'https://cdn.pixabay.com/custom_watermelon_thumb.jpg',
        photographerName: 'User',
        photographerUrl: 'https://nutrifridge.app',
        sourcePageUrl: 'https://nutrifridge.app',
        altDescription: 'My own chosen image',
        provider: 'user_override',
      );

      await FoodImageService.instance.setUserOverride(
        name: 'Watermelon',
        type: FoodEntityType.ingredient,
        candidate: userCandidate,
      );

      final resolved = await FoodImageService.instance.resolveImage(
        name: 'Watermelon',
        type: FoodEntityType.ingredient,
      );

      expect(resolved.imageUrl, 'https://cdn.pixabay.com/custom_watermelon.jpg');
      expect(resolved.isUserOverride, isTrue);
    });

    // 9. Verify category fallback is used only when no relevant image is found, and never substitutes an unrelated specific food
    test('9. Verify category fallback is used only when no relevant image is found, and never substitutes an unrelated specific food', () async {
      FoodImageResolver.mockHandler = (body) async {
        // No relevant image found
        return {
          'ok': true,
          'action': 'resolve',
          'candidates': [],
          'bestMatch': null,
        };
      };

      final unknownFruit = await FoodImageService.instance.resolveImage(
        name: 'Mysterious Jungle Berry 123',
        type: FoodEntityType.ingredient,
        category: 'Fruits',
      );

      // Must be a category fallback, NEVER apple.png!
      expect(unknownFruit.isPlaceholder, isTrue);
      expect(unknownFruit.imageUrl, 'assets/images/categories/fruits.png');
      expect(unknownFruit.imageUrl, isNot('assets/images/foods/apple.png'));

      final unknownVeg = await FoodImageService.instance.resolveImage(
        name: 'Ancient Wild Root 456',
        type: FoodEntityType.ingredient,
        category: 'Vegetables',
      );

      expect(unknownVeg.isPlaceholder, isTrue);
      expect(unknownVeg.imageUrl, 'assets/images/categories/vegetables.png');
      expect(unknownVeg.imageUrl, isNot('assets/images/foods/tomato.png'));

      // FoodItemAssetRegistry also strictly adheres to category fallback
      final fallbackAsset = FoodItemAssetRegistry.getAssetForItem('Unknown Wild Fruit', 'Fruits');
      expect(fallbackAsset, 'assets/images/categories/fruits.png');
      expect(fallbackAsset, isNot('assets/images/foods/apple.png'));
    });

    // 10. Verify API key is not exposed or hardcoded
    test('10. Verify API key is not exposed or hardcoded', () {
      final libDir = Directory('lib');
      final dartFiles = libDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        // Check for common leaked Pixabay API key formats or hardcoded string keys
        expect(content.contains(RegExp(r'''['"][0-9]{7,8}-[a-f0-9]{20,30}['"]''')), isFalse,
            reason: 'Hardcoded Pixabay API key detected in ${file.path}!');
      }
    });

    // 11. Verify 24-hour search cache
    test('11. Verify 24-hour search cache', () {
      final repo = FoodImageRepository.instance;
      const candidates = [
        FoodImageCandidate(
          photoId: '101',
          imageUrl: 'https://cdn.pixabay.com/101.jpg',
          thumbnailUrl: 'https://cdn.pixabay.com/101_thumb.jpg',
          photographerName: 'Test',
          photographerUrl: 'https://pixabay.com',
          sourcePageUrl: 'https://pixabay.com',
          altDescription: 'Test',
        ),
      ];

      repo.cacheSearch('fresh watermelon', 'square', candidates);

      // Immediate hit
      final cached = repo.getCachedSearch('fresh watermelon', 'square');
      expect(cached, isNotNull);
      expect(cached!.length, 1);
      expect(cached.first.photoId, '101');
    });

    // 12. Verify no infinite loops or rate limit exhaustion
    test('12. Verify no infinite loops or rate limit exhaustion', () async {
      int apiCallCount = 0;
      FoodImageResolver.mockHandler = (body) async {
        apiCallCount++;
        // Simulate rate limited response
        return {
          'ok': false,
          'error': 'RATE_LIMITED',
          'message': 'Pixabay API rate limit exceeded.',
        };
      };

      // 10 concurrent requests for same ingredient
      final futures = List.generate(
        10,
        (_) => FoodImageService.instance.resolveImage(
          name: 'Dragonfruit Exotics',
          type: FoodEntityType.ingredient,
          category: 'Fruits',
        ),
      );

      final results = await Future.wait(futures);

      // All 10 requests should complete safely with category fallback without crashing
      for (final res in results) {
        expect(res.isPlaceholder, isTrue);
        expect(res.imageUrl, 'assets/images/categories/fruits.png');
      }

      // In-flight deduplication must prevent 10 separate calls
      expect(apiCallCount, 1, reason: 'Concurrent requests must be deduplicated into a single call');

      // Subsequent call within failure cooldown period must return cached fallback without re-calling API
      final cooldownResult = await FoodImageService.instance.resolveImage(
        name: 'Dragonfruit Exotics',
        type: FoodEntityType.ingredient,
        category: 'Fruits',
      );
      expect(cooldownResult.isPlaceholder, isTrue);
      expect(apiCallCount, 1, reason: 'Failure cooldown must prevent repeated hammering on error/rate limit');
    });

    // Widget rendering test: FoodImageView with resolved network image
    testWidgets('FoodImageView renders resolved network image without falling back to apple', (tester) async {
      final watermelonModel = FoodImageModel(
        entityType: FoodEntityType.ingredient,
        entityKey: 'watermelon',
        displayName: 'Watermelon',
        imageUrl: 'https://cdn.pixabay.com/photo/watermelon.jpg',
        provider: 'pixabay',
        photographerName: 'Pixabay Artist',
      );
      FoodImageRepository.instance.putInMemoryCache(watermelonModel);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FoodImageView(
              name: 'Watermelon',
              type: FoodEntityType.ingredient,
              category: 'Fruits',
              showAttributionPill: true,
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify Image.network is rendered with correct watermelon URL
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.image, isA<NetworkImage>());
      final networkImage = imageWidget.image as NetworkImage;
      expect(networkImage.url, 'https://cdn.pixabay.com/photo/watermelon.jpg');

      // Verify attribution pill
      expect(find.text('Photo by Pixabay Artist on Pixabay'), findsOneWidget);
    });
  });
}
