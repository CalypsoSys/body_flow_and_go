import 'package:flutter_test/flutter_test.dart';
import 'package:golog/core/time/calendar_date.dart';
import 'package:golog/features/events/domain/body_event.dart';
import 'package:golog/features/events/domain/event_enums.dart';
import 'package:golog/features/trends/domain/trend_calculator.dart';
import 'package:golog/features/trends/domain/trend_range.dart';

void main() {
  const calculator = TrendCalculator();

  group('TrendRange', () {
    test('is inclusive and iterates safely across leap day', () {
      final range = TrendRange(
        start: CalendarDate(2024, 2, 28),
        end: CalendarDate(2024, 3, 1),
      );

      expect(range.dayCount, 3);
      expect(range.dates.map((date) => date.format()), [
        '2024-02-28',
        '2024-02-29',
        '2024-03-01',
      ]);
      expect(range.contains(CalendarDate(2024, 2, 28)), isTrue);
      expect(range.contains(CalendarDate(2024, 3, 1)), isTrue);
      expect(range.contains(CalendarDate(2024, 3, 2)), isFalse);
    });

    test('rejects a reversed range in all build modes', () {
      expect(
        () => TrendRange(
          start: CalendarDate(2026, 8, 6),
          end: CalendarDate(2026, 8, 5),
        ),
        throwsArgumentError,
      );
    });
  });

  group('TrendCalculator daily and hourly summaries', () {
    test('zero-fills days and includes zero days in averages', () {
      final range = TrendRange(
        start: CalendarDate(2026, 1, 1),
        end: CalendarDate(2026, 1, 3),
      );
      final events = [
        _event(
          id: 1,
          type: EventType.urination,
          occurredAtUtc: DateTime.utc(2026, 1, 1, 23, 30),
          utcOffsetMinutes: 120,
        ),
        _event(
          id: 2,
          type: EventType.bowelMovement,
          occurredAtUtc: DateTime.utc(2026, 1, 3, 14),
          utcOffsetMinutes: -300,
        ),
        _event(
          id: 3,
          type: EventType.urination,
          occurredAtUtc: DateTime.utc(2025, 12, 31, 12),
        ),
      ];

      final summary = calculator.calculate(events: events, range: range);

      expect(summary.dailyTotals, hasLength(3));
      expect(
        summary.dailyTotals.map(
          (day) => [
            day.date.format(),
            day.urinationCount,
            day.bowelMovementCount,
          ],
        ),
        [
          ['2026-01-01', 0, 0],
          ['2026-01-02', 1, 0],
          ['2026-01-03', 0, 1],
        ],
      );
      expect(summary.averageUrinationEventsPerDay, closeTo(1 / 3, 0.0001));
      expect(summary.averageBowelMovementEventsPerDay, closeTo(1 / 3, 0.0001));
      expect(summary.averageTotalEventsPerDay, closeTo(2 / 3, 0.0001));
      expect(summary.urinationByHour[1], 1);
      expect(summary.bowelMovementByHour[9], 1);
      expect(summary.urinationByHour.reduce((a, b) => a + b), 1);
      expect(summary.bowelMovementByHour.reduce((a, b) => a + b), 1);
    });

    test('uses the recorded offset rather than the test machine timezone', () {
      final range = TrendRange(
        start: CalendarDate(2026, 8, 5),
        end: CalendarDate(2026, 8, 5),
      );
      final events = [
        _event(
          id: 1,
          type: EventType.urination,
          occurredAtUtc: DateTime.utc(2026, 8, 5, 23, 45),
          utcOffsetMinutes: -240,
        ),
        _event(
          id: 2,
          type: EventType.bowelMovement,
          occurredAtUtc: DateTime.utc(2026, 8, 5, 1, 15),
          utcOffsetMinutes: 330,
        ),
      ];

      final summary = calculator.calculate(events: events, range: range);

      expect(summary.urinationByHour[19], 1);
      expect(summary.bowelMovementByHour[6], 1);
    });
  });

  group('TrendCalculator calendar buckets', () {
    test('uses Monday weeks and calendar months across a year boundary', () {
      final range = TrendRange(
        start: CalendarDate(2024, 12, 29),
        end: CalendarDate(2025, 1, 7),
      );
      final events = [
        _localEvent(1, EventType.urination, 2024, 12, 29, 8),
        _localEvent(2, EventType.bowelMovement, 2024, 12, 31, 9),
        _localEvent(3, EventType.urination, 2025, 1, 1, 10),
        _localEvent(4, EventType.bowelMovement, 2025, 1, 7, 11),
      ];

      final summary = calculator.calculate(events: events, range: range);

      expect(
        summary.weeklyTotals.map(
          (week) => [
            week.weekStart.format(),
            week.weekEnd.format(),
            week.urinationCount,
            week.bowelMovementCount,
          ],
        ),
        [
          ['2024-12-23', '2024-12-29', 1, 0],
          ['2024-12-30', '2025-01-05', 1, 1],
          ['2025-01-06', '2025-01-12', 0, 1],
        ],
      );
      expect(
        summary.monthlyTotals.map(
          (month) => [
            month.year,
            month.month,
            month.urinationCount,
            month.bowelMovementCount,
          ],
        ),
        [
          [2024, 12, 1, 1],
          [2025, 1, 1, 1],
        ],
      );
    });
  });

  group('TrendCalculator nocturia summary', () {
    test('counts only marked urination events in the selected range', () {
      final range = TrendRange(
        start: CalendarDate(2026, 8, 5),
        end: CalendarDate(2026, 8, 6),
      );
      final events = [
        _event(
          id: 1,
          type: EventType.urination,
          occurredAtUtc: DateTime.utc(2026, 8, 5, 1),
          wokeFromSleep: true,
        ),
        _event(
          id: 2,
          type: EventType.urination,
          occurredAtUtc: DateTime.utc(2026, 8, 5, 8),
          wokeFromSleep: false,
        ),
        _event(
          id: 3,
          type: EventType.urination,
          occurredAtUtc: DateTime.utc(2026, 8, 6, 2),
        ),
        _event(
          id: 4,
          type: EventType.urination,
          occurredAtUtc: DateTime.utc(2026, 8, 7, 1),
          wokeFromSleep: true,
        ),
        _event(
          id: 5,
          type: EventType.bowelMovement,
          occurredAtUtc: DateTime.utc(2026, 8, 5, 3),
          wokeFromSleep: true,
        ),
      ];

      final summary = calculator.calculate(events: events, range: range);

      expect(summary.nocturiaCount, 1);
    });

    test('is zero for an empty range', () {
      final range = TrendRange(
        start: CalendarDate(2026, 8, 5),
        end: CalendarDate(2026, 8, 5),
      );

      final summary = calculator.calculate(events: const [], range: range);

      expect(summary.nocturiaCount, 0);
    });

    test('counts nighttime wakeups but excludes nap wakeups', () {
      final range = TrendRange(
        start: CalendarDate(2026, 8, 6),
        end: CalendarDate(2026, 8, 6),
      );
      final events = [
        _localEvent(
          1,
          EventType.urination,
          2026,
          8,
          5,
          23,
          wokeFromSleep: true,
        ),
        _localEvent(
          2,
          EventType.urination,
          2026,
          8,
          6,
          2,
          wokeFromSleep: true,
        ),
        _localEvent(
          3,
          EventType.urination,
          2026,
          8,
          6,
          7,
          wokeFromSleep: false,
        ),
        _localEvent(
          4,
          EventType.urination,
          2026,
          8,
          6,
          14,
          wokeFromSleep: true,
          wokeFromNap: true,
        ),
      ];

      final summary = calculator.calculate(events: events, range: range);

      expect(summary.nocturiaCount, 2);
      expect(summary.averageNocturiaWakeupsPerNight, 2);
      expect(summary.dailyTotals.single.nocturiaCount, 2);
    });
  });

  group('TrendCalculator urination intervals', () {
    test('sorts UTC instants and computes longest and arithmetic mean', () {
      final range = TrendRange(
        start: CalendarDate(2026, 3, 8),
        end: CalendarDate(2026, 3, 8),
      );
      final events = [
        _event(
          id: 3,
          type: EventType.urination,
          occurredAtUtc: DateTime.utc(2026, 3, 8, 8),
          utcOffsetMinutes: -240,
        ),
        _event(
          id: 1,
          type: EventType.urination,
          occurredAtUtc: DateTime.utc(2026, 3, 8, 5),
          utcOffsetMinutes: -300,
        ),
        _event(
          id: 2,
          type: EventType.urination,
          occurredAtUtc: DateTime.utc(2026, 3, 8, 6),
          utcOffsetMinutes: -300,
        ),
        _event(
          id: 4,
          type: EventType.bowelMovement,
          occurredAtUtc: DateTime.utc(2026, 3, 8, 12),
          utcOffsetMinutes: -240,
        ),
      ];

      final summary = calculator.calculate(events: events, range: range);

      expect(summary.longestUrinationInterval, const Duration(hours: 2));
      expect(
        summary.averageUrinationInterval,
        const Duration(hours: 1, minutes: 30),
      );
    });

    test('returns null intervals with fewer than two urination events', () {
      final range = TrendRange(
        start: CalendarDate(2026, 1, 1),
        end: CalendarDate(2026, 1, 2),
      );

      final summary = calculator.calculate(
        events: [_localEvent(1, EventType.urination, 2026, 1, 1, 12)],
        range: range,
      );

      expect(summary.longestUrinationInterval, isNull);
      expect(summary.averageUrinationInterval, isNull);
    });

    test('retains zero-length intervals for duplicate instants', () {
      final range = TrendRange(
        start: CalendarDate(2026, 1, 1),
        end: CalendarDate(2026, 1, 1),
      );
      final instant = DateTime.utc(2026, 1, 1, 12);

      final summary = calculator.calculate(
        events: [
          _event(id: 1, type: EventType.urination, occurredAtUtc: instant),
          _event(id: 2, type: EventType.urination, occurredAtUtc: instant),
        ],
        range: range,
      );

      expect(summary.longestUrinationInterval, Duration.zero);
      expect(summary.averageUrinationInterval, Duration.zero);
    });
  });
}

BodyEvent _localEvent(
  int id,
  EventType type,
  int year,
  int month,
  int day,
  int hour,
  {
  bool? wokeFromSleep,
  bool? wokeFromNap,
  }
) => _event(
  id: id,
  type: type,
  occurredAtUtc: DateTime.utc(year, month, day, hour),
  wokeFromSleep: wokeFromSleep,
  wokeFromNap: wokeFromNap,
);

BodyEvent _event({
  required int id,
  required EventType type,
  required DateTime occurredAtUtc,
  int utcOffsetMinutes = 0,
  bool? wokeFromSleep,
  bool? wokeFromNap,
}) {
  final instant = occurredAtUtc.toUtc();
  return BodyEvent(
    id: id,
    eventType: type,
    occurredAtUtc: instant,
    utcOffsetMinutes: utcOffsetMinutes,
    localDate: CalendarDate.fromUtcAndOffset(instant, utcOffsetMinutes),
    wokeFromSleep: wokeFromSleep,
    wokeFromNap: wokeFromNap,
    createdAtUtc: instant,
    updatedAtUtc: instant,
  );
}
