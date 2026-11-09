import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/screens/home/services/meal_recommendation_service.dart';
import 'package:nutrifridge/screens/home/widgets/recommendation_card.dart';
import 'package:nutrifridge/screens/meal_detail/meal_detail_screen.dart';
import 'package:nutrifridge/screens/meal_detail/models/meal_detail_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FridgeCategoryRepository.forceInMemoryForTesting = true;
    FridgeCategoryRepository.reset();
  });

  tearDown(() {
    FridgeCategoryRepository.reset();
    FridgeCategoryRepository.forceInMemoryForTesting = false;
  });

  RecipeRecommendation createTestRec({
    required String title,
    int calories = 300,
    int proteinGrams = 20,
    int prepTimeMinutes = 0,
    int? cookingTimeMinutes,
    int fridgeItemsUsed = 0,
    List<String> requiredIngredients = const [],
    List<String> matchReasons = const [],
    List<RecipePreparationStep> preparationSteps = const [],
    String? videoSearchQuery,
    String? videoUrl,
  }) {
    return RecipeRecommendation(
      title: title,
      imageUrl: 'assets/images/paneer_rice_bowl.jpg',
      calories: calories,
      proteinGrams: proteinGrams,
      prepTimeMinutes: prepTimeMinutes,
      cookingTimeMinutes: cookingTimeMinutes,
      fridgeItemsUsed: fridgeItemsUsed,
      requiredIngredients: requiredIngredients,
      matchReasons: matchReasons,
      preparationSteps: preparationSteps,
      videoSearchQuery: videoSearchQuery,
      videoUrl: videoUrl,
    );
  }

  group('NutriFridge — Custom Meal Detail Screen Refinements Tests', () {
    // -------------------------------------------------------------------------
    // Scenario 1: Two ingredients available, one partially available -> fridge count displays 2 ("Uses 2 ingredients from your fridge")
    // -------------------------------------------------------------------------
    test('Scenario 1: One available and one partially available count as 2 ingredients from fridge with plural grammar', () {
      // Setup inventory:
      // - Eggs: 2 pieces (recipe needs 2 -> fully available)
      // - Bread: 1 slice (recipe needs 2 -> partially available)
      // - Tomato: not in fridge (recipe needs 1 -> missing)
      FridgeCategoryRepository.addOrMergeItem(
        categoryName: 'Dairy Products',
        name: 'Eggs',
        quantity: 2,
        unit: 'pieces',
      );
      FridgeCategoryRepository.addOrMergeItem(
        categoryName: 'Packaged Food',
        name: 'Bread',
        quantity: 1,
        unit: 'slice',
      );

      final rec = createTestRec(
        title: 'Egg Sandwich',
        calories: 320,
        proteinGrams: 18,
        prepTimeMinutes: 10,
        cookingTimeMinutes: 5,
        requiredIngredients: [
          'Eggs (2 pieces)',
          'Bread (2 slices)',
          'Tomato (1 piece)',
        ],
      );

      // Verify recommendation calculated fridge count
      expect(rec.calculatedFridgeItemsUsed, equals(2));

      // Verify MealDetailInfo resolves reasons
      final detailInfo = MealDetailInfo.fromRecommendation(rec);
      expect(
        detailInfo.whyReasons.any((r) => r == 'Uses 2 ingredients from your fridge'),
        isTrue,
        reason: 'Should state "Uses 2 ingredients from your fridge" with plural grammar',
      );
    });

    // -------------------------------------------------------------------------
    // Scenario 2: One available and one completely unavailable -> displays 1 ("Uses 1 ingredient from your fridge")
    // -------------------------------------------------------------------------
    test('Scenario 2: One available and one completely unavailable -> displays 1 with singular grammar', () {
      FridgeCategoryRepository.addOrMergeItem(
        categoryName: 'Dairy Products',
        name: 'Eggs',
        quantity: 3,
        unit: 'pieces',
      );

      final rec = createTestRec(
        title: 'Boiled Eggs & Spinach',
        calories: 160,
        proteinGrams: 14,
        prepTimeMinutes: 5,
        cookingTimeMinutes: 8,
        requiredIngredients: [
          'Eggs (2 pieces)',
          'Spinach (1 bunch)',
        ],
      );

      expect(rec.calculatedFridgeItemsUsed, equals(1));

      final detailInfo = MealDetailInfo.fromRecommendation(rec);
      expect(
        detailInfo.whyReasons.any((r) => r == 'Uses 1 ingredient from your fridge'),
        isTrue,
        reason: 'Should state "Uses 1 ingredient from your fridge" with singular grammar',
      );
      expect(
        detailInfo.whyReasons.any((r) => r.contains('ingredients')),
        isFalse,
        reason: 'Must not use plural "ingredients" for a single item',
      );
    });

    // -------------------------------------------------------------------------
    // Scenario 3: No matching inventory ingredients -> displays 0 or omits fridge-use claim
    // -------------------------------------------------------------------------
    test('Scenario 3: No matching inventory ingredients -> calculated count is 0 and omits fridge-use claim', () {
      // Fridge has only unrelated item
      FridgeCategoryRepository.addOrMergeItem(
        categoryName: 'Fruits',
        name: 'Mango',
        quantity: 1,
        unit: 'piece',
      );

      final rec = createTestRec(
        title: 'Chicken Soup',
        calories: 250,
        proteinGrams: 28,
        prepTimeMinutes: 10,
        cookingTimeMinutes: 20,
        requiredIngredients: [
          'Chicken Breast (200 g)',
          'Carrot (1 piece)',
        ],
        matchReasons: ['High in protein', 'Uses ingredients from your fridge.'],
      );

      expect(rec.calculatedFridgeItemsUsed, equals(0));

      final detailInfo = MealDetailInfo.fromRecommendation(rec);
      expect(
        detailInfo.whyReasons.any((r) => r.toLowerCase().contains('from your fridge')),
        isFalse,
        reason: 'Must omit any fridge-use claim when 0 matching ingredients are available',
      );
      expect(
        detailInfo.whyReasons.any((r) => r.toLowerCase().contains('uses ingredients')),
        isFalse,
        reason: 'Must filter out stale/generic claims from matchReasons',
      );
    });

    // -------------------------------------------------------------------------
    // Scenario 4: Different recipes display their own actual cooking durations
    // -------------------------------------------------------------------------
    test('Scenario 4: Different recipes display distinct dynamic total durations without 20 min hardcoded fallback', () {
      // 15 min recipe (e.g. Omelette: 5 min prep + 10 min cook)
      final omelette = createTestRec(
        title: 'Omelette',
        calories: 210,
        proteinGrams: 14,
        prepTimeMinutes: 5,
        cookingTimeMinutes: 10,
      );
      expect(omelette.totalTimeMinutes, equals(15));
      final omeletteDetail = MealDetailInfo.fromRecommendation(omelette);
      expect(omeletteDetail.totalTimeMinutes, equals(15));

      // 25 min recipe (e.g. Fried Rice: 10 min prep + 15 min cook)
      final friedRice = createTestRec(
        title: 'Fried Rice',
        calories: 380,
        proteinGrams: 10,
        prepTimeMinutes: 10,
        cookingTimeMinutes: 15,
      );
      expect(friedRice.totalTimeMinutes, equals(25));
      final friedRiceDetail = MealDetailInfo.fromRecommendation(friedRice);
      expect(friedRiceDetail.totalTimeMinutes, equals(25));

      // 30 min recipe (e.g. Pasta: 10 min prep + 20 min cook)
      final pasta = createTestRec(
        title: 'Pasta Primavera',
        calories: 420,
        proteinGrams: 12,
        prepTimeMinutes: 10,
        cookingTimeMinutes: 20,
      );
      expect(pasta.totalTimeMinutes, equals(30));
      final pastaDetail = MealDetailInfo.fromRecommendation(pasta);
      expect(pastaDetail.totalTimeMinutes, equals(30));

      // Recipe with NO time estimate (0 prep, null cook) -> totalTimeMinutes is null (no 20 min fallback!)
      final noTimeRecipe = createTestRec(
        title: 'Custom Mystery Salad',
        calories: 150,
        proteinGrams: 4,
        prepTimeMinutes: 0,
        cookingTimeMinutes: null,
      );
      expect(noTimeRecipe.totalTimeMinutes, isNull);
      final noTimeDetail = MealDetailInfo.fromRecommendation(noTimeRecipe);
      expect(noTimeDetail.totalTimeMinutes, isNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 5: Dashboard card and detail screen display identical duration values
    // -------------------------------------------------------------------------
    testWidgets('Scenario 5: Dashboard card and detail screen display identical duration values', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final rec = createTestRec(
        title: 'Mediterranean Quinoa',
        calories: 340,
        proteinGrams: 12,
        prepTimeMinutes: 10,
        cookingTimeMinutes: 15, // total 25 min
        requiredIngredients: ['Quinoa (100g)'],
      );

      // Verify Dashboard RecommendationCard renders "25 min"
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecommendationCard(
              discoveryMode: MealDiscoveryMode.aiSuggestion,
              recommendation: rec,
              status: RecommendationStatus.loaded,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('25 min'), findsOneWidget);

      // Verify MealDetailScreen renders "25 min" in both Hero overlay and Nutrition & prep badge
      await tester.pumpWidget(
        MaterialApp(
          home: MealDetailScreen(
            recommendation: rec,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // MealDetailScreen has 2 instances of "25 min": one in hero overlay, one in nutrition & prep
      expect(find.text('25 min'), findsNWidgets(2));
    });

    // -------------------------------------------------------------------------
    // Scenario 6: Preparation steps display directly without "Generate Steps" or "Cook with AI" buttons in preparation; hides section when steps empty
    // -------------------------------------------------------------------------
    testWidgets('Scenario 6: Preparation steps display directly; no redundant AI buttons in preparation; hides section when empty', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Case A: Recipe with preparation steps
      final recWithSteps = createTestRec(
        title: 'Custom Scramble',
        calories: 220,
        proteinGrams: 16,
        prepTimeMinutes: 5,
        cookingTimeMinutes: 5,
        requiredIngredients: ['Eggs (2 pieces)'],
        preparationSteps: const [
          RecipePreparationStep(
            stepNumber: 1,
            instruction: 'Whisk eggs thoroughly with salt and pepper.',
            time: '2 mins',
          ),
          RecipePreparationStep(
            stepNumber: 2,
            instruction: 'Pour into hot pan and scramble gently.',
            time: '3 mins',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MealDetailScreen(
            recommendation: recWithSteps,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Steps are displayed directly
      expect(find.text('Preparation'), findsOneWidget);
      expect(find.text('2 steps'), findsOneWidget);
      expect(find.text('Whisk eggs thoroughly with salt and pepper.'), findsOneWidget);
      expect(find.text('Pour into hot pan and scramble gently.'), findsOneWidget);

      // Redundant AI generation triggers/buttons from the preparation section MUST NOT exist
      expect(find.text('Generate Steps'), findsNothing);
      expect(find.text('Step-by-step instructions available via AI'), findsNothing);
      expect(find.textContaining('Tap "Cook with AI" to generate full preparation steps'), findsNothing);

      // Case B: Recipe with NO preparation steps initially renders Generate Steps placeholder
      final recWithoutSteps = createTestRec(
        title: 'Raw Snack Plate',
        calories: 120,
        proteinGrams: 3,
        prepTimeMinutes: 2,
        cookingTimeMinutes: null,
        requiredIngredients: ['Almonds (20g)'],
        preparationSteps: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MealDetailScreen(
            recommendation: recWithoutSteps,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Preparation section renders Generate Steps button for empty steps
      expect(find.text('Preparation'), findsOneWidget);
      expect(find.text('Generate Steps'), findsOneWidget);
      expect(find.text('Step-by-step instructions available via AI'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 7: "Watch how it's made" video carousel section renders and functions as expected
    // -------------------------------------------------------------------------
    testWidgets('Scenario 7: "Watch how it\'s made" video carousel renders and functions cleanly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Case A: Recommendation with video URL provided
      final recWithVideo = createTestRec(
        title: 'Paneer Butter Masala',
        calories: 450,
        proteinGrams: 20,
        prepTimeMinutes: 10,
        cookingTimeMinutes: 20,
        videoSearchQuery: 'how to cook paneer butter masala restaurant style',
        videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MealDetailScreen(
            recommendation: recWithVideo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify "Watch how it's made" section exists
      expect(find.text("Watch how it's made"), findsOneWidget);

      // Verify the video card with title and channel is rendered
      expect(find.text('Paneer Butter Masala - Video Guide'), findsOneWidget);
      expect(find.text('Cooking Tutorial'), findsOneWidget);

      // Case B: Recommendation without specific video URL falls back to YouTube search action card
      final recWithoutVideo = createTestRec(
        title: 'Quick Oats',
        calories: 200,
        proteinGrams: 8,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MealDetailScreen(
            recommendation: recWithoutVideo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Watch how it's made"), findsOneWidget);
      expect(find.text('Find cooking videos'), findsOneWidget);
      expect(find.text('Watch tutorials for this recipe.'), findsOneWidget);
    });
  });
}
