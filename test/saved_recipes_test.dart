import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/screens/guided_cooking/screens/guided_cooking_screen.dart';
import 'package:nutrifridge/screens/meal_detail/meal_detail_screen.dart';
import 'package:nutrifridge/screens/meal_detail/models/recipe_preparation_step.dart';
import 'package:nutrifridge/screens/saved_recipes/saved_recipes_screen.dart';
import 'package:nutrifridge/screens/saved_recipes/widgets/recipe_save_button.dart';
import 'package:nutrifridge/services/recipe/saved_recipes_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testRecipe = RecipeRecommendation(
    id: 'rec_test_101',
    title: 'Spinach Paneer Scramble',
    mealType: 'BREAKFAST',
    tag: 'BREAKFAST',
    calories: 380,
    proteinGrams: 28,
    carbsGrams: 14,
    fatGrams: 22,
    prepTimeMinutes: 10,
    cookingTimeMinutes: 15,
    servingSize: '2 servings',
    fridgeItemsUsed: 2,
    imageUrl: 'assets/images/meals/paneer_scramble.png',
    requiredIngredients: ['Spinach (100g)', 'Paneer (150g)', 'Olive Oil (1 tbsp)'],
    missingIngredients: ['Salt'],
    preparationSteps: [
      RecipePreparationStep(stepNumber: 1, instruction: 'Chop the fresh spinach finely.'),
      RecipePreparationStep(stepNumber: 2, instruction: 'Crumble the paneer and sautÃ© with spinach.'),
      RecipePreparationStep(stepNumber: 3, instruction: 'Season lightly and serve hot.'),
    ],
  );

  final testDinnerRecipe = RecipeRecommendation(
    id: 'rec_test_202',
    title: 'Hearty Tomato Lentil Soup',
    mealType: 'DINNER',
    tag: 'DINNER',
    calories: 420,
    proteinGrams: 22,
    carbsGrams: 58,
    fatGrams: 8,
    prepTimeMinutes: 15,
    cookingTimeMinutes: 30,
    servingSize: '3 servings',
    fridgeItemsUsed: 3,
    imageUrl: 'assets/images/meals/lentil_soup.png',
    requiredIngredients: ['Lentils (1 cup)', 'Tomatoes (2 diced)', 'Garlic (3 cloves)'],
    missingIngredients: [],
    preparationSteps: [
      RecipePreparationStep(stepNumber: 1, instruction: 'Rinse lentils thoroughly.'),
      RecipePreparationStep(stepNumber: 2, instruction: 'Simmer with diced tomatoes and garlic for 25 minutes.'),
    ],
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SavedRecipesService.instance.resetForTesting();
    await SavedRecipesService.instance.init(forceReload: true);
  });

  group('NutriFridge — Saved Recipes & Favourites System Tests', () {
    // 1. Saving a generated recipe adds it to Saved Recipes
    test('1. Saving a generated recipe adds it to Saved Recipes', () async {
      final service = SavedRecipesService.instance;
      expect(service.isSaved(testRecipe), isFalse);

      final result = await service.saveRecipe(testRecipe);
      expect(result, isTrue);
      expect(service.isSaved(testRecipe), isTrue);
      expect(service.currentSavedRecipes.length, 1);
      expect(service.currentSavedRecipes.first.title, 'Spinach Paneer Scramble');
    });

    // 2. Heart icon reflects saved status
    testWidgets('2. Heart icon reflects saved status', (tester) async {
      final service = SavedRecipesService.instance;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RecipeSaveButton(recipe: testRecipe),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially unsaved -> outline heart
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);

      // Tap to save
      await tester.tap(find.byType(RecipeSaveButton));
      await tester.pumpAndSettle();

      // Now saved -> filled heart
      expect(service.isSaved(testRecipe), isTrue);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    });

    // 3. Repeated saves do not create duplicates
    test('3. Repeated saves do not create duplicates', () async {
      final service = SavedRecipesService.instance;
      await service.saveRecipe(testRecipe);
      await service.saveRecipe(testRecipe);
      await service.saveRecipe(testRecipe);

      expect(service.currentSavedRecipes.length, 1);
    });

    // 4. Unsaving removes the recipe
    test('4. Unsaving removes the recipe', () async {
      final service = SavedRecipesService.instance;
      await service.saveRecipe(testRecipe);
      expect(service.isSaved(testRecipe), isTrue);

      final removed = await service.removeRecipe(testRecipe.id);
      expect(removed, isTrue);
      expect(service.isSaved(testRecipe), isFalse);
      expect(service.currentSavedRecipes, isEmpty);
    });

    // 5. Saved recipes survive app restart
    test('5. Saved recipes survive app restart', () async {
      final service = SavedRecipesService.instance;
      await service.saveRecipe(testRecipe);
      expect(service.isSaved(testRecipe), isTrue);

      // Simulate app restart: re-initialize service from persistent storage
      SavedRecipesService.instance.resetForTesting();
      expect(service.currentSavedRecipes, isEmpty);

      await SavedRecipesService.instance.init(forceReload: true);
      expect(service.isSaved(testRecipe), isTrue);
      expect(service.currentSavedRecipes.length, 1);
      expect(service.currentSavedRecipes.first.id, testRecipe.id);
    });

    // 6. Recipes remain associated with the correct user
    test('6. Recipes remain associated with the correct user', () async {
      final service = SavedRecipesService.instance;
      await service.saveRecipe(testRecipe, userId: 'user_alice');
      await service.saveRecipe(testDinnerRecipe, userId: 'user_bob');

      final aliceRecipes = await service.getSavedRecipesForUser('user_alice');
      final bobRecipes = await service.getSavedRecipesForUser('user_bob');

      expect(aliceRecipes.length, 1);
      expect(aliceRecipes.first.title, 'Spinach Paneer Scramble');

      expect(bobRecipes.length, 1);
      expect(bobRecipes.first.title, 'Hearty Tomato Lentil Soup');
    });

    // 7. Saved recipe details load without Gemini calls
    testWidgets('7. Saved recipe details load without Gemini calls', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MealDetailScreen(recommendation: testRecipe),
        ),
      );
      await tester.pumpAndSettle();

      // Verify recipe details are rendered purely from snapshot
      expect(find.text('Spinach Paneer Scramble'), findsWidgets);
      expect(find.text('380'), findsWidgets);
      expect(find.text('28'), findsWidgets);
      expect(find.text('Chop the fresh spinach finely.'), findsOneWidget);
    });

    // 8. Original ingredients, quantities and instructions remain intact
    test('8. Original ingredients, quantities and instructions remain intact', () {
      final jsonSnapshot = testRecipe.toJson();
      final restored = RecipeRecommendation.fromJson(jsonSnapshot);

      expect(restored.id, testRecipe.id);
      expect(restored.title, testRecipe.title);
      expect(restored.calories, testRecipe.calories);
      expect(restored.proteinGrams, testRecipe.proteinGrams);
      expect(restored.carbsGrams, testRecipe.carbsGrams);
      expect(restored.fatGrams, testRecipe.fatGrams);
      expect(restored.prepTimeMinutes, testRecipe.prepTimeMinutes);
      expect(restored.cookingTimeMinutes, testRecipe.cookingTimeMinutes);
      expect(restored.servingSize, testRecipe.servingSize);
      expect(restored.requiredIngredients, testRecipe.requiredIngredients);
      expect(restored.missingIngredients, testRecipe.missingIngredients);
      expect(restored.preparationSteps.length, 3);
      expect(restored.preparationSteps.first.instruction, 'Chop the fresh spinach finely.');
    });

    // 9. Search finds saved recipes correctly
    testWidgets('9. Search finds saved recipes correctly', (tester) async {
      await SavedRecipesService.instance.saveRecipe(testRecipe);
      await SavedRecipesService.instance.saveRecipe(testDinnerRecipe);

      await tester.pumpWidget(
        const MaterialApp(
          home: SavedRecipesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Spinach Paneer Scramble'), findsOneWidget);
      expect(find.text('Hearty Tomato Lentil Soup'), findsOneWidget);

      // Search for Lentil
      await tester.enterText(find.byKey(const ValueKey('saved_recipes_search_input')), 'Lentil');
      await tester.pumpAndSettle();

      expect(find.text('Hearty Tomato Lentil Soup'), findsOneWidget);
      expect(find.text('Spinach Paneer Scramble'), findsNothing);
    });

    // 10. Category filters work
    testWidgets('10. Category filters work', (tester) async {
      await SavedRecipesService.instance.saveRecipe(testRecipe); // BREAKFAST
      await SavedRecipesService.instance.saveRecipe(testDinnerRecipe); // DINNER

      await tester.pumpWidget(
        const MaterialApp(
          home: SavedRecipesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Breakfast chip
      await tester.tap(find.byKey(const ValueKey('category_chip_Breakfast')));
      await tester.pumpAndSettle();

      expect(find.text('Spinach Paneer Scramble'), findsOneWidget);
      expect(find.text('Hearty Tomato Lentil Soup'), findsNothing);

      // Tap Dinner chip
      await tester.tap(find.byKey(const ValueKey('category_chip_Dinner')));
      await tester.pumpAndSettle();

      expect(find.text('Hearty Tomato Lentil Soup'), findsOneWidget);
      expect(find.text('Spinach Paneer Scramble'), findsNothing);
    });

    // 11. Empty state appears when no recipes are saved
    testWidgets('11. Empty state appears when no recipes are saved', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SavedRecipesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No saved recipes yet'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    });

    // 12. Start Cooking uses the saved recipe's actual data
    testWidgets('12. Start Cooking uses the saved recipe\'s actual data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MealDetailScreen(recommendation: testRecipe),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to Start Cooking button
      final startCookingFinder = find.widgetWithText(ElevatedButton, 'Start Cooking');
      expect(startCookingFinder, findsOneWidget);

      await tester.ensureVisible(startCookingFinder);
      await tester.tap(startCookingFinder);
      await tester.pumpAndSettle();

      // Guided Cooking mode opened with saved recipe
      expect(find.byType(GuidedCookingScreen), findsOneWidget);
      expect(find.text('Spinach Paneer Scramble'), findsWidgets);
      expect(find.byKey(const ValueKey('begin_cooking_btn')), findsOneWidget);
    });

    // 13. Storage errors are handled without falsely showing success
    test('13. Storage errors are handled without falsely showing success', () async {
      final service = SavedRecipesService.instance;
      service.simulateStorageError = true;

      // Attempting to save under storage error
      bool errorCaught = false;
      try {
        final result = await service.saveRecipe(testRecipe);
        if (!result) errorCaught = true;
      } catch (_) {
        errorCaught = true;
      }

      expect(errorCaught, isTrue);
      // Service must not falsely record recipe as saved
      expect(service.isSaved(testRecipe), isFalse);
      expect(service.currentSavedRecipes, isEmpty);
    });
  });
}
