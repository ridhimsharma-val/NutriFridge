import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/screens/food_image/food_image_picker_sheet.dart';
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
            'imageUrl': 'https://images.pexels.com/photos/123/paneer.jpg',
            'thumbnailUrl': 'https://images.pexels.com/photos/123/paneer_small.jpg',
            'photographerName': 'Chef Aarti',
            'photographerUrl': 'https://www.pexels.com/@aarti',
            'sourcePageUrl': 'https://www.pexels.com/photo/fresh-paneer-cubes-123/',
            'altDescription': 'Fresh organic paneer cubes on wooden board',
            'provider': 'pexels',
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
      expect(resolved.imageUrl, 'https://images.pexels.com/photos/123/paneer.jpg');
      expect(resolved.provider, 'pexels');
      expect(resolved.photographerName, 'Chef Aarti');
      expect(resolved.hasAttribution, isTrue);
      expect(resolved.attributionText, 'Photo by Chef Aarti on Pexels');
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
            'imageUrl': 'https://images.pexels.com/photos/456/apple.jpg',
            'thumbnailUrl': 'https://images.pexels.com/photos/456/apple_thumb.jpg',
            'photographerName': 'John Orchard',
            'photographerUrl': 'https://www.pexels.com/@john',
            'sourcePageUrl': 'https://www.pexels.com/photo/crisp-red-apple-456/',
            'altDescription': 'Crisp red apple on rustic table',
            'provider': 'pexels',
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
      expect(resolved.imageUrl, 'https://images.pexels.com/photos/456/apple.jpg');
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
        expect(body['orientation'], 'landscape');
        return {
          'ok': true,
          'action': 'resolve',
          'bestMatch': {
            'photoId': 'px_shahi_789',
            'imageUrl': 'https://images.pexels.com/photos/789/shahi_paneer.jpg',
            'thumbnailUrl': 'https://images.pexels.com/photos/789/shahi_paneer_thumb.jpg',
            'photographerName': 'Priya Gourmet',
            'photographerUrl': 'https://www.pexels.com/@priya',
            'sourcePageUrl': 'https://www.pexels.com/photo/royal-shahi-paneer-curry-789/',
            'altDescription': 'Authentic royal Shahi Paneer with rich gravy',
            'provider': 'pexels',
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
      expect(resolved.imageUrl, 'https://images.pexels.com/photos/789/shahi_paneer.jpg');
      expect(resolved.provider, 'pexels');
    });

    // Scenario 5: Open the same ingredient across three different screens -> identical image mapping
    test('Scenario 5: Same ingredient across multiple screens returns the identical resolved mapping', () async {
      final savedModel = FoodImageModel(
        entityType: FoodEntityType.ingredient,
        entityKey: 'paneer',
        displayName: 'Paneer',
        imageUrl: 'https://images.pexels.com/photos/123/paneer.jpg',
        provider: 'pexels',
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

      expect(imgScreen1, 'https://images.pexels.com/photos/123/paneer.jpg');
      expect(imgScreen2, 'https://images.pexels.com/photos/123/paneer.jpg');
      expect(imgScreen3, 'https://images.pexels.com/photos/123/paneer.jpg');
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
            'imageUrl': 'https://images.pexels.com/photos/999/pasta.jpg',
            'thumbnailUrl': 'https://images.pexels.com/photos/999/pasta_thumb.jpg',
            'photographerName': 'Luigi Rossi',
            'photographerUrl': 'https://www.pexels.com/@luigi',
            'sourcePageUrl': 'https://www.pexels.com/photo/italian-pasta-999/',
            'altDescription': 'Fresh homemade vegetable pasta',
            'provider': 'pexels',
            'score': 90,
          },
        };
      };

      // First time viewing
      final first = await FoodImageService.instance.resolveImage(
        name: 'Veggie Pasta',
        type: FoodEntityType.recipe,
      );
      expect(first.imageUrl, 'https://images.pexels.com/photos/999/pasta.jpg');
      expect(searchRequestsCount, 1);

      // Second time viewing (e.g., navigating back to recipe or reopening detail)
      final second = await FoodImageService.instance.resolveImage(
        name: 'Veggie Pasta',
        type: FoodEntityType.recipe,
      );
      expect(second.imageUrl, 'https://images.pexels.com/photos/999/pasta.jpg');
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
        imageUrl: 'https://images.pexels.com/photos/auto/paneer.jpg',
        provider: 'pexels',
      );
      FoodImageRepository.instance.putInMemoryCache(autoModel);

      // 2. User selects an alternative photo
      const newCandidate = FoodImageCandidate(
        photoId: 'px_user_selected_77',
        imageUrl: 'https://images.pexels.com/photos/manual/crispy_paneer.jpg',
        thumbnailUrl: 'https://images.pexels.com/photos/manual/crispy_paneer_thumb.jpg',
        photographerName: 'Gourmet Master',
        photographerUrl: 'https://www.pexels.com/@gourmet',
        sourcePageUrl: 'https://www.pexels.com/photo/crispy-paneer-77/',
        altDescription: 'Golden pan-fried paneer cubes',
      );

      final override = await FoodImageService.instance.setUserOverride(
        name: 'Paneer',
        type: FoodEntityType.ingredient,
        candidate: newCandidate,
        userId: 'test_user_1',
      );

      expect(override.isUserOverride, isTrue);
      expect(override.imageUrl, 'https://images.pexels.com/photos/manual/crispy_paneer.jpg');

      // 3. Any screen querying Paneer receives the new user override
      final resolved = FoodImageService.instance.getImageSync(
        name: 'Paneer',
        type: FoodEntityType.ingredient,
        userId: 'test_user_1',
      );
      expect(resolved.imageUrl, 'https://images.pexels.com/photos/manual/crispy_paneer.jpg');
      expect(resolved.isUserOverride, isTrue);
    });

    // Scenario 8: Restore automatic image -> original resolved mapping returns
    test('Scenario 8: Restoring automatic image removes user override and returns base mapping', () async {
      // Seed automatic catalog mapping
      final autoModel = FoodImageModel(
        entityType: FoodEntityType.ingredient,
        entityKey: 'tomato',
        displayName: 'Tomato',
        imageUrl: 'https://images.pexels.com/photos/auto/tomato.jpg',
        provider: 'pexels',
      );
      FoodImageRepository.instance.putInMemoryCache(autoModel);

      // Set user override
      await FoodImageService.instance.setUserOverride(
        name: 'Tomato',
        type: FoodEntityType.ingredient,
        candidate: const FoodImageCandidate(
          photoId: 'px_override',
          imageUrl: 'https://images.pexels.com/photos/manual/cherry_tomato.jpg',
          thumbnailUrl: 'https://images.pexels.com/photos/manual/cherry_tomato_thumb.jpg',
          photographerName: 'Farmer Dan',
          photographerUrl: 'https://www.pexels.com/@dan',
          sourcePageUrl: 'https://www.pexels.com/photo/cherry-tomatoes-1/',
          altDescription: 'Ripe cherry tomatoes',
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
      expect(restored.imageUrl, 'https://images.pexels.com/photos/auto/tomato.jpg');
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
          imageUrl: 'https://images.pexels.com/user_a_paneer.jpg',
          thumbnailUrl: 'https://images.pexels.com/user_a_paneer_thumb.jpg',
          photographerName: 'Alice',
          photographerUrl: 'https://www.pexels.com/@alice',
          sourcePageUrl: 'https://www.pexels.com/photo/a/',
          altDescription: 'Alice Paneer',
        ),
        userId: 'user_a',
      );

      // User B overrides Paneer to Photo B
      await FoodImageService.instance.setUserOverride(
        name: 'Paneer',
        type: FoodEntityType.ingredient,
        candidate: const FoodImageCandidate(
          photoId: 'photo_user_b',
          imageUrl: 'https://images.pexels.com/user_b_paneer.jpg',
          thumbnailUrl: 'https://images.pexels.com/user_b_paneer_thumb.jpg',
          photographerName: 'Bob',
          photographerUrl: 'https://www.pexels.com/@bob',
          sourcePageUrl: 'https://www.pexels.com/photo/b/',
          altDescription: 'Bob Paneer',
        ),
        userId: 'user_b',
      );

      // User A sees Photo A
      final modelA = FoodImageService.instance.getImageSync(
        name: 'Paneer',
        type: FoodEntityType.ingredient,
        userId: 'user_a',
      );
      expect(modelA.imageUrl, 'https://images.pexels.com/user_a_paneer.jpg');

      // User B sees Photo B
      final modelB = FoodImageService.instance.getImageSync(
        name: 'Paneer',
        type: FoodEntityType.ingredient,
        userId: 'user_b',
      );
      expect(modelB.imageUrl, 'https://images.pexels.com/user_b_paneer.jpg');
    });

    // Scenario 10: Pexels unavailable or rate-limited -> application continues working with placeholders
    test('Scenario 10: Pexels rate-limit or outage falls back safely without crashing', () async {
      FoodImageResolver.mockHandler = (body) async {
        return {
          'ok': false,
          'error': 'RATE_LIMITED',
          'message': 'Pexels API rate limit exceeded. Please try again later.',
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

    // Scenario 11: No Pexels key configured -> no crash or fake image assignment
    test('Scenario 11: Missing Pexels key returns structured error and clean fallback without fake images', () async {
      FoodImageResolver.mockHandler = (body) async {
        return {
          'ok': false,
          'error': 'PEXELS_API_KEY_NOT_CONFIGURED',
          'message': 'Pexels API key is not configured in Supabase secrets.',
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

    // Scenario 12: Cooking Pan cutouts and animations remain unchanged
    test('Scenario 12: Cooking Pan cutouts remain strictly transparent PNG assets regardless of Pexels URLs', () {
      // Even if an item has a resolved network Pexels photo
      const itemWithNetworkPhoto = CategoryFoodItem(
        id: 'paneer_item_1',
        name: 'Paneer',
        quantity: '250g',
        imageAsset: 'https://images.pexels.com/photos/123/paneer_curry_bowl.jpg',
      );

      // CookingPanVisual.resolvePanAsset must ignore remote photos and retain dedicated transparent cutout
      final panAsset = CookingPanVisual.resolvePanAsset(itemWithNetworkPhoto);

      expect(panAsset, isNotNull);
      expect(panAsset, startsWith('assets/images/foods/'));
      expect(panAsset, endsWith('.png'));
      expect(panAsset, 'assets/images/foods/paneer.png');
    });

    // Widget Scenario: FoodImageView renders network image with attribution pill
    testWidgets('FoodImageView renders correctly and displays attribution pill', (tester) async {
      FoodImageRepository.instance.putInMemoryCache(
        const FoodImageModel(
          entityType: FoodEntityType.recipe,
          entityKey: 'paneer biryani',
          displayName: 'Paneer Biryani',
          imageUrl: 'https://images.pexels.com/photos/101/biryani.jpg',
          photographerName: 'Chef Sanjay',
          provider: 'pexels',
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

      expect(find.text('Photo by Chef Sanjay on Pexels'), findsOneWidget);
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
              'imageUrl': 'https://images.pexels.com/photos/1/paneer_1.jpg',
              'thumbnailUrl': 'https://images.pexels.com/photos/1/paneer_1_thumb.jpg',
              'photographerName': 'Photographer One',
              'altDescription': 'Fresh paneer',
              'provider': 'pexels',
            },
            {
              'photoId': 'cand_2',
              'imageUrl': 'https://images.pexels.com/photos/2/paneer_2.jpg',
              'thumbnailUrl': 'https://images.pexels.com/photos/2/paneer_2_thumb.jpg',
              'photographerName': 'Photographer Two',
              'altDescription': 'Paneer cubes',
              'provider': 'pexels',
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
      expect(find.text('Photography provided by Pexels'), findsOneWidget);

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
