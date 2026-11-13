import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/screens/guided_cooking/models/guided_cooking_timer_state.dart';
import 'package:nutrifridge/screens/guided_cooking/screens/guided_cooking_screen.dart';
import 'package:nutrifridge/screens/guided_cooking/utils/cooking_timer_helper.dart';
import 'package:nutrifridge/screens/guided_cooking/utils/step_instruction_parser.dart';
import 'package:nutrifridge/screens/meal_detail/meal_detail_screen.dart';
import 'package:nutrifridge/screens/meal_detail/models/meal_detail_data.dart';
import 'package:nutrifridge/screens/ai_assistant/services/ai_assistant_service.dart';
import 'package:nutrifridge/screens/home/services/meal_recommendation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecipeRecommendation testRecommendation;
  late MealDetailInfo testMeal;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MockDataRepository.forceInMemoryForTesting = true;
    MockDataRepository.reset();
    FridgeCategoryRepository.forceInMemoryForTesting = true;
    FridgeCategoryRepository.reset();

    testRecommendation = const RecipeRecommendation(
      id: 'rec_guided_test_001',
      title: 'Spinach Tomato Paneer Curry',
      imageUrl: 'assets/images/foods/curry.png',
      calories: 380,
      proteinGrams: 24,
      carbsGrams: 16,
      fatGrams: 14,
      prepTimeMinutes: 10,
      cookingTimeMinutes: 20,
      fridgeItemsUsed: 3,
      tag: 'Dinner',
      mealType: 'dinner',
      servingSize: '2 servings',
      requiredIngredients: [
        'Spinach (1 bunch)',
        'Tomatoes (2 pieces)',
        'Paneer (200 g)',
      ],
      missingIngredients: [],
      preparationSteps: [
        RecipePreparationStep(
          stepNumber: 1,
          instruction: 'Wash and roughly chop the spinach leaves and tomatoes.',
        ),
        RecipePreparationStep(
          stepNumber: 2,
          instruction: 'Sauté tomatoes with spices in a pan for 5 minutes.',
          time: '5 mins',
        ),
        RecipePreparationStep(
          stepNumber: 3,
          instruction: 'Add paneer cubes and simmer on low heat for 10 minutes.',
          time: '10 mins',
        ),
        RecipePreparationStep(
          stepNumber: 4,
          instruction: 'Garnish with freshly chopped coriander and serve hot.',
        ),
      ],
    );

    testMeal = MealDetailInfo.fromRecommendation(testRecommendation);
  });

  group('NutriFridge — Interactive Guided Cooking Mode (v1)', () {
    // 1. Start Cooking opens the correct recipe.
    testWidgets('1. Start Cooking opens the correct recipe', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MealDetailScreen(
            recommendation: testRecommendation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Start Cooking button on MealDetailScreen
      final startCookingBtn = find.byKey(const ValueKey('start_cooking_btn'));
      expect(startCookingBtn, findsOneWidget);

      await tester.ensureVisible(startCookingBtn);
      await tester.tap(startCookingBtn);
      await tester.pumpAndSettle();

      // Guided Cooking Preparation Screen should be opened with the exact recipe title
      expect(find.byType(GuidedCookingScreen), findsOneWidget);
      expect(find.text('Spinach Tomato Paneer Curry'), findsOneWidget);
      expect(find.text('Preparation Checklist'), findsOneWidget);
    });

    // 2. Correct ingredients and quantities are displayed.
    testWidgets('2. Correct ingredients and quantities are displayed', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GuidedCookingScreen(
            meal: testMeal,
            recommendation: testRecommendation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check ingredient names and quantity representations
      expect(find.text('Spinach'), findsOneWidget);
      expect(find.text('Tomatoes'), findsOneWidget);
      expect(find.text('Paneer'), findsOneWidget);
      expect(find.text('1 bunch'), findsOneWidget);
      expect(find.text('2 pieces'), findsOneWidget);
      expect(find.text('200 g'), findsOneWidget);
    });

    // 3. Preparation checklist works.
    testWidgets('3. Preparation checklist works', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GuidedCookingScreen(
            meal: testMeal,
            recommendation: testRecommendation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 of 3 ready'), findsOneWidget);

      // Tap on first ingredient to tick it
      await tester.tap(find.text('Spinach'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 3 ready'), findsOneWidget);

      // Tap "Check All"
      await tester.tap(find.text('Check All'));
      await tester.pumpAndSettle();
      expect(find.text('3 of 3 ready'), findsOneWidget);

      // Tap "Uncheck All"
      await tester.tap(find.text('Uncheck All'));
      await tester.pumpAndSettle();
      expect(find.text('0 of 3 ready'), findsOneWidget);
    });

    // 4. Previous and Next navigation work.
    testWidgets('4. Previous and Next navigation work', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GuidedCookingScreen(
            meal: testMeal,
            recommendation: testRecommendation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Begin Cooking
      final beginBtn = find.byKey(const ValueKey('begin_cooking_btn'));
      expect(beginBtn, findsOneWidget);
      await tester.tap(beginBtn);
      await tester.pumpAndSettle();

      // Should be on Step 1
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(find.text('Wash and roughly chop the spinach leaves and tomatoes.'), findsOneWidget);

      // Tap Next Step -> advances to Step 2
      final nextBtn = find.byKey(const ValueKey('next_step_btn'));
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 4'), findsOneWidget);
      expect(find.text('Sauté tomatoes with spices in a pan for 5 minutes.'), findsOneWidget);

      // Tap Previous -> returns to Step 1
      final prevBtn = find.byKey(const ValueKey('previous_step_btn'));
      await tester.tap(prevBtn);
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 4'), findsOneWidget);

      // Tap Previous on Step 1 -> returns to Preparation Checklist
      await tester.tap(prevBtn);
      await tester.pumpAndSettle();

      expect(find.text('Preparation Checklist'), findsOneWidget);
    });

    // 5. Progress updates correctly.
    testWidgets('5. Progress updates correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GuidedCookingScreen(
            meal: testMeal,
            recommendation: testRecommendation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('begin_cooking_btn')));
      await tester.pumpAndSettle();

      // Step 1: 1 / 4 = 0.25
      LinearProgressIndicator progressBar = tester.widget(find.byKey(const ValueKey('step_progress_bar')));
      expect(progressBar.value, 0.25);

      // Advance to Step 2: 2 / 4 = 0.50
      await tester.tap(find.byKey(const ValueKey('next_step_btn')));
      await tester.pumpAndSettle();

      progressBar = tester.widget(find.byKey(const ValueKey('step_progress_bar')));
      expect(progressBar.value, 0.50);

      // Advance to Step 3: 3 / 4 = 0.75
      await tester.tap(find.byKey(const ValueKey('next_step_btn')));
      await tester.pumpAndSettle();

      progressBar = tester.widget(find.byKey(const ValueKey('step_progress_bar')));
      expect(progressBar.value, 0.75);

      // Advance to Step 4: 4 / 4 = 1.0
      await tester.tap(find.byKey(const ValueKey('next_step_btn')));
      await tester.pumpAndSettle();

      progressBar = tester.widget(find.byKey(const ValueKey('step_progress_bar')));
      expect(progressBar.value, 1.0);
    });

    // 6. Timers start, pause, resume and reset.
    testWidgets('6. Timers start, pause, resume and reset', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GuidedCookingScreen(
            meal: testMeal,
            recommendation: testRecommendation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter step-by-step mode and advance to Step 2 (has a 5 min timer = 300s)
      await tester.tap(find.byKey(const ValueKey('begin_cooking_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('next_step_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 4'), findsOneWidget);
      expect(find.text('05:00'), findsOneWidget);

      // Start Timer
      final startTimerBtn = find.byKey(const ValueKey('start_timer_btn'));
      expect(startTimerBtn, findsOneWidget);
      await tester.ensureVisible(startTimerBtn);
      await tester.tap(startTimerBtn);
      await tester.pump();

      // Advance clock 2 seconds
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('04:58'), findsOneWidget);

      // Pause Timer
      final pauseBtn = find.byKey(const ValueKey('pause_timer_btn'));
      expect(pauseBtn, findsOneWidget);
      await tester.ensureVisible(pauseBtn);
      await tester.tap(pauseBtn);
      await tester.pump();

      // Clock advances while paused -> remaining seconds should stay frozen
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('04:58'), findsOneWidget);

      // Resume Timer
      final resumeBtn = find.byKey(const ValueKey('resume_timer_btn'));
      expect(resumeBtn, findsOneWidget);
      await tester.ensureVisible(resumeBtn);
      await tester.tap(resumeBtn);
      await tester.pump();

      // Advance clock 3 seconds
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('04:55'), findsOneWidget);

      // Reset Timer
      final resetBtn = find.byKey(const ValueKey('reset_timer_btn'));
      expect(resetBtn, findsOneWidget);
      await tester.ensureVisible(resetBtn);
      await tester.tap(resetBtn);
      await tester.pump();

      expect(find.text('05:00'), findsOneWidget);
    });

    // 7. Timer remains accurate while navigating steps.
    testWidgets('7. Timer remains accurate while navigating steps', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GuidedCookingScreen(
            meal: testMeal,
            recommendation: testRecommendation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('begin_cooking_btn')));
      await tester.pumpAndSettle();

      // Go to Step 2 (5 mins timer)
      await tester.tap(find.byKey(const ValueKey('next_step_btn')));
      await tester.pumpAndSettle();

      expect(find.text('05:00'), findsOneWidget);
      final startBtn = find.byKey(const ValueKey('start_timer_btn'));
      await tester.ensureVisible(startBtn);
      await tester.tap(startBtn);
      await tester.pump();

      // Elapse 5 seconds on Step 2
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('04:55'), findsOneWidget);

      // Navigate to Step 3 while Step 2 timer is running
      await tester.tap(find.byKey(const ValueKey('next_step_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Step 3 of 4'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);

      // Elapse 10 seconds while on Step 3
      await tester.pump(const Duration(seconds: 10));

      // Navigate back to Step 2
      await tester.tap(find.byKey(const ValueKey('previous_step_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Step 2 of 4'), findsOneWidget);

      // Step 2 timer continued running accurately in background: 300 - 5 - 10 = 285s = 04:45
      expect(find.text('04:45'), findsOneWidget);
    });

    // 8. Missing cooking duration does not produce fabricated timers.
    testWidgets('8. Missing cooking duration does not produce fabricated timers', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GuidedCookingScreen(
            meal: testMeal,
            recommendation: testRecommendation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('begin_cooking_btn')));
      await tester.pumpAndSettle();

      // Step 1 has no time specified
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(find.byKey(const ValueKey('start_timer_btn')), findsNothing);
      expect(find.byKey(const ValueKey('step_timer_countdown')), findsNothing);

      // Step 4 also has no time specified
      await tester.tap(find.byKey(const ValueKey('next_step_btn'))); // Step 2
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('next_step_btn'))); // Step 3
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('next_step_btn'))); // Step 4
      await tester.pumpAndSettle();

      expect(find.text('Step 4 of 4'), findsOneWidget);
      expect(find.byKey(const ValueKey('start_timer_btn')), findsNothing);
      expect(find.byKey(const ValueKey('step_timer_countdown')), findsNothing);
    });

    // 9. Completing the final step opens the completion screen.
    testWidgets('9. Completing the final step opens the completion screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GuidedCookingScreen(
            meal: testMeal,
            recommendation: testRecommendation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('begin_cooking_btn')));
      await tester.pumpAndSettle();

      // Advance through Steps 1 to 4
      await tester.tap(find.byKey(const ValueKey('next_step_btn'))); // to 2
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('next_step_btn'))); // to 3
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('next_step_btn'))); // to 4
      await tester.pumpAndSettle();

      expect(find.text('Complete Cooking'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('next_step_btn')));
      await tester.pumpAndSettle();

      // Completion screen must be displayed
      expect(find.byKey(const ValueKey('cooking_complete_title')), findsOneWidget);
      expect(find.text('Cooking Complete!'), findsOneWidget);
      expect(find.byKey(const ValueKey('log_this_meal_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('return_to_recipes_btn')), findsOneWidget);
    });

    // 10. Log This Meal invokes the existing meal logging flow.
    testWidgets('10. Log This Meal invokes the existing meal logging flow', (WidgetTester tester) async {
      bool logMealInvoked = false;
      MealDetailInfo? loggedMeal;

      await tester.pumpWidget(
        MaterialApp(
          home: GuidedCookingScreen(
            meal: testMeal,
            recommendation: testRecommendation,
            onLogMeal: (m) async {
              logMealInvoked = true;
              loggedMeal = m;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fast forward to completion screen
      await tester.tap(find.byKey(const ValueKey('begin_cooking_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('next_step_btn'))); // 2
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('next_step_btn'))); // 3
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('next_step_btn'))); // 4
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('next_step_btn'))); // Complete
      await tester.pumpAndSettle();

      // Tap Log This Meal
      final logBtn = find.byKey(const ValueKey('log_this_meal_btn'));
      expect(logBtn, findsOneWidget);
      await tester.tap(logBtn);
      await tester.pumpAndSettle();

      expect(logMealInvoked, true);
      expect(loggedMeal, isNotNull);
      expect(loggedMeal!.name, 'Spinach Tomato Paneer Curry');
    });

    // 11. Existing inventory quantities remain unchanged during cooking.
    testWidgets('11. Existing inventory quantities remain unchanged during cooking', (WidgetTester tester) async {
      FridgeCategoryRepository.seedSampleDataForTesting();
      final inventoryBefore = FridgeCategoryRepository.allItems
          .map((i) => '${i.id}:${i.name}:${i.decimalAmount}')
          .toList();

      await tester.pumpWidget(
        MaterialApp(
          home: GuidedCookingScreen(
            meal: testMeal,
            recommendation: testRecommendation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // User ticks ingredients in checklist
      await tester.tap(find.text('Spinach'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check All'));
      await tester.pumpAndSettle();

      // User navigates through steps and runs timers
      await tester.tap(find.byKey(const ValueKey('begin_cooking_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('next_step_btn')));
      await tester.pumpAndSettle();
      final timerBtn = find.byKey(const ValueKey('start_timer_btn'));
      await tester.ensureVisible(timerBtn);
      await tester.tap(timerBtn);
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.byKey(const ValueKey('next_step_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('previous_step_btn')));
      await tester.pumpAndSettle();

      // Verify inventory is completely unchanged
      final inventoryAfter = FridgeCategoryRepository.allItems
          .map((i) => '${i.id}:${i.name}:${i.decimalAmount}')
          .toList();

      expect(inventoryAfter, equals(inventoryBefore));
    });

    // 12. No bottom overflow at 320px, 360px, 390px, 430px viewport widths
    testWidgets('12. No bottom overflow at 320px, 360px, 390px and 430px viewport widths', (WidgetTester tester) async {
      final widths = [320.0, 360.0, 390.0, 430.0];

      for (final width in widths) {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.physicalSize = Size(width, 700.0);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            home: GuidedCookingScreen(
              key: UniqueKey(),
              meal: testMeal,
              recommendation: testRecommendation,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Advance to step-by-step cooking
        await tester.tap(find.byKey(const ValueKey('begin_cooking_btn')));
        await tester.pumpAndSettle();

        // Previous and Next buttons must be visible
        expect(find.byKey(const ValueKey('previous_step_btn')), findsOneWidget);
        expect(find.byKey(const ValueKey('next_step_btn')), findsOneWidget);

        expect(tester.takeException(), isNull);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    });

    // 13. No bottom overflow at different supported screen heights
    testWidgets('13. No bottom overflow at different supported screen heights (568, 667, 800, 926)', (WidgetTester tester) async {
      final heights = [568.0, 667.0, 800.0, 926.0];

      for (final height in heights) {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.physicalSize = Size(375.0, height);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            home: GuidedCookingScreen(
              key: UniqueKey(),
              meal: testMeal,
              recommendation: testRecommendation,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('begin_cooking_btn')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('previous_step_btn')), findsOneWidget);
        expect(find.byKey(const ValueKey('next_step_btn')), findsOneWidget);
        expect(tester.takeException(), isNull);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    });

    // 14. Raw Markdown formatting markers are not displayed and heading is extracted
    testWidgets('14. Raw Markdown formatting markers are not displayed and heading is extracted', (WidgetTester tester) async {
      const markdownRecommendation = RecipeRecommendation(
        id: 'rec_markdown_test',
        title: 'Peach Yogurt Bowl',
        imageUrl: 'assets/images/foods/curry.png',
        calories: 250,
        proteinGrams: 15,
        fridgeItemsUsed: 2,
        requiredIngredients: ['Peaches (2 pieces)', 'Yogurt (1 bowl)'],
        missingIngredients: [],
        preparationSteps: [
          RecipePreparationStep(
            stepNumber: 1,
            instruction: '**Assemble the Bowl:** Arrange the peach slices neatly over the yogurt in a fan or circular pattern.',
          ),
          RecipePreparationStep(
            stepNumber: 2,
            instruction: '### Garnish & Serve\nSprinkle with **chia seeds** and drizzle *honey* lightly.',
          ),
        ],
      );

      final markdownMeal = MealDetailInfo.fromRecommendation(markdownRecommendation);

      await tester.pumpWidget(
        MaterialApp(
          home: GuidedCookingScreen(
            meal: markdownMeal,
            recommendation: markdownRecommendation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('begin_cooking_btn')));
      await tester.pumpAndSettle();

      // Step 1: Heading is extracted as "ASSEMBLE THE BOWL"
      expect(find.byKey(const ValueKey('step_action_heading')), findsOneWidget);
      expect(find.text('ASSEMBLE THE BOWL'), findsOneWidget);

      // Clean instruction contains no raw asterisks
      expect(find.text('Arrange the peach slices neatly over the yogurt in a fan or circular pattern.'), findsOneWidget);
      expect(find.textContaining('**'), findsNothing);

      // Advance to Step 2
      await tester.tap(find.byKey(const ValueKey('next_step_btn')));
      await tester.pumpAndSettle();

      expect(find.text('GARNISH & SERVE'), findsOneWidget);
      expect(find.text('Sprinkle with chia seeds and drizzle honey lightly.'), findsOneWidget);
      expect(find.textContaining('###'), findsNothing);
      expect(find.textContaining('**'), findsNothing);
      expect(find.textContaining('*honey*'), findsNothing);
    });

    // 15. Long cooking instructions scroll correctly without clipping footer
    testWidgets('15. Long cooking instructions scroll correctly without clipping footer', (WidgetTester tester) async {
      final longStepRecommendation = RecipeRecommendation(
        id: 'rec_long_step',
        title: 'Artisan Braised Stew',
        imageUrl: 'assets/images/foods/curry.png',
        calories: 450,
        proteinGrams: 30,
        fridgeItemsUsed: 1,
        requiredIngredients: ['Carrots (3 pieces)'],
        missingIngredients: [],
        preparationSteps: [
          RecipePreparationStep(
            stepNumber: 1,
            instruction: 'In a large heavy-bottomed Dutch oven, gently heat two tablespoons of extra-virgin olive oil over low heat until shimmering. ' * 10,
          ),
        ],
      );

      final longMeal = MealDetailInfo.fromRecommendation(longStepRecommendation);

      await tester.pumpWidget(
        MaterialApp(
          home: GuidedCookingScreen(
            meal: longMeal,
            recommendation: longStepRecommendation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('begin_cooking_btn')));
      await tester.pumpAndSettle();

      // Footer is still anchored and visible
      expect(find.byKey(const ValueKey('previous_step_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('next_step_btn')), findsOneWidget);

      // Can scroll without overflowing
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    // =========================================================================
    // v3 CORRECTION 1: HEADER TESTS
    // =========================================================================
    testWidgets('16. Prep shortcut is absent from the cooking step header', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GuidedCookingScreen(
            meal: testMeal,
            recommendation: testRecommendation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Begin cooking -> advance to Step 1
      await tester.tap(find.byKey(const ValueKey('begin_cooking_btn')));
      await tester.pumpAndSettle();

      // Prep shortcut (checklist icon + "Prep" text) must NOT be present in AppBar actions
      expect(find.widgetWithText(TextButton, 'Prep'), findsNothing);
      expect(find.byIcon(Icons.checklist_rounded), findsNothing);
    });

    testWidgets('17. Exit button remains visible and functional', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const ValueKey('open_screen_btn'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => GuidedCookingScreen(
                      meal: testMeal,
                      recommendation: testRecommendation,
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_screen_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('begin_cooking_btn')));
      await tester.pumpAndSettle();

      // Exit button (Icons.close_rounded) is visible in the top-left
      final exitBtn = find.byIcon(Icons.close_rounded);
      expect(exitBtn, findsOneWidget);

      await tester.tap(exitBtn);
      await tester.pumpAndSettle();

      // Screen popped back to root
      expect(find.byType(GuidedCookingScreen), findsNothing);
      expect(find.byKey(const ValueKey('open_screen_btn')), findsOneWidget);
    });

    testWidgets('18. Step counter and progress indicator remain correct', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GuidedCookingScreen(
            meal: testMeal,
            recommendation: testRecommendation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('begin_cooking_btn')));
      await tester.pumpAndSettle();

      // Step counter displays "Step 1 of 4"
      expect(find.byKey(const ValueKey('step_counter_title')), findsOneWidget);
      expect(find.text('Step 1 of 4'), findsOneWidget);

      // Progress bar exists
      expect(find.byKey(const ValueKey('step_progress_bar')), findsOneWidget);

      // Advance to Step 2
      await tester.tap(find.byKey(const ValueKey('next_step_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 4'), findsOneWidget);
    });

    // =========================================================================
    // v3 CORRECTION 2: STEP HEADING TESTS
    // =========================================================================
    testWidgets('19. "Toast the Bread: ..." renders full heading "TOAST THE BREAD"', (WidgetTester tester) async {
      const toastRecommendation = RecipeRecommendation(
        id: 'rec_toast_bread',
        title: 'Avocado Toast',
        imageUrl: 'assets/images/foods/curry.png',
        calories: 320,
        proteinGrams: 10,
        fridgeItemsUsed: 1,
        requiredIngredients: ['Bread (2 slices)'],
        missingIngredients: [],
        preparationSteps: [
          RecipePreparationStep(
            stepNumber: 1,
            instruction: 'Toast the Bread: Place the bread slices in a toaster until golden and crispy.',
          ),
        ],
      );

      final toastMeal = MealDetailInfo.fromRecommendation(toastRecommendation);

      await tester.pumpWidget(
        MaterialApp(
          home: GuidedCookingScreen(
            meal: toastMeal,
            recommendation: toastRecommendation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('begin_cooking_btn')));
      await tester.pumpAndSettle();

      // Must be full heading "TOAST THE BREAD", never truncated to "TOAST THE"
      expect(find.byKey(const ValueKey('step_action_heading')), findsOneWidget);
      expect(find.text('TOAST THE BREAD'), findsOneWidget);
      expect(find.text('TOAST THE'), findsNothing);

      // Description is kept separate and clean
      expect(find.text('Place the bread slices in a toaster until golden and crispy.'), findsOneWidget);
    });

    testWidgets('20. "Prepare the Apples: ..." renders "PREPARE THE APPLES"', (WidgetTester tester) async {
      const appleRecommendation = RecipeRecommendation(
        id: 'rec_prepare_apples',
        title: 'Cinnamon Apple Bowl',
        imageUrl: 'assets/images/foods/curry.png',
        calories: 210,
        proteinGrams: 4,
        fridgeItemsUsed: 1,
        requiredIngredients: ['Apples (2 pieces)'],
        missingIngredients: [],
        preparationSteps: [
          RecipePreparationStep(
            stepNumber: 1,
            instruction: 'Prepare the Apples: Slice the apples into thin wedges and discard the core.',
          ),
        ],
      );

      final appleMeal = MealDetailInfo.fromRecommendation(appleRecommendation);

      await tester.pumpWidget(
        MaterialApp(
          home: GuidedCookingScreen(
            meal: appleMeal,
            recommendation: appleRecommendation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('begin_cooking_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('step_action_heading')), findsOneWidget);
      expect(find.text('PREPARE THE APPLES'), findsOneWidget);
      expect(find.text('PREPARE THE'), findsNothing);
      expect(find.text('Slice the apples into thin wedges and discard the core.'), findsOneWidget);
    });

    testWidgets('21. "Assemble the Bowl: ..." renders "ASSEMBLE THE BOWL" and derived sentence heading', (WidgetTester tester) async {
      const bowlRecommendation = RecipeRecommendation(
        id: 'rec_assemble_bowl',
        title: 'Berry Smoothie Bowl',
        imageUrl: 'assets/images/foods/curry.png',
        calories: 280,
        proteinGrams: 12,
        fridgeItemsUsed: 2,
        requiredIngredients: ['Yogurt (1 cup)', 'Berries (1 cup)'],
        missingIngredients: [],
        preparationSteps: [
          RecipePreparationStep(
            stepNumber: 1,
            instruction: 'Assemble the Bowl: Arrange the fresh berries neatly over the smooth yogurt base.',
          ),
          RecipePreparationStep(
            stepNumber: 2,
            instruction: 'Mix the ingredients thoroughly in a large mixing bowl until smooth.',
          ),
        ],
      );

      final bowlMeal = MealDetailInfo.fromRecommendation(bowlRecommendation);

      await tester.pumpWidget(
        MaterialApp(
          home: GuidedCookingScreen(
            meal: bowlMeal,
            recommendation: bowlRecommendation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('begin_cooking_btn')));
      await tester.pumpAndSettle();

      // Step 1: Colon heading
      expect(find.text('ASSEMBLE THE BOWL'), findsOneWidget);
      expect(find.text('ASSEMBLE THE'), findsNothing);

      // Advance to Step 2: Derived imperative sentence heading
      await tester.tap(find.byKey(const ValueKey('next_step_btn')));
      await tester.pumpAndSettle();

      expect(find.text('MIX THE INGREDIENTS THOROUGHLY'), findsOneWidget);
      expect(find.text('MIX THE'), findsNothing);
      expect(find.text('Mix the ingredients thoroughly in a large mixing bowl until smooth.'), findsOneWidget);
    });

    testWidgets('22. Long headings wrap without clipping', (WidgetTester tester) async {
      const longTitleRec = RecipeRecommendation(
        id: 'rec_long_heading',
        title: 'Caramelized Onion Dip',
        imageUrl: 'assets/images/foods/curry.png',
        calories: 200,
        proteinGrams: 5,
        fridgeItemsUsed: 1,
        requiredIngredients: ['Onions (2 pieces)'],
        missingIngredients: [],
        preparationSteps: [
          RecipePreparationStep(
            stepNumber: 1,
            instruction: 'Caramelize the Sweet Red Onions and Fresh Herbs: Heat olive oil over medium-low heat.',
          ),
        ],
      );

      final longTitleMeal = MealDetailInfo.fromRecommendation(longTitleRec);

      await tester.pumpWidget(
        MaterialApp(
          home: GuidedCookingScreen(
            meal: longTitleMeal,
            recommendation: longTitleRec,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('begin_cooking_btn')));
      await tester.pumpAndSettle();

      // Full action heading is rendered and wraps without layout exceptions
      expect(find.text('CARAMELIZE THE SWEET RED ONIONS AND FRESH HERBS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('23. Raw Markdown syntax is not displayed in heading or body', (WidgetTester tester) async {
      const rawMarkdownRec = RecipeRecommendation(
        id: 'rec_raw_md',
        title: 'Chia Toast',
        imageUrl: 'assets/images/foods/curry.png',
        calories: 220,
        proteinGrams: 8,
        fridgeItemsUsed: 1,
        requiredIngredients: ['Bread (2 slices)'],
        missingIngredients: [],
        preparationSteps: [
          RecipePreparationStep(
            stepNumber: 1,
            instruction: '**Toast the Bread:** Sprinkle with **chia seeds** and drizzle *honey* lightly.',
          ),
        ],
      );

      final rawMeal = MealDetailInfo.fromRecommendation(rawMarkdownRec);

      await tester.pumpWidget(
        MaterialApp(
          home: GuidedCookingScreen(
            meal: rawMeal,
            recommendation: rawMarkdownRec,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('begin_cooking_btn')));
      await tester.pumpAndSettle();

      expect(find.text('TOAST THE BREAD'), findsOneWidget);
      expect(find.text('Sprinkle with chia seeds and drizzle honey lightly.'), findsOneWidget);
      expect(find.textContaining('**'), findsNothing);
      expect(find.textContaining('*honey*'), findsNothing);
    });

    // =========================================================================
    // v3 CORRECTION 3: CONDITIONAL START COOKING VISIBILITY TESTS
    // =========================================================================
    testWidgets('24. Before preparation generation, Start Cooking is hidden', (WidgetTester tester) async {
      // Recommendation without any pre-baked steps
      const unreadyRec = RecipeRecommendation(
        id: 'rec_unready_001',
        title: 'Custom Zucchini Pasta Salad',
        imageUrl: 'assets/images/foods/curry.png',
        calories: 310,
        proteinGrams: 14,
        fridgeItemsUsed: 1,
        requiredIngredients: ['Zucchini (2 pieces)'],
        missingIngredients: [],
        preparationSteps: [], // NO steps yet
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: MealDetailScreen(
            recommendation: unreadyRec,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Start Cooking button must be HIDDEN
      expect(find.byKey(const ValueKey('start_cooking_btn')), findsNothing);
      expect(find.byKey(const ValueKey('prep_section_start_cooking_btn')), findsNothing);

      // Generate Steps button must be VISIBLE
      expect(find.byKey(const ValueKey('generate_steps_btn')), findsOneWidget);

      // Log Meal Directly must remain VISIBLE and usable
      expect(find.byKey(const ValueKey('direct_log_meal_btn')), findsOneWidget);
    });

    testWidgets('25. During generation, Start Cooking remains hidden', (WidgetTester tester) async {
      const unreadyRec = RecipeRecommendation(
        id: 'rec_generating_001',
        title: 'Custom Golden Lentil Soup',
        imageUrl: 'assets/images/foods/curry.png',
        calories: 340,
        proteinGrams: 18,
        fridgeItemsUsed: 1,
        requiredIngredients: ['Lentils (1 cup)'],
        missingIngredients: [],
        preparationSteps: [],
      );

      // Mock delayed AI response
      final completer = Completer<Map<String, dynamic>>();
      AiAssistantService.mockHandler = (_) => completer.future;

      await tester.pumpWidget(
        const MaterialApp(
          home: MealDetailScreen(
            recommendation: unreadyRec,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Generate Steps
      final genBtn = find.byKey(const ValueKey('generate_steps_btn'));
      await tester.ensureVisible(genBtn);
      await tester.tap(genBtn);
      await tester.pump();

      // During generation: Start Cooking remains HIDDEN
      expect(find.byKey(const ValueKey('start_cooking_btn')), findsNothing);

      // Loading indicator is visible
      expect(find.text('Generating recipe steps from your fridge ingredients...'), findsOneWidget);

      // Complete AI response to clean up
      completer.complete({
        'meal': {
          'preparationSteps': [
            {'stepNumber': 1, 'instruction': 'Simmer lentils in broth.'},
          ],
        },
      });
      await tester.pumpAndSettle();
      AiAssistantService.mockHandler = null;
    });

    testWidgets('26. After successful generation with valid steps, Start Cooking appears', (WidgetTester tester) async {
      const unreadyRec = RecipeRecommendation(
        id: 'rec_success_gen_001',
        title: 'Fresh Garden Stir Fry',
        imageUrl: 'assets/images/foods/curry.png',
        calories: 270,
        proteinGrams: 11,
        fridgeItemsUsed: 1,
        requiredIngredients: ['Broccoli (1 head)'],
        missingIngredients: [],
        preparationSteps: [],
      );

      AiAssistantService.mockHandler = (_) async => {
        'meal': {
          'preparationSteps': [
            {'stepNumber': 1, 'instruction': 'Wash and chop vegetables.'},
            {'stepNumber': 2, 'instruction': 'Sauté in hot pan for 5 minutes.', 'time': '5 mins'},
          ],
        },
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: MealDetailScreen(
            recommendation: unreadyRec,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('start_cooking_btn')), findsNothing);

      // Generate steps
      final genBtn26 = find.byKey(const ValueKey('generate_steps_btn'));
      await tester.ensureVisible(genBtn26);
      await tester.tap(genBtn26);
      await tester.pumpAndSettle();

      // Start Cooking button is now VISIBLE!
      final startCookingBtn = find.byKey(const ValueKey('start_cooking_btn'));
      expect(startCookingBtn, findsOneWidget);

      // Tap Start Cooking -> opens Guided Cooking Mode with the generated steps
      await tester.ensureVisible(startCookingBtn);
      await tester.tap(startCookingBtn);
      await tester.pumpAndSettle();

      expect(find.byType(GuidedCookingScreen), findsOneWidget);
      expect(find.text('Fresh Garden Stir Fry'), findsOneWidget);

      AiAssistantService.mockHandler = null;
    });

    testWidgets('27. Empty or failed generation does not reveal Start Cooking', (WidgetTester tester) async {
      const failRec = RecipeRecommendation(
        id: 'rec_fail_001',
        title: 'Roasted Bell Peppers',
        imageUrl: 'assets/images/foods/curry.png',
        calories: 150,
        proteinGrams: 3,
        fridgeItemsUsed: 1,
        requiredIngredients: ['Bell Peppers (2 pieces)'],
        missingIngredients: [],
        preparationSteps: [],
      );

      AiAssistantService.mockHandler = (_) async {
        throw Exception('AI server unavailable');
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: MealDetailScreen(
            recommendation: failRec,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final genBtn27 = find.byKey(const ValueKey('generate_steps_btn'));
      await tester.ensureVisible(genBtn27);
      await tester.tap(genBtn27);
      await tester.pumpAndSettle();

      // Start Cooking must remain HIDDEN
      expect(find.byKey(const ValueKey('start_cooking_btn')), findsNothing);

      // Error message & Retry button are displayed
      expect(find.text('Unable to generate preparation steps. Tap retry to try again.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      AiAssistantService.mockHandler = null;
    });

    testWidgets('28. Retrying generation updates the button correctly', (WidgetTester tester) async {
      const retryRec = RecipeRecommendation(
        id: 'rec_retry_001',
        title: 'Baked Sweet Potato Fries',
        imageUrl: 'assets/images/foods/curry.png',
        calories: 220,
        proteinGrams: 4,
        fridgeItemsUsed: 1,
        requiredIngredients: ['Sweet Potatoes (2 pieces)'],
        missingIngredients: [],
        preparationSteps: [],
      );

      // First call fails
      int callCount = 0;
      AiAssistantService.mockHandler = (_) async {
        callCount++;
        if (callCount == 1) {
          throw Exception('Network glitch');
        }
        return {
          'meal': {
            'preparationSteps': [
              {'stepNumber': 1, 'instruction': 'Cut potatoes into fries.'},
              {'stepNumber': 2, 'instruction': 'Bake at 200°C for 25 minutes.', 'time': '25 mins'},
            ],
          },
        };
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: MealDetailScreen(
            recommendation: retryRec,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial generate fails
      final genBtn27 = find.byKey(const ValueKey('generate_steps_btn'));
      await tester.ensureVisible(genBtn27);
      await tester.tap(genBtn27);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('start_cooking_btn')), findsNothing);

      // Tap Retry -> succeeds!
      final retryBtn = find.text('Retry');
      await tester.ensureVisible(retryBtn);
      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('start_cooking_btn')), findsOneWidget);

      AiAssistantService.mockHandler = null;
    });

    testWidgets('29. Previously generated valid steps remain accessible when revisiting the recipe', (WidgetTester tester) async {
      const revisitRec = RecipeRecommendation(
        id: 'rec_revisit_001',
        title: 'Mushroom Risotto',
        imageUrl: 'assets/images/foods/curry.png',
        calories: 390,
        proteinGrams: 12,
        fridgeItemsUsed: 1,
        requiredIngredients: ['Mushrooms (200 g)'],
        missingIngredients: [],
        preparationSteps: [],
      );

      // Pre-persist steps in repository
      MealRecommendationService.savePreparationSteps(
        recipe: revisitRec,
        steps: const [
          RecipePreparationStep(stepNumber: 1, instruction: 'Sauté mushrooms in butter.'),
          RecipePreparationStep(stepNumber: 2, instruction: 'Simmer arborio rice with broth.'),
        ],
      );

      // Open screen for the revisited recipe
      await tester.pumpWidget(
        const MaterialApp(
          home: MealDetailScreen(
            recommendation: revisitRec,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Start Cooking is immediately visible!
      expect(find.byKey(const ValueKey('start_cooking_btn')), findsOneWidget);
    });
  });
}
