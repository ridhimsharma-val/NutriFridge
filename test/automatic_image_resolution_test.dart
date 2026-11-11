import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/services/food_image/food_image_model.dart';
import 'package:nutrifridge/services/food_image/food_image_resolver.dart';
import 'package:nutrifridge/services/food_image/food_image_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FoodImageService.instance.resetForTesting();
  });

  tearDown(() {
    FoodImageResolver.mockHandler = null;
  });

  group('NutriFridge — Automatic Image Resolution & Integrity', () {
    test('1. First appearance of new ingredient (Pineapple) triggers automatic resolution', () async {
      int edgeCallCount = 0;
      FoodImageResolver.mockHandler = (body) async {
        edgeCallCount++;
        expect(body['action'], 'resolve');
        expect(body['query'], 'pineapple');
        return {
          'ok': true,
          'action': 'resolve',
          'bestMatch': {
            'photoId': '867245',
            'imageUrl': 'https://kmwagsheagttauoqbzom.supabase.co/storage/v1/object/public/food-photos/ingredients/867245.jpg',
            'thumbnailUrl': 'https://cdn.pixabay.com/photo/867245_150.jpg',
            'photographerName': 'pineapplesupplyco',
            'photographerUrl': 'https://pixabay.com/users/3119825/',
            'sourcePageUrl': 'https://pixabay.com/photos/867245/',
            'altDescription': 'Fresh tropical pineapple',
            'provider': 'pixabay',
            'score': 100,
          },
        };
      };

      // 1. Initial synchronous call returns clean placeholder without unrelated apple photograph
      final syncModel = FoodImageService.instance.getImageSync(
        name: 'Pineapple',
        type: FoodEntityType.ingredient,
        category: 'Fruits',
      );
      expect(syncModel.isPlaceholder, isTrue);

      // CategoryFoodItem.effectiveImageAsset also returns null while resolving (clean placeholder)
      final categoryItem = CategoryFoodItem(
        id: 'test_pineapple',
        name: 'Pineapple',
        category: 'Fruits',
        quantity: '1 piece',
      );
      expect(categoryItem.effectiveImageAsset, isNull);

      // 2. Await background resolution
      final resolved = await FoodImageService.instance.resolveImage(
        name: 'Pineapple',
        type: FoodEntityType.ingredient,
        category: 'Fruits',
      );

      expect(resolved.imageUrl, contains('867245.jpg'));
      expect(resolved.provider, 'pixabay');
      expect(edgeCallCount, 1);

      // 3. CategoryFoodItem.effectiveImageAsset now reflects the resolved mirrored photograph
      expect(categoryItem.effectiveImageAsset, contains('867245.jpg'));
    });

    test('2. First appearance of Avocado does not display unrelated tomato photograph', () async {
      FoodImageResolver.mockHandler = (body) async {
        return {
          'ok': true,
          'action': 'resolve',
          'bestMatch': {
            'photoId': '2115922',
            'imageUrl': 'https://kmwagsheagttauoqbzom.supabase.co/storage/v1/object/public/food-photos/ingredients/2115922.jpg',
            'thumbnailUrl': 'https://cdn.pixabay.com/photo/2115922_150.jpg',
            'photographerName': 'avocado_artist',
            'photographerUrl': 'https://pixabay.com/users/avocado_artist/',
            'sourcePageUrl': 'https://pixabay.com/photos/2115922/',
            'altDescription': 'Fresh organic sliced avocado',
            'provider': 'pixabay',
            'score': 100,
          },
        };
      };

      final avocadoItem = CategoryFoodItem(
        id: 'test_avocado',
        name: 'Avocado',
        category: 'Vegetables',
        quantity: '2 pieces',
      );

      // Before resolution, should NOT show tomato.png or apple.png
      expect(avocadoItem.effectiveImageAsset, isNull);

      final resolved = await FoodImageService.instance.resolveImage(
        name: 'Avocado',
        type: FoodEntityType.ingredient,
        category: 'Vegetables',
      );
      expect(resolved.imageUrl, contains('2115922.jpg'));
      expect(avocadoItem.effectiveImageAsset, contains('2115922.jpg'));
    });

    test('3. Recipe Shahi Paneer resolves genuinely relevant Indian paneer dish', () async {
      FoodImageResolver.mockHandler = (body) async {
        expect(body['query'], 'shahi paneer');
        return {
          'ok': true,
          'action': 'resolve',
          'bestMatch': {
            'photoId': '8991043',
            'imageUrl': 'https://kmwagsheagttauoqbzom.supabase.co/storage/v1/object/public/food-photos/recipes/8991043.jpg',
            'thumbnailUrl': 'https://cdn.pixabay.com/photo/8991043_150.jpg',
            'photographerName': 'IndianChef',
            'photographerUrl': 'https://pixabay.com/users/chef/',
            'sourcePageUrl': 'https://pixabay.com/photos/8991043/',
            'altDescription': 'bowl, dish, paneer, indian, recipe, kitchen, restaurant, food',
            'provider': 'pixabay',
            'score': 80,
          },
        };
      };

      final resolved = await FoodImageService.instance.resolveImage(
        name: 'Shahi Paneer',
        type: FoodEntityType.recipe,
        cuisine: 'Indian',
        ingredients: ['paneer', 'cream', 'tomato', 'spices'],
      );

      expect(resolved.imageUrl, contains('8991043.jpg'));
      expect(resolved.provider, 'pixabay');
    });

    test('4. Cooking Pan cutout for uncurated ingredient remains transparent cutout, never rectangular JPG', () async {
      final categoryItem = CategoryFoodItem(
        id: 'test_pineapple',
        name: 'Pineapple',
        category: 'Fruits',
        quantity: '1 piece',
      );

      final panAsset = categoryItem.effectivePanAsset;
      expect(panAsset, isNotNull);
      // Transparent PNG placeholder fallback, never a photographic JPG
      expect(panAsset!.endsWith('.png') || panAsset.endsWith('.webp'), isTrue);
      expect(panAsset.endsWith('.jpg'), isFalse);
    });

    test('5. Reopening the same item does not trigger redundant external search', () async {
      int edgeCallCount = 0;
      FoodImageResolver.mockHandler = (body) async {
        edgeCallCount++;
        return {
          'ok': true,
          'action': 'resolve',
          'bestMatch': {
            'photoId': '867245',
            'imageUrl': 'https://kmwagsheagttauoqbzom.supabase.co/storage/v1/object/public/food-photos/ingredients/867245.jpg',
            'thumbnailUrl': 'https://cdn.pixabay.com/photo/867245_150.jpg',
            'photographerName': 'pineapplesupplyco',
            'photographerUrl': 'https://pixabay.com/users/3119825/',
            'sourcePageUrl': 'https://pixabay.com/photos/867245/',
            'altDescription': 'Fresh tropical pineapple',
            'provider': 'pixabay',
            'score': 100,
          },
        };
      };

      // First resolution
      await FoodImageService.instance.resolveImage(
        name: 'Pineapple',
        type: FoodEntityType.ingredient,
      );
      expect(edgeCallCount, 1);

      // Second retrieval (synchronous) hits cache, does not trigger edge function
      final cachedSync = FoodImageService.instance.getImageSync(
        name: 'Pineapple',
        type: FoodEntityType.ingredient,
      );
      expect(cachedSync.isPlaceholder, isFalse);
      expect(cachedSync.imageUrl, contains('867245.jpg'));
      expect(edgeCallCount, 1);
    });

    test('6. User override updates mapping and Restore Automatic returns original mapping', () async {
      FoodImageResolver.mockHandler = (body) async {
        return {
          'ok': true,
          'action': 'resolve',
          'bestMatch': {
            'photoId': '867245',
            'imageUrl': 'https://kmwagsheagttauoqbzom.supabase.co/storage/v1/object/public/food-photos/ingredients/867245.jpg',
            'thumbnailUrl': 'https://cdn.pixabay.com/photo/867245_150.jpg',
            'photographerName': 'pineapplesupplyco',
            'photographerUrl': 'https://pixabay.com/users/3119825/',
            'sourcePageUrl': 'https://pixabay.com/photos/867245/',
            'altDescription': 'Fresh tropical pineapple',
            'provider': 'pixabay',
            'score': 100,
          },
        };
      };

      // 1. Initial resolution
      final initial = await FoodImageService.instance.resolveImage(
        name: 'Pineapple',
        type: FoodEntityType.ingredient,
      );
      expect(initial.imageUrl, contains('867245.jpg'));

      // 2. Set manual user override
      final overrideCandidate = FoodImageCandidate(
        photoId: '999999',
        imageUrl: 'https://kmwagsheagttauoqbzom.supabase.co/storage/v1/object/public/food-photos/ingredients/999999.jpg',
        thumbnailUrl: 'https://cdn.pixabay.com/photo/999999_150.jpg',
        photographerName: 'Custom Photographer',
        photographerUrl: 'https://pixabay.com/users/custom/',
        sourcePageUrl: 'https://pixabay.com/photos/999999/',
        altDescription: 'Alternative pineapple composition',
        provider: 'pixabay',
        score: 95,
      );

      final overridden = await FoodImageService.instance.setUserOverride(
        name: 'Pineapple',
        type: FoodEntityType.ingredient,
        candidate: overrideCandidate,
      );
      expect(overridden.imageUrl, contains('999999.jpg'));
      expect(overridden.isUserOverride, isTrue);

      // 3. Restore automatic image
      final restored = await FoodImageService.instance.restoreAutomaticImage(
        name: 'Pineapple',
        type: FoodEntityType.ingredient,
      );
      expect(restored.imageUrl, contains('867245.jpg'));
      expect(restored.isUserOverride, isFalse);
    });
  });
}
