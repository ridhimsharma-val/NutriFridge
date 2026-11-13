import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/screens/fridge/screens/cooking_workspace_screen.dart';
import 'package:nutrifridge/screens/fridge/services/cooking_basket_service.dart';
import 'package:nutrifridge/screens/fridge/widgets/cooking_ingredient_cutout_view.dart';
import 'package:nutrifridge/screens/fridge/widgets/cooking_pan_visual.dart';
import 'package:nutrifridge/services/food_image/cooking_cutout_resolver.dart';
import 'package:nutrifridge/services/food_image/food_image_model.dart';
import 'package:nutrifridge/services/food_image/food_image_repository.dart';
import 'package:nutrifridge/services/food_image/food_image_resolver.dart';
import 'package:nutrifridge/services/food_image/food_image_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MockDataRepository.forceInMemoryForTesting = true;
    MockDataRepository.reset();
    CookingBasketService.clear();
    CookingCutoutResolver.resetForTesting();
    FoodImageService.instance.resetForTesting();
  });

  tearDown(() {
    SharedPreferences.setMockInitialValues({});
    MockDataRepository.reset();
    CookingBasketService.clear();
    CookingCutoutResolver.resetForTesting();
    FoodImageService.instance.resetForTesting();
  });

  group('NutriFridge — Automatic Ingredient Cutout System for Cooking Workspace', () {
    // Case 1: An ingredient with an existing transparent cutout uses it
    test('Case 1: An ingredient with an existing transparent cutout uses it', () {
      const appleItem = CategoryFoodItem(
        id: 'apple_1',
        name: 'Apple',
        quantity: '2 pcs',
        category: 'Fruits',
      );

      final result = CookingCutoutResolver.resolveSync(appleItem);

      expect(result.isTransparentCutout, isTrue);
      expect(result.imagePath, 'assets/images/foods/apple.png');
      expect(result.isFridgePhotoFallback, isFalse);
      expect(CookingPanVisual.resolvePanAsset(appleItem), 'assets/images/foods/apple.png');
    });

    // Case 2: An ingredient without a cutout automatically attempts background removal
    test('Case 2: An ingredient without a cutout automatically attempts background removal', () async {
      int removalAttempts = 0;
      String? queriedKey;

      CookingCutoutResolver.mockCutoutGenerator = (canonicalKey, sourceImageUrl) async {
        removalAttempts++;
        queriedKey = canonicalKey;
        return 'https://supabase.nutrifridge.com/food-photos/cutouts/$canonicalKey.png';
      };

      // Seed verified Fridge photograph for Cabbage
      final cabbageFridgeModel = FoodImageModel(
        entityType: FoodEntityType.ingredient,
        entityKey: 'cabbage',
        displayName: 'Cabbage',
        imageUrl: 'https://cdn.pixabay.com/photo/fresh_cabbage.jpg',
        provider: 'pixabay',
      );
      FoodImageRepository.instance.putInMemoryCache(cabbageFridgeModel);

      // Attempt async resolution
      final res = await CookingCutoutResolver.resolveByNameAsync(
        name: 'Cabbage',
        category: 'Vegetables',
      );

      expect(removalAttempts, 1);
      expect(queriedKey, 'cabbage');
      expect(res.isTransparentCutout, isTrue);
      expect(res.imagePath, 'https://supabase.nutrifridge.com/food-photos/cutouts/cabbage.png');
    });

    // Case 3: A successfully generated cutout has a genuine transparent background
    test('Case 3: A successfully generated cutout has a genuine transparent background', () async {
      CookingCutoutResolver.mockCutoutGenerator = (canonicalKey, sourceImageUrl) async {
        return 'https://supabase.nutrifridge.com/food-photos/cutouts/purple_brinjal_cutout.png';
      };

      final brinjalModel = FoodImageModel(
        entityType: FoodEntityType.ingredient,
        entityKey: 'brinjal',
        displayName: 'Brinjal',
        imageUrl: 'https://cdn.pixabay.com/photo/eggplant_purple.jpg',
        provider: 'pixabay',
      );
      FoodImageRepository.instance.putInMemoryCache(brinjalModel);

      final res = await CookingCutoutResolver.resolveByNameAsync(
        name: 'Brinjal',
        category: 'Vegetables',
      );

      expect(res.isTransparentCutout, isTrue);
      expect(res.imagePath.endsWith('.png'), isTrue);
      expect(res.isFridgePhotoFallback, isFalse);
      expect(CookingCutoutResolver.isCutoutAsset(res.imagePath), isTrue);
    });

    // Case 4: Failed cutout generation uses the exact Fridge photograph
    test('Case 4: Failed cutout generation uses the exact Fridge photograph', () async {
      // Simulate background removal returning null (failed or unavailable)
      CookingCutoutResolver.mockCutoutGenerator = (canonicalKey, sourceImageUrl) async {
        return null; // Generation failed
      };

      const verifiedFridgePhoto = 'https://cdn.pixabay.com/photo/verified_exotic_mushroom.jpg';
      final mushroomModel = FoodImageModel(
        entityType: FoodEntityType.ingredient,
        entityKey: 'mushroom',
        displayName: 'Mushroom',
        imageUrl: verifiedFridgePhoto,
        provider: 'pixabay',
      );
      FoodImageRepository.instance.putInMemoryCache(mushroomModel);

      final res = await CookingCutoutResolver.resolveByNameAsync(
        name: 'Mushroom',
        category: 'Vegetables',
      );

      // Must fall back to the exact Fridge photograph without pretending it is a transparent cutout
      expect(res.imagePath, verifiedFridgePhoto);
      expect(res.isTransparentCutout, isFalse);
      expect(res.isFridgePhotoFallback, isTrue);
    });

    // Case 5: Brinjal uses brinjal imagery
    test('Case 5: Brinjal uses brinjal imagery', () async {
      const brinjalPhoto = 'https://cdn.pixabay.com/photo/eggplant_purple.jpg';
      final brinjalModel = FoodImageModel(
        entityType: FoodEntityType.ingredient,
        entityKey: 'brinjal',
        displayName: 'Brinjal',
        imageUrl: brinjalPhoto,
        provider: 'pixabay',
      );
      FoodImageRepository.instance.putInMemoryCache(brinjalModel);

      const brinjalItem = CategoryFoodItem(
        id: 'brinjal_item',
        name: 'Brinjal',
        quantity: '500 g',
        category: 'Vegetables',
      );

      final res = CookingCutoutResolver.resolveSync(brinjalItem);

      // Must use brinjal imagery (never apple.png or broccoli emoji)
      expect(res.imagePath, brinjalPhoto);
      expect(res.imagePath, isNot(contains('apple')));
      expect(res.imagePath, isNot(contains('broccoli')));
      expect(res.canonicalKey, 'brinjal');
    });

    // Case 6: Cabbage uses cabbage imagery
    test('Case 6: Cabbage uses cabbage imagery', () async {
      const cabbagePhoto = 'https://cdn.pixabay.com/photo/green_cabbage.jpg';
      final cabbageModel = FoodImageModel(
        entityType: FoodEntityType.ingredient,
        entityKey: 'cabbage',
        displayName: 'Cabbage',
        imageUrl: cabbagePhoto,
        provider: 'pixabay',
      );
      FoodImageRepository.instance.putInMemoryCache(cabbageModel);

      const cabbageItem = CategoryFoodItem(
        id: 'cabbage_item',
        name: 'Cabbage',
        quantity: '1 head',
        category: 'Vegetables',
      );

      final res = CookingCutoutResolver.resolveSync(cabbageItem);

      // Must use cabbage imagery (never apple.png or unrelated vegetable)
      expect(res.imagePath, cabbagePhoto);
      expect(res.imagePath, isNot(contains('apple')));
      expect(res.canonicalKey, 'cabbage');
    });

    // Case 7: Multiple selected ingredients resolve independently
    test('Case 7: Multiple selected ingredients resolve independently', () async {
      // 1. Apple has curated cutout
      const appleItem = CategoryFoodItem(id: 'a1', name: 'Apple', quantity: '2 pcs', category: 'Fruits');
      // 2. Tomato has curated cutout
      const tomatoItem = CategoryFoodItem(id: 't1', name: 'Tomato', quantity: '3 pcs', category: 'Vegetables');
      // 3. Brinjal has photo fallback
      final brinjalModel = FoodImageModel(
        entityType: FoodEntityType.ingredient,
        entityKey: 'brinjal',
        displayName: 'Brinjal',
        imageUrl: 'https://cdn.pixabay.com/photo/purple_brinjal.jpg',
        provider: 'pixabay',
      );
      FoodImageRepository.instance.putInMemoryCache(brinjalModel);
      const brinjalItem = CategoryFoodItem(id: 'b1', name: 'Brinjal', quantity: '1 pc', category: 'Vegetables');

      final appleRes = CookingCutoutResolver.resolveSync(appleItem);
      final tomatoRes = CookingCutoutResolver.resolveSync(tomatoItem);
      final brinjalRes = CookingCutoutResolver.resolveSync(brinjalItem);

      expect(appleRes.imagePath, 'assets/images/foods/apple.png');
      expect(appleRes.isTransparentCutout, isTrue);

      expect(tomatoRes.imagePath, 'assets/images/foods/tomato.png');
      expect(tomatoRes.isTransparentCutout, isTrue);

      expect(brinjalRes.imagePath, 'https://cdn.pixabay.com/photo/purple_brinjal.jpg');
      expect(brinjalRes.isTransparentCutout, isFalse);
      expect(brinjalRes.isFridgePhotoFallback, isTrue);
    });

    // Case 8: Cached cutouts are reused
    test('Case 8: Cached cutouts are reused', () async {
      int removalCalls = 0;
      CookingCutoutResolver.mockCutoutGenerator = (canonicalKey, sourceImageUrl) async {
        removalCalls++;
        return 'https://supabase.nutrifridge.com/food-photos/cutouts/spinach_cutout.png';
      };

      final spinachModel = FoodImageModel(
        entityType: FoodEntityType.ingredient,
        entityKey: 'spinach',
        displayName: 'Spinach',
        imageUrl: 'https://cdn.pixabay.com/photo/spinach_leaf.jpg',
        provider: 'pixabay',
      );
      FoodImageRepository.instance.putInMemoryCache(spinachModel);

      // 1. First resolution generates cutout
      final first = await CookingCutoutResolver.resolveByNameAsync(name: 'Spinach', category: 'Vegetables');
      expect(first.imagePath, 'https://supabase.nutrifridge.com/food-photos/cutouts/spinach_cutout.png');
      expect(removalCalls, 1);

      // 2. Second resolution synchronously uses cached cutout without re-generating
      const spinachItem = CategoryFoodItem(id: 'sp_1', name: 'Spinach', quantity: '1 bunch', category: 'Vegetables');
      final second = CookingCutoutResolver.resolveSync(spinachItem);
      expect(second.imagePath, 'https://supabase.nutrifridge.com/food-photos/cutouts/spinach_cutout.png');
      expect(second.isTransparentCutout, isTrue);
      expect(removalCalls, 1); // No new background removal call
    });

    // Case 9: No emoji or unrelated ingredient photographs appear as fallbacks
    test('Case 9: No emoji or unrelated ingredient photographs appear as fallbacks', () {
      final watermelonModel = FoodImageModel(
        entityType: FoodEntityType.ingredient,
        entityKey: 'watermelon',
        displayName: 'Watermelon',
        imageUrl: 'https://cdn.pixabay.com/photo/watermelon_slice.jpg',
        provider: 'pixabay',
      );
      FoodImageRepository.instance.putInMemoryCache(watermelonModel);

      const watermelonItem = CategoryFoodItem(
        id: 'wm_1',
        name: 'Watermelon',
        quantity: '1 piece',
        category: 'Fruits',
        iconEmoji: '🍉',
      );

      final res = CookingCutoutResolver.resolveSync(watermelonItem);

      // Must NOT be apple.png
      expect(res.imagePath, isNot('assets/images/foods/apple.png'));
      // Must NOT be an emoji string
      expect(res.imagePath, isNot('🍉'));
      expect(res.imagePath, 'https://cdn.pixabay.com/photo/watermelon_slice.jpg');
    });

    // Case 10: Existing Fridge photographs remain unchanged
    test('Case 10: Existing Fridge photographs remain unchanged', () async {
      const originalFridgeUrl = 'https://cdn.pixabay.com/photo/eggplant_purple.jpg';
      final brinjalModel = FoodImageModel(
        entityType: FoodEntityType.ingredient,
        entityKey: 'brinjal',
        displayName: 'Brinjal',
        imageUrl: originalFridgeUrl,
        provider: 'pixabay',
      );
      FoodImageRepository.instance.putInMemoryCache(brinjalModel);

      // Cutout generator generates a transparent cutout
      CookingCutoutResolver.mockCutoutGenerator = (canonicalKey, sourceImageUrl) async {
        return 'https://supabase.nutrifridge.com/food-photos/cutouts/brinjal_alpha.png';
      };

      await CookingCutoutResolver.resolveByNameAsync(name: 'Brinjal', category: 'Vegetables');

      // Check Fridge photo mapping: imageUrl must remain the original verified photograph!
      final fridgeModel = FoodImageRepository.instance.getCachedMapping(
        type: FoodEntityType.ingredient,
        entityKey: 'brinjal',
      );

      expect(fridgeModel, isNotNull);
      expect(fridgeModel!.imageUrl, originalFridgeUrl);
      expect(fridgeModel.panCutoutUrl, 'https://supabase.nutrifridge.com/food-photos/cutouts/brinjal_alpha.png');
    });

    // Case 11: Cauliflower uses cauliflower imagery and does not fall back to carrot
    test('Case 11: Cauliflower uses cauliflower imagery and does not fall back to carrot', () async {
      const cauliflowerPhoto = 'https://cdn.pixabay.com/photo/white_cauliflower.jpg';
      final cauliflowerModel = FoodImageModel(
        entityType: FoodEntityType.ingredient,
        entityKey: 'cauliflower',
        displayName: 'Cauliflower',
        imageUrl: cauliflowerPhoto,
        provider: 'pixabay',
      );
      FoodImageRepository.instance.putInMemoryCache(cauliflowerModel);

      const cauliflowerItem = CategoryFoodItem(
        id: 'cauliflower_item',
        name: 'Cauliflower',
        quantity: '1 head',
        category: 'Vegetables',
      );

      final res = CookingCutoutResolver.resolveSync(cauliflowerItem);

      // Must use cauliflower imagery (never carrot or unrelated vegetable)
      expect(res.imagePath, cauliflowerPhoto);
      expect(res.imagePath, isNot(contains('carrot')));
      expect(res.canonicalKey, 'cauliflower');
    });

    // Cooking Workspace Widget Tests: CookingPanVisual & CookingIngredientCutoutView
    testWidgets('CookingPanVisual renders transparent cutout for Apple and contained photo for Brinjal', (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const appleItem = CategoryFoodItem(id: 'a1', name: 'Apple', quantity: '2 pcs', category: 'Fruits');
      const brinjalItem = CategoryFoodItem(id: 'b1', name: 'Brinjal', quantity: '1 pc', category: 'Vegetables');

      final brinjalModel = FoodImageModel(
        entityType: FoodEntityType.ingredient,
        entityKey: 'brinjal',
        displayName: 'Brinjal',
        imageUrl: 'https://cdn.pixabay.com/photo/eggplant_purple.jpg',
        provider: 'pixabay',
      );
      FoodImageRepository.instance.putInMemoryCache(brinjalModel);

      CookingBasketService.toggleItem(appleItem);
      CookingBasketService.toggleItem(brinjalItem);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CookingPanVisual(
              width: 300,
              height: 200,
              isExpanded: true,
            ),
          ),
        ),
      );

      await tester.pump();

      // Pan is rendered
      expect(find.byType(CookingPanVisual), findsOneWidget);

      // Both items are in pan
      expect(CookingBasketService.selectedItems.length, 2);

      // CookingPanVisual resolved assets:
      // Apple resolves to transparent cutout
      expect(CookingPanVisual.resolvePanAsset(appleItem), 'assets/images/foods/apple.png');
      // Brinjal resolves to brinjal photograph fallback (never apple.png!)
      expect(CookingPanVisual.resolvePanAsset(brinjalItem), 'https://cdn.pixabay.com/photo/eggplant_purple.jpg');
    });

    testWidgets('CookingWorkspaceScreen renders CookingIngredientCutoutView in chips and carousel', (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const appleItem = CategoryFoodItem(id: 'a1', name: 'Apple', quantity: '2 pcs', category: 'Fruits');
      CookingBasketService.toggleItem(appleItem);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CookingWorkspaceScreen(),
          ),
        ),
      );

      await tester.pump();

      // CookingIngredientCutoutView rendered for selected ingredient chips
      expect(find.byType(CookingIngredientCutoutView), findsAtLeastNWidgets(1));
      expect(find.text('Apple'), findsAtLeastNWidgets(1));
    });
  });
}
