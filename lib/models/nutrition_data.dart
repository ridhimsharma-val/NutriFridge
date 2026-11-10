import 'package:flutter/foundation.dart';
import '../screens/fridge/models/category_item.dart';
import '../screens/profile/models/user_profile_data.dart';
import '../services/auth/auth_service.dart';
import '../services/meals/meal_tracking_service.dart';
import '../services/meals/models/meal_models.dart';
import '../services/profile/profile_service.dart';
import 'notification_data.dart';
import '../screens/meal_detail/models/recipe_preparation_step.dart';

/// Supported recommendation lifecycle states.
enum RecommendationStatus {
  empty, // Fridge has zero items
  loading, // Fetching recommendation asynchronously
  loaded, // Valid recommendation available
  noMatch, // Items in fridge, but no reasonable recipe match found
  error, // Backend or network error (retry state)
}

class UserProfile {
  final String name;
  final String greeting;
  final String subtitle;

  const UserProfile({
    required this.name,
    required this.greeting,
    required this.subtitle,
  });
}

/// Centralized registry mapping recipe identities and meal names to photographic food assets.
class MealImageRegistry {
  static const Map<String, String> _imageMap = {
    'paneer_rice_bowl': 'assets/images/paneer_rice_bowl.jpg',
    'dal_rice': 'assets/images/foods/dal_rice.jpg',
    'vegetable_pulao': 'assets/images/foods/dal_rice.jpg',
    'vegetable_khichdi': 'assets/images/foods/dal_rice.jpg',
    'paneer_curry': 'assets/images/foods/paneer_curry.jpg',
    'paneer_capsicum_curry': 'assets/images/foods/paneer_curry.jpg',
    'stir_fried_veggies': 'assets/images/foods/paneer_curry.jpg',
    'pasta': 'assets/images/foods/pasta.jpg',
    'veggie_pasta': 'assets/images/foods/pasta.jpg',
    'hearty_vegetable_pasta': 'assets/images/foods/pasta.jpg',
    'chicken': 'assets/images/foods/chicken.jpg',
    'grilled_chicken': 'assets/images/foods/chicken.jpg',
    'chicken_salad': 'assets/images/foods/chicken.jpg',
    'fish': 'assets/images/foods/fish.jpg',
    'pan_seared_fish': 'assets/images/foods/fish.jpg',
    'eggs': 'assets/images/foods/eggs.jpg',
    'egg_toast': 'assets/images/foods/eggs.jpg',
    'scrambled_eggs': 'assets/images/foods/eggs.jpg',
    'banana': 'assets/images/foods/banana.jpg',
    'banana_smoothie': 'assets/images/foods/banana.jpg',
    'banana_oat_smoothie': 'assets/images/foods/banana.jpg',
    'oats_banana': 'assets/images/foods/banana.jpg',
    'fruit_bowl': 'assets/images/foods/apple.jpg',
    'apple_slices': 'assets/images/foods/apple.jpg',
    'peanut_butter_apple': 'assets/images/foods/peanut_butter.jpg',
    'vegetable_sandwich': 'assets/images/foods/bread.jpg',
    'toast': 'assets/images/foods/bread.jpg',
    'yogurt_bowl': 'assets/images/foods/curd.png',
    'fruit_yogurt_bowl': 'assets/images/foods/curd.png',
    'energy_mix': 'assets/images/foods/dry_fruits_mix.jpg',
    'nut_dry_fruit_mix': 'assets/images/foods/dry_fruits_mix.jpg',
  };

  static String resolveImage({
    String? imageKey,
    String? mealName,
    String? providedUrl,
  }) {
    if (providedUrl != null && providedUrl.isNotEmpty) {
      if (providedUrl.startsWith('assets/')) return providedUrl;
    }
    if (imageKey != null && imageKey.isNotEmpty) {
      final clean = imageKey.toLowerCase().trim().replaceAll('-', '_');
      if (_imageMap.containsKey(clean)) return _imageMap[clean]!;
      if (clean.startsWith('assets/')) return imageKey;
    }
    final name = (mealName ?? '').toLowerCase();
    if (name.contains('rice') && name.contains('paneer')) return 'assets/images/paneer_rice_bowl.jpg';
    if (name.contains('dal') || name.contains('pulao') || name.contains('khichdi')) {
      return 'assets/images/foods/dal_rice.jpg';
    }
    if (name.contains('curry') || name.contains('stir-fried') || name.contains('paneer')) {
      return 'assets/images/foods/paneer_curry.jpg';
    }
    if (name.contains('pasta')) return 'assets/images/foods/pasta.jpg';
    if (name.contains('chicken')) return 'assets/images/foods/chicken.jpg';
    if (name.contains('fish')) return 'assets/images/foods/fish.jpg';
    if (name.contains('egg') || name.contains('scramble') || name.contains('omelet')) {
      return 'assets/images/foods/eggs.jpg';
    }
    if (name.contains('smoothie') || name.contains('banana') || name.contains('oat')) {
      return 'assets/images/foods/banana.jpg';
    }
    if (name.contains('peanut butter')) return 'assets/images/foods/peanut_butter.jpg';
    if (name.contains('fruit') || name.contains('apple')) return 'assets/images/foods/apple.jpg';
    if (name.contains('sandwich') || name.contains('bread') || name.contains('toast')) {
      return 'assets/images/foods/bread.jpg';
    }
    if (name.contains('yogurt') || name.contains('curd')) return 'assets/images/foods/curd.png';
    if (name.contains('nut') || name.contains('dry fruit')) return 'assets/images/foods/dry_fruits_mix.jpg';
    return 'assets/images/paneer_rice_bowl.jpg';
  }
}

class RecipeRecommendation {
  final String id;
  final String title;
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final int prepTimeMinutes;
  final int fridgeItemsUsed;
  final String tag;
  final String mealType;
  final String imageUrl;
  final String? imageKey;
  final bool nutritionIsEstimate;
  final List<String> matchReasons;
  final List<String> requiredIngredients;
  final List<String> missingIngredients;
  final String? explanation;
  final int? cookingTimeMinutes;
  final String servingSize;
  final List<RecipePreparationStep> preparationSteps;
  final List<String> cookingTips;
  final List<String> substitutions;
  final String? videoSearchQuery;
  final String? videoUrl;

  const RecipeRecommendation({
    this.id = '',
    required this.title,
    required this.calories,
    required this.proteinGrams,
    this.carbsGrams = 62,
    this.fatGrams = 18,
    this.prepTimeMinutes = 0,
    required this.fridgeItemsUsed,
    this.tag = 'Picked for your fridge',
    this.mealType = '',
    required this.imageUrl,
    this.imageKey,
    this.nutritionIsEstimate = true,
    this.matchReasons = const [
      'Uses items from your fridge',
      "Helps complete today's protein goal",
    ],
    this.requiredIngredients = const [],
    this.missingIngredients = const [],
    this.explanation,
    this.cookingTimeMinutes,
    this.servingSize = '1 serving',
    this.preparationSteps = const [],
    this.cookingTips = const [],
    this.substitutions = const [],
    this.videoSearchQuery,
    this.videoUrl,
  });

  RecipeRecommendation copyWith({
    String? id,
    String? title,
    int? calories,
    int? proteinGrams,
    int? carbsGrams,
    int? fatGrams,
    int? prepTimeMinutes,
    int? fridgeItemsUsed,
    String? tag,
    String? mealType,
    String? imageUrl,
    String? imageKey,
    bool? nutritionIsEstimate,
    List<String>? matchReasons,
    List<String>? requiredIngredients,
    List<String>? missingIngredients,
    String? explanation,
    int? cookingTimeMinutes,
    String? servingSize,
    List<RecipePreparationStep>? preparationSteps,
    List<String>? cookingTips,
    List<String>? substitutions,
    String? videoSearchQuery,
    String? videoUrl,
  }) {
    return RecipeRecommendation(
      id: id ?? this.id,
      title: title ?? this.title,
      calories: calories ?? this.calories,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      carbsGrams: carbsGrams ?? this.carbsGrams,
      fatGrams: fatGrams ?? this.fatGrams,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      fridgeItemsUsed: fridgeItemsUsed ?? this.fridgeItemsUsed,
      tag: tag ?? this.tag,
      mealType: mealType ?? this.mealType,
      imageUrl: imageUrl ?? this.imageUrl,
      imageKey: imageKey ?? this.imageKey,
      nutritionIsEstimate: nutritionIsEstimate ?? this.nutritionIsEstimate,
      matchReasons: matchReasons ?? this.matchReasons,
      requiredIngredients: requiredIngredients ?? this.requiredIngredients,
      missingIngredients: missingIngredients ?? this.missingIngredients,
      explanation: explanation ?? this.explanation,
      cookingTimeMinutes: cookingTimeMinutes ?? this.cookingTimeMinutes,
      servingSize: servingSize ?? this.servingSize,
      preparationSteps: preparationSteps ?? this.preparationSteps,
      cookingTips: cookingTips ?? this.cookingTips,
      substitutions: substitutions ?? this.substitutions,
      videoSearchQuery: videoSearchQuery ?? this.videoSearchQuery,
      videoUrl: videoUrl ?? this.videoUrl,
    );
  }

  /// Total preparation and cooking duration in minutes. Returns null if neither is available.
  int? get totalTimeMinutes {
    final p = prepTimeMinutes > 0 ? prepTimeMinutes : 0;
    final c = (cookingTimeMinutes != null && cookingTimeMinutes! > 0) ? cookingTimeMinutes! : 0;
    final sum = p + c;
    return sum > 0 ? sum : null;
  }

  /// Authoritative count of unique recipe ingredients actually available in fridge inventory.
  int get calculatedFridgeItemsUsed {
    final matchedIds = <String>{};
    for (final req in requiredIngredients) {
      final parsed = MealTrackingService.parseIngredientQuantity(req);
      final found = FridgeCategoryRepository.findItemByName(parsed.name);
      if (found != null && found.decimalAmount > 0) {
        matchedIds.add(found.id.isNotEmpty ? found.id : found.name.toLowerCase());
      }
    }
    if (matchedIds.isNotEmpty) return matchedIds.length;
    return fridgeItemsUsed;
  }

  /// Factory constructor to parse structured backend recommendation response
  factory RecipeRecommendation.fromJson(Map<String, dynamic> json) {
    final title = (json['name'] ?? json['title'] ?? 'Chef Special').toString();
    final mealType = (json['mealType'] ?? '').toString();
    final imageKey = json['imageKey']?.toString();
    final imageUrl = MealImageRegistry.resolveImage(
      imageKey: imageKey,
      mealName: title,
      providedUrl: json['imageUrl']?.toString(),
    );

    final List<String> requiredIngs = [];
    final List<String> missingIngs = [];
    int availableCount =
        (json['availableIngredientCount'] as num? ?? json['fridgeItemsUsed'] as num? ?? 0).toInt();

    if (json['ingredients'] is List) {
      for (final item in json['ingredients'] as List) {
        if (item is Map) {
          final name = (item['name'] ?? '').toString().trim();
          final rawQty = item['quantity'] ?? item['amount'];
          final rawUnit = (item['unit'] ?? '').toString().trim();
          if (name.isNotEmpty) {
            if (rawQty != null && rawUnit.isNotEmpty) {
              requiredIngs.add('$name ($rawQty $rawUnit)');
            } else if (rawQty != null) {
              requiredIngs.add('$name ($rawQty)');
            } else {
              requiredIngs.add(name);
            }
          }
          final inFridge = item['availableInFridge'] == true || item['inFridge'] == true;
          if (!inFridge && name.isNotEmpty) {
            missingIngs.add(name);
          }
        } else if (item is String) {
          requiredIngs.add(item);
        }
      }
    }

    if (json['missingIngredients'] is List) {
      for (final m in json['missingIngredients'] as List) {
        final s = m.toString();
        if (!missingIngs.contains(s)) missingIngs.add(s);
      }
    }

    if (availableCount == 0 && requiredIngs.isNotEmpty) {
      availableCount = requiredIngs.length - missingIngs.length;
      if (availableCount < 0) availableCount = 0;
    }

    final List<String> reasons = [];
    if (json['reason'] != null) {
      reasons.add(json['reason'].toString());
    } else if (json['matchReasons'] is List) {
      for (final r in json['matchReasons'] as List) {
        reasons.add(r.toString());
      }
    }
    if (reasons.isEmpty) {
      reasons.add('Uses $availableCount items from your fridge');
      reasons.add("Helps support today's protein goal");
    }

    int? parseMinutes(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toInt();
      if (val is String) {
        final match = RegExp(r'\d+').firstMatch(val);
        if (match != null) {
          return int.tryParse(match.group(0)!);
        }
      }
      return null;
    }

    final int? rawPrep = parseMinutes(json['preparationTimeMinutes'] ??
        json['prepTimeMinutes'] ??
        json['prepTime'] ??
        json['preparation_time_minutes'] ??
        json['prep_time_minutes'] ??
        json['preparation_time'] ??
        json['prep_time']);
    final int? rawCook = parseMinutes(json['cookingTimeMinutes'] ??
        json['cookingTime'] ??
        json['cookTimeMinutes'] ??
        json['cookTime'] ??
        json['cooking_time_minutes'] ??
        json['cook_time_minutes'] ??
        json['cooking_time'] ??
        json['cook_time']);
    final int? rawTotal = parseMinutes(json['totalTimeMinutes'] ??
        json['totalTime'] ??
        json['totalDurationMinutes'] ??
        json['total_time_minutes'] ??
        json['total_duration_minutes'] ??
        json['durationMinutes'] ??
        json['duration_minutes'] ??
        json['timeMinutes'] ??
        json['time_minutes']);

    final int prepTime;
    final int? cookTime;
    if (rawPrep == null && rawCook == null && rawTotal != null) {
      prepTime = 0;
      cookTime = rawTotal;
    } else {
      prepTime = rawPrep ?? 0;
      cookTime = rawCook;
    }

    return RecipeRecommendation(
      id: (json['id'] ?? '').toString(),
      title: title,
      calories: (json['calories'] as num? ?? 450).toInt(),
      proteinGrams: (json['proteinG'] as num? ??
              json['proteinGrams'] as num? ??
              json['protein'] as num? ??
              20)
          .toInt(),
      carbsGrams: (json['carbsG'] as num? ??
              json['carbsGrams'] as num? ??
              json['carbs'] as num? ??
              55)
          .toInt(),
      fatGrams: (json['fatG'] as num? ??
              json['fatGrams'] as num? ??
              json['fat'] as num? ??
              14)
          .toInt(),
      prepTimeMinutes: prepTime,
      fridgeItemsUsed: availableCount > 0 ? availableCount : requiredIngs.length,
      mealType: mealType.isNotEmpty ? mealType.toUpperCase() : '',
      tag: mealType.isNotEmpty ? mealType.toUpperCase() : 'Picked for your fridge',
      imageUrl: imageUrl,
      imageKey: imageKey,
      nutritionIsEstimate: json['nutritionIsEstimate'] as bool? ?? true,
      matchReasons: reasons,
      requiredIngredients: requiredIngs,
      missingIngredients: missingIngs,
      explanation: (json['description'] ?? json['explanation'] ?? reasons.firstOrNull)?.toString(),
      cookingTimeMinutes: cookTime,
      servingSize: (json['servingSize'] ?? json['servings'] ?? '1 serving').toString(),
      preparationSteps: (() {
        final List<RecipePreparationStep> steps = [];
        final rawSteps = json['preparationSteps'] ?? json['steps'] ?? json['instructions'];
        if (rawSteps is List) {
          for (int i = 0; i < rawSteps.length; i++) {
            final s = rawSteps[i];
            if (s is Map) {
              steps.add(RecipePreparationStep.fromJson(Map<String, dynamic>.from(s), i + 1));
            } else if (s != null && s.toString().trim().isNotEmpty) {
              steps.add(RecipePreparationStep(stepNumber: i + 1, instruction: s.toString().trim()));
            }
          }
        }
        return steps;
      })(),
      cookingTips: (() {
        final List<String> tips = [];
        final rawTips = json['cookingTips'] ?? json['tips'];
        if (rawTips is List) {
          for (final t in rawTips) {
            if (t != null && t.toString().trim().isNotEmpty) tips.add(t.toString().trim());
          }
        }
        return tips;
      })(),
      substitutions: (() {
        final List<String> subs = [];
        final rawSubs = json['substitutions'] ?? json['alternatives'];
        if (rawSubs is List) {
          for (final s in rawSubs) {
            if (s != null && s.toString().trim().isNotEmpty) subs.add(s.toString().trim());
          }
        }
        return subs;
      })(),
      videoSearchQuery: json['videoSearchQuery']?.toString(),
      videoUrl: json['videoUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': title,
      'mealType': mealType,
      'imageUrl': imageUrl,
      'imageKey': imageKey,
      'calories': calories,
      'proteinG': proteinGrams,
      'carbsG': carbsGrams,
      'fatG': fatGrams,
      'preparationTimeMinutes': prepTimeMinutes,
      'fridgeItemsUsed': fridgeItemsUsed,
      'requiredIngredients': requiredIngredients,
      'missingIngredients': missingIngredients,
      'matchReasons': matchReasons,
      'explanation': explanation,
      'cookingTimeMinutes': cookingTimeMinutes,
      'servingSize': servingSize,
      'preparationSteps': preparationSteps.map((s) => s.toJson()).toList(),
      'cookingTips': cookingTips,
      'substitutions': substitutions,
      'videoSearchQuery': videoSearchQuery,
      'videoUrl': videoUrl,
    };
  }
}

class MacroNutrient {
  final String name;
  final int amountGrams;
  final int targetGrams;
  final String unit;

  const MacroNutrient({
    required this.name,
    required this.amountGrams,
    required this.targetGrams,
    this.unit = 'g',
  });

  double get progress => (amountGrams / targetGrams).clamp(0.0, 1.0);

  MacroNutrient copyWith({
    String? name,
    int? amountGrams,
    int? targetGrams,
    String? unit,
  }) {
    return MacroNutrient(
      name: name ?? this.name,
      amountGrams: amountGrams ?? this.amountGrams,
      targetGrams: targetGrams ?? this.targetGrams,
      unit: unit ?? this.unit,
    );
  }
}

class DailyNutritionData {
  final int consumedCalories;
  final int targetCalories;
  final MacroNutrient protein;
  final MacroNutrient carbs;
  final MacroNutrient fat;

  const DailyNutritionData({
    required this.consumedCalories,
    required this.targetCalories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  double get calorieProgress => (consumedCalories / targetCalories).clamp(0.0, 1.0);

  DailyNutritionData copyWith({
    int? consumedCalories,
    int? targetCalories,
    MacroNutrient? protein,
    MacroNutrient? carbs,
    MacroNutrient? fat,
  }) {
    return DailyNutritionData(
      consumedCalories: consumedCalories ?? this.consumedCalories,
      targetCalories: targetCalories ?? this.targetCalories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
    );
  }

  /// Authoritative calculation of daily nutrition totals for a specific local calendar date.
  /// Reuses the exact same local date-matching and aggregation contract as the Progress page.
  static DailyNutritionCalculation calculateDailyTotals({
    required DateTime date,
    required List<Map<String, dynamic>> loggedMealsHistory,
  }) {
    final localTarget = date.toLocal();
    final targetYear = localTarget.year;
    final targetMonth = localTarget.month;
    final targetDay = localTarget.day;

    int totalCalories = 0;
    int totalProtein = 0;
    int totalCarbs = 0;
    int totalFat = 0;
    int totalMealsCount = 0;

    for (final m in loggedMealsHistory) {
      final rawTs = m['timestamp'];
      final DateTime? t = rawTs is DateTime
          ? rawTs.toLocal()
          : (rawTs is String && rawTs.isNotEmpty
              ? DateTime.tryParse(rawTs)?.toLocal()
              : null);
      if (t != null && t.year == targetYear && t.month == targetMonth && t.day == targetDay) {
        totalCalories += (m['calories'] as num? ?? 0).toInt();
        totalProtein += (m['protein'] as num? ?? 0).toInt();
        totalCarbs += (m['carbs'] as num? ?? 0).toInt();
        totalFat += (m['fat'] as num? ?? 0).toInt();
        totalMealsCount++;
      }
    }

    return DailyNutritionCalculation(
      calories: totalCalories,
      protein: totalProtein,
      carbs: totalCarbs,
      fat: totalFat,
      mealsCount: totalMealsCount,
    );
  }
}

/// Represents the authoritative daily nutrition aggregation result.
class DailyNutritionCalculation {
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int mealsCount;

  const DailyNutritionCalculation({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.mealsCount,
  });

  static const DailyNutritionCalculation zero = DailyNutritionCalculation(
    calories: 0,
    protein: 0,
    carbs: 0,
    fat: 0,
    mealsCount: 0,
  );
}

enum MealStatus { completed, upcoming }

class MealItem {
  final String id;
  final String name;
  final String mealType;
  final MealStatus status;
  final String? time;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final String iconEmoji;
  final String? imageUrl;

  const MealItem({
    this.id = '',
    required this.name,
    this.mealType = '',
    required this.status,
    this.time,
    this.calories = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.iconEmoji = '',
    this.imageUrl,
  });

  bool get isCompleted => status == MealStatus.completed;

  MealItem copyWith({
    String? id,
    String? name,
    String? mealType,
    MealStatus? status,
    String? time,
    int? calories,
    int? proteinG,
    int? carbsG,
    int? fatG,
    String? iconEmoji,
    String? imageUrl,
  }) {
    return MealItem(
      id: id ?? this.id,
      name: name ?? this.name,
      mealType: mealType ?? this.mealType,
      status: status ?? this.status,
      time: time ?? this.time,
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      iconEmoji: iconEmoji ?? this.iconEmoji,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

class MockDataRepository {
  /// Testable clock provider allowing controlled time injection in tests
  static DateTime Function() currentTimeProvider = DateTime.now;

  /// Resets clock provider to system wall clock
  static void resetClock() {
    currentTimeProvider = DateTime.now;
  }

  /// Start of today (00:00:00 local time)
  static DateTime get localStartOfToday {
    final now = currentTimeProvider();
    return DateTime(now.year, now.month, now.day);
  }

  /// Start of tomorrow (00:00:00 local time)
  static DateTime get localStartOfTomorrow =>
      localStartOfToday.add(const Duration(days: 1));

  /// Start of yesterday (00:00:00 local time)
  static DateTime get localStartOfYesterday =>
      localStartOfToday.subtract(const Duration(days: 1));

  /// Returns genuine logged meal history belonging strictly to today in local timezone
  static List<Map<String, dynamic>> get todayLoggedMealsHistory {
    final start = localStartOfToday;
    final end = localStartOfTomorrow;

    return _loggedMealsHistory.where((m) {
      final ts = m['timestamp'];
      final DateTime? local = ts is DateTime
          ? ts.toLocal()
          : (ts is String && ts.isNotEmpty ? DateTime.tryParse(ts)?.toLocal() : null);
      if (local != null) {
        return !local.isBefore(start) && local.isBefore(end);
      }
      return false;
    }).toList();
  }

  static String _formatMealType(String raw) {
    if (raw.isEmpty) return 'Meal';
    final lower = raw.trim().toLowerCase();
    if (lower == 'breakfast') return 'Breakfast';
    if (lower == 'lunch') return 'Lunch';
    if (lower == 'dinner') return 'Dinner';
    if (lower == 'snack') return 'Snack';
    return raw[0].toUpperCase() + raw.substring(1);
  }

  static String _emojiForMealType(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.contains('breakfast')) return '🍳';
    if (lower.contains('lunch')) return '🥗';
    if (lower.contains('dinner')) return '🍲';
    if (lower.contains('snack')) return '🍎';
    return '🍽️';
  }

  /// ValueNotifier triggering dashboard updates on meal logging
  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  static void _notify() {
    notifier.value++;
  }

  static UserProfile get user => UserProfile(
    name: _currentProfile.displayName.isNotEmpty ? _currentProfile.displayName : 'Food Explorer',
    greeting: _currentProfile.displayName.isNotEmpty
        ? 'Welcome back, ${_currentProfile.displayName} 👋'
        : 'Welcome to NutriFridge 👋',
    subtitle: 'Ready for a healthier day?',
  );

  static RecipeRecommendation? Function()? recommendationProvider;
  static RecommendationStatus Function()? recommendationStatusProvider;
  static VoidCallback? onResetRecommendation;

  static RecipeRecommendation? _explicitRecommendation;
  static RecipeRecommendation? get recommendation =>
      _explicitRecommendation ?? _deriveDynamicRecommendation();

  static RecommendationStatus get recommendationStatus {
    if (_explicitRecommendation != null) return RecommendationStatus.loaded;
    return recommendationStatusProvider?.call() ?? RecommendationStatus.empty;
  }

  static void setRecommendationForTesting(RecipeRecommendation? rec) {
    _explicitRecommendation = rec;
    _notify();
  }

  static RecipeRecommendation? _deriveDynamicRecommendation() {
    return recommendationProvider?.call();
  }

  static const DailyNutritionData _initialNutrition = DailyNutritionData(
    consumedCalories: 0,
    targetCalories: 2000,
    protein: MacroNutrient(name: 'Protein', amountGrams: 0, targetGrams: 90),
    carbs: MacroNutrient(name: 'Carbs', amountGrams: 0, targetGrams: 260),
    fat: MacroNutrient(name: 'Fat', amountGrams: 0, targetGrams: 70),
  );

  static DailyNutritionData _currentNutrition = _initialNutrition;
  static List<MealItem> _currentMeals = [];
  static final List<Map<String, dynamic>> _loggedMealsHistory = [];
  static UserProfileData _currentProfile = const UserProfileData(
    displayName: '',
    dietaryPreference: null,
    nutritionGoal: null,
    dailyCalorieTarget: null,
    allergies: {},
    avoidedFoods: {},
    customRestrictions: [],
    mealRemindersEnabled: false,
    expiryAlertsEnabled: false,
  );

  /// Current user profile settings
  static UserProfileData get profile => _currentProfile;

  /// Updates user profile settings and syncs calorie target if modified
  static void updateProfile(UserProfileData updated) {
    _currentProfile = updated;
    if (updated.dailyCalorieTarget != null) {
      _currentNutrition = _currentNutrition.copyWith(
        targetCalories: updated.dailyCalorieTarget!,
      );
    }
    _notify();

    if (AuthService.instance.isAuthenticated &&
        AuthService.instance.currentUser != null) {
      ProfileService.instance.saveProfileWithGoals(updated).catchError((_) {});
    }
  }

  /// Flag to force in-memory mock repository behavior in widget tests
  static bool forceInMemoryForTesting = false;

  static bool _isCompleteSnapshot = true;
  static int _mealsWithUnknownNutrition = 0;

  /// Returns true if all logged meals for today's snapshot have complete, known nutrition values
  static bool get isCompleteSnapshot => _isCompleteSnapshot;

  /// Number of meals logged today with incomplete or unknown nutrition
  static int get mealsWithUnknownNutrition => _mealsWithUnknownNutrition;

  static String _formatTimeString(DateTime time) {
    final rawHour = time.hour;
    final hour = rawHour > 12 ? rawHour - 12 : (rawHour == 0 ? 12 : rawHour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = rawHour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// Automatically derives ingredient deduction mappings from name list against current inventory.
  /// Safely parses explicit quantities and units (e.g. "Paneer (100g)", "100g Paneer")
  /// and strictly prevents defaulting mass/volume items to 1g/1ml.
  static List<MealIngredientDeduction> _deriveDeductionsFromIngredients(List<String>? ingredients) {
    if (ingredients == null || ingredients.isEmpty) return const [];
    final list = <MealIngredientDeduction>[];
    for (final raw in ingredients) {
      final clean = raw.trim();
      if (clean.isEmpty) continue;

      final parsed = MealTrackingService.parseIngredientQuantity(clean);
      final matched = FridgeCategoryRepository.findItemByName(parsed.name);
      final isRealUuid = matched != null &&
          matched.id.isNotEmpty &&
          !matched.id.startsWith('item_') &&
          !matched.id.startsWith('food_') &&
          !matched.id.startsWith('dairy_');

      num? deductQty = parsed.quantity;
      String? deductUnit = parsed.unit;

      bool isUnitCompatible = false;
      if (matched != null) {
        if (deductUnit != null && deductUnit.isNotEmpty) {
          isUnitCompatible = FridgeCategoryRepository.areUnitsCompatible(matched.unit, deductUnit);
        } else {
          // If unit was not specified in string, only allow deduction if item is countable (piece/item)
          final normInv = FridgeCategoryRepository.normalizeUnit(matched.unit);
          const countable = {'piece', 'pack', 'bottle', 'jar', 'tub', 'box', 'can', 'item'};
          if (countable.contains(normInv)) {
            deductUnit = matched.unit;
            isUnitCompatible = true;
          }
        }
      }

      // Strictly require positive explicit quantity and compatible units before deducting.
      // Continuous items (mass 'g', volume 'ml') must NEVER default to 1.
      final canDeductInMemory = forceInMemoryForTesting ||
          !AuthService.instance.isAuthenticated ||
          AuthService.instance.currentUser == null;
      final doDeduct = isUnitCompatible &&
          deductQty != null &&
          deductQty > 0 &&
          (isRealUuid || canDeductInMemory);

      list.add(MealIngredientDeduction(
        name: parsed.name,
        matchedFridgeItemId: (doDeduct && isRealUuid) ? matched.id : null,
        requiredQuantity: deductQty,
        requiredUnit: deductUnit ?? matched?.unit ?? 'pieces',
        deductQuantity: doDeduct ? deductQty : null,
        deductUnit: doDeduct ? deductUnit : null,
        doDeduct: doDeduct,
      ));
    }
    return list;
  }

  /// Loads user profile, nutrition goals, today's snapshot, meal slots, and meal history
  /// from Supabase for the authenticated user.
  static Future<void> loadFromSupabase({String? userId, bool force = false}) async {
    final effectiveUserId = userId ?? AuthService.instance.currentUser?.id;
    if (effectiveUserId == null) return;

    try {
      // 1. Profile and nutrition goals
      final savedProfile = await ProfileService.instance.fetchProfileWithGoals(userId: effectiveUserId);
      if (savedProfile != null) {
        _currentProfile = savedProfile;
      }
      final targetCal = savedProfile?.dailyCalorieTarget ?? _currentNutrition.targetCalories;

      // 2. Daily nutrition snapshot from public.daily_nutrition_snapshots (if available)
      final snapshot = await MealTrackingService.instance.fetchDailyNutritionSnapshot(
        userId: effectiveUserId,
        date: currentTimeProvider(),
      );

      // 3. Genuine meals logged today from public.meals
      final todayMealRecords = await MealTrackingService.instance.fetchTodayMeals(
        userId: effectiveUserId,
        clientTime: currentTimeProvider(),
      );

      if (todayMealRecords.isNotEmpty) {
        _currentMeals = todayMealRecords.map((m) {
          final timeStr = _formatTimeString(m.loggedAt.toLocal());
          final formattedSlot = _formatMealType(m.mealType);
          return MealItem(
            id: m.id,
            name: m.name,
            mealType: formattedSlot,
            status: MealStatus.completed,
            time: timeStr,
            calories: m.calories ?? 0,
            proteinG: m.proteinG ?? 0,
            carbsG: m.carbsG ?? 0,
            fatG: m.fatG ?? 0,
            iconEmoji: _emojiForMealType(m.mealType),
            imageUrl: m.imageUrl,
          );
        }).toList();
      } else {
        _currentMeals = [];
      }

      // 4. Meal History from public.meals
      final historyRecords = await MealTrackingService.instance.fetchMealHistory(
        userId: effectiveUserId,
        limit: 50,
      );

      _loggedMealsHistory.clear();
      final seenMealIds = <String>{};
      if (historyRecords.isNotEmpty) {
        for (final m in historyRecords) {
          if (m.id.isNotEmpty) seenMealIds.add(m.id);
          _loggedMealsHistory.add(m.toMap());
        }
      }
      for (final tm in todayMealRecords) {
        if (!seenMealIds.contains(tm.id)) {
          seenMealIds.add(tm.id);
          _loggedMealsHistory.add(tm.toMap());
        }
      }

      // 5. Authoritative Daily Nutrition Calculation
      // Derived from genuine meal records using the shared Progress calculation.
      final todayTotals = DailyNutritionData.calculateDailyTotals(
        date: localStartOfToday,
        loggedMealsHistory: _loggedMealsHistory,
      );

      if (todayTotals.mealsCount > 0 || todayMealRecords.isNotEmpty) {
        // Authoritative: actual logged meal records produce the nutrition totals
        _currentNutrition = DailyNutritionData(
          consumedCalories: todayTotals.calories,
          targetCalories: targetCal,
          protein: _currentNutrition.protein.copyWith(amountGrams: todayTotals.protein),
          carbs: _currentNutrition.carbs.copyWith(amountGrams: todayTotals.carbs),
          fat: _currentNutrition.fat.copyWith(amountGrams: todayTotals.fat),
        );
        _isCompleteSnapshot = true;
        _mealsWithUnknownNutrition = todayMealRecords.where((m) => m.calories == null).length;
      } else if (snapshot != null && (snapshot.totalCalories ?? 0) > 0) {
        // Fallback to snapshot if table row exists with recorded calories
        _isCompleteSnapshot = snapshot.isComplete;
        _mealsWithUnknownNutrition = snapshot.mealsWithUnknownNutrition;
        _currentNutrition = DailyNutritionData(
          consumedCalories: snapshot.totalCalories ?? 0,
          targetCalories: snapshot.targetCalories > 0 ? snapshot.targetCalories : targetCal,
          protein: _currentNutrition.protein.copyWith(amountGrams: snapshot.proteinG ?? 0),
          carbs: _currentNutrition.carbs.copyWith(amountGrams: snapshot.carbsG ?? 0),
          fat: _currentNutrition.fat.copyWith(amountGrams: snapshot.fatG ?? 0),
        );
      } else {
        // Genuine day with no meals logged: cleanly reset to zero
        _isCompleteSnapshot = true;
        _mealsWithUnknownNutrition = 0;
        _currentNutrition = DailyNutritionData(
          consumedCalories: 0,
          targetCalories: targetCal,
          protein: _currentNutrition.protein.copyWith(amountGrams: 0),
          carbs: _currentNutrition.carbs.copyWith(amountGrams: 0),
          fat: _currentNutrition.fat.copyWith(amountGrams: 0),
        );
      }

      _notify();
    } catch (e) {
      debugPrint('[MockDataRepository] loadFromSupabase error: $e');
    }
  }

  /// Synchronizes `_currentNutrition` from `_loggedMealsHistory` for `localStartOfToday`.
  static void syncTodayNutritionFromMeals() {
    final todayTotals = DailyNutritionData.calculateDailyTotals(
      date: localStartOfToday,
      loggedMealsHistory: _loggedMealsHistory,
    );
    if (todayTotals.mealsCount > 0) {
      _currentNutrition = DailyNutritionData(
        consumedCalories: todayTotals.calories,
        targetCalories: _currentNutrition.targetCalories,
        protein: _currentNutrition.protein.copyWith(amountGrams: todayTotals.protein),
        carbs: _currentNutrition.carbs.copyWith(amountGrams: todayTotals.carbs),
        fat: _currentNutrition.fat.copyWith(amountGrams: todayTotals.fat),
      );
      _notify();
    }
  }

  /// Current daily nutrition totals
  static DailyNutritionData get nutrition => _currentNutrition;

  /// Current today's meals list
  static List<MealItem> get meals => List.unmodifiable(_currentMeals);

  /// Mock meal history log
  static List<Map<String, dynamic>> get loggedMealsHistory => List.unmodifiable(_loggedMealsHistory);

  /// Logs a meal, transactionally executing Supabase RPC `public.log_meal_transaction`
  /// when authenticated, or updating local in-memory state in test/offline modes.
  static Future<MealTransactionResult?> logMeal({
    required String mealType,
    required String mealName,
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
    int? fiber,
    List<String>? ingredients,
    DateTime? timestamp,
    String? recipeId,
    String? imageUrl,
    String? idempotencyKey,
    List<MealIngredientDeduction>? ingredientDeductions,
    bool? deductInventoryInMemory,
    bool isEstimate = true,
    String nutritionSource = 'ai_estimate',
  }) async {
    final effectiveKey = idempotencyKey ?? MealTrackingService.generateIdempotencyKey();
    final shouldDeductInMemory = deductInventoryInMemory ?? (ingredientDeductions == null && ingredients != null && ingredients.isNotEmpty);

    // 1. Transactional Supabase RPC when authenticated and not in forced-memory test mode
    if (!forceInMemoryForTesting &&
        AuthService.instance.isAuthenticated &&
        AuthService.instance.currentUser != null) {
      final deductions = ingredientDeductions ?? _deriveDeductionsFromIngredients(ingredients);
      final result = await MealTrackingService.instance.logMealTransaction(
        idempotencyKey: effectiveKey,
        mealName: mealName,
        mealType: mealType,
        calories: calories,
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
        fiberG: fiber,
        isEstimate: isEstimate,
        nutritionSource: nutritionSource,
        recipeId: MealTrackingService.isValidUuid(recipeId) ? recipeId : null,
        imageUrl: imageUrl,
        ingredients: deductions,
      );

      // Refresh authoritative PostgreSQL state
      await Future.wait([
        loadFromSupabase(force: true),
        FridgeCategoryRepository.loadFromSupabase(force: true),
      ]);

      return result;
    }

    // 2. In-memory fallback (used in widget tests and offline mode)
    final cleanType = mealType.trim().toLowerCase();
    final timeNow = timestamp ?? currentTimeProvider();
    final isToday = !timeNow.isBefore(localStartOfToday) && timeNow.isBefore(localStartOfTomorrow);

    if (isToday) {
      // 2a. Add nutrition totals
      _currentNutrition = _currentNutrition.copyWith(
        consumedCalories: _currentNutrition.consumedCalories + calories,
        protein: _currentNutrition.protein.copyWith(
          amountGrams: _currentNutrition.protein.amountGrams + protein,
        ),
        carbs: _currentNutrition.carbs.copyWith(
          amountGrams: _currentNutrition.carbs.amountGrams + carbs,
        ),
        fat: _currentNutrition.fat.copyWith(
          amountGrams: _currentNutrition.fat.amountGrams + fat,
        ),
      );

      // 2b. Format current time
      final timeString = _formatTimeString(timeNow);

      // 2c. Update matching meal item in Today's Meals
      final formattedSlot = _formatMealType(mealType);
      final formattedName = mealName.isNotEmpty ? mealName : formattedSlot;

      final newMealItem = MealItem(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        name: formattedName,
        mealType: formattedSlot,
        status: MealStatus.completed,
        time: timeString,
        calories: calories,
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
        iconEmoji: _emojiForMealType(mealType),
        imageUrl: imageUrl,
      );

      final placeholderIndex = _currentMeals.indexWhere((m) {
        final itemSlot = m.mealType.isNotEmpty ? m.mealType.toLowerCase() : m.name.toLowerCase();
        return !m.isCompleted && (itemSlot == cleanType || (itemSlot.startsWith('snack') && cleanType.startsWith('snack')));
      });
      if (placeholderIndex != -1) {
        _currentMeals[placeholderIndex] = newMealItem;
      } else {
        _currentMeals.add(newMealItem);
      }
    }

    // 2d. Save to history
    _loggedMealsHistory.add({
      'mealType': mealType,
      'mealName': mealName,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'ingredients': ingredients ?? const <String>[],
      'timestamp': timeNow,
      'idempotencyKey': effectiveKey,
    });

    // 2e. Post in-app notification
    NotificationRepository.addNotification(
      title: 'Meal logged',
      description: 'Your $mealType ($mealName) has been added to today\'s nutrition.',
      type: NotificationType.mealLogged,
    );

    // 2f. Deduct in-memory inventory for offline/test environments if requested
    if (shouldDeductInMemory) {
      final deductionsToApply = ingredientDeductions ?? _deriveDeductionsFromIngredients(ingredients);
      for (final d in deductionsToApply) {
        if (d.doDeduct && d.deductQuantity != null && d.deductQuantity! > 0) {
          FridgeCategoryRepository.deductItemQuantityByName(
            name: d.name,
            quantity: d.deductQuantity!,
            unit: d.deductUnit,
          );
        }
      }
    }

    _notify();
    return MealTransactionResult(
      status: 'success',
      alreadyProcessed: false,
      mealId: 'local_${DateTime.now().millisecondsSinceEpoch}',
      localDate: DateTime.now().toIso8601String().substring(0, 10),
      mealType: cleanType,
    );
  }

  /// Seeds sample demo data for specific automated widget test suites
  static void seedSampleDataForTesting() {
    _explicitRecommendation = const RecipeRecommendation(
      title: 'Paneer Rice Bowl',
      calories: 520,
      proteinGrams: 24,
      carbsGrams: 62,
      fatGrams: 18,
      prepTimeMinutes: 20,
      fridgeItemsUsed: 4,
      tag: 'Picked for your fridge',
      imageUrl: 'assets/images/paneer_rice_bowl.jpg',
      matchReasons: [
        'Uses 4 ingredients from your fridge',
        "Helps support today's protein goal",
      ],
      requiredIngredients: ['Paneer', 'Rice', 'Capsicum', 'Onion'],
    );
    _currentNutrition = const DailyNutritionData(
      consumedCalories: 1620,
      targetCalories: 2200,
      protein: MacroNutrient(name: 'Protein', amountGrams: 72, targetGrams: 90),
      carbs: MacroNutrient(name: 'Carbs', amountGrams: 210, targetGrams: 260),
      fat: MacroNutrient(name: 'Fat', amountGrams: 62, targetGrams: 70),
    );
    _currentMeals = [
      const MealItem(
        name: 'Breakfast',
        status: MealStatus.completed,
        time: '8:30 AM',
        iconEmoji: '🍳',
      ),
      const MealItem(
        name: 'Lunch',
        status: MealStatus.completed,
        time: '1:15 PM',
        iconEmoji: '🥗',
      ),
      const MealItem(
        name: 'Snack',
        status: MealStatus.upcoming,
        time: '4:45 PM',
        iconEmoji: '🍎',
      ),
      const MealItem(
        name: 'Dinner',
        status: MealStatus.upcoming,
        time: '8:00 PM',
        iconEmoji: '🍲',
      ),
    ];
    _currentProfile = const UserProfileData(
      displayName: 'Ridhim',
      dietaryPreference: 'Vegetarian',
      nutritionGoal: 'Balanced eating',
      dailyCalorieTarget: 2200,
      allergies: {},
      avoidedFoods: {},
      customRestrictions: [],
      mealRemindersEnabled: true,
      expiryAlertsEnabled: true,
    );
    _loggedMealsHistory.clear();
    _loggedMealsHistory.addAll([
      {
        'mealType': 'breakfast',
        'mealName': 'Oats & Banana',
        'calories': 380,
        'protein': 14,
        'carbs': 65,
        'fat': 8,
      },
      {
        'mealType': 'lunch',
        'mealName': 'Paneer Rice Bowl',
        'calories': 520,
        'protein': 24,
        'carbs': 62,
        'fat': 18,
      },
    ]);
    _notify();
  }

  static void clearLoggedMealsHistoryForTesting() {
    _loggedMealsHistory.clear();
    _notify();
  }

  /// Resets mock repository to clean initial empty state
  static void reset() {
    _currentNutrition = _initialNutrition;
    _currentMeals = [];
    _loggedMealsHistory.clear();
    _isCompleteSnapshot = true;
    _mealsWithUnknownNutrition = 0;
    _currentProfile = const UserProfileData(
      displayName: '',
      dietaryPreference: null,
      nutritionGoal: null,
      dailyCalorieTarget: null,
      allergies: {},
      avoidedFoods: {},
      customRestrictions: [],
      mealRemindersEnabled: false,
      expiryAlertsEnabled: false,
    );
    _explicitRecommendation = null;
    resetClock();
    onResetRecommendation?.call();
    NotificationRepository.reset();
    _notify();
  }
}
