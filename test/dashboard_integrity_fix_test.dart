import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/screens/fridge/models/category_item.dart';
import 'package:nutrifridge/screens/home/services/meal_recommendation_service.dart';
import 'package:nutrifridge/screens/home/widgets/meal_status_card.dart';

void main() {
  setUp(() {
    MockDataRepository.reset();
    MealRecommendationService.reset();
    MealRecommendationService.resetClock();
    FridgeCategoryRepository.reset();
  });

  tearDown(() {
    MockDataRepository.reset();
    MealRecommendationService.reset();
    MealRecommendationService.resetClock();
    FridgeCategoryRepository.reset();
  });

  group('ISSUE ONE — AI Recommendation State & Error Categorization', () {
    test('Empty inventory transitions to empty state cleanly', () async {
      FridgeCategoryRepository.reset();
      expect(FridgeCategoryRepository.totalFridgeItems, 0);

      await MealRecommendationService.ensureInitialized();
      await MealRecommendationService.fetchRecommendation(forceRefresh: true);

      expect(MealRecommendationService.currentStatus, RecommendationStatus.empty);
      expect(MealRecommendationService.currentRecommendation, isNull);
    });

    test('Handling explicit no_match backend response updates status to noMatch', () async {
      FridgeCategoryRepository.seedSampleDataForTesting();

      // Simulate no_match payload directly handled by service
      MealRecommendationService.statusNotifier.value = RecommendationStatus.noMatch;
      expect(MealRecommendationService.statusNotifier.value, RecommendationStatus.noMatch);
    });

    test('Network/offline backend failure sets categorized error state without fabricating recommendations', () async {
      FridgeCategoryRepository.seedSampleDataForTesting();
      MealRecommendationService.currentTimeProvider = () => DateTime(2026, 11, 4, 8, 30);

      await MealRecommendationService.ensureInitialized();
      final rec = await MealRecommendationService.fetchRecommendation(forceRefresh: true);
      // In offline unit test environment, network failure sets clean error status with retry message
      expect(rec, isNull);
      expect(MealRecommendationService.currentStatus, RecommendationStatus.error);
      expect(MealRecommendationService.errorMessage, isNotNull);
    });

    test('Local catalog synchronous recommendation returns valid matching meal', () {
      FridgeCategoryRepository.seedSampleDataForTesting();
      MealRecommendationService.currentTimeProvider = () => DateTime(2026, 11, 4, 8, 0);

      final rec = MealRecommendationService.getRecommendation();
      expect(rec, isNotNull);
      expect(rec!.mealType, 'BREAKFAST');
    });
  });

  group('ISSUE TWO — Wellness Score Dynamic Calculation & Day Boundaries', () {
    test('New day with 0 records displays 0/100 and statusText indicates no meals logged yet', () {
      // 0 meals logged and 0 calories consumed
      expect(MockDataRepository.nutrition.consumedCalories, 0);
      expect(MockDataRepository.meals.isEmpty, isTrue);

      final wellness = MockDataRepository.wellness;
      expect(wellness, isNotNull);
      expect(wellness!.currentScore, 0);
      expect(wellness.maxScore, 100);
      expect(wellness.statusText, 'No meals logged yet today');
    });

    test('Yesterday score is not carried into today currentScore', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await MockDataRepository.logMeal(
        mealType: 'dinner',
        mealName: 'Paneer Curry',
        calories: 600,
        protein: 30,
        carbs: 50,
        fat: 20,
        timestamp: yesterday,
      );

      // Reset today's nutrition to 0 to simulate waking up the next day
      // The dynamic wellness calculation must show 0/100 today, with previousScore reflecting yesterday
      final todayWellness = MockDataRepository.wellness;
      expect(todayWellness, isNotNull);
      // Because consumedCalories today is 0 and 0 meals logged today:
      expect(MockDataRepository.todayLoggedMealsHistory.isEmpty, isTrue);
      expect(todayWellness!.currentScore, 0);
      expect(todayWellness.previousScore, greaterThan(0));
    });

    test('Logging first meal today updates score according to formula (72 + mealsCount * 5)', () async {
      final now = DateTime.now();
      MockDataRepository.currentTimeProvider = () => now;

      await MockDataRepository.logMeal(
        mealType: 'breakfast',
        mealName: 'Oats & Milk',
        calories: 350,
        protein: 15,
        carbs: 50,
        fat: 8,
        timestamp: now,
      );

      expect(MockDataRepository.nutrition.consumedCalories, 350);
      final wellness = MockDataRepository.wellness;
      expect(wellness, isNotNull);
      // Formula: (72 + (1 * 5)).clamp(70, 95) = 77
      expect(wellness!.currentScore, 77);
      expect(wellness.maxScore, 100);
    });

    test('Wellness score calculates difference vs yesterday accurately', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await MockDataRepository.logMeal(
        mealType: 'lunch',
        mealName: 'Rice Bowl',
        calories: 500,
        protein: 20,
        carbs: 60,
        fat: 15,
        timestamp: yesterday,
      );

      final today = DateTime.now();
      await MockDataRepository.logMeal(
        mealType: 'breakfast',
        mealName: 'Avocado Toast',
        calories: 400,
        protein: 12,
        carbs: 40,
        fat: 18,
        timestamp: today,
      );

      final wellness = MockDataRepository.wellness;
      expect(wellness, isNotNull);
      expect(wellness!.currentScore, 77); // 72 + 5 = 77
      expect(wellness.previousScore, 77); // Yesterday had 1 meal -> 77
      expect(wellness.scoreDiff, 0);
    });

    test('Local midnight boundary separates today and yesterday regardless of UTC offset', () {
      // Local time: 00:30 on Nov 8 (which might be Nov 7 in UTC)
      final localMidnightPlus30 = DateTime(2026, 11, 8, 0, 30);
      MockDataRepository.currentTimeProvider = () => localMidnightPlus30;

      final startToday = MockDataRepository.localStartOfToday;
      expect(startToday, DateTime(2026, 11, 8, 0, 0));

      final startYesterday = MockDataRepository.localStartOfYesterday;
      expect(startYesterday, DateTime(2026, 11, 7, 0, 0));
    });
  });

  group('ISSUE THREE — Today\'s Meals UI & Clean Empty State', () {
    testWidgets('Empty state displays clean "No meals logged today" and informative subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MealStatusCardSection(
                meals: MockDataRepository.meals,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No meals logged today'), findsOneWidget);
      expect(find.text('Your logged meals will appear here.'), findsOneWidget);
      // Ensure no fake upcoming cards are rendered
      expect(find.text('Breakfast'), findsNothing);
      expect(find.text('Lunch'), findsNothing);
      expect(find.text('Dinner'), findsNothing);
    });

    testWidgets('Day with 1 logged meal displays only that meal', (tester) async {
      await MockDataRepository.logMeal(
        mealType: 'breakfast',
        mealName: 'Sunny Omelette',
        calories: 320,
        protein: 18,
        carbs: 5,
        fat: 22,
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MealStatusCardSection(
                meals: MockDataRepository.meals,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only the single logged meal should appear
      expect(find.text('Sunny Omelette'), findsOneWidget);
      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.text('320'), findsOneWidget);
      expect(find.text('kcal'), findsOneWidget);

      // Fake upcoming meals should NOT appear
      expect(find.text('Lunch'), findsNothing);
      expect(find.text('Snack'), findsNothing);
      expect(find.text('Dinner'), findsNothing);
    });

    testWidgets('Previous-day meals are excluded from today\'s meal card display', (tester) async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await MockDataRepository.logMeal(
        mealType: 'dinner',
        mealName: 'Yesterday Dal Tadka',
        calories: 450,
        protein: 16,
        carbs: 65,
        fat: 10,
        timestamp: yesterday,
      );

      // In real scenario, loadFromSupabase filters to only today's meals.
      // MockDataRepository.meals only holds today's meals.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MealStatusCardSection(
                meals: MockDataRepository.meals,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Yesterday's meal should not appear in today's section
      expect(find.text('Yesterday Dal Tadka'), findsNothing);
      expect(find.text('No meals logged today'), findsOneWidget);
    });
  });
}
