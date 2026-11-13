/// Represents a structured, recipe-specific preparation step.
class RecipePreparationStep {
  final int stepNumber;
  final String instruction;
  final String? title;
  final String? time;
  final String? temperature;
  final String? tip;

  const RecipePreparationStep({
    required this.stepNumber,
    required this.instruction,
    this.title,
    this.time,
    this.temperature,
    this.tip,
  });

  factory RecipePreparationStep.fromJson(Map<String, dynamic> json, int defaultNumber) {
    return RecipePreparationStep(
      stepNumber: (json['stepNumber'] as num?)?.toInt() ?? defaultNumber,
      instruction: (json['instruction'] ?? json['text'] ?? json['description'] ?? '').toString(),
      title: json['title']?.toString() ?? json['action']?.toString() ?? json['heading']?.toString(),
      time: json['time']?.toString(),
      temperature: json['temperature']?.toString(),
      tip: json['tip']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'stepNumber': stepNumber,
        'instruction': instruction,
        if (title != null) 'title': title,
        if (time != null) 'time': time,
        if (temperature != null) 'temperature': temperature,
        if (tip != null) 'tip': tip,
      };
}
