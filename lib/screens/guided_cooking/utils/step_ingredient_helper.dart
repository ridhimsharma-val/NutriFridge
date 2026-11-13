import '../../meal_detail/models/meal_detail_data.dart';

/// Helper for matching ingredients mentioned in a specific cooking instruction step.
class StepIngredientHelper {
  /// Scans the [instruction] text and returns a list of recipe [ingredients]
  /// that are referenced in this step, along with their quantities.
  static List<MealIngredientItem> findRelevantIngredients({
    required String instruction,
    required List<MealIngredientItem> ingredients,
  }) {
    if (instruction.trim().isEmpty || ingredients.isEmpty) {
      return const [];
    }

    final lowerInstruction = instruction.toLowerCase();
    final matched = <MealIngredientItem>[];

    for (final ing in ingredients) {
      final name = ing.name.toLowerCase().trim();
      if (name.isEmpty) continue;

      // Extract key terms from compound ingredient names (e.g. "chopped spinach" -> "spinach", "olive oil" -> "oil")
      final tokens = name.split(RegExp(r'\s+')).where((t) => t.length > 2).toList();

      bool isMentioned = lowerInstruction.contains(name);
      if (!isMentioned && tokens.isNotEmpty) {
        // If whole name wasn't matched, check if primary noun token is present
        for (final token in tokens) {
          // Avoid matching common filler words like "fresh", "organic", "raw"
          if (['fresh', 'organic', 'raw', 'cooked', 'diced', 'chopped', 'sliced', 'crushed'].contains(token)) {
            continue;
          }
          if (RegExp('\\b$token\\b', caseSensitive: false).hasMatch(lowerInstruction)) {
            isMentioned = true;
            break;
          }
        }
      }

      if (isMentioned) {
        matched.add(ing);
      }
    }

    return matched;
  }
}
