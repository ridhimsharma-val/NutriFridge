/// Structured meal context passed when transitioning from Meal Detail to AI Assistant.
class MealAiContext {
  final String mealId;
  final String mealTitle;
  final String mealDescription;
  final String mealType;
  final String nutritionSummary;
  final String servingSize;
  final int? prepTimeMinutes;
  final int? cookingTimeMinutes;
  final int? calories;
  final int? proteinGrams;
  final int? carbsGrams;
  final int? fatGrams;
  final List<String> requiredIngredients;
  final Map<String, String> availableFridgeQuantities;
  final List<String> missingIngredients;
  final List<String> preparationSteps;
  final List<Map<String, dynamic>> detailedSteps;
  final List<Map<String, dynamic>> detailedIngredients;
  final List<String> cookingTips;
  final List<String> substitutions;
  final List<String> recommendationReasons;
  final String? _customRecipeMarkdown;

  // ignore: prefer_initializing_formals
  const MealAiContext({
    required this.mealId,
    required this.mealTitle,
    this.mealDescription = '',
    required this.mealType,
    required this.nutritionSummary,
    this.servingSize = '1 serving',
    this.prepTimeMinutes,
    this.cookingTimeMinutes,
    this.calories,
    this.proteinGrams,
    this.carbsGrams,
    this.fatGrams,
    required this.requiredIngredients,
    required this.availableFridgeQuantities,
    required this.missingIngredients,
    this.preparationSteps = const [],
    this.detailedSteps = const [],
    this.detailedIngredients = const [],
    this.cookingTips = const [],
    this.substitutions = const [],
    this.recommendationReasons = const [],
    String? formattedRecipeMarkdown,
  }) : _customRecipeMarkdown = formattedRecipeMarkdown;

  String get formattedRecipeMarkdown =>
      _customRecipeMarkdown ??
      buildRecipeMarkdown(
        mealTitle: mealTitle,
        mealDescription: mealDescription,
        servingSize: servingSize,
        prepTimeMinutes: prepTimeMinutes,
        cookingTimeMinutes: cookingTimeMinutes,
        calories: calories,
        proteinGrams: proteinGrams,
        carbsGrams: carbsGrams,
        fatGrams: fatGrams,
        nutritionSummary: nutritionSummary,
        detailedIngredients: detailedIngredients,
        requiredIngredients: requiredIngredients,
        availableFridgeQuantities: availableFridgeQuantities,
        missingIngredients: missingIngredients,
        detailedSteps: detailedSteps,
        preparationSteps: preparationSteps,
        cookingTips: cookingTips,
        substitutions: substitutions,
      );

  Map<String, dynamic> toJson() => {
        'mealId': mealId,
        'mealTitle': mealTitle,
        'mealDescription': mealDescription,
        'mealType': mealType,
        'nutritionSummary': nutritionSummary,
        'servingSize': servingSize,
        if (prepTimeMinutes != null) 'prepTimeMinutes': prepTimeMinutes,
        if (cookingTimeMinutes != null) 'cookingTimeMinutes': cookingTimeMinutes,
        if (calories != null) 'calories': calories,
        if (proteinGrams != null) 'proteinGrams': proteinGrams,
        if (carbsGrams != null) 'carbsGrams': carbsGrams,
        if (fatGrams != null) 'fatGrams': fatGrams,
        'requiredIngredients': requiredIngredients,
        'availableFridgeQuantities': availableFridgeQuantities,
        'missingIngredients': missingIngredients,
        'preparationSteps': preparationSteps,
        if (detailedSteps.isNotEmpty) 'detailedSteps': detailedSteps,
        if (detailedIngredients.isNotEmpty) 'detailedIngredients': detailedIngredients,
        if (cookingTips.isNotEmpty) 'cookingTips': cookingTips,
        if (substitutions.isNotEmpty) 'substitutions': substitutions,
        'recommendationReasons': recommendationReasons,
        'formattedRecipeMarkdown': formattedRecipeMarkdown,
      };

  /// Builds a complete, beautifully structured recipe markdown document
  static String buildRecipeMarkdown({
    required String mealTitle,
    String? mealDescription,
    String servingSize = '1 serving',
    int? prepTimeMinutes,
    int? cookingTimeMinutes,
    int? calories,
    int? proteinGrams,
    int? carbsGrams,
    int? fatGrams,
    String? nutritionSummary,
    List<Map<String, dynamic>> detailedIngredients = const [],
    List<String> requiredIngredients = const [],
    Map<String, String> availableFridgeQuantities = const {},
    List<String> missingIngredients = const [],
    List<Map<String, dynamic>> detailedSteps = const [],
    List<String> preparationSteps = const [],
    List<String> cookingTips = const [],
    List<String> substitutions = const [],
  }) {
    final buffer = StringBuffer();

    // 1. Title & Description
    buffer.writeln('# $mealTitle');
    if (mealDescription != null && mealDescription.trim().isNotEmpty) {
      buffer.writeln(mealDescription.trim());
    } else {
      buffer.writeln('A delicious, nutritious meal prepared with ingredients from your fridge.');
    }
    buffer.writeln();

    // 2. Preparation Details
    buffer.writeln('### Preparation Details');
    if (prepTimeMinutes != null && prepTimeMinutes > 0) {
      buffer.writeln('- **Prep Time:** $prepTimeMinutes mins');
    }
    if (cookingTimeMinutes != null && cookingTimeMinutes > 0) {
      buffer.writeln('- **Cooking Time:** $cookingTimeMinutes mins');
    }
    buffer.writeln('- **Serving Size:** $servingSize');
    buffer.writeln();

    // 3. Ingredients Required (highlighting available fridge stock vs missing items)
    buffer.writeln('### Ingredients');
    if (detailedIngredients.isNotEmpty) {
      for (final ing in detailedIngredients) {
        final name = ing['name']?.toString() ?? 'Ingredient';
        final reqQty = ing['requiredQuantity'];
        final reqUnit = ing['requiredUnit']?.toString() ?? '';
        final reqText = (reqQty != null && reqQty.toString().isNotEmpty)
            ? '$reqQty $reqUnit'.trim()
            : (ing['recipeQuantityText']?.toString() ?? '');
        final availFridge = ing['availableQuantityInFridge']?.toString();
        final isAvailable = ing['availability'] == 'available' ||
            ing['isAvailable'] == true ||
            (availFridge != null && availFridge.isNotEmpty);
        final isMissing = ing['availability'] == 'missing' ||
            ing['isMissing'] == true ||
            missingIngredients.any((m) => m.toLowerCase() == name.toLowerCase());

        String statusSuffix;
        if (isAvailable && availFridge != null && availFridge.isNotEmpty) {
          statusSuffix = ' (Available in fridge: $availFridge)';
        } else if (isAvailable) {
          statusSuffix = ' (Available in fridge)';
        } else if (isMissing) {
          statusSuffix = ' (Not in fridge)';
        } else {
          statusSuffix = '';
        }

        if (reqText.isNotEmpty) {
          buffer.writeln('- $name: $reqText$statusSuffix');
        } else {
          buffer.writeln('- $name$statusSuffix');
        }
      }
    } else if (requiredIngredients.isNotEmpty) {
      for (final ing in requiredIngredients) {
        final cleanName = ing.split('(').first.trim();
        final avail = availableFridgeQuantities[cleanName] ?? availableFridgeQuantities[ing];
        final isMissing = missingIngredients.any((m) => m.toLowerCase() == cleanName.toLowerCase());

        String statusSuffix;
        if (avail != null && avail.isNotEmpty) {
          statusSuffix = ' (Available in fridge: $avail)';
        } else if (isMissing) {
          statusSuffix = ' (Not in fridge)';
        } else {
          statusSuffix = ' (Available in fridge)';
        }
        buffer.writeln('- $ing$statusSuffix');
      }
    }
    buffer.writeln();

    // 4. Step-by-Step Instructions
    buffer.writeln('### Step-by-Step Instructions');
    if (detailedSteps.isNotEmpty) {
      for (int i = 0; i < detailedSteps.length; i++) {
        final s = detailedSteps[i];
        final num = s['stepNumber'] ?? (i + 1);
        final instr = s['instruction']?.toString() ?? '';
        final time = s['time']?.toString();
        final temp = s['temperature']?.toString();
        final tip = s['tip']?.toString();

        final metaParts = <String>[];
        if (time != null && time.isNotEmpty) metaParts.add('⏱ $time');
        if (temp != null && temp.isNotEmpty) metaParts.add('🔥 $temp');
        if (tip != null && tip.isNotEmpty) metaParts.add('💡 Chef\'s Tip: $tip');

        if (metaParts.isNotEmpty) {
          buffer.writeln('$num. $instr (${metaParts.join(', ')})');
        } else {
          buffer.writeln('$num. $instr');
        }
      }
    } else if (preparationSteps.isNotEmpty) {
      for (int i = 0; i < preparationSteps.length; i++) {
        final s = preparationSteps[i];
        final hasNumber = RegExp(r'^\d+\.').hasMatch(s.trim());
        if (hasNumber) {
          buffer.writeln(s.trim());
        } else {
          buffer.writeln('${i + 1}. $s');
        }
      }
    }
    buffer.writeln();

    // 5. Chef's Cooking Tips & Substitutions
    if (cookingTips.isNotEmpty || substitutions.isNotEmpty) {
      buffer.writeln('### Chef\'s Cooking Tips & Substitutions');
      for (final tip in cookingTips) {
        buffer.writeln('- **Tip:** $tip');
      }
      for (final sub in substitutions) {
        buffer.writeln('- **Substitution:** $sub');
      }
      buffer.writeln();
    }

    // 6. Nutrition Information (Approximate)
    buffer.writeln('### Nutrition Information (Approximate)');
    if (calories != null) {
      buffer.writeln('- **Calories:** $calories kcal');
      if (proteinGrams != null) buffer.writeln('- **Protein:** ${proteinGrams}g');
      if (carbsGrams != null) buffer.writeln('- **Carbs:** ${carbsGrams}g');
      if (fatGrams != null) buffer.writeln('- **Fat:** ${fatGrams}g');
    } else if (nutritionSummary != null &&
        nutritionSummary.isNotEmpty &&
        nutritionSummary != 'Nutrition unavailable') {
      buffer.writeln('- $nutritionSummary');
    } else {
      buffer.writeln('- Calories: ~450 kcal, Protein: ~25g, Carbs: ~40g, Fat: ~15g');
    }

    return buffer.toString().trim();
  }

  /// Builds recipe markdown from a backend meal map (e.g. from Gemini response)
  static String buildRecipeMarkdownFromMealMap({
    required Map<String, dynamic> mealMap,
    MealAiContext? fallbackContext,
  }) {
    final title = mealMap['name']?.toString() ?? fallbackContext?.mealTitle ?? 'Recipe';
    final desc = mealMap['description']?.toString() ?? fallbackContext?.mealDescription;
    final serving = mealMap['servings']?.toString() ??
        mealMap['servingSize']?.toString() ??
        fallbackContext?.servingSize ??
        '1 serving';
    final prep = (mealMap['preparationTimeMinutes'] as num?)?.toInt() ?? fallbackContext?.prepTimeMinutes;
    final cook = (mealMap['cookingTimeMinutes'] as num?)?.toInt() ?? fallbackContext?.cookingTimeMinutes;

    final detailedSteps = <Map<String, dynamic>>[];
    final rawSteps = mealMap['preparationSteps'] ?? mealMap['steps'] ?? mealMap['instructions'];
    if (rawSteps is List) {
      for (int i = 0; i < rawSteps.length; i++) {
        final s = rawSteps[i];
        if (s is Map) {
          detailedSteps.add(Map<String, dynamic>.from(s));
        } else if (s != null && s.toString().trim().isNotEmpty) {
          detailedSteps.add({
            'stepNumber': i + 1,
            'instruction': s.toString().trim(),
          });
        }
      }
    }

    final detailedIngredients = <Map<String, dynamic>>[];
    final rawIngs = mealMap['ingredients'];
    if (rawIngs is List) {
      for (final ing in rawIngs) {
        if (ing is Map) {
          detailedIngredients.add(Map<String, dynamic>.from(ing));
        }
      }
    }

    final rawNutr = mealMap['nutrition'] is Map ? Map<String, dynamic>.from(mealMap['nutrition']) : {};
    final cal = (mealMap['calories'] as num?)?.toInt() ?? (rawNutr['calories'] as num?)?.toInt() ?? fallbackContext?.calories;
    final prot = (mealMap['proteinG'] as num?)?.toInt() ?? (rawNutr['proteinG'] as num?)?.toInt() ?? fallbackContext?.proteinGrams;
    final carb = (mealMap['carbsG'] as num?)?.toInt() ?? (rawNutr['carbsG'] as num?)?.toInt() ?? fallbackContext?.carbsGrams;
    final fat = (mealMap['fatG'] as num?)?.toInt() ?? (rawNutr['fatG'] as num?)?.toInt() ?? fallbackContext?.fatGrams;

    final tips = <String>[];
    if (mealMap['cookingTips'] is List) {
      for (final t in mealMap['cookingTips']) {
        if (t != null && t.toString().isNotEmpty) tips.add(t.toString());
      }
    } else if (fallbackContext != null) {
      tips.addAll(fallbackContext.cookingTips);
    }

    final subs = <String>[];
    if (mealMap['substitutions'] is List) {
      for (final s in mealMap['substitutions']) {
        if (s != null && s.toString().isNotEmpty) subs.add(s.toString());
      }
    } else if (fallbackContext != null) {
      subs.addAll(fallbackContext.substitutions);
    }

    return buildRecipeMarkdown(
      mealTitle: title,
      mealDescription: desc,
      servingSize: serving,
      prepTimeMinutes: prep,
      cookingTimeMinutes: cook,
      calories: cal,
      proteinGrams: prot,
      carbsGrams: carb,
      fatGrams: fat,
      detailedIngredients: detailedIngredients.isNotEmpty ? detailedIngredients : (fallbackContext?.detailedIngredients ?? const []),
      requiredIngredients: fallbackContext?.requiredIngredients ?? const [],
      availableFridgeQuantities: fallbackContext?.availableFridgeQuantities ?? const {},
      missingIngredients: fallbackContext?.missingIngredients ?? const [],
      detailedSteps: detailedSteps.isNotEmpty ? detailedSteps : (fallbackContext?.detailedSteps ?? const []),
      preparationSteps: fallbackContext?.preparationSteps ?? const [],
      cookingTips: tips,
      substitutions: subs,
    );
  }
}
