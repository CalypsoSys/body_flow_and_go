import 'package:sqflite/sqflite.dart';

/// Stable names used by the SQLite event schema.
abstract final class EventTableSchema {
  static const table = 'events';

  static const id = 'id';
  static const eventType = 'event_type';
  static const occurredAtUtc = 'occurred_at_utc';
  static const utcOffsetMinutes = 'utc_offset_minutes';
  static const localDate = 'local_date';
  static const amount = 'amount';
  static const urgency = 'urgency';
  static const leakage = 'leakage';
  static const wokeFromSleep = 'woke_from_sleep';
  static const bristolType = 'bristol_type';
  static const notes = 'notes';
  static const extraDetailsJson = 'extra_details_json';
  static const createdAtUtc = 'created_at_utc';
  static const updatedAtUtc = 'updated_at_utc';

  static const localDateOccurredIndex = 'idx_events_local_date_occurred_at';
  static const typeLocalDateIndex = 'idx_events_type_local_date';
  static const occurredAtIndex = 'idx_events_occurred_at';
}

/// Incremental database migrations for the application database.
///
/// Version 1 establishes the event record and the UTC offset required to
/// reconstruct its recorded wall time. Version 2 adds a JSON extension point
/// for future optional fields without weakening the typed first-class columns.
/// Version 3 adds nullable wake-from-sleep context for every event type.
abstract final class AppDatabaseMigrations {
  static const currentVersion = 3;

  static Future<void> migrate(
    DatabaseExecutor database, {
    required int fromVersion,
    required int toVersion,
  }) async {
    if (fromVersion < 0 ||
        toVersion < fromVersion ||
        toVersion > currentVersion) {
      throw ArgumentError(
        'Unsupported migration range $fromVersion -> $toVersion.',
      );
    }

    for (var version = fromVersion + 1; version <= toVersion; version++) {
      switch (version) {
        case 1:
          await _createVersion1(database);
        case 2:
          await _upgradeToVersion2(database);
        case 3:
          await _upgradeToVersion3(database);
      }
    }
  }

  static Future<void> _createVersion1(DatabaseExecutor database) async {
    await database.execute('''
CREATE TABLE ${EventTableSchema.table} (
  ${EventTableSchema.id} INTEGER PRIMARY KEY AUTOINCREMENT,
  ${EventTableSchema.eventType} TEXT NOT NULL,
  ${EventTableSchema.occurredAtUtc} INTEGER NOT NULL,
  ${EventTableSchema.utcOffsetMinutes} INTEGER NOT NULL,
  ${EventTableSchema.localDate} TEXT NOT NULL,
  ${EventTableSchema.amount} TEXT,
  ${EventTableSchema.urgency} TEXT,
  ${EventTableSchema.leakage} TEXT,
  ${EventTableSchema.bristolType} INTEGER
    CHECK (${EventTableSchema.bristolType} IS NULL OR
      ${EventTableSchema.bristolType} BETWEEN 1 AND 7),
  ${EventTableSchema.notes} TEXT,
  ${EventTableSchema.createdAtUtc} INTEGER NOT NULL,
  ${EventTableSchema.updatedAtUtc} INTEGER NOT NULL
)
''');
    await database.execute('''
CREATE INDEX ${EventTableSchema.localDateOccurredIndex}
ON ${EventTableSchema.table} (
  ${EventTableSchema.localDate},
  ${EventTableSchema.occurredAtUtc}
)
''');
    await database.execute('''
CREATE INDEX ${EventTableSchema.typeLocalDateIndex}
ON ${EventTableSchema.table} (
  ${EventTableSchema.eventType},
  ${EventTableSchema.localDate},
  ${EventTableSchema.occurredAtUtc}
)
''');
    await database.execute('''
CREATE INDEX ${EventTableSchema.occurredAtIndex}
ON ${EventTableSchema.table} (${EventTableSchema.occurredAtUtc})
''');
  }

  static Future<void> _upgradeToVersion2(DatabaseExecutor database) async {
    await database.execute('''
ALTER TABLE ${EventTableSchema.table}
ADD COLUMN ${EventTableSchema.extraDetailsJson} TEXT
''');
  }

  static Future<void> _upgradeToVersion3(DatabaseExecutor database) async {
    await database.execute('''
ALTER TABLE ${EventTableSchema.table}
ADD COLUMN ${EventTableSchema.wokeFromSleep} INTEGER
  CHECK (${EventTableSchema.wokeFromSleep} IS NULL OR
    ${EventTableSchema.wokeFromSleep} IN (0, 1))
''');
  }
}
