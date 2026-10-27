import 'package:flutter/material.dart';
import '../../models/notification_data.dart';
import '../../models/nutrition_data.dart';
import '../meal_detail/meal_detail_screen.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/meal_status_card.dart';
import 'widgets/notification_popover.dart';
import 'widgets/nutrition_card.dart';
import 'widgets/recommendation_card.dart';
import 'widgets/wellness_score_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isWellnessExpanded = false;
  bool _isNutritionExpanded = false;

  @override
  Widget build(BuildContext context) {
    const recommendation = MockDataRepository.recommendation;
    const wellness = MockDataRepository.wellness;

    return ListenableBuilder(
      listenable: Listenable.merge([
        MockDataRepository.notifier,
        NotificationRepository.notifier,
      ]),
      builder: (context, _) {
        final nutrition = MockDataRepository.nutrition;
        final meals = MockDataRepository.meals;
        final hasUnread = NotificationRepository.hasUnread;

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
                  // 1. Header (Logo & Interactive Notification Bell)
                  DashboardHeader(
                    hasUnread: hasUnread,
                    onNotificationTap: () => NotificationPopover.show(context),
                  ),

                  const SizedBox(height: 14),

                  // 2. Suggested For You
                  RecommendationCard(
                    recommendation: recommendation,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => MealDetailScreen(
                            recommendation: recommendation,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  // 3. Today's Wellness (Interactive Smooth Expandable Card)
                  WellnessScoreCard(
                    wellnessData: wellness,
                    isExpanded: _isWellnessExpanded,
                    onToggle: () {
                      setState(() {
                        _isWellnessExpanded = !_isWellnessExpanded;
                      });
                    },
                  ),

                  const SizedBox(height: 14),

                  // 4. Nutrition Today (Interactive Smooth Expandable Card)
                  NutritionCard(
                    nutritionData: nutrition,
                    isExpanded: _isNutritionExpanded,
                    onToggle: () {
                      setState(() {
                        _isNutritionExpanded = !_isNutritionExpanded;
                      });
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
