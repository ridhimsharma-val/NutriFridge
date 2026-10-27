/// Model representing the user's personal profile, nutrition goals,
/// dietary restrictions, and application preferences.
/// Designed for local session persistence and future Supabase sync.
class UserProfileData {
  final String displayName;
  final String? dietaryPreference;
  final String? nutritionGoal;
  final int? dailyCalorieTarget;
  final Set<String> allergies;
  final Set<String> avoidedFoods;
  final List<String> customRestrictions;
  final bool mealRemindersEnabled;
  final bool expiryAlertsEnabled;

  const UserProfileData({
    required this.displayName,
    this.dietaryPreference = 'Vegetarian',
    this.nutritionGoal = 'Balanced eating',
    this.dailyCalorieTarget = 2200,
    this.allergies = const {},
    this.avoidedFoods = const {},
    this.customRestrictions = const [],
    this.mealRemindersEnabled = true,
    this.expiryAlertsEnabled = true,
  });

  /// Standard dietary preference options
  static const List<String> dietaryOptions = [
    'Vegetarian',
    'Eggetarian',
    'Non-vegetarian',
    'Vegan',
    'Other / flexible',
  ];

  /// Standard nutrition goals
  static const List<String> nutritionGoals = [
    'Balanced eating',
    'Increase protein intake',
    'Manage calorie intake',
    'Eat more fruits and vegetables',
    'Maintain current habits',
  ];

  /// Standard common allergens
  static const List<String> commonAllergies = [
    'Peanuts',
    'Dairy / Lactose',
    'Gluten / Wheat',
    'Shellfish',
    'Tree nuts',
    'Soy',
    'Eggs',
  ];

  /// Standard common avoided foods
  static const List<String> commonAvoidedFoods = [
    'Refined sugar',
    'Red meat',
    'Pork',
    'Alcohol',
    'Caffeine',
    'Mushrooms',
  ];

  UserProfileData copyWith({
    String? displayName,
    String? dietaryPreference,
    bool clearDietaryPreference = false,
    String? nutritionGoal,
    bool clearNutritionGoal = false,
    int? dailyCalorieTarget,
    bool clearCalorieTarget = false,
    Set<String>? allergies,
    Set<String>? avoidedFoods,
    List<String>? customRestrictions,
    bool? mealRemindersEnabled,
    bool? expiryAlertsEnabled,
  }) {
    return UserProfileData(
      displayName: displayName ?? this.displayName,
      dietaryPreference: clearDietaryPreference
          ? null
          : (dietaryPreference ?? this.dietaryPreference),
      nutritionGoal: clearNutritionGoal
          ? null
          : (nutritionGoal ?? this.nutritionGoal),
      dailyCalorieTarget: clearCalorieTarget
          ? null
          : (dailyCalorieTarget ?? this.dailyCalorieTarget),
      allergies: allergies ?? this.allergies,
      avoidedFoods: avoidedFoods ?? this.avoidedFoods,
      customRestrictions: customRestrictions ?? this.customRestrictions,
      mealRemindersEnabled: mealRemindersEnabled ?? this.mealRemindersEnabled,
      expiryAlertsEnabled: expiryAlertsEnabled ?? this.expiryAlertsEnabled,
    );
  }

  /// Serialization ready for Supabase persistence
  Map<String, dynamic> toMap() {
    return {
      'display_name': displayName,
      'dietary_preference': dietaryPreference,
      'nutrition_goal': nutritionGoal,
      'daily_calorie_target': dailyCalorieTarget,
      'allergies': allergies.toList(),
      'avoided_foods': avoidedFoods.toList(),
      'custom_restrictions': customRestrictions,
      'meal_reminders_enabled': mealRemindersEnabled,
      'expiry_alerts_enabled': expiryAlertsEnabled,
    };
  }

  factory UserProfileData.fromMap(Map<String, dynamic> map) {
    return UserProfileData(
      displayName: map['display_name'] as String? ?? 'Ridhim',
      dietaryPreference: map['dietary_preference'] as String?,
      nutritionGoal: map['nutrition_goal'] as String?,
      dailyCalorieTarget: map['daily_calorie_target'] as int?,
      allergies: (map['allergies'] as List<dynamic>?)?.cast<String>().toSet() ?? const {},
      avoidedFoods: (map['avoided_foods'] as List<dynamic>?)?.cast<String>().toSet() ?? const {},
      customRestrictions: (map['custom_restrictions'] as List<dynamic>?)?.cast<String>() ?? const [],
      mealRemindersEnabled: map['meal_reminders_enabled'] as bool? ?? true,
      expiryAlertsEnabled: map['expiry_alerts_enabled'] as bool? ?? true,
    );
  }
}
