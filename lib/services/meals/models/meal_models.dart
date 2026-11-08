/// Data models for persistent meal logging, daily nutrition snapshots,
/// daily meal slot progression, and meal audit logging.
library;

/// Parsed ingredient representation with separate name, quantity, and unit.
class ParsedIngredient {
  final String name;
  final num? quantity;
  final String? unit;

  const ParsedIngredient({
    required this.name,
    this.quantity,
    this.unit,
  });

  @override
  String toString() => 'ParsedIngredient(name: $name, quantity: $quantity, unit: $unit)';
}

/// Ingredient deduction mapping for the Supabase transactional RPC `public.log_meal_transaction`.
class MealIngredientDeduction {
  final String name;
  final num? requiredQuantity;
  final String? requiredUnit;
  final String? matchedFridgeItemId;
  final num? deductQuantity;
  final String? deductUnit;
  final bool doDeduct;

  const MealIngredientDeduction({
    required this.name,
    this.requiredQuantity,
    this.requiredUnit,
    this.matchedFridgeItemId,
    this.deductQuantity,
    this.deductUnit,
    this.doDeduct = false,
  });

  MealIngredientDeduction copyWith({
    String? name,
    num? requiredQuantity,
    String? requiredUnit,
    String? matchedFridgeItemId,
    num? deductQuantity,
    String? deductUnit,
    bool? doDeduct,
  }) {
    return MealIngredientDeduction(
      name: name ?? this.name,
      requiredQuantity: requiredQuantity ?? this.requiredQuantity,
      requiredUnit: requiredUnit ?? this.requiredUnit,
      matchedFridgeItemId: matchedFridgeItemId ?? this.matchedFridgeItemId,
      deductQuantity: deductQuantity ?? this.deductQuantity,
      deductUnit: deductUnit ?? this.deductUnit,
      doDeduct: doDeduct ?? this.doDeduct,
    );
  }

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  Map<String, dynamic> toJson() {
    final validMatchedId = (matchedFridgeItemId != null && _uuidRegex.hasMatch(matchedFridgeItemId!.trim()))
        ? matchedFridgeItemId!.trim()
        : null;

    return {
      'name': name.trim(),
      'required_quantity': requiredQuantity,
      'required_unit': requiredUnit?.trim().isNotEmpty == true ? requiredUnit!.trim() : 'pieces',
      'matched_fridge_item_id': validMatchedId,
      'deduct_quantity': deductQuantity,
      'deduct_unit': deductUnit?.trim().isNotEmpty == true ? deductUnit!.trim() : 'pieces',
      'do_deduct': doDeduct,
    };
  }

  factory MealIngredientDeduction.fromJson(Map<String, dynamic> json) {
    return MealIngredientDeduction(
      name: (json['name'] ?? '').toString(),
      requiredQuantity: json['required_quantity'] as num?,
      requiredUnit: json['required_unit']?.toString(),
      matchedFridgeItemId: json['matched_fridge_item_id']?.toString(),
      deductQuantity: json['deduct_quantity'] as num?,
      deductUnit: json['deduct_unit']?.toString(),
      doDeduct: json['do_deduct'] as bool? ?? false,
    );
  }
}

/// Transactional response from `public.log_meal_transaction`.
class MealTransactionResult {
  final String status; // 'success' or 'idempotent_duplicate'
  final bool alreadyProcessed;
  final String mealId;
  final String localDate;
  final String mealType;
  final int deductionsApplied;
  final List<Map<String, dynamic>> deductionDetails;
  final String? message;

  const MealTransactionResult({
    required this.status,
    required this.alreadyProcessed,
    required this.mealId,
    required this.localDate,
    required this.mealType,
    this.deductionsApplied = 0,
    this.deductionDetails = const [],
    this.message,
  });

  bool get isSuccess => status == 'success';
  bool get isDuplicate => alreadyProcessed || status == 'idempotent_duplicate';

  factory MealTransactionResult.fromJson(Map<String, dynamic> json) {
    final rawDetails = json['deduction_details'];
    List<Map<String, dynamic>> details = [];
    if (rawDetails is List) {
      details = rawDetails
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    return MealTransactionResult(
      status: json['status']?.toString() ?? 'success',
      alreadyProcessed: json['already_processed'] as bool? ?? false,
      mealId: json['meal_id']?.toString() ?? '',
      localDate: json['local_date']?.toString() ?? '',
      mealType: json['meal_type']?.toString() ?? '',
      deductionsApplied: (json['deductions_applied'] as num?)?.toInt() ?? 0,
      deductionDetails: details,
      message: json['message']?.toString(),
    );
  }
}

/// Represents a persistent meal row in `public.meals`.
class LoggedMealRecord {
  final String id;
  final String userId;
  final String name;
  final String mealType;
  final DateTime loggedAt;
  final String localDate;
  final String servingSize;
  final int? calories;
  final int? proteinG;
  final int? carbsG;
  final int? fatG;
  final int? fiberG;
  final bool isEstimate;
  final String nutritionSource;
  final String? recipeId;
  final String? imageUrl;
  final String idempotencyKey;
  final DateTime createdAt;

  const LoggedMealRecord({
    required this.id,
    required this.userId,
    required this.name,
    required this.mealType,
    required this.loggedAt,
    required this.localDate,
    required this.servingSize,
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.fiberG,
    this.isEstimate = true,
    this.nutritionSource = 'ai_estimate',
    this.recipeId,
    this.imageUrl,
    required this.idempotencyKey,
    required this.createdAt,
  });

  factory LoggedMealRecord.fromJson(Map<String, dynamic> json) {
    return LoggedMealRecord(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      mealType: json['meal_type']?.toString() ?? '',
      loggedAt: DateTime.tryParse(json['logged_at']?.toString() ?? '') ?? DateTime.now(),
      localDate: json['local_date']?.toString() ?? '',
      servingSize: json['serving_size']?.toString() ?? '1 serving',
      calories: (json['calories'] as num?)?.toInt(),
      proteinG: (json['protein_g'] as num?)?.toInt(),
      carbsG: (json['carbs_g'] as num?)?.toInt(),
      fatG: (json['fat_g'] as num?)?.toInt(),
      fiberG: (json['fiber_g'] as num?)?.toInt(),
      isEstimate: json['is_estimate'] as bool? ?? true,
      nutritionSource: json['nutrition_source']?.toString() ?? 'ai_estimate',
      recipeId: json['recipe_id']?.toString(),
      imageUrl: json['image_url']?.toString(),
      idempotencyKey: json['idempotency_key']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  /// Converts to Map for legacy in-memory UI consistency.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mealType': mealType,
      'mealName': name,
      'calories': calories,
      'protein': proteinG,
      'carbs': carbsG,
      'fat': fatG,
      'fiber': fiberG,
      'isEstimate': isEstimate,
      'nutritionSource': nutritionSource,
      'imageUrl': imageUrl,
      'timestamp': loggedAt,
      'localDate': localDate,
      'idempotencyKey': idempotencyKey,
      'ingredients': <String>[],
    };
  }
}

/// Represents a row in `public.daily_nutrition_snapshots`.
class DailyNutritionSnapshotRecord {
  final String id;
  final String userId;
  final String logDate;
  final int? totalCalories;
  final int targetCalories;
  final int? proteinG;
  final int? carbsG;
  final int? fatG;
  final int? fiberG;
  final int mealsLoggedCount;
  final int mealsWithUnknownNutrition;
  final bool isComplete;
  final DateTime? updatedAt;

  const DailyNutritionSnapshotRecord({
    required this.id,
    required this.userId,
    required this.logDate,
    this.totalCalories,
    this.targetCalories = 2000,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.fiberG,
    this.mealsLoggedCount = 0,
    this.mealsWithUnknownNutrition = 0,
    this.isComplete = true,
    this.updatedAt,
  });

  factory DailyNutritionSnapshotRecord.fromJson(Map<String, dynamic> json) {
    return DailyNutritionSnapshotRecord(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      logDate: json['log_date']?.toString() ?? '',
      totalCalories: (json['total_calories'] as num?)?.toInt(),
      targetCalories: (json['target_calories'] as num?)?.toInt() ?? 2000,
      proteinG: (json['protein_g'] as num?)?.toInt(),
      carbsG: (json['carbs_g'] as num?)?.toInt(),
      fatG: (json['fat_g'] as num?)?.toInt(),
      fiberG: (json['fiber_g'] as num?)?.toInt(),
      mealsLoggedCount: (json['meals_logged_count'] as num?)?.toInt() ?? 0,
      mealsWithUnknownNutrition: (json['meals_with_unknown_nutrition'] as num?)?.toInt() ?? 0,
      isComplete: json['is_complete'] as bool? ?? true,
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }
}

/// Represents a row in `public.daily_meal_slots`.
class DailyMealSlotRecord {
  final String id;
  final String userId;
  final String logDate;
  final String mealSlot;
  final String status; // 'pending', 'completed', 'skipped'
  final DateTime? completedAt;
  final String? primaryMealId;

  const DailyMealSlotRecord({
    required this.id,
    required this.userId,
    required this.logDate,
    required this.mealSlot,
    required this.status,
    this.completedAt,
    this.primaryMealId,
  });

  bool get isCompleted => status == 'completed';

  factory DailyMealSlotRecord.fromJson(Map<String, dynamic> json) {
    return DailyMealSlotRecord(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      logDate: json['log_date']?.toString() ?? '',
      mealSlot: json['meal_slot']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      completedAt: DateTime.tryParse(json['completed_at']?.toString() ?? ''),
      primaryMealId: json['primary_meal_id']?.toString(),
    );
  }

  factory DailyMealSlotRecord.empty(String slot) {
    return DailyMealSlotRecord(
      id: '',
      userId: '',
      logDate: '',
      mealSlot: slot,
      status: 'pending',
    );
  }
}

/// Represents a row in `public.app_notifications`.
class AppNotificationRecord {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String type;
  final Map<String, dynamic>? metadata;
  final bool isRead;
  final DateTime createdAt;

  const AppNotificationRecord({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.type,
    this.metadata,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotificationRecord.fromJson(Map<String, dynamic> json) {
    return AppNotificationRecord(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      metadata: json['metadata'] as Map<String, dynamic>?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
