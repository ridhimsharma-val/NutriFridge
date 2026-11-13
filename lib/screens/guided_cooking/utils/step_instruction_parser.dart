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
  // Prepositions / conjunctions that introduce subordinate clauses or prepositional modifiers
  static const Set<String> _clauseStopWords = {
    'until',
    'for',
    'in',
    'into',
    'on',
    'onto',
    'over',
    'by',
    'with',
    'before',
    'after',
    'while',
    'at',
    'then',
    'as',
    'to',
    'till',
    'so',
    'using',
  };

  // Trailing words that can NEVER be the end of an action heading
  static const Set<String> _incompleteTrailingWords = {
    'the',
    'a',
    'an',
    'and',
    'or',
    'of',
    'with',
    'in',
    'into',
    'to',
    'for',
    'on',
    'at',
    'by',
    'from',
    'as',
    'your',
    'their',
    'some',
    'any',
    'each',
    'all',
    'few',
    'both',
    'our',
    'my',
    'this',
    'that',
    'these',
    'those',
  };

  /// Parses [rawInstruction] into an action heading and readable clean body.
  /// Eliminates all raw Markdown asterisks, colons, or syntax characters.
  /// Preserves the complete action and object without premature truncation.
  static ParsedStepInstruction parse({
    required String rawInstruction,
    int? stepNumber,
    String? structuredTitle,
  }) {
    // 0. If structured step title is already provided, prioritize it
    if (structuredTitle != null && structuredTitle.trim().isNotEmpty) {
      final cleanHeading = _cleanHeading(structuredTitle);
      final cleanBody = _stripMarkdown(rawInstruction).trim();
      if (cleanHeading.isNotEmpty) {
        return ParsedStepInstruction(
          actionHeading: cleanHeading,
          cleanInstruction: cleanBody.isNotEmpty ? cleanBody : cleanHeading,
        );
      }
    }

    if (rawInstruction.trim().isEmpty) {
      return ParsedStepInstruction(
        actionHeading: 'Step ${stepNumber ?? 1}',
        cleanInstruction: '',
      );
    }

    final trimmed = rawInstruction.trim();

    // 1. Check for Markdown Header (e.g. "### Toast the Bread\nPlace bread...")
    final markdownHeaderPattern = RegExp(
      r'^(?:\d+[\.\)]\s*|Step\s*\d+[:\.]\s*)*#{1,6}\s*([^\r\n]{2,80})\r?\n+(.*)$',
      dotAll: true,
      caseSensitive: false,
    );
    final headerMatch = markdownHeaderPattern.firstMatch(trimmed);
    if (headerMatch != null) {
      final cleanHeading = _cleanHeading(headerMatch.group(1) ?? '');
      final cleanBody = _stripMarkdown(headerMatch.group(2) ?? '').trim();
      if (cleanHeading.isNotEmpty) {
        return ParsedStepInstruction(
          actionHeading: cleanHeading,
          cleanInstruction: cleanBody.isNotEmpty ? cleanBody : cleanHeading,
        );
      }
    }

    // 2. Check for Bold or Plain Heading with Colon Separator:
    // e.g. "**Toast the Bread:** Place slices in toaster...", "Toast the Bread: Place slices..."
    // "1. Toast the Bread: Place...", "Step 1: Toast the Bread: Place..."
    final colonPattern = RegExp(
      r'^(?:\d+[\.\)]\s*|Step\s*\d+[:\.]\s*)*'
      r'(?:\*\*)?'
      r'([^:\r\n]{2,80})'
      r'(?:\*\*)?'
      r':\s*'
      r'(.*)$',
      dotAll: true,
      caseSensitive: false,
    );
    final colonMatch = colonPattern.firstMatch(trimmed);
    if (colonMatch != null) {
      final rawHeading = colonMatch.group(1) ?? '';
      final rawBody = colonMatch.group(2) ?? '';
      final cleanHeading = _cleanHeading(rawHeading);
      final cleanBody = _stripMarkdown(rawBody).trim();

      if (cleanHeading.isNotEmpty && cleanBody.isNotEmpty) {
        return ParsedStepInstruction(
          actionHeading: cleanHeading,
          cleanInstruction: cleanBody,
        );
      }
    }

    // 3. Check for Dash Separator (e.g. "Toast the Bread - Place slices in...")
    final dashPattern = RegExp(
      r'^(?:\d+[\.\)]\s*|Step\s*\d+[:\.]\s*)*'
      r'(?:\*\*)?'
      r'([^:\r\n\-\–\—]{2,80})'
      r'(?:\*\*)?'
      r'\s+[\-\–\—]\s+'
      r'(.*)$',
      dotAll: true,
      caseSensitive: false,
    );
    final dashMatch = dashPattern.firstMatch(trimmed);
    if (dashMatch != null) {
      final rawHeading = dashMatch.group(1) ?? '';
      final rawBody = dashMatch.group(2) ?? '';
      final cleanHeading = _cleanHeading(rawHeading);
      final cleanBody = _stripMarkdown(rawBody).trim();

      if (cleanHeading.isNotEmpty && cleanBody.isNotEmpty) {
        return ParsedStepInstruction(
          actionHeading: cleanHeading,
          cleanInstruction: cleanBody,
        );
      }
    }

    // 4. Fallback: Derive complete action heading (Action + Object) from instruction text
    final cleanFullBody = _stripMarkdown(trimmed);
    final derivedHeading = _deriveHeadingFromInstruction(cleanFullBody, stepNumber);

    return ParsedStepInstruction(
      actionHeading: derivedHeading,
      cleanInstruction: cleanFullBody,
    );
  }

  /// Cleans heading candidate: strips markdown, trims trailing punctuation, normalizes spaces
  static String _cleanHeading(String raw) {
    var s = _stripMarkdown(raw).trim();
    // Remove leading step numbers (e.g. "1. ", "Step 1: ")
    s = s.replaceFirst(RegExp(r'^(?:Step\s*\d+[:\.]\s*|\d+[\.\)]\s*)', caseSensitive: false), '').trim();
    // Remove trailing colons, periods, dashes
    s = s.replaceAll(RegExp(r'[:\.\-\–\—]+$'), '').trim();
    return s;
  }

  /// Derives complete action heading from leading imperative phrase
  /// Preserves complete action verb + full direct object (e.g. "Toast the bread until..." -> "Toast the Bread")
  static String _deriveHeadingFromInstruction(String cleanText, int? stepNumber) {
    if (cleanText.isEmpty) return 'Step ${stepNumber ?? 1}';

    // Strip leading numbers or "Step X"
    final stripped = cleanText.replaceFirst(
      RegExp(r'^(?:Step\s*\d+[:\.]\s*|\d+[\.\)]\s*)', caseSensitive: false),
      '',
    ).trim();

    // Isolate the first clause before major punctuation (. ; \n)
    final firstClauseMatch = RegExp(r'^([^.;\n\r]+)').firstMatch(stripped);
    final firstClause = firstClauseMatch != null ? firstClauseMatch.group(1)!.trim() : stripped;

    final rawWords = firstClause.split(RegExp(r'\s+'));
    if (rawWords.isEmpty) return 'Step ${stepNumber ?? 1}';

    final collectedWords = <String>[];

    for (int i = 0; i < rawWords.length; i++) {
      final word = rawWords[i].replaceAll(RegExp(r'[^a-zA-Z0-9\-]'), '');
      if (word.isEmpty) continue;

      final lower = word.toLowerCase();

      // Check if we hit a clause stop word (e.g. "until", "for", "in", "with")
      if (_clauseStopWords.contains(lower)) {
        // Can only stop if we already have at least 2 words AND last word is not an incomplete trailing word
        if (collectedWords.length >= 2 && !_incompleteTrailingWords.contains(collectedWords.last.toLowerCase())) {
          break;
        }
      }

      collectedWords.add(word);

      // Stop once we have a complete 3-to-5 word phrase and reached a natural noun ending
      if (collectedWords.length >= 3 && !_incompleteTrailingWords.contains(lower)) {
        if (collectedWords.length >= 5) {
          break;
        }
      }
    }

    // Ensure the resulting phrase does not end on an incomplete trailing word
    while (collectedWords.isNotEmpty && _incompleteTrailingWords.contains(collectedWords.last.toLowerCase())) {
      // Find the next available word in rawWords if any
      final nextIdx = collectedWords.length;
      if (nextIdx < rawWords.length) {
        final nextWord = rawWords[nextIdx].replaceAll(RegExp(r'[^a-zA-Z0-9\-]'), '');
        if (nextWord.isNotEmpty) {
          collectedWords.add(nextWord);
          continue;
        }
      }
      // If no more words, remove the incomplete trailing word
      collectedWords.removeLast();
    }

    if (collectedWords.isEmpty) {
      return 'Step ${stepNumber ?? 1}';
    }

    // Format heading as Title Case
    return collectedWords.map(_capitalize).join(' ');
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
