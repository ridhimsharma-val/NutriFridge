import 'package:flutter/material.dart';
import '../../models/nutrition_data.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/meal_status_card.dart';
import 'widgets/nutrition_card.dart';
import 'widgets/recommendation_card.dart';
import 'widgets/wellness_score_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const recommendation = MockDataRepository.recommendation;
    const wellness = MockDataRepository.wellness;

    return ListenableBuilder(
      listenable: MockDataRepository.notifier,
      builder: (context, _) {
        final nutrition = MockDataRepository.nutrition;
        final meals = MockDataRepository.meals;

        return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(top: 10, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header (Logo & Notification Bell)
              DashboardHeader(
                onNotificationTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notifications coming soon!'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              // 2. Suggested For You (Directly after Greeting)
              RecommendationCard(
                recommendation: recommendation,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Opening ${recommendation.title} recipe...'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              // 3. Today's Wellness (Prominent Mint/Teal Card with Score & Ring)
              WellnessScoreCard(
                wellnessData: wellness,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Viewing wellness score breakdown...'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              // 4. Nutrition Today (Unified Calories & Macros Card)
              NutritionCard(
                nutritionData: nutrition,
                onSeeMore: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Detailed Nutrition report coming soon!'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              // 5. Today's Meals (Breakfast, Lunch, Snack, Dinner)
              MealStatusCardSection(
                meals: meals,
                onMealTap: (meal) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${meal.name}: ${meal.isCompleted ? "Completed" : "Upcoming"}',
                      ),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
      },
    );
  }
}
