import 'package:flutter_test/flutter_test.dart';
import 'package:golog/core/database/app_database.dart';
import 'package:golog/core/time/calendar_date.dart';
import 'package:golog/features/events/data/development_event_seeder.dart';
import 'package:golog/features/events/data/sqlite_event_repository.dart';
import 'package:golog/features/events/domain/event_draft.dart';
import 'package:golog/features/events/domain/event_enums.dart';
import 'package:golog/features/events/domain/event_query.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase appDatabase;
  late SQLiteEventRepository repository;
  late DateTime clockValue;

  setUp(() async {
    clockValue = DateTime.utc(2026, 6, 10, 12);
    appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repository = SQLiteEventRepository(appDatabase, clock: () => clockValue);
    await appDatabase.database;
  });

  tearDown(() => appDatabase.close());

  test('add and findById round-trip every urination field', () async {
    final occurredAt = DateTime.utc(2026, 6, 10, 10, 12, 13, 14, 15);
    final added = await repository.add(
      EventDraft(
        eventType: EventType.urination,
        occurredAtUtc: occurredAt,
        utcOffsetMinutes: -240,
        amount: EventAmount.large,
        urgency: EventUrgency.severe,
        leakage: LeakageLevel.moderate,
        wokeFromSleep: true,
        notes: '  before appointment  ',
        extraDetails: {
          'futureScale': 2,
          'flags': ['a', 'b'],
        },
      ),
    );

    expect(added.id, 1);
    expect(added.occurredAtUtc, occurredAt);
    expect(added.localDate, CalendarDate(2026, 6, 10));
    expect(added.notes, 'before appointment');
    expect(added.wokeFromSleep, isTrue);
    expect(added.createdAtUtc, clockValue);
    expect(added.updatedAtUtc, clockValue);

    final loaded = await repository.findById(added.id);
    expect(loaded, isNotNull);
    expect(loaded!.eventType, EventType.urination);
    expect(loaded.occurredAtUtc, occurredAt);
    expect(loaded.utcOffsetMinutes, -240);
    expect(loaded.localDate, CalendarDate(2026, 6, 10));
    expect(loaded.amount, EventAmount.large);
    expect(loaded.urgency, EventUrgency.severe);
    expect(loaded.leakage, LeakageLevel.moderate);
    expect(loaded.wokeFromSleep, isTrue);
    expect(loaded.bristolType, isNull);
    expect(loaded.notes, 'before appointment');
    expect(loaded.extraDetails, {
      'futureScale': 2,
      'flags': ['a', 'b'],
    });
    expect(await repository.findById(999), isNull);
  });

  test(
    'update changes editable fields and preserves creation metadata',
    () async {
      final original = await repository.add(
        _draft(
          EventType.urination,
          DateTime.utc(2026, 6, 9, 14),
          amount: EventAmount.small,
          leakage: LeakageLevel.drops,
          wokeFromSleep: true,
        ),
      );
      clockValue = DateTime.utc(2026, 6, 10, 13);

      final updated = await repository.update(
        original.id,
        _draft(
          EventType.bowelMovement,
          DateTime.utc(2026, 6, 8, 14),
          amount: EventAmount.medium,
          urgency: EventUrgency.moderate,
          bristolType: 4,
          wokeFromSleep: true,
          wokeFromNap: true,
          notes: 'edited',
        ),
      );

      expect(updated.id, original.id);
      expect(updated.eventType, EventType.bowelMovement);
      expect(updated.leakage, isNull);
      expect(updated.wokeFromSleep, isTrue);
      expect(updated.wokeFromNap, isTrue);
      expect(updated.bristolType, 4);
      expect(updated.notes, 'edited');
      expect(updated.createdAtUtc, original.createdAtUtc);
      expect(updated.updatedAtUtc, clockValue);
      expect((await repository.findById(original.id))!.bristolType, 4);

      expect(
        () => repository.update(999, _draft(EventType.urination, clockValue)),
        throwsStateError,
      );
    },
  );

  test('round-trips tri-state sleep context for every event type', () async {
    var hour = 6;
    for (final eventType in EventType.values) {
      for (final wokeFromSleep in const <bool?>[null, false, true]) {
        final added = await repository.add(
          _draft(
            eventType,
            DateTime.utc(2026, 6, 10, hour++),
            wokeFromSleep: wokeFromSleep,
          ),
        );

        expect(
          (await repository.findById(added.id))!.wokeFromSleep,
          wokeFromSleep,
        );
      }
    }
  });

  test(
    'query applies type, inclusive local-date, ordering, and limit filters',
    () async {
      final first = await repository.add(
        _draft(
          EventType.urination,
          DateTime.utc(2026, 1, 1, 23),
          utcOffsetMinutes: 120,
        ),
      );
      await repository.add(
        _draft(
          EventType.bowelMovement,
          DateTime.utc(2026, 1, 2, 12),
          bristolType: 4,
        ),
      );
      final third = await repository.add(
        _draft(
          EventType.urination,
          DateTime.utc(2026, 1, 3, 2),
          utcOffsetMinutes: -300,
        ),
      );
      await repository.add(
        _draft(
          EventType.bowelMovement,
          DateTime.utc(2026, 1, 3, 12),
          bristolType: 5,
        ),
      );

      final filtered = await repository.query(
        EventQuery(
          eventTypes: {EventType.urination},
          fromDate: CalendarDate(2026, 1, 2),
          throughDate: CalendarDate(2026, 1, 2),
        ),
      );
      expect(filtered.map((event) => event.id), [third.id, first.id]);
      expect(
        filtered.every((event) => event.localDate == CalendarDate(2026, 1, 2)),
        isTrue,
      );

      final oldestOnward = await repository.query(
        EventQuery(
          fromDate: CalendarDate(2026, 1, 2),
          newestFirst: false,
          limit: 2,
        ),
      );
      expect(oldestOnward.map((event) => event.id), [first.id, 2]);
    },
  );

  test('stable ordering uses id when event instants are equal', () async {
    final instant = DateTime.utc(2026, 6, 10, 8);
    final first = await repository.add(_draft(EventType.urination, instant));
    final second = await repository.add(_draft(EventType.urination, instant));

    expect((await repository.query()).map((event) => event.id), [
      second.id,
      first.id,
    ]);
    expect((await repository.allForExport()).map((event) => event.id), [
      first.id,
      second.id,
    ]);
  });

  test('deleteById reports deletion and deleteAll empties storage', () async {
    final first = await repository.add(
      _draft(EventType.urination, DateTime.utc(2026, 6, 10, 8)),
    );
    await repository.add(
      _draft(
        EventType.bowelMovement,
        DateTime.utc(2026, 6, 10, 9),
        bristolType: 3,
      ),
    );

    expect(await repository.deleteById(first.id), isTrue);
    expect(await repository.deleteById(first.id), isFalse);
    expect((await repository.query()).length, 1);

    await repository.deleteAll();
    expect(await repository.query(), isEmpty);
  });

  test(
    'development seeding is opt-in, relative, and only runs when empty',
    () async {
      final anchor = DateTime.utc(2026, 6, 10, 12);
      final seeder = DevelopmentEventSeeder(repository, clock: () => anchor);

      expect(await seeder.seedIfEnabled(enabled: false), 0);
      expect(await repository.query(), isEmpty);

      expect(await seeder.seedIfEnabled(enabled: true), 9);
      final events = await repository.allForExport();
      expect(events, hasLength(9));
      expect(
        events.first.occurredAtUtc,
        anchor.subtract(const Duration(days: 6, hours: 1)),
      );
      expect(
        events.last.occurredAtUtc,
        anchor.subtract(const Duration(minutes: 35)),
      );
      expect(
        events.every((event) => event.notes == 'Development sample'),
        isTrue,
      );
      final wokeFromSleepEvents = events
          .where((event) => event.wokeFromSleep == true)
          .toList();
      expect(wokeFromSleepEvents, hasLength(2));
      expect(
        wokeFromSleepEvents.map((event) => event.eventType).toSet(),
        EventType.values.toSet(),
      );
      expect(await seeder.seedIfEnabled(enabled: true), 0);
      expect(await repository.query(), hasLength(9));
    },
  );

  test('ids must be positive at repository boundaries', () async {
    expect(() => repository.findById(0), throwsArgumentError);
    expect(() => repository.deleteById(-1), throwsArgumentError);
    expect(
      () => repository.update(0, _draft(EventType.urination, clockValue)),
      throwsArgumentError,
    );
  });
}

EventDraft _draft(
  EventType eventType,
  DateTime occurredAtUtc, {
  int utcOffsetMinutes = 0,
  EventAmount? amount,
  EventUrgency? urgency,
  LeakageLevel? leakage,
  bool? wokeFromSleep,
  bool? wokeFromNap,
  int? bristolType,
  String? notes,
}) {
  return EventDraft(
    eventType: eventType,
    occurredAtUtc: occurredAtUtc,
    utcOffsetMinutes: utcOffsetMinutes,
    amount: amount,
    urgency: urgency,
    leakage: leakage,
    wokeFromSleep: wokeFromSleep,
    wokeFromNap: wokeFromNap,
    bristolType: bristolType,
    notes: notes,
  );
}
