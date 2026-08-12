import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golog/core/database/app_database.dart';
import 'package:golog/core/database/database_migrations.dart';
import 'package:golog/features/events/data/sqlite_event_repository.dart';
import 'package:path/path.dart' as path_package;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('fresh database applies every schema version and index', () async {
    final appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(appDatabase.close);

    final database = await appDatabase.database;
    expect(await database.getVersion(), AppDatabase.schemaVersion);

    final columns = await database.rawQuery(
      'PRAGMA table_info(${EventTableSchema.table})',
    );
    final columnNames = columns.map((row) => row['name']).toSet();
    expect(columnNames, {
      EventTableSchema.id,
      EventTableSchema.eventType,
      EventTableSchema.occurredAtUtc,
      EventTableSchema.utcOffsetMinutes,
      EventTableSchema.localDate,
      EventTableSchema.amount,
      EventTableSchema.urgency,
      EventTableSchema.leakage,
      EventTableSchema.wokeFromSleep,
      EventTableSchema.wokeFromNap,
      EventTableSchema.bristolType,
      EventTableSchema.notes,
      EventTableSchema.extraDetailsJson,
      EventTableSchema.createdAtUtc,
      EventTableSchema.updatedAtUtc,
    });

    final indexes = await database.rawQuery(
      'PRAGMA index_list(${EventTableSchema.table})',
    );
    final indexNames = indexes.map((row) => row['name']).toSet();
    expect(
      indexNames,
      containsAll({
        EventTableSchema.localDateOccurredIndex,
        EventTableSchema.typeLocalDateIndex,
        EventTableSchema.occurredAtIndex,
      }),
    );
  });

  test('schema rejects non-boolean woke-from-sleep values', () async {
    final appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(appDatabase.close);
    final database = await appDatabase.database;
    final timestamp = DateTime.utc(2026, 1, 1).microsecondsSinceEpoch;

    await expectLater(
      database.insert(EventTableSchema.table, {
        EventTableSchema.eventType: 'urination',
        EventTableSchema.occurredAtUtc: timestamp,
        EventTableSchema.utcOffsetMinutes: 0,
        EventTableSchema.localDate: '2026-01-01',
        EventTableSchema.wokeFromSleep: 2,
        EventTableSchema.createdAtUtc: timestamp,
        EventTableSchema.updatedAtUtc: timestamp,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test(
    'opening a version 1 database migrates incrementally to current',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'golog_database_migration_',
      );
      addTearDown(() => temporaryDirectory.delete(recursive: true));
      final databasePath = path_package.join(
        temporaryDirectory.path,
        'migration.sqlite',
      );
      final instant = DateTime.utc(2026, 1, 1, 5, 30);
      final timestamp = instant.microsecondsSinceEpoch;

      final version1Database = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (database, version) {
            return AppDatabaseMigrations.migrate(
              database,
              fromVersion: 0,
              toVersion: version,
            );
          },
        ),
      );
      await version1Database.insert(EventTableSchema.table, {
        EventTableSchema.eventType: 'urination',
        EventTableSchema.occurredAtUtc: timestamp,
        EventTableSchema.utcOffsetMinutes: -300,
        EventTableSchema.localDate: '2026-01-01',
        EventTableSchema.amount: 'medium',
        EventTableSchema.urgency: null,
        EventTableSchema.leakage: null,
        EventTableSchema.bristolType: null,
        EventTableSchema.notes: 'legacy record',
        EventTableSchema.createdAtUtc: timestamp,
        EventTableSchema.updatedAtUtc: timestamp,
      });
      await version1Database.close();

      final appDatabase = AppDatabase(
        databaseFactory: databaseFactoryFfi,
        path: databasePath,
      );
      addTearDown(appDatabase.close);
      final upgradedDatabase = await appDatabase.database;

      expect(
        await upgradedDatabase.getVersion(),
        AppDatabaseMigrations.currentVersion,
      );
      final columns = await upgradedDatabase.rawQuery(
        'PRAGMA table_info(${EventTableSchema.table})',
      );
      expect(
        columns.map((row) => row['name']),
        contains(EventTableSchema.extraDetailsJson),
      );
      expect(
        columns.map((row) => row['name']),
        contains(EventTableSchema.wokeFromSleep),
      );
      expect(
        columns.map((row) => row['name']),
        contains(EventTableSchema.wokeFromNap),
      );

      final repository = SQLiteEventRepository(appDatabase);
      final migrated = await repository.findById(1);
      expect(migrated, isNotNull);
      expect(migrated!.notes, 'legacy record');
      expect(migrated.amount?.storageValue, 'medium');
      expect(migrated.utcOffsetMinutes, -300);
      expect(migrated.extraDetails, isNull);
      expect(migrated.wokeFromSleep, isNull);
    },
  );

  test(
    'opening a version 2 database preserves data through version 3',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'golog_database_v2_migration_',
      );
      addTearDown(() => temporaryDirectory.delete(recursive: true));
      final databasePath = path_package.join(
        temporaryDirectory.path,
        'migration.sqlite',
      );
      final instant = DateTime.utc(2026, 2, 3, 4, 5);
      final timestamp = instant.microsecondsSinceEpoch;

      final version2Database = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (database, version) {
            return AppDatabaseMigrations.migrate(
              database,
              fromVersion: 0,
              toVersion: version,
            );
          },
        ),
      );
      await version2Database.insert(EventTableSchema.table, {
        EventTableSchema.eventType: 'urination',
        EventTableSchema.occurredAtUtc: timestamp,
        EventTableSchema.utcOffsetMinutes: 0,
        EventTableSchema.localDate: '2026-02-03',
        EventTableSchema.amount: 'small',
        EventTableSchema.extraDetailsJson: '{"legacy":true}',
        EventTableSchema.createdAtUtc: timestamp,
        EventTableSchema.updatedAtUtc: timestamp,
      });
      await version2Database.close();

      final appDatabase = AppDatabase(
        databaseFactory: databaseFactoryFfi,
        path: databasePath,
      );
      addTearDown(appDatabase.close);
      final upgradedDatabase = await appDatabase.database;

      expect(
        await upgradedDatabase.getVersion(),
        AppDatabaseMigrations.currentVersion,
      );
      final migrated = await SQLiteEventRepository(appDatabase).findById(1);
      expect(migrated, isNotNull);
      expect(migrated!.amount?.storageValue, 'small');
      expect(migrated.extraDetails, {'legacy': true});
      expect(migrated.wokeFromSleep, isNull);
    },
  );

  test('migration runner rejects skipped or unsupported directions', () async {
    final appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(appDatabase.close);
    final database = await appDatabase.database;

    expect(
      () =>
          AppDatabaseMigrations.migrate(database, fromVersion: 2, toVersion: 1),
      throwsArgumentError,
    );
    expect(
      () => AppDatabaseMigrations.migrate(
        database,
        fromVersion: 0,
        toVersion: AppDatabaseMigrations.currentVersion + 1,
      ),
      throwsArgumentError,
    );
  });
}
