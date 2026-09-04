import '../../../core/time/calendar_date.dart';
import '../../events/domain/body_event.dart';
import '../../events/domain/event_enums.dart';
import 'trend_range.dart';
import 'trend_summary.dart';

class TrendCalculator {
  const TrendCalculator();

  TrendSummary calculate({
    required List<BodyEvent> events,
    required TrendRange range,
  }) {
    final daily = <String, _MutableTotal>{
      for (final date in range.dates) date.format(): _MutableTotal(date),
    };
    final urinationByHour = List<int>.filled(24, 0);
    final bowelMovementByHour = List<int>.filled(24, 0);
    final urinationEvents = <BodyEvent>[];
    final nocturiaByDate = _nocturiaByDate(events, range);

    for (final event in events) {
      if (!range.contains(event.localDate)) {
        continue;
      }

      final total = daily[event.localDate.format()];
      if (total == null) {
        continue;
      }

      final hour = event.recordedLocalDateTime.hour;
      switch (event.eventType) {
        case EventType.urination:
          total.urinationCount++;
          urinationByHour[hour]++;
          urinationEvents.add(event);
        case EventType.bowelMovement:
          total.bowelMovementCount++;
          bowelMovementByHour[hour]++;
      }
    }

    final dailyTotals = daily.values
        .map(
          (total) => DailyEventTotal(
            date: total.date,
            urinationCount: total.urinationCount,
            bowelMovementCount: total.bowelMovementCount,
            nocturiaCount: nocturiaByDate[total.date.format()] ?? 0,
          ),
        )
        .toList(growable: false);
    final weeklyTotals = _weeklyTotals(dailyTotals);
    final monthlyTotals = _monthlyTotals(dailyTotals);
    final loggedDates = dailyTotals
        .where((total) => total.totalCount > 0)
        .map((total) => total.date)
        .toSet();
    final intervals = _urinationIntervals(urinationEvents, loggedDates);
    final urinationCount = dailyTotals.fold<int>(
      0,
      (sum, total) => sum + total.urinationCount,
    );
    final bowelMovementCount = dailyTotals.fold<int>(
      0,
      (sum, total) => sum + total.bowelMovementCount,
    );
    final nocturiaCount = dailyTotals.fold<int>(
      0,
      (sum, total) => sum + total.nocturiaCount,
    );
    final loggedDayCount = dailyTotals
        .where((total) => total.totalCount > 0)
        .length;
    final averageDenominator = loggedDayCount == 0 ? 1 : loggedDayCount;

    return TrendSummary(
      range: range,
      dailyTotals: dailyTotals,
      averageUrinationEventsPerDay: urinationCount / averageDenominator,
      averageBowelMovementEventsPerDay: bowelMovementCount / averageDenominator,
      averageTotalEventsPerDay:
          (urinationCount + bowelMovementCount) / averageDenominator,
      averageNocturiaWakeupsPerNight:
          nocturiaByDate.values.fold<int>(0, (sum, value) => sum + value) /
          averageDenominator,
      urinationByHour: urinationByHour,
      bowelMovementByHour: bowelMovementByHour,
      weeklyTotals: weeklyTotals,
      monthlyTotals: monthlyTotals,
      nocturiaCount: nocturiaCount,
      longestUrinationInterval: intervals.longest,
      averageUrinationInterval: intervals.average,
    );
  }

  Map<String, int> _nocturiaByDate(List<BodyEvent> events, TrendRange range) {
    final urinations =
        events.where((event) => event.eventType == EventType.urination).toList()
          ..sort(
            (a, b) =>
                a.recordedLocalDateTime.compareTo(b.recordedLocalDateTime),
          );
    final result = <String, int>{};

    for (final date in range.dates) {
      final start = DateTime.utc(
        date.year,
        date.month,
        date.day,
      ).subtract(const Duration(hours: 4));
      final end = DateTime.utc(date.year, date.month, date.day, 20);
      final nightEvents = urinations.where((event) {
        final wall = event.recordedLocalDateTime;
        return !wall.isBefore(start) && wall.isBefore(end);
      });
      DateTime? firstAwake;
      for (final event in nightEvents) {
        final wall = event.recordedLocalDateTime;
        if (wall.day == date.day &&
            wall.month == date.month &&
            wall.year == date.year &&
            event.wokeFromSleep == false) {
          firstAwake = wall;
          break;
        }
      }
      final count = nightEvents.where((event) {
        final wall = event.recordedLocalDateTime;
        return (firstAwake == null || wall.isBefore(firstAwake)) &&
            event.wokeFromSleep == true &&
            event.wokeFromNap != true;
      }).length;
      result[date.format()] = count;
    }
    return result;
  }

  List<WeeklyEventTotal> _weeklyTotals(List<DailyEventTotal> dailyTotals) {
    final buckets = <String, _MutableWeeklyTotal>{};
    for (final total in dailyTotals) {
      final date = _asUtc(total.date);
      final monday = date.subtract(
        Duration(days: date.weekday - DateTime.monday),
      );
      final weekStart = CalendarDate(monday.year, monday.month, monday.day);
      final bucket = buckets.putIfAbsent(
        weekStart.format(),
        () => _MutableWeeklyTotal(weekStart),
      );
      bucket.urinationCount += total.urinationCount;
      bucket.bowelMovementCount += total.bowelMovementCount;
      bucket.nocturiaCount += total.nocturiaCount;
    }

    return buckets.values
        .map((bucket) {
          final end = _asUtc(bucket.weekStart).add(const Duration(days: 6));
          return WeeklyEventTotal(
            weekStart: bucket.weekStart,
            weekEnd: CalendarDate(end.year, end.month, end.day),
            urinationCount: bucket.urinationCount,
            bowelMovementCount: bucket.bowelMovementCount,
            nocturiaCount: bucket.nocturiaCount,
          );
        })
        .toList(growable: false);
  }

  List<MonthlyEventTotal> _monthlyTotals(List<DailyEventTotal> dailyTotals) {
    final buckets = <String, _MutableMonthlyTotal>{};
    for (final total in dailyTotals) {
      final key =
          '${total.date.year.toString().padLeft(4, '0')}-'
          '${total.date.month.toString().padLeft(2, '0')}';
      final bucket = buckets.putIfAbsent(
        key,
        () => _MutableMonthlyTotal(total.date.year, total.date.month),
      );
      bucket.urinationCount += total.urinationCount;
      bucket.bowelMovementCount += total.bowelMovementCount;
      bucket.nocturiaCount += total.nocturiaCount;
    }

    return buckets.values
        .map(
          (bucket) => MonthlyEventTotal(
            year: bucket.year,
            month: bucket.month,
            urinationCount: bucket.urinationCount,
            bowelMovementCount: bucket.bowelMovementCount,
            nocturiaCount: bucket.nocturiaCount,
          ),
        )
        .toList(growable: false);
  }

  _Intervals _urinationIntervals(
    List<BodyEvent> events,
    Set<CalendarDate> loggedDates,
  ) {
    if (events.length < 2) {
      return const _Intervals();
    }

    events.sort(
      (a, b) => a.occurredAtUtc.compareTo(b.occurredAtUtc),
    );
    Duration? longest;
    var totalMicroseconds = 0;
    var intervalCount = 0;
    for (var index = 1; index < events.length; index++) {
      final previous = events[index - 1];
      final current = events[index];
      var date = previous.localDate.asUtcMidnight.add(const Duration(days: 1));
      var hasUnloggedDay = false;
      while (date.isBefore(current.localDate.asUtcMidnight)) {
        final calendarDate = CalendarDate.fromRecordedWallDate(date);
        if (!loggedDates.contains(calendarDate)) {
          hasUnloggedDay = true;
          break;
        }
        date = date.add(const Duration(days: 1));
      }
      if (hasUnloggedDay) {
        continue;
      }

      final interval = current.occurredAtUtc.difference(
        previous.occurredAtUtc,
      );
      totalMicroseconds += interval.inMicroseconds;
      intervalCount++;
      if (longest == null || interval > longest) {
        longest = interval;
      }
    }

    if (intervalCount == 0) {
      return const _Intervals();
    }

    return _Intervals(
      longest: longest,
      average: Duration(
        microseconds: totalMicroseconds ~/ intervalCount,
      ),
    );
  }

  DateTime _asUtc(CalendarDate date) =>
      DateTime.utc(date.year, date.month, date.day);
}

class _MutableTotal {
  _MutableTotal(this.date);

  final CalendarDate date;
  int urinationCount = 0;
  int bowelMovementCount = 0;
  int nocturiaCount = 0;
}

class _MutableWeeklyTotal {
  _MutableWeeklyTotal(this.weekStart);

  final CalendarDate weekStart;
  int urinationCount = 0;
  int bowelMovementCount = 0;
  int nocturiaCount = 0;
}

class _MutableMonthlyTotal {
  _MutableMonthlyTotal(this.year, this.month);

  final int year;
  final int month;
  int urinationCount = 0;
  int bowelMovementCount = 0;
  int nocturiaCount = 0;
}

class _Intervals {
  const _Intervals({this.longest, this.average});

  final Duration? longest;
  final Duration? average;
}
