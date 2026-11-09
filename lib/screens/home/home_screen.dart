import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/transitions/hero_transition_route.dart';
import '../../models/notification_data.dart';
import '../../models/nutrition_data.dart';
import '../../services/auth/auth_service.dart';
import '../ai_assistant/ai_assistant_screen.dart';
import '../fridge/fridge_page.dart';
import '../fridge/models/category_item.dart';
import '../meal_detail/meal_detail_screen.dart';
import 'services/meal_recommendation_service.dart';
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isWellnessExpanded = false;
  bool _isNutritionExpanded = false;
  DateTime _lastKnownDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeDataAndRecommendations();
    _scheduleNextMidnightTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    _midnightTimer = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDateChangeOrRefresh();
    }
  }

  void _scheduleNextMidnightTimer() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final durationUntilMidnight = nextMidnight.difference(now) + const Duration(milliseconds: 500);

    _midnightTimer = Timer(durationUntilMidnight, () {
      if (!mounted) return;
      _onMidnightCrossed();
      _scheduleNextMidnightTimer();
    });
  }

  void _onMidnightCrossed() {
    final now = DateTime.now();
    final currentDate = DateTime(now.year, now.month, now.day);
    if (currentDate != _lastKnownDate) {
      _lastKnownDate = currentDate;
      MockDataRepository.loadFromSupabase(force: true);
      MealRecommendationService.fetchRecommendation(forceRefresh: true);
    }
  }

  void _checkDateChangeOrRefresh() {
    final now = DateTime.now();
    final currentDate = DateTime(now.year, now.month, now.day);
    if (currentDate != _lastKnownDate) {
      _lastKnownDate = currentDate;
      // Midnight crossed: reset and reload daily data
      MockDataRepository.loadFromSupabase(force: true);
      MealRecommendationService.fetchRecommendation(forceRefresh: true);
      _scheduleNextMidnightTimer();
    } else {
      // App resumed from background: refresh daily score and meals
      MockDataRepository.loadFromSupabase();
    }
  }

  void _initializeDataAndRecommendations() {
    // 1. Refresh today's meals and wellness score when dashboard opens
    if (AuthService.instance.isAuthenticated && AuthService.instance.currentUser != null) {
      MockDataRepository.loadFromSupabase();
    }

    // 2. Initialize recommendations
    try {
      MealRecommendationService.ensureInitialized().then((_) {
        // Only fetch automatically if AI Suggestion mode is already active and recommendation is null.
        // On a fresh dashboard session with mode == none, do NOT auto-generate before user selects a mode.
        if (mounted &&
            MealRecommendationService.discoveryMode == MealDiscoveryMode.aiSuggestion &&
            MealRecommendationService.currentRecommendation == null) {
          MealRecommendationService.fetchRecommendation();
        }
      }).catchError((e) {
        debugPrint('MealRecommendationService initialization error: $e');
      });
    } catch (e) {
      debugPrint('MealRecommendationService synchronous initialization error: $e');
    }
  }

  void _handleOpenUseMyIngredients() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const FridgePage(isSelectionMode: true),
      ),
    );
    // When returning from ingredient selection without generating,
    // ensure the dashboard retains the clean two-option selection state.
    if (MealRecommendationService.pendingCustomRecipe == null) {
      MealRecommendationService.selectDiscoveryMode(
        MealDiscoveryMode.none,
        fetch: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        MockDataRepository.notifier,
        NotificationRepository.notifier,
        FridgeCategoryRepository.notifier,
        MealRecommendationService.statusNotifier,
        MealRecommendationService.recommendationNotifier,
        MealRecommendationService.isChangingSuggestionNotifier,
        MealRecommendationService.discoveryModeNotifier,
        MealRecommendationService.recipeOriginNotifier,
      ]),
      builder: (context, _) {
        final recommendation = MockDataRepository.recommendation;
        final recStatus = MockDataRepository.recommendationStatus;
        final errorMessage = MealRecommendationService.errorMessage;
        final alternativeMessage = MealRecommendationService.alternativeMessage;
        final isChanging = MealRecommendationService.isChangingSuggestion;
        final wellness = MockDataRepository.wellness;
        final nutrition = MockDataRepository.nutrition;
        final meals = MockDataRepository.meals;
        final hasUnread = NotificationRepository.hasUnread;
        final bottomInset = MediaQuery.of(context).padding.bottom;
        // Navigation bar clearance: _barTop (16) + barHeight (66) + wave rise / active circle (~14) + safe area + breathing margin
        final double bottomScrollPadding = 118.0 + bottomInset;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(top: 12, bottom: bottomScrollPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header (Logo & Interactive Notification Bell)
                  DashboardHeader(
                    hasUnread: hasUnread,
                    onNotificationTap: () => NotificationPopover.show(context),
                  ),

                  const SizedBox(height: 16),

                  // 2. Suggested For You
                  RecommendationCard(
                    recommendation: recommendation,
                    status: recStatus,
                    errorMessage: errorMessage,
                    isChangingSuggestion: isChanging,
                    alternativeMessage: alternativeMessage,
                    discoveryMode: MealRecommendationService.discoveryMode,
                    recipeOrigin: MealRecommendationService.recipeOrigin,
                    onSelectAiSuggestion: () {
                      MealRecommendationService.selectDiscoveryMode(
                        MealDiscoveryMode.aiSuggestion,
                      );
                    },
                    onSelectUseMyIngredients: _handleOpenUseMyIngredients,
                    onSwitchMode: () {
                      MealRecommendationService.selectDiscoveryMode(
                        MealDiscoveryMode.none,
                        fetch: false,
                      );
                    },
                    onChangeSuggestion: () {
                      MealRecommendationService.changeSuggestion(
                        onMessage: (msg) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(msg),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                      );
                    },
                    onRetry: () =>
                        MealRecommendationService.fetchRecommendation(forceRefresh: true),
                    onOpenAssistant: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AiAssistantScreen(),
                        ),
                      );
                    },
                    onTap: () {
                      if (recommendation != null) {
                        Navigator.of(context).push(
                          HeroTransitionRoute(
                            page: MealDetailScreen(
                              recommendation: recommendation,
                            ),
                          ),
                        );
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AiAssistantScreen(),
                          ),
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 16),

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

                  const SizedBox(height: 16),

                  // 4. Nutrition Today (Interactive Smooth Expandable Card with Hero Calorie Arc & Compact Macro Cards)
                  NutritionCard(
                    nutritionData: nutrition,
                    isExpanded: _isNutritionExpanded,
                    onToggle: () {
                      setState(() {
                        _isNutritionExpanded = !_isNutritionExpanded;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // 5. Today's Meals (Breakfast, Lunch, Snack, Dinner with Real Food Photography & Calorie Count)
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

                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
