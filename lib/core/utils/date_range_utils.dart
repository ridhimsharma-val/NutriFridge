import 'dart:math' as math;

/// Represents a calendar-month date range with strict local boundaries
/// and UTC conversion for database queries.
class CalendarMonthRange {
  final int year;
  final int month;
  final DateTime start; // Local 1st day of month at 00:00:00
  final DateTime endExclusive; // Local 1st day of next month at 00:00:00
  final int daysInMonth;

  const CalendarMonthRange({
    required this.year,
    required this.month,
    required this.start,
    required this.endExclusive,
    required this.daysInMonth,
  });

  /// UTC start timestamp for Supabase queries (.gte)
  DateTime get startUtc => start.toUtc();

  /// UTC exclusive end timestamp for Supabase queries (.lt)
  DateTime get endUtcExclusive => endExclusive.toUtc();

  /// Checks if a given DateTime falls within this calendar month (using local date)
  bool contains(DateTime date) {
    final local = date.toLocal();
    return !local.isBefore(start) && local.isBefore(endExclusive);
  }
}

/// Represents a week segment within a calendar month following NutriFridge conventions:
/// - Days 1–7   -> Week 1
/// - Days 8–14  -> Week 2
/// - Days 15–21 -> Week 3
/// - Days 22–28 -> Week 4
/// - Days 29–31 -> Week 5 (if daysInMonth > 28)
class MonthWeekSegment {
  final int weekNumber; // 1 to 5
  final int startDay; // 1, 8, 15, 22, 29
  final int endDay; // 7, 14, 21, 28, or daysInMonth
  final DateTime startDate; // Local DateTime at 00:00:00
  final DateTime endDate; // Local DateTime at 23:59:59
  final DateTime endExclusive; // Next day at 00:00:00
  final int totalDaysInSegment;
  final String dateRangeLabel; // e.g. 'Nov 1–7', 'Nov 8–14'

  const MonthWeekSegment({
    required this.weekNumber,
    required this.startDay,
    required this.endDay,
    required this.startDate,
    required this.endDate,
    required this.endExclusive,
    required this.totalDaysInSegment,
    required this.dateRangeLabel,
  });

  /// Checks if this segment is the current week relative to [now]
  bool isCurrentWeek(DateTime now) {
    final localNow = now.toLocal();
    return localNow.year == startDate.year &&
        localNow.month == startDate.month &&
        localNow.day >= startDay &&
        localNow.day <= endDay;
  }

  /// Checks if this segment is entirely in the future relative to [now]
  bool isFutureWeek(DateTime now) {
    final localNow = now.toLocal();
    if (localNow.year < startDate.year) return true;
    if (localNow.year > startDate.year) return false;
    if (localNow.month < startDate.month) return true;
    if (localNow.month > startDate.month) return false;
    return startDay > localNow.day;
  }

  /// Number of elapsed days in this segment up to [now]
  int elapsedDays(DateTime now) {
    final localNow = now.toLocal();
    if (isFutureWeek(localNow)) return 0;
    if (isCurrentWeek(localNow)) {
      return (localNow.day - startDay + 1).clamp(1, totalDaysInSegment);
    }
    return totalDaysInSegment;
  }

  /// Checks if a date falls within this week segment
  bool contains(DateTime date) {
    final local = date.toLocal();
    return !local.isBefore(startDate) && local.isBefore(endExclusive);
  }
}

/// Represents a 7-day Monday–Sunday calendar week
class CalendarWeekRange {
  final DateTime mondayStart; // Monday 00:00:00 local
  final DateTime sundayEndExclusive; // Next Monday 00:00:00 local
  final List<DateTime> days; // 7 dates (Mon to Sun)

  const CalendarWeekRange({
    required this.mondayStart,
    required this.sundayEndExclusive,
    required this.days,
  });

  DateTime get startUtc => mondayStart.toUtc();
  DateTime get endUtcExclusive => sundayEndExclusive.toUtc();

  bool contains(DateTime date) {
    final local = date.toLocal();
    return !local.isBefore(mondayStart) && local.isBefore(sundayEndExclusive);
  }
}

/// Centralized date calculations for calendar months, week segments, and timezone boundaries.
class DateRangeUtils {
  static const List<String> monthNamesAbbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  static String getMonthAbbr(int month) {
    return monthNamesAbbr[(month - 1).clamp(0, 11)];
  }

  /// Returns the number of days in a given month (handles leap years).
  static int getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  /// Builds a [CalendarMonthRange] for the given [localDate] with strict
  /// boundaries: local 1st at 00:00:00 to local 1st of next month at 00:00:00.
  static CalendarMonthRange getCalendarMonthRange(DateTime localDate) {
    final year = localDate.year;
    final month = localDate.month;
    final start = DateTime(year, month, 1, 0, 0, 0);
    final endExclusive = DateTime(year, month + 1, 1, 0, 0, 0);
    final daysInMonth = getDaysInMonth(year, month);

    return CalendarMonthRange(
      year: year,
      month: month,
      start: start,
      endExclusive: endExclusive,
      daysInMonth: daysInMonth,
    );
  }

  /// Returns the week segment number (1 to 5) for a given calendar day (1 to 31):
  /// - Days 1–7   -> 1 (Week 1)
  /// - Days 8–14  -> 2 (Week 2)
  /// - Days 15–21 -> 3 (Week 3)
  /// - Days 22–28 -> 4 (Week 4)
  /// - Days 29–31 -> 5 (Week 5)
  static int getWeekNumberForDay(int day) {
    if (day <= 0) return 1;
    return ((day - 1) ~/ 7) + 1;
  }

  /// Generates the week segments for a given calendar month:
  /// - Week 1: 1–7
  /// - Week 2: 8–14
  /// - Week 3: 15–21
  /// - Week 4: 22–28
  /// - Week 5: 29–end (omitted if daysInMonth == 28, e.g. Feb non-leap year)
  static List<MonthWeekSegment> getMonthWeekSegments(DateTime localDate) {
    final year = localDate.year;
    final month = localDate.month;
    final daysInMonth = getDaysInMonth(year, month);
    final monthAbbr = getMonthAbbr(month);

    final totalWeeks = getWeekNumberForDay(daysInMonth);
    final segments = <MonthWeekSegment>[];

    for (int w = 1; w <= totalWeeks; w++) {
      final startDay = (w - 1) * 7 + 1;
      final endDay = math.min(w * 7, daysInMonth);
      final startDate = DateTime(year, month, startDay, 0, 0, 0);
      final endDate = DateTime(year, month, endDay, 23, 59, 59, 999);
      final endExclusive = DateTime(year, month, endDay).add(const Duration(days: 1));
      final dateRangeLabel = startDay == endDay
          ? '$monthAbbr $startDay'
          : '$monthAbbr $startDay–$endDay';

      segments.add(MonthWeekSegment(
        weekNumber: w,
        startDay: startDay,
        endDay: endDay,
        startDate: startDate,
        endDate: endDate,
        endExclusive: endExclusive,
        totalDaysInSegment: endDay - startDay + 1,
        dateRangeLabel: dateRangeLabel,
      ));
    }

    return segments;
  }

  /// Builds a [CalendarWeekRange] spanning Monday 00:00:00 to next Monday 00:00:00
  /// for the week containing [localDate].
  static CalendarWeekRange getCurrentWeekRange(DateTime localDate) {
    final localMidnight = DateTime(localDate.year, localDate.month, localDate.day);
    final monday = localMidnight.subtract(Duration(days: localDate.weekday - 1));
    final sundayEndExclusive = monday.add(const Duration(days: 7));

    final days = List.generate(7, (i) => monday.add(Duration(days: i)));

    return CalendarWeekRange(
      mondayStart: monday,
      sundayEndExclusive: sundayEndExclusive,
      days: days,
    );
  }
}
