import '../../../core/time/calendar_date.dart';
import 'trend_range.dart';

class DailyEventTotal {
  const DailyEventTotal({
    required this.date,
    required this.urinationCount,
    required this.bowelMovementCount,
    this.nocturiaCount = 0,
  });

  final CalendarDate date;
  final int urinationCount;
  final int bowelMovementCount;
  final int nocturiaCount;

  int get totalCount => urinationCount + bowelMovementCount;
}

class WeeklyEventTotal {
  const WeeklyEventTotal({
    required this.weekStart,
    required this.weekEnd,
    required this.urinationCount,
    required this.bowelMovementCount,
    this.nocturiaCount = 0,
  });

  final CalendarDate weekStart;
  final CalendarDate weekEnd;
  final int urinationCount;
  final int bowelMovementCount;
  final int nocturiaCount;

  int get totalCount => urinationCount + bowelMovementCount;
}

class MonthlyEventTotal {
  const MonthlyEventTotal({
    required this.year,
    required this.month,
    required this.urinationCount,
    required this.bowelMovementCount,
    this.nocturiaCount = 0,
  });

  final int year;
  final int month;
  final int urinationCount;
  final int bowelMovementCount;
  final int nocturiaCount;

  int get totalCount => urinationCount + bowelMovementCount;
}

class TrendSummary {
  TrendSummary({
    required this.range,
    required List<DailyEventTotal> dailyTotals,
    required this.averageUrinationEventsPerDay,
    required this.averageBowelMovementEventsPerDay,
    required this.averageTotalEventsPerDay,
    required this.averageNocturiaWakeupsPerNight,
    required List<int> urinationByHour,
    required List<int> bowelMovementByHour,
    required List<WeeklyEventTotal> weeklyTotals,
    required List<MonthlyEventTotal> monthlyTotals,
    required this.nocturiaCount,
    required this.longestUrinationInterval,
    required this.averageUrinationInterval,
  }) : assert(urinationByHour.length == 24),
       assert(bowelMovementByHour.length == 24),
       dailyTotals = List.unmodifiable(dailyTotals),
       urinationByHour = List.unmodifiable(urinationByHour),
       bowelMovementByHour = List.unmodifiable(bowelMovementByHour),
       weeklyTotals = List.unmodifiable(weeklyTotals),
       monthlyTotals = List.unmodifiable(monthlyTotals);

  final TrendRange range;
  final List<DailyEventTotal> dailyTotals;
  final double averageUrinationEventsPerDay;
  final double averageBowelMovementEventsPerDay;
  final double averageTotalEventsPerDay;
  final double averageNocturiaWakeupsPerNight;
  final List<int> urinationByHour;
  final List<int> bowelMovementByHour;
  final List<WeeklyEventTotal> weeklyTotals;
  final List<MonthlyEventTotal> monthlyTotals;
  final int nocturiaCount;
  final Duration? longestUrinationInterval;
  final Duration? averageUrinationInterval;
}
