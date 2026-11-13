/// Structured parsed cooking instruction representation.
class ParsedStepInstruction {
  final String actionHeading;
  final String cleanInstruction;

  const ParsedStepInstruction({
    required this.actionHeading,
    required this.cleanInstruction,
  });
}

/// Helper for extracting action headings and cleaning raw Markdown syntax
/// from cooking instructions to guarantee a polished, editorial cookbook experience.
class StepInstructionParser {
  /// Parses [rawInstruction] into an action heading and readable clean body.
  /// Eliminates all raw Markdown asterisks, colons, or syntax characters.
  static ParsedStepInstruction parse({
    required String rawInstruction,
    int? stepNumber,
  }) {
    if (rawInstruction.trim().isEmpty) {
      return ParsedStepInstruction(
        actionHeading: 'Step ${stepNumber ?? 1}',
        cleanInstruction: '',
      );
    }

    String trimmed = rawInstruction.trim();

    // 1. Check for leading markdown bold heading (e.g. "**Assemble the Bowl:** ...", "**Heat the Pan** ...")
    final boldHeadingPattern = RegExp(
      r'^(?:\d+[\.\)]\s*)?(?:Step\s*\d+[:\.]\s*)?\*\*(.*?)\*\*:?\s*(.*)$',
      dotAll: true,
    );
    final boldMatch = boldHeadingPattern.firstMatch(trimmed);

    if (boldMatch != null) {
      final rawHeading = boldMatch.group(1)?.trim() ?? '';
      final rawBody = boldMatch.group(2)?.trim() ?? '';

      final cleanHeading = _stripMarkdown(rawHeading).replaceAll(RegExp(r'[:\.]+$'), '').trim();
      final cleanBody = _stripMarkdown(rawBody).trim();

      if (cleanHeading.isNotEmpty) {
        return ParsedStepInstruction(
          actionHeading: cleanHeading,
          cleanInstruction: cleanBody.isNotEmpty ? cleanBody : cleanHeading,
        );
      }
    }

    // 2. Check for markdown header (e.g. "### Assemble the Bowl\nArrange...")
    final markdownHeaderPattern = RegExp(r'^#{1,6}\s*(.*?)\n+(.*)$', dotAll: true);
    final headerMatch = markdownHeaderPattern.firstMatch(trimmed);
    if (headerMatch != null) {
      final cleanHeading = _stripMarkdown(headerMatch.group(1) ?? '').replaceAll(RegExp(r'[:\.]+$'), '').trim();
      final cleanBody = _stripMarkdown(headerMatch.group(2) ?? '').trim();
      if (cleanHeading.isNotEmpty) {
        return ParsedStepInstruction(
          actionHeading: cleanHeading,
          cleanInstruction: cleanBody.isNotEmpty ? cleanBody : cleanHeading,
        );
      }
    }

    // 3. Check for plain colon heading (e.g. "Assemble the Bowl: Arrange the peach...")
    final colonPattern = RegExp(r'^([A-Z][A-Za-z0-9\s,&/]{2,30}):\s+(.*)$', dotAll: true);
    final colonMatch = colonPattern.firstMatch(trimmed);
    if (colonMatch != null) {
      final cleanHeading = _stripMarkdown(colonMatch.group(1) ?? '').trim();
      final cleanBody = _stripMarkdown(colonMatch.group(2) ?? '').trim();
      if (cleanHeading.isNotEmpty && cleanBody.isNotEmpty) {
        return ParsedStepInstruction(
          actionHeading: cleanHeading,
          cleanInstruction: cleanBody,
        );
      }
    }

    // 4. Fallback: Generate a concise action heading from the leading imperative verbs / phrase
    final cleanBody = _stripMarkdown(trimmed);
    final generatedHeading = _deriveHeadingFromInstruction(cleanBody, stepNumber);

    return ParsedStepInstruction(
      actionHeading: generatedHeading,
      cleanInstruction: cleanBody,
    );
  }

  /// Derives an action heading from the initial words of an instruction (e.g. "Sauté tomatoes in pan..." -> "Sauté Tomatoes")
  static String _deriveHeadingFromInstruction(String cleanText, int? stepNumber) {
    if (cleanText.isEmpty) return 'Step ${stepNumber ?? 1}';

    // Strip leading numbers or "Step X"
    final stripped = cleanText.replaceFirst(RegExp(r'^(?:Step\s*\d+[:\.]\s*|\d+[\.\)]\s*)', caseSensitive: false), '').trim();
    final words = stripped.split(RegExp(r'\s+'));

    if (words.length >= 2) {
      // Common culinary verbs
      final firstWord = words.first.replaceAll(RegExp(r'[^a-zA-Z]'), '');
      final secondWord = words[1].replaceAll(RegExp(r'[^a-zA-Z]'), '');
      if (firstWord.isNotEmpty && secondWord.isNotEmpty) {
        return '${_capitalize(firstWord)} ${_capitalize(secondWord)}';
      }
    }

    if (words.isNotEmpty && words.first.isNotEmpty) {
      return _capitalize(words.first.replaceAll(RegExp(r'[^a-zA-Z]'), ''));
    }

    return 'Step ${stepNumber ?? 1}';
  }

  /// Removes all raw markdown markers (*, **, _, __, ~~, `, #) while preserving clean text
  static String _stripMarkdown(String text) {
    var result = text;
    // Bold / italic asterisks
    result = result.replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (m) => m.group(1) ?? '');
    result = result.replaceAllMapped(RegExp(r'\*(.*?)\*'), (m) => m.group(1) ?? '');
    // Underscores
    result = result.replaceAllMapped(RegExp(r'__(.*?)__'), (m) => m.group(1) ?? '');
    result = result.replaceAllMapped(RegExp(r'_(.*?)_'), (m) => m.group(1) ?? '');
    // Strikethrough & inline code
    result = result.replaceAllMapped(RegExp(r'~~(.*?)~~'), (m) => m.group(1) ?? '');
    result = result.replaceAllMapped(RegExp(r'`(.*?)`'), (m) => m.group(1) ?? '');
    // Remaining lone asterisks or markers
    result = result.replaceAll(RegExp(r'[\*#_`~]'), '');
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
}
