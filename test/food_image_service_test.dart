import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/screens/food_image/food_image_picker_sheet.dart';
import 'package:nutrifridge/screens/food_image/pan_cutout_picker_sheet.dart';
import 'package:nutrifridge/screens/food_image/widgets/food_image_view.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/screens/fridge/widgets/cooking_pan_visual.dart';
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

  group('NutriFridge — Centralized Food Image System Scenarios', () {
    // Scenario 1: Add Paneer for the first time -> automatically resolves a Paneer photograph
    test('Scenario 1: Add Paneer for the first time automatically resolves a Paneer photograph', () async {
      int edgeFunctionCallCount = 0;
      FoodImageResolver.mockHandler = (body) async {
        edgeFunctionCallCount++;
        expect(body['query'], 'paneer');
        return {
          'ok': true,
          'action': 'resolve',
          'bestMatch': {
            'photoId': 'px_paneer_123',
            'imageUrl': 'https://cdn.pixabay.com/photo/123/paneer.jpg',
            'thumbnailUrl': 'https://cdn.pixabay.com/photo/123/paneer_small.jpg',
            'photographerName': 'Chef Aarti',
            'photographerUrl': 'https://pixabay.com/users/aarti-123/',
            'sourcePageUrl': 'https://pixabay.com/photos/fresh-paneer-cubes-123/',
            'altDescription': 'Fresh organic paneer cubes on wooden board',
            'provider': 'pixabay',
            'score': 95,
          },
        };
      };

      // Raw ingredient with quantity
      final resolved = await FoodImageService.instance.resolveImage(
        name: 'Paneer - 500 g',
        type: FoodEntityType.ingredient,
        category: 'Dairy Products',
      );

      expect(resolved.entityKey, 'paneer');
      expect(resolved.imageUrl, 'https://cdn.pixabay.com/photo/123/paneer.jpg');
      expect(resolved.provider, 'pixabay');
      expect(resolved.photographerName, 'Chef Aarti');
      expect(resolved.hasAttribution, isTrue);
      expect(resolved.attributionText, 'Photo by Chef Aarti on Pixabay');
      expect(edgeFunctionCallCount, 1);
    });

    // Scenario 2: Add Apple -> resolves an Apple photograph
    test('Scenario 2: Add Apple resolves an Apple photograph', () async {
      FoodImageResolver.mockHandler = (body) async {
        return {
          'ok': true,
          'action': 'resolve',
          'bestMatch': {
            'photoId': 'px_apple_456',
            'imageUrl': 'https://cdn.pixabay.com/photo/456/apple.jpg',
            'thumbnailUrl': 'https://cdn.pixabay.com/photo/456/apple_thumb.jpg',
            'photographerName': 'John Orchard',
            'photographerUrl': 'https://pixabay.com/users/john-456/',
            'sourcePageUrl': 'https://pixabay.com/photos/crisp-red-apple-456/',
            'altDescription': 'Crisp red apple on rustic table',
            'provider': 'pixabay',
            'score': 100,
          },
        };
      };

      final resolved = await FoodImageService.instance.resolveImage(
        name: 'Fresh Apples (4 pcs)',
        type: FoodEntityType.ingredient,
        category: 'Fruits',
      );

      expect(resolved.entityKey, 'apple');
      expect(resolved.imageUrl, 'https://cdn.pixabay.com/photo/456/apple.jpg');
    });

    // Scenario 3: Add an unfamiliar ingredient -> resolves a relevant image or displays a clean placeholder
    test('Scenario 3: Add unfamiliar ingredient resolves safely or uses clean category placeholder', () async {
      FoodImageResolver.mockHandler = (body) async {
        // External provider has no sufficiently relevant candidate for obscure ingredient
        return {
          'ok': true,
          'action': 'resolve',
          'candidates': [],
          'bestMatch': null,
        };
      };

      final resolved = await FoodImageService.instance.resolveImage(
        name: 'Dragonfruit Extract Powder',
        type: FoodEntityType.ingredient,
        category: 'Fruits',
      );

      expect(resolved.isPlaceholder, isTrue);
      // Clean category placeholder for Fruits
      expect(resolved.imageUrl, 'assets/images/foods/apple.png');
    });

    // Scenario 4: Generate Shahi Paneer -> resolves a matching recipe photograph
    test('Scenario 4: Generate Shahi Paneer resolves matching recipe photograph', () async {
      FoodImageResolver.mockHandler = (body) async {
        expect(body['entityType'], 'recipe');
        return {
          'ok': true,
          'action': 'resolve',
          'bestMatch': {
            'photoId': 'px_shahi_789',
            'imageUrl': 'https://cdn.pixabay.com/photo/789/shahi_paneer.jpg',
            'thumbnailUrl': 'https://cdn.pixabay.com/photo/789/shahi_paneer_thumb.jpg',
            'photographerName': 'Priya Gourmet',
            'photographerUrl': 'https://pixabay.com/users/priya-789/',
            'sourcePageUrl': 'https://pixabay.com/photos/royal-shahi-paneer-curry-789/',
            'altDescription': 'Authentic royal Shahi Paneer with rich gravy',
            'provider': 'pixabay',
            'score': 90,
          },
        };
      };

      final resolved = await FoodImageService.instance.resolveImage(
        name: 'Shahi Paneer (Chef Special)',
        type: FoodEntityType.recipe,
        cuisine: 'North Indian',
      );

      expect(resolved.entityKey, 'shahi paneer');
      expect(resolved.imageUrl, 'https://cdn.pixabay.com/photo/789/shahi_paneer.jpg');
      expect(resolved.provider, 'pixabay');
    });

    // Scenario 5: Open the same ingredient across three different screens -> identical image mapping
    test('Scenario 5: Same ingredient across multiple screens returns the identical resolved mapping', () async {
      final savedModel = FoodImageModel(
        entityType: FoodEntityType.ingredient,
        entityKey: 'paneer',
        displayName: 'Paneer',
        imageUrl: 'https://cdn.pixabay.com/photo/123/paneer.jpg',
        provider: 'pixabay',
        photographerName: 'Chef Aarti',
      );
      FoodImageRepository.instance.putInMemoryCache(savedModel);

      // Screen 1: Inventory model check
      final item = const CategoryFoodItem(
        id: 'paneer_1',
        name: 'Paneer',
        quantity: '500g',
        category: 'Dairy Products',
      );
      final imgScreen1 = item.effectiveImageAsset;

      // Screen 2: FoodImageService sync lookup
      final imgScreen2 = FoodImageService.instance.getImageSync(
        name: 'Paneer',
        type: FoodEntityType.ingredient,
      ).imageUrl;

      // Screen 3: Asynchronous resolve call
      final imgScreen3 = (await FoodImageService.instance.resolveImage(
        name: 'Paneer',
        type: FoodEntityType.ingredient,
      )).imageUrl;

      expect(imgScreen1, 'https://cdn.pixabay.com/photo/123/paneer.jpg');
      expect(imgScreen2, 'https://cdn.pixabay.com/photo/123/paneer.jpg');
      expect(imgScreen3, 'https://cdn.pixabay.com/photo/123/paneer.jpg');
      expect(imgScreen1, equals(imgScreen2));
      expect(imgScreen2, equals(imgScreen3));
    });

    // Scenario 6: Open previously viewed recipe -> no unnecessary image search request
    test('Scenario 6: Previously resolved recipe does not trigger redundant external search', () async {
      int searchRequestsCount = 0;
      FoodImageResolver.mockHandler = (body) async {
        searchRequestsCount++;
        return {
          'ok': true,
          'action': 'resolve',
          'bestMatch': {
            'photoId': 'px_pasta_1',
            'imageUrl': 'https://cdn.pixabay.com/photo/999/pasta.jpg',
            'thumbnailUrl': 'https://cdn.pixabay.com/photo/999/pasta_thumb.jpg',
            'photographerName': 'Luigi Rossi',
            'photographerUrl': 'https://pixabay.com/users/luigi-999/',
            'sourcePageUrl': 'https://pixabay.com/photos/italian-pasta-999/',
            'altDescription': 'Fresh homemade vegetable pasta',
            'provider': 'pixabay',
            'score': 90,
          },
        };
      };

      // First time viewing
      final first = await FoodImageService.instance.resolveImage(
        name: 'Veggie Pasta',
        type: FoodEntityType.recipe,
      );
      expect(first.imageUrl, 'https://cdn.pixabay.com/photo/999/pasta.jpg');
      expect(searchRequestsCount, 1);

      // Second time viewing (e.g., navigating back to recipe or reopening detail)
      final second = await FoodImageService.instance.resolveImage(
        name: 'Veggie Pasta',
        type: FoodEntityType.recipe,
      );
      expect(second.imageUrl, 'https://cdn.pixabay.com/photo/999/pasta.jpg');
      // No additional network call made
      expect(searchRequestsCount, 1);
    });

    // Scenario 7: Manually change an ingredient photograph -> change appears across all its screens
    test('Scenario 7: Manually changing a photograph updates mapping and reflects everywhere', () async {
      // 1. Initial automatic mapping
      final autoModel = FoodImageModel(
        entityType: FoodEntityType.ingredient,
        entityKey: 'paneer',
        displayName: 'Paneer',
        imageUrl: 'https://cdn.pixabay.com/photo/auto/paneer.jpg',
        provider: 'pixabay',
      );
      FoodImageRepository.instance.putInMemoryCache(autoModel);

      // 2. User selects an alternative photo
      const newCandidate = FoodImageCandidate(
        photoId: 'px_user_selected_77',
        imageUrl: 'https://cdn.pixabay.com/photo/manual/crispy_paneer.jpg',
        thumbnailUrl: 'https://cdn.pixabay.com/photo/manual/crispy_paneer_thumb.jpg',
        photographerName: 'Gourmet Master',
        photographerUrl: 'https://pixabay.com/users/gourmet-77/',
        sourcePageUrl: 'https://pixabay.com/photos/crispy-paneer-77/',
        altDescription: 'Golden pan-fried paneer cubes',
        provider: 'pixabay',
      );

      final override = await FoodImageService.instance.setUserOverride(
        name: 'Paneer',
        type: FoodEntityType.ingredient,
        candidate: newCandidate,
        userId: 'test_user_1',
      );

      expect(override.isUserOverride, isTrue);
      expect(override.imageUrl, 'https://cdn.pixabay.com/photo/manual/crispy_paneer.jpg');

      // 3. Any screen querying Paneer receives the new user override
      final resolved = FoodImageService.instance.getImageSync(
        name: 'Paneer',
        type: FoodEntityType.ingredient,
        userId: 'test_user_1',
      );
      expect(resolved.imageUrl, 'https://cdn.pixabay.com/photo/manual/crispy_paneer.jpg');
      expect(resolved.isUserOverride, isTrue);
    });

    // Scenario 8: Restore automatic image -> original resolved mapping returns
    test('Scenario 8: Restoring automatic image removes user override and returns base mapping', () async {
      // Seed automatic catalog mapping
      final autoModel = FoodImageModel(
        entityType: FoodEntityType.ingredient,
        entityKey: 'tomato',
        displayName: 'Tomato',
        imageUrl: 'https://cdn.pixabay.com/photo/auto/tomato.jpg',
        provider: 'pixabay',
      );
      FoodImageRepository.instance.putInMemoryCache(autoModel);

      // Set user override
      await FoodImageService.instance.setUserOverride(
        name: 'Tomato',
        type: FoodEntityType.ingredient,
        candidate: const FoodImageCandidate(
          photoId: 'px_override',
          imageUrl: 'https://cdn.pixabay.com/photo/manual/cherry_tomato.jpg',
          thumbnailUrl: 'https://cdn.pixabay.com/photo/manual/cherry_tomato_thumb.jpg',
          photographerName: 'Farmer Dan',
          photographerUrl: 'https://pixabay.com/users/dan-1/',
          sourcePageUrl: 'https://pixabay.com/photos/cherry-tomatoes-1/',
          altDescription: 'Ripe cherry tomatoes',
          provider: 'pixabay',
        ),
        userId: 'test_user_1',
      );

      expect(FoodImageService.instance.hasUserOverride(name: 'Tomato', type: FoodEntityType.ingredient, userId: 'test_user_1'), isTrue);

      // Restore automatic
      final restored = await FoodImageService.instance.restoreAutomaticImage(
        name: 'Tomato',
        type: FoodEntityType.ingredient,
        userId: 'test_user_1',
      );

      expect(restored.isUserOverride, isFalse);
      expect(restored.imageUrl, 'https://cdn.pixabay.com/photo/auto/tomato.jpg');
      expect(FoodImageService.instance.hasUserOverride(name: 'Tomato', type: FoodEntityType.ingredient, userId: 'test_user_1'), isFalse);
    });

    // Scenario 9: Two users select different overrides -> their overrides remain isolated
    test('Scenario 9: Two users select different overrides and stay completely isolated', () async {
      // User A overrides Paneer to Photo A
      await FoodImageService.instance.setUserOverride(
        name: 'Paneer',
        type: FoodEntityType.ingredient,
        candidate: const FoodImageCandidate(
          photoId: 'photo_user_a',
          imageUrl: 'https://cdn.pixabay.com/user_a_paneer.jpg',
          thumbnailUrl: 'https://cdn.pixabay.com/user_a_paneer_thumb.jpg',
          photographerName: 'Alice',
          photographerUrl: 'https://pixabay.com/users/alice-1/',
          sourcePageUrl: 'https://pixabay.com/photos/a/',
          altDescription: 'Alice Paneer',
          provider: 'pixabay',
        ),
        userId: 'user_a',
      );

      // User B overrides Paneer to Photo B
      await FoodImageService.instance.setUserOverride(
        name: 'Paneer',
        type: FoodEntityType.ingredient,
        candidate: const FoodImageCandidate(
          photoId: 'photo_user_b',
          imageUrl: 'https://cdn.pixabay.com/user_b_paneer.jpg',
          thumbnailUrl: 'https://cdn.pixabay.com/user_b_paneer_thumb.jpg',
          photographerName: 'Bob',
          photographerUrl: 'https://pixabay.com/users/bob-2/',
          sourcePageUrl: 'https://pixabay.com/photos/b/',
          altDescription: 'Bob Paneer',
          provider: 'pixabay',
        ),
        userId: 'user_b',
      );

      // User A sees Photo A
      final modelA = FoodImageService.instance.getImageSync(
        name: 'Paneer',
        type: FoodEntityType.ingredient,
        userId: 'user_a',
      );
      expect(modelA.imageUrl, 'https://cdn.pixabay.com/user_a_paneer.jpg');

      // User B sees Photo B
      final modelB = FoodImageService.instance.getImageSync(
        name: 'Paneer',
        type: FoodEntityType.ingredient,
        userId: 'user_b',
      );
      expect(modelB.imageUrl, 'https://cdn.pixabay.com/user_b_paneer.jpg');
    });

    // Scenario 10: Pixabay unavailable or rate-limited -> application continues working with placeholders
    test('Scenario 10: Pixabay rate-limit or outage falls back safely without crashing', () async {
      FoodImageResolver.mockHandler = (body) async {
        return {
          'ok': false,
          'error': 'RATE_LIMITED',
          'message': 'Pixabay API rate limit exceeded. Please try again later.',
        };
      };

      final resolved = await FoodImageService.instance.resolveImage(
        name: 'Fresh Tofu',
        type: FoodEntityType.ingredient,
        category: 'Dairy Products',
      );

      expect(resolved.isPlaceholder, isTrue);
      // Still returns a clean category asset so UI does not crash
      expect(resolved.imageUrl, 'assets/images/foods/milk.png');
    });

    // Scenario 11: No Pixabay key configured -> no crash or fake image assignment
    test('Scenario 11: Missing Pixabay key returns structured error and clean fallback without fake images', () async {
      FoodImageResolver.mockHandler = (body) async {
        return {
          'ok': false,
          'error': 'PIXABAY_API_KEY_NOT_CONFIGURED',
          'message': 'Pixabay API key is not configured in Supabase secrets.',
          'candidates': [],
          'bestMatch': null,
        };
      };

      final resolved = await FoodImageService.instance.resolveImage(
        name: 'Organic Lentils',
        type: FoodEntityType.ingredient,
        category: 'Vegetables',
      );

      expect(resolved.isPlaceholder, isTrue);
      expect(resolved.imageUrl, isNotEmpty);
    });

    // Scenario 12: Cooking Pan cutouts remain strictly transparent PNG assets regardless of Pixabay URLs
    test('Scenario 12: Cooking Pan cutouts remain strictly transparent PNG assets regardless of Pixabay URLs', () {
      // Even if an item has a resolved network Pixabay photo
      const itemWithNetworkPhoto = CategoryFoodItem(
        id: 'paneer_item_1',
        name: 'Paneer',
        quantity: '250g',
        imageAsset: 'https://cdn.pixabay.com/photo/123/paneer_curry_bowl.jpg',
      );

      // CookingPanVisual.resolvePanAsset must ignore remote photos and retain dedicated transparent cutout
      final panAsset = CookingPanVisual.resolvePanAsset(itemWithNetworkPhoto);

      expect(panAsset, isNotNull);
      expect(panAsset, startsWith('assets/images/foods/'));
      expect(panAsset, endsWith('.png'));
      expect(panAsset, 'assets/images/foods/paneer.png');
    });

    // Scenario 13: Dedicated transparent cutout resolution for Paneer, Apple, Broccoli, Eggs, Milk, Chicken
    test('Scenario 13: Dedicated transparent cutout resolution for Paneer, Apple, Broccoli, Eggs, Milk, Chicken', () {
      final testCases = [
        {'name': 'Paneer', 'expected': 'assets/images/foods/paneer.png'},
        {'name': 'Fresh Apples', 'expected': 'assets/images/foods/apple.png'},
        {'name': 'Broccoli Florets', 'expected': 'assets/images/foods/broccoli.png'},
        {'name': 'Organic Eggs', 'expected': 'assets/images/foods/eggs.png'},
        {'name': 'Whole Milk', 'expected': 'assets/images/foods/milk.png'},
        {'name': 'Chicken Breast', 'expected': 'assets/images/foods/chicken.png'},
      ];

      for (final tc in testCases) {
        final item = CategoryFoodItem(
          id: 'test_${tc['name']}',
          name: tc['name']!,
          quantity: '100g',
          imageAsset: 'https://cdn.pixabay.com/photo/999/random_photo.jpg',
        );

        final panAsset = CookingPanVisual.resolvePanAsset(item);
        expect(panAsset, tc['expected']);
        expect(item.effectivePanAsset, tc['expected']);
      }
    });

    // Scenario 14: FoodImageModel stores separate displayImageUrl and panCutoutUrl
    test('Scenario 14: FoodImageModel maintains two separate image variants for ingredients', () async {
      FoodImageResolver.mockHandler = (body) async {
        return {
          'ok': true,
          'action': 'resolve',
          'bestMatch': {
            'photoId': 'px_paneer_photo_1',
            'imageUrl': 'https://cdn.pixabay.com/photo/111/rich_paneer_photo.jpg',
            'thumbnailUrl': 'https://cdn.pixabay.com/photo/111/thumb.jpg',
            'photographerName': 'Food Stylist',
            'altDescription': 'Fresh paneer photo',
            'provider': 'pixabay',
            'score': 90,
          },
          'panCutoutUrl': 'https://kmwagsheagttauoqbzom.supabase.co/storage/v1/object/public/food-photos/cutouts/paneer.png',
        };
      };

      final resolved = await FoodImageService.instance.resolveImage(
        name: 'Paneer Block',
        type: FoodEntityType.ingredient,
        category: 'Dairy Products',
      );

      // Display image is regular food photography
      expect(resolved.displayImageUrl, 'https://cdn.pixabay.com/photo/111/rich_paneer_photo.jpg');
      // Pan cutout is background-free transparent asset
      expect(resolved.panCutoutUrl, isNotNull);
      expect(resolved.panCutoutUrl, contains('paneer'));
    });

    // Scenario 15: Changing regular photo does NOT overwrite pan cutout
    test('Scenario 15: Changing regular photograph does not overwrite existing pan cutout', () async {
      // 1. Initial mapping with both display photo and pan cutout
      final initialModel = FoodImageModel(
        entityType: FoodEntityType.ingredient,
        entityKey: 'paneer',
        displayName: 'Paneer',
        imageUrl: 'https://cdn.pixabay.com/photo/initial/paneer.jpg',
        panCutoutUrl: 'assets/images/foods/paneer.png',
        provider: 'pixabay',
      );
      FoodImageRepository.instance.putInMemoryCache(initialModel);

      // 2. User changes regular photograph
      const newCandidate = FoodImageCandidate(
        photoId: 'px_new_photo',
        imageUrl: 'https://cdn.pixabay.com/photo/user_chosen/paneer.jpg',
        thumbnailUrl: 'https://cdn.pixabay.com/photo/user_chosen/thumb.jpg',
        photographerName: 'New Photographer',
        photographerUrl: 'https://pixabay.com',
        sourcePageUrl: 'https://pixabay.com',
        altDescription: 'User chosen paneer',
      );

      final updated = await FoodImageService.instance.setUserOverride(
        name: 'Paneer',
        type: FoodEntityType.ingredient,
        candidate: newCandidate,
      );

      expect(updated.imageUrl, 'https://cdn.pixabay.com/photo/user_chosen/paneer.jpg');
      expect(updated.isUserOverride, isTrue);
      // Pan cutout is completely preserved!
      expect(updated.panCutoutUrl, 'assets/images/foods/paneer.png');
    });

    // Scenario 16: Changing pan cutout does NOT overwrite regular photograph
    test('Scenario 16: Changing pan cutout does not overwrite regular photograph', () async {
      // 1. Initial mapping
      final initialModel = FoodImageModel(
        entityType: FoodEntityType.ingredient,
        entityKey: 'apple',
        displayName: 'Apple',
        imageUrl: 'https://cdn.pixabay.com/photo/initial/apple.jpg',
        panCutoutUrl: 'assets/images/foods/apple.png',
        provider: 'pixabay',
      );
      FoodImageRepository.instance.putInMemoryCache(initialModel);

      // 2. User sets a custom pan cutout
      final updated = await FoodImageService.instance.setPanOverride(
        name: 'Apple',
        panCutoutUrl: 'https://kmwagsheagttauoqbzom.supabase.co/storage/v1/object/public/food-photos/cutouts/green_apple.png',
      );

      expect(updated.panCutoutUrl, 'https://kmwagsheagttauoqbzom.supabase.co/storage/v1/object/public/food-photos/cutouts/green_apple.png');
      expect(updated.isPanOverride, isTrue);
      // Regular photo remains unchanged!
      expect(updated.imageUrl, 'https://cdn.pixabay.com/photo/initial/apple.jpg');
      expect(updated.isUserOverride, isFalse);
    });

    // Scenario 17: Flying animation asset is 100% identical to CookingPanVisual asset
    test('Scenario 17: FlyingIngredientOverlay and CookingPanVisual resolve identical cutout asset', () {
      final items = [
        const CategoryFoodItem(id: 'p1', name: 'Paneer', quantity: '100g'),
        const CategoryFoodItem(id: 'a1', name: 'Apple', quantity: '2 pcs'),
        const CategoryFoodItem(id: 'b1', name: 'Broccoli', quantity: '150g'),
        const CategoryFoodItem(id: 'e1', name: 'Eggs', quantity: '6 pcs'),
        const CategoryFoodItem(id: 'm1', name: 'Milk', quantity: '500ml'),
        const CategoryFoodItem(id: 'c1', name: 'Chicken', quantity: '200g'),
      ];

      for (final item in items) {
        final panAsset = CookingPanVisual.resolvePanAsset(item);
        final itemPanAsset = item.effectivePanAsset;

        expect(panAsset, isNotNull);
        expect(panAsset, equals(itemPanAsset));
        expect(panAsset!.endsWith('.png') || panAsset.endsWith('.webp'), isTrue);
      }
    });

    // Scenario 18: Fallback when background removal fails uses clean transparent placeholder
    test('Scenario 18: Remote background removal failure falls back to clean transparent asset rather than rectangular photo', () async {
      FoodImageResolver.mockHandler = (body) async {
        return {
          'ok': true,
          'action': 'resolve-cutout',
          'panCutoutUrl': null, // background removal failed or unavailable
        };
      };

      final cutout = await FoodImageService.instance.resolvePanCutout(
        name: 'Exotic Starfruit',
        category: 'Fruits',
      );

      expect(cutout, isNotNull);
      expect(cutout.endsWith('.png') || cutout.endsWith('.webp'), isTrue);
      expect(cutout, 'assets/images/foods/apple.png'); // clean transparent fruit fallback
    });

    // Scenario 19: PanCutoutPickerSheet renders skillet canvas and allows selecting cutout
    testWidgets('Scenario 19: PanCutoutPickerSheet displays skillet preview and selects cutout', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PanCutoutPickerSheet(
              entityName: 'Paneer',
              category: 'Dairy Products',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cooking Pan Cutout'), findsOneWidget);
      expect(find.text('Transparent cutout for Paneer'), findsOneWidget);
      expect(find.text('Dark skillet surface preview'), findsOneWidget);
      expect(find.text('Set for Cooking Pan'), findsOneWidget);

      // Tap on Broccoli cutout option (index 2: Paneer, Apple, Broccoli)
      final cutoutCards = find.byWidgetPredicate((w) => w is GestureDetector && w.child is Container);
      await tester.tap(cutoutCards.at(2));
      await tester.pumpAndSettle();

      // Button is enabled
      final elevatedBtn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Set for Cooking Pan'));
      expect(elevatedBtn.onPressed, isNotNull);
    });

    // Widget Scenario: FoodImageView renders network image with attribution pill
    testWidgets('FoodImageView renders correctly and displays attribution pill', (tester) async {
      FoodImageRepository.instance.putInMemoryCache(
        const FoodImageModel(
          entityType: FoodEntityType.recipe,
          entityKey: 'paneer biryani',
          displayName: 'Paneer Biryani',
          imageUrl: 'https://cdn.pixabay.com/photo/101/biryani.jpg',
          photographerName: 'Chef Sanjay',
          provider: 'pixabay',
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FoodImageView(
              name: 'Paneer Biryani',
              type: FoodEntityType.recipe,
              showAttributionPill: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Photo by Chef Sanjay on Pixabay'), findsOneWidget);
    });

    // Widget Scenario: FoodImagePickerSheet renders candidate grid and lets user select
    testWidgets('FoodImagePickerSheet displays candidate grid and selects photo', (tester) async {
      FoodImageResolver.mockHandler = (body) async {
        return {
          'ok': true,
          'action': 'search',
          'candidates': [
            {
              'photoId': 'cand_1',
              'imageUrl': 'https://cdn.pixabay.com/photo/1/paneer_1.jpg',
              'thumbnailUrl': 'https://cdn.pixabay.com/photo/1/paneer_1_thumb.jpg',
              'photographerName': 'Photographer One',
              'altDescription': 'Fresh paneer',
              'provider': 'pixabay',
            },
            {
              'photoId': 'cand_2',
              'imageUrl': 'https://cdn.pixabay.com/photo/2/paneer_2.jpg',
              'thumbnailUrl': 'https://cdn.pixabay.com/photo/2/paneer_2_thumb.jpg',
              'photographerName': 'Photographer Two',
              'altDescription': 'Paneer cubes',
              'provider': 'pixabay',
            },
          ],
        };
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FoodImagePickerSheet(
              entityName: 'Paneer',
              entityType: FoodEntityType.ingredient,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Change Photo'), findsOneWidget);
      expect(find.text('Paneer'), findsWidgets);
      expect(find.text('Photographer One'), findsOneWidget);
      expect(find.text('Photographer Two'), findsOneWidget);
      expect(find.text('Photography provided by Pixabay'), findsOneWidget);

      // Tap on second candidate card
      final candidateCards = find.byWidgetPredicate((w) => w is GestureDetector && w.child is AnimatedContainer);
      await tester.tap(candidateCards.at(1));
      await tester.pumpAndSettle();

      // Apply Photo button is now active
      expect(find.text('Apply Photo'), findsOneWidget);
      final elevatedBtn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Apply Photo'));
      expect(elevatedBtn.onPressed, isNotNull);
    });
  });
}
