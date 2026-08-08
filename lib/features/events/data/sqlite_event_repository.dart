import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_migrations.dart';
import '../../../core/time/calendar_date.dart';
import '../domain/body_event.dart';
import '../domain/event_draft.dart';
import '../domain/event_enums.dart';
import '../domain/event_query.dart';
import '../domain/event_repository.dart';

typedef UtcClock = DateTime Function();

/// SQLite implementation of [EventRepository].
final class SQLiteEventRepository implements EventRepository {
  SQLiteEventRepository(this._appDatabase, {UtcClock? clock})
    : _clock = clock ?? _systemUtcNow;

  final AppDatabase _appDatabase;
  final UtcClock _clock;

  static DateTime _systemUtcNow() => DateTime.now().toUtc();

  @override
  Future<BodyEvent> add(EventDraft draft) async {
    final database = await _appDatabase.database;
    final now = _readClock();
    final values = _editableValues(draft)
      ..[EventTableSchema.createdAtUtc] = _toStorageTimestamp(now)
      ..[EventTableSchema.updatedAtUtc] = _toStorageTimestamp(now);

    final id = await database.insert(
      EventTableSchema.table,
      values,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return BodyEvent(
      id: id,
      eventType: draft.eventType,
      occurredAtUtc: draft.occurredAtUtc,
      utcOffsetMinutes: draft.utcOffsetMinutes,
      localDate: draft.localDate,
      amount: draft.amount,
      urgency: draft.urgency,
      leakage: draft.leakage,
      wokeFromSleep: draft.wokeFromSleep,
      bristolType: draft.bristolType,
      notes: draft.notes,
      extraDetails: draft.extraDetails,
      createdAtUtc: now,
      updatedAtUtc: now,
    );
  }

  @override
  Future<BodyEvent?> findById(int id) async {
    _requirePositiveId(id);
    final database = await _appDatabase.database;
    final rows = await database.query(
      EventTableSchema.table,
      where: '${EventTableSchema.id} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _eventFromRow(rows.single);
  }

  @override
  Future<List<BodyEvent>> query([EventQuery? query]) async {
    final effectiveQuery = query ?? EventQuery();
    final whereParts = <String>[];
    final whereArguments = <Object?>[];

    if (effectiveQuery.eventTypes.isNotEmpty) {
      final selectedTypes = EventType.values
          .where(effectiveQuery.eventTypes.contains)
          .toList(growable: false);
      whereParts.add(
        '${EventTableSchema.eventType} IN '
        '(${List.filled(selectedTypes.length, '?').join(', ')})',
      );
      whereArguments.addAll(
        selectedTypes.map((eventType) => eventType.storageValue),
      );
    }
    if (effectiveQuery.fromDate case final fromDate?) {
      whereParts.add('${EventTableSchema.localDate} >= ?');
      whereArguments.add(fromDate.format());
    }
    if (effectiveQuery.throughDate case final throughDate?) {
      whereParts.add('${EventTableSchema.localDate} <= ?');
      whereArguments.add(throughDate.format());
    }

    final direction = effectiveQuery.newestFirst ? 'DESC' : 'ASC';
    final database = await _appDatabase.database;
    final rows = await database.query(
      EventTableSchema.table,
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereArguments.isEmpty ? null : whereArguments,
      orderBy:
          '${EventTableSchema.occurredAtUtc} $direction, '
          '${EventTableSchema.id} $direction',
      limit: effectiveQuery.limit,
    );
    return rows.map(_eventFromRow).toList(growable: false);
  }

  @override
  Future<BodyEvent> update(int id, EventDraft draft) async {
    _requirePositiveId(id);
    final database = await _appDatabase.database;
    return database.transaction((transaction) async {
      final existingRows = await transaction.query(
        EventTableSchema.table,
        where: '${EventTableSchema.id} = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (existingRows.isEmpty) {
        throw StateError('Cannot update missing event $id.');
      }

      final existing = _eventFromRow(existingRows.single);
      final clockValue = _readClock();
      final updatedAt = clockValue.isBefore(existing.createdAtUtc)
          ? existing.createdAtUtc
          : clockValue;
      final values = _editableValues(draft)
        ..[EventTableSchema.updatedAtUtc] = _toStorageTimestamp(updatedAt);

      await transaction.update(
        EventTableSchema.table,
        values,
        where: '${EventTableSchema.id} = ?',
        whereArgs: [id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      return BodyEvent(
        id: id,
        eventType: draft.eventType,
        occurredAtUtc: draft.occurredAtUtc,
        utcOffsetMinutes: draft.utcOffsetMinutes,
        localDate: draft.localDate,
        amount: draft.amount,
        urgency: draft.urgency,
        leakage: draft.leakage,
        wokeFromSleep: draft.wokeFromSleep,
        bristolType: draft.bristolType,
        notes: draft.notes,
        extraDetails: draft.extraDetails,
        createdAtUtc: existing.createdAtUtc,
        updatedAtUtc: updatedAt,
      );
    });
  }

  @override
  Future<bool> deleteById(int id) async {
    _requirePositiveId(id);
    final database = await _appDatabase.database;
    final count = await database.delete(
      EventTableSchema.table,
      where: '${EventTableSchema.id} = ?',
      whereArgs: [id],
    );
    return count > 0;
  }

  @override
  Future<void> deleteAll() async {
    final database = await _appDatabase.database;
    await database.delete(EventTableSchema.table);
  }

  @override
  Future<List<BodyEvent>> allForExport() {
    return query(EventQuery(newestFirst: false));
  }

  DateTime _readClock() {
    final value = _clock();
    return value.isUtc ? value : value.toUtc();
  }

  static void _requirePositiveId(int id) {
    if (id < 1) {
      throw ArgumentError.value(id, 'id', 'Must be positive.');
    }
  }

  static Map<String, Object?> _editableValues(EventDraft draft) {
    return <String, Object?>{
      EventTableSchema.eventType: draft.eventType.storageValue,
      EventTableSchema.occurredAtUtc: _toStorageTimestamp(draft.occurredAtUtc),
      EventTableSchema.utcOffsetMinutes: draft.utcOffsetMinutes,
      EventTableSchema.localDate: draft.localDate.format(),
      EventTableSchema.amount: draft.amount?.storageValue,
      EventTableSchema.urgency: draft.urgency?.storageValue,
      EventTableSchema.leakage: draft.leakage?.storageValue,
      EventTableSchema.wokeFromSleep: _encodeNullableBool(draft.wokeFromSleep),
      EventTableSchema.bristolType: draft.bristolType,
      EventTableSchema.notes: draft.notes,
      EventTableSchema.extraDetailsJson: _encodeExtraDetails(
        draft.extraDetails,
      ),
    };
  }

  static int _toStorageTimestamp(DateTime value) {
    return value.toUtc().microsecondsSinceEpoch;
  }

  static DateTime _timestampFromRow(Map<String, Object?> row, String column) {
    final value = row[column];
    if (value is! int) {
      throw FormatException('Expected integer timestamp in $column.', value);
    }
    return DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true);
  }

  static BodyEvent _eventFromRow(Map<String, Object?> row) {
    return BodyEvent(
      id: row[EventTableSchema.id]! as int,
      eventType: EventType.fromStorage(
        row[EventTableSchema.eventType]! as String,
      ),
      occurredAtUtc: _timestampFromRow(row, EventTableSchema.occurredAtUtc),
      utcOffsetMinutes: row[EventTableSchema.utcOffsetMinutes]! as int,
      localDate: CalendarDate.parse(row[EventTableSchema.localDate]! as String),
      amount: _readOptionalEnum(
        row[EventTableSchema.amount],
        EventAmount.fromStorage,
      ),
      urgency: _readOptionalEnum(
        row[EventTableSchema.urgency],
        EventUrgency.fromStorage,
      ),
      leakage: _readOptionalEnum(
        row[EventTableSchema.leakage],
        LeakageLevel.fromStorage,
      ),
      wokeFromSleep: _decodeNullableBool(row[EventTableSchema.wokeFromSleep]),
      bristolType: row[EventTableSchema.bristolType] as int?,
      notes: row[EventTableSchema.notes] as String?,
      extraDetails: _decodeExtraDetails(
        row[EventTableSchema.extraDetailsJson] as String?,
      ),
      createdAtUtc: _timestampFromRow(row, EventTableSchema.createdAtUtc),
      updatedAtUtc: _timestampFromRow(row, EventTableSchema.updatedAtUtc),
    );
  }

  static T? _readOptionalEnum<T>(Object? value, T Function(String) parser) {
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw FormatException('Expected a stored enum string.', value);
    }
    return parser(value);
  }

  static int? _encodeNullableBool(bool? value) {
    return switch (value) {
      true => 1,
      false => 0,
      null => null,
    };
  }

  static bool? _decodeNullableBool(Object? value) {
    return switch (value) {
      null => null,
      0 => false,
      1 => true,
      _ => throw FormatException(
        'Expected null, 0, or 1 for ${EventTableSchema.wokeFromSleep}.',
        value,
      ),
    };
  }

  static String? _encodeExtraDetails(Map<String, Object?>? extraDetails) {
    if (extraDetails == null || extraDetails.isEmpty) {
      return null;
    }
    try {
      return jsonEncode(extraDetails);
    } on JsonUnsupportedObjectError catch (error) {
      throw ArgumentError.value(
        extraDetails,
        'extraDetails',
        'Values must be JSON-compatible: $error',
      );
    }
  }

  static Map<String, Object?>? _decodeExtraDetails(String? encoded) {
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('extra_details_json must contain an object.');
    }
    return Map<String, Object?>.from(decoded);
  }
}
