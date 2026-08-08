import 'package:flutter_test/flutter_test.dart';
import 'package:golog/core/time/calendar_date.dart';
import 'package:golog/features/events/domain/body_event.dart';
import 'package:golog/features/events/domain/event_draft.dart';
import 'package:golog/features/events/domain/event_enums.dart';
import 'package:golog/features/events/domain/event_query.dart';

void main() {
  group('stable enum storage values', () {
    test('event types remain independent from Dart enum names', () {
      expect(EventType.urination.storageValue, 'urination');
      expect(EventType.bowelMovement.storageValue, 'bowel_movement');
      expect(
        EventType.values.map(
          (value) => EventType.fromStorage(value.storageValue),
        ),
        EventType.values,
      );
      expect(() => EventType.fromStorage('future_type'), throwsFormatException);
    });

    test('optional detail enums round-trip their stable values', () {
      for (final amount in EventAmount.values) {
        expect(EventAmount.fromStorage(amount.storageValue), amount);
      }
      for (final urgency in EventUrgency.values) {
        expect(EventUrgency.fromStorage(urgency.storageValue), urgency);
      }
      for (final leakage in LeakageLevel.values) {
        expect(LeakageLevel.fromStorage(leakage.storageValue), leakage);
      }

      expect(() => EventAmount.fromStorage('huge'), throwsFormatException);
      expect(() => EventUrgency.fromStorage('urgent'), throwsFormatException);
      expect(() => LeakageLevel.fromStorage('some'), throwsFormatException);
    });
  });

  group('CalendarDate', () {
    test('formats, parses, compares, and exposes value equality', () {
      final leapDay = CalendarDate(2024, 2, 29);

      expect(leapDay.format(), '2024-02-29');
      expect(CalendarDate.parse('2024-02-29'), leapDay);
      expect(leapDay.compareTo(CalendarDate(2024, 3, 1)), isNegative);
      expect(CalendarDate(2025, 1, 1).compareTo(leapDay), isPositive);
      expect(leapDay.asUtcMidnight, DateTime.utc(2024, 2, 29));
      expect(leapDay.toString(), '2024-02-29');
    });

    test('rejects malformed and impossible dates', () {
      expect(() => CalendarDate.parse('2024-2-09'), throwsFormatException);
      expect(() => CalendarDate.parse('2023-02-29'), throwsFormatException);
      expect(() => CalendarDate(2024, 13, 1), throwsArgumentError);
    });

    test('derives the recorded day across UTC boundaries', () {
      expect(
        CalendarDate.fromUtcAndOffset(DateTime.utc(2026, 5, 4, 2), -300),
        CalendarDate(2026, 5, 3),
      );
      expect(
        CalendarDate.fromUtcAndOffset(DateTime.utc(2026, 5, 4, 23), 120),
        CalendarDate(2026, 5, 5),
      );
      expect(
        () => CalendarDate.fromUtcAndOffset(DateTime(2026), 0),
        throwsArgumentError,
      );
    });
  });

  group('EventDraft', () {
    test('normalizes notes and calculates the recorded local date', () {
      final draft = EventDraft(
        eventType: EventType.urination,
        occurredAtUtc: DateTime.utc(2026, 1, 2, 2, 30),
        utcOffsetMinutes: -300,
        amount: EventAmount.medium,
        urgency: EventUrgency.mild,
        leakage: LeakageLevel.none,
        wokeFromSleep: true,
        notes: '  hydrated  ',
        extraDetails: {'source': 'test'},
      );

      expect(draft.localDate, CalendarDate(2026, 1, 1));
      expect(draft.notes, 'hydrated');
      expect(draft.wokeFromSleep, isTrue);
      expect(draft.extraDetails, {'source': 'test'});
      expect(
        () => draft.extraDetails!['source'] = 'changed',
        throwsUnsupportedError,
      );
      expect(draft.copyWith(notes: null).notes, isNull);
      expect(draft.copyWith(amount: null).amount, isNull);
      expect(draft.copyWith(wokeFromSleep: false).wokeFromSleep, isFalse);
      expect(draft.copyWith(wokeFromSleep: null).wokeFromSleep, isNull);
    });

    test('rejects non-UTC instants and out-of-range offsets', () {
      expect(
        () => EventDraft(
          eventType: EventType.urination,
          occurredAtUtc: DateTime(2026),
          utcOffsetMinutes: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => EventDraft(
          eventType: EventType.urination,
          occurredAtUtc: DateTime.utc(2026),
          utcOffsetMinutes: 1441,
        ),
        throwsRangeError,
      );
    });

    test('rejects irrelevant details and invalid Bristol values', () {
      expect(
        () => EventDraft(
          eventType: EventType.urination,
          occurredAtUtc: DateTime.utc(2026),
          utcOffsetMinutes: 0,
          bristolType: 4,
        ),
        throwsArgumentError,
      );
      expect(
        () => EventDraft(
          eventType: EventType.bowelMovement,
          occurredAtUtc: DateTime.utc(2026),
          utcOffsetMinutes: 0,
          leakage: LeakageLevel.drops,
        ),
        throwsArgumentError,
      );
      expect(
        () => EventDraft(
          eventType: EventType.bowelMovement,
          occurredAtUtc: DateTime.utc(2026),
          utcOffsetMinutes: 0,
          bristolType: 8,
        ),
        throwsRangeError,
      );
    });

    test('allows tri-state sleep context for every event type', () {
      for (final eventType in EventType.values) {
        for (final wokeFromSleep in const <bool?>[null, false, true]) {
          final draft = EventDraft(
            eventType: eventType,
            occurredAtUtc: DateTime.utc(2026),
            utcOffsetMinutes: 0,
            wokeFromSleep: wokeFromSleep,
          );

          expect(draft.wokeFromSleep, wokeFromSleep);
        }
      }
    });
  });

  group('BodyEvent', () {
    test('reconstructs wall time and recalculates date in copyWith', () {
      final event = BodyEvent(
        id: 7,
        eventType: EventType.urination,
        occurredAtUtc: DateTime.utc(2026, 4, 2, 3, 15),
        utcOffsetMinutes: -240,
        localDate: CalendarDate(2026, 4, 1),
        amount: EventAmount.large,
        wokeFromSleep: true,
        createdAtUtc: DateTime.utc(2026, 4, 2, 3, 16),
        updatedAtUtc: DateTime.utc(2026, 4, 2, 3, 16),
      );

      expect(event.recordedLocalDateTime.year, 2026);
      expect(event.recordedLocalDateTime.month, 4);
      expect(event.recordedLocalDateTime.day, 1);
      expect(event.recordedLocalDateTime.hour, 23);
      expect(event.recordedLocalDateTime.minute, 15);
      expect(event.wokeFromSleep, isTrue);

      final changed = event.copyWith(
        occurredAtUtc: DateTime.utc(2026, 4, 3, 6),
        amount: null,
        wokeFromSleep: null,
      );
      expect(changed.localDate, CalendarDate(2026, 4, 3));
      expect(changed.amount, isNull);
      expect(changed.wokeFromSleep, isNull);
    });

    test('rejects a local date inconsistent with instant and offset', () {
      expect(
        () => BodyEvent(
          id: 1,
          eventType: EventType.urination,
          occurredAtUtc: DateTime.utc(2026, 1, 1, 1),
          utcOffsetMinutes: -300,
          localDate: CalendarDate(2026, 1, 1),
          createdAtUtc: DateTime.utc(2026, 1, 1, 2),
          updatedAtUtc: DateTime.utc(2026, 1, 1, 2),
        ),
        throwsArgumentError,
      );
    });

    test('allows tri-state sleep context on bowel movements', () {
      for (final wokeFromSleep in const <bool?>[null, false, true]) {
        final event = BodyEvent(
          id: 1,
          eventType: EventType.bowelMovement,
          occurredAtUtc: DateTime.utc(2026, 1, 1),
          utcOffsetMinutes: 0,
          localDate: CalendarDate(2026, 1, 1),
          wokeFromSleep: wokeFromSleep,
          createdAtUtc: DateTime.utc(2026, 1, 1),
          updatedAtUtc: DateTime.utc(2026, 1, 1),
        );

        expect(event.wokeFromSleep, wokeFromSleep);
      }
    });
  });

  group('EventQuery', () {
    test('copies filters and validates range and limit', () {
      final mutableTypes = <EventType>{EventType.urination};
      final query = EventQuery(
        eventTypes: mutableTypes,
        fromDate: CalendarDate(2026, 1, 1),
        throughDate: CalendarDate(2026, 1, 31),
        limit: 20,
      );
      mutableTypes.add(EventType.bowelMovement);

      expect(query.eventTypes, {EventType.urination});
      expect(query.newestFirst, isTrue);
      expect(() => query.eventTypes.clear(), throwsUnsupportedError);
      expect(() => EventQuery(limit: 0), throwsArgumentError);
      expect(
        () => EventQuery(
          fromDate: CalendarDate(2026, 2, 1),
          throughDate: CalendarDate(2026, 1, 31),
        ),
        throwsArgumentError,
      );
    });
  });
}
