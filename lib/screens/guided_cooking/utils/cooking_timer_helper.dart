/// Helper for parsing and formatting cooking durations for Guided Cooking Mode.
/// Strictly parses explicit durations and never invents timers when none are provided.
class CookingTimerHelper {
  /// Parses duration in seconds from [explicitTime] or [instruction].
  /// Returns null if no explicit duration is mentioned.
  static int? parseDurationSeconds({String? explicitTime, required String instruction}) {
    // 1. Try explicit step.time field first
    if (explicitTime != null && explicitTime.trim().isNotEmpty) {
      final parsed = _extractSeconds(explicitTime.trim());
      if (parsed != null && parsed > 0) return parsed;
    }

    // 2. Scan instruction for explicit time phrasing (e.g. "for 10 minutes", "cook 5 mins", "simmer for 30 seconds")
    if (instruction.trim().isNotEmpty) {
      final parsedFromInstruction = _extractSecondsFromInstruction(instruction);
      if (parsedFromInstruction != null && parsedFromInstruction > 0) {
        return parsedFromInstruction;
      }
    }

    // Never fabricate or guess a duration
    return null;
  }

  /// Extracts duration in seconds from a short time string (e.g. "10 mins", "5-7 minutes", "30 secs", "1 hour")
  static int? _extractSeconds(String text) {
    final lower = text.toLowerCase().trim();

    // Pattern matching numbers and time unit
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*(?:-|to)?\s*(\d+(?:\.\d+)?)?\s*(hour|hr|minute|min|second|sec)s?', caseSensitive: false).firstMatch(lower);
    if (match != null) {
      final numStr = match.group(1);
      final unit = match.group(3)?.toLowerCase();
      if (numStr != null && unit != null) {
        final val = double.tryParse(numStr);
        if (val != null) {
          if (unit.startsWith('h')) {
            return (val * 3600).round();
          } else if (unit.startsWith('m')) {
            return (val * 60).round();
          } else if (unit.startsWith('s')) {
            return val.round();
          }
        }
      }
    }

    // Raw integer fallback if just "10" with unit in text
    final rawNumberMatch = RegExp(r'(\d+)\s*(m|s|h)\b').firstMatch(lower);
    if (rawNumberMatch != null) {
      final numVal = int.tryParse(rawNumberMatch.group(1)!);
      final unitChar = rawNumberMatch.group(2);
      if (numVal != null && unitChar != null) {
        if (unitChar == 'h') return numVal * 3600;
        if (unitChar == 'm') return numVal * 60;
        if (unitChar == 's') return numVal;
      }
    }

    return null;
  }

  /// Extracts duration in seconds from instruction prose (e.g., "simmer for 10 minutes", "bake 25 mins")
  static int? _extractSecondsFromInstruction(String instruction) {
    final lower = instruction.toLowerCase();

    // Regex matching explicit duration indicators in instructions
    final pattern = RegExp(
      r'(?:for|about|around|another)?\s*(\d+(?:\.\d+)?)\s*(?:-|to)?\s*(?:\d+(?:\.\d+)?)?\s*(hours?|hrs?|minutes?|mins?|seconds?|secs?)\b',
      caseSensitive: false,
    );

    final match = pattern.firstMatch(lower);
    if (match != null) {
      final numStr = match.group(1);
      final unit = match.group(2)?.toLowerCase();
      if (numStr != null && unit != null) {
        final val = double.tryParse(numStr);
        if (val != null) {
          if (unit.startsWith('h')) {
            return (val * 3600).round();
          } else if (unit.startsWith('m')) {
            return (val * 60).round();
          } else if (unit.startsWith('s')) {
            return val.round();
          }
        }
      }
    }

    return null;
  }

  /// Formats seconds into human-readable countdown string (e.g. "05:00", "01:15:00")
  static String formatCountdown(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final hh = hours.toString().padLeft(2, '0');
      return '$hh:$mm:$ss';
    }
    return '$mm:$ss';
  }

  /// Formats duration into a concise badge label (e.g. "5 mins", "30 secs", "1 hr")
  static String formatBadge(int totalSeconds) {
    if (totalSeconds >= 3600) {
      final hrs = totalSeconds / 3600;
      return '${hrs.toStringAsFixed(hrs.truncateToDouble() == hrs ? 0 : 1)} hr';
    }
    if (totalSeconds >= 60) {
      final mins = totalSeconds ~/ 60;
      return '$mins min${mins == 1 ? '' : 's'}';
    }
    return '$totalSeconds sec${totalSeconds == 1 ? '' : 's'}';
  }
}
