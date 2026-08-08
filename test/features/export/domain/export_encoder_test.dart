import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:golog/core/time/calendar_date.dart';
import 'package:golog/features/events/domain/body_event.dart';
import 'package:golog/features/events/domain/event_enums.dart';
import 'package:golog/features/export/domain/export_encoder.dart';
import 'package:golog/features/export/domain/export_format.dart';

void main() {
  const encoder = ExportEncoder();
  final exportedAt = DateTime.utc(2026, 8, 5, 16, 7, 9);

  test('CSV uses the exact header, stable ordering, and blank null fields', () {
    final later = _event(
      id: 2,
      type: EventType.bowelMovement,
      occurredAtUtc: DateTime.utc(2026, 8, 5, 16),
      utcOffsetMinutes: -240,
      bristolType: 4,
    );
    final earlier = _event(
      id: 1,
      type: EventType.urination,
      occurredAtUtc: DateTime.utc(2026, 8, 5, 14, 5, 3),
      utcOffsetMinutes: -240,
      amount: EventAmount.medium,
      urgency: EventUrgency.mild,
      leakage: LeakageLevel.drops,
      wokeFromSleep: true,
    );

    final artifact = encoder.encode(
      format: ExportFormat.csv,
      events: [later, earlier],
      exportedAt: exportedAt,
    );
    final csv = utf8.decode(artifact.bytes);

    expect(
      csv,
      startsWith(
        'Date,Time,Event type,Woke from sleep,Amount,Urgency,Leakage,'
        'Bristol type,Notes\r\n',
      ),
    );
    expect(
      csv,
      contains(
        '2026-08-05,10:05:03-04:00,urination,yes,medium,mild,drops,,\r\n',
      ),
    );
    expect(
      csv,
      contains('2026-08-05,12:00:00-04:00,bowel_movement,,,,,4,\r\n'),
    );
    expect(csv.indexOf('urination'), lessThan(csv.indexOf('bowel_movement')));
    expect(artifact.fileName, 'body_flow_and_go_export_20260805_160709.csv');
    expect(artifact.mimeType, 'text/csv');
  });

  test('CSV encodes woke-from-sleep as blank, yes, or no', () {
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
        occurredAtUtc: DateTime.utc(2026, 8, 5, 2),
        wokeFromSleep: false,
      ),
      _event(
        id: 3,
        type: EventType.urination,
        occurredAtUtc: DateTime.utc(2026, 8, 5, 3),
      ),
    ];

    final artifact = encoder.encode(
      format: ExportFormat.csv,
      events: events,
      exportedAt: exportedAt,
    );
    final rows = const LineSplitter()
        .convert(utf8.decode(artifact.bytes))
        .skip(1)
        .where((row) => row.isNotEmpty)
        .map((row) => row.split(','))
        .toList();

    expect(rows.map((row) => row[3]), ['yes', 'no', '']);
  });

  test('CSV applies RFC4180 escaping and preserves Unicode', () {
    final event = _event(
      id: 1,
      type: EventType.urination,
      occurredAtUtc: DateTime.utc(2026, 8, 5, 12),
      notes: 'Café, "steady"\nsecond line — ठीक',
    );

    final artifact = encoder.encode(
      format: ExportFormat.csv,
      events: [event],
      exportedAt: exportedAt,
    );
    final csv = utf8.decode(artifact.bytes);

    expect(csv, contains('"Café, ""steady""\nsecond line — ठीक"'));
    expect(csv, endsWith('\r\n'));
  });

  test('JSON envelope contains every field and sorts records ascending', () {
    final later = _event(
      id: 9,
      type: EventType.bowelMovement,
      occurredAtUtc: DateTime.utc(2026, 8, 6, 1),
    );
    final explicitNo = _event(
      id: 7,
      type: EventType.urination,
      occurredAtUtc: DateTime.utc(2026, 8, 5, 18),
      wokeFromSleep: false,
    );
    final earlier = _event(
      id: 4,
      type: EventType.urination,
      occurredAtUtc: DateTime.utc(2026, 8, 5, 14),
      utcOffsetMinutes: -240,
      amount: EventAmount.large,
      urgency: EventUrgency.severe,
      leakage: LeakageLevel.none,
      wokeFromSleep: true,
      notes: 'hydrated ✓',
      extraDetails: const {'futureScale': 2, 'flag': true},
    );

    final artifact = encoder.encode(
      format: ExportFormat.json,
      events: [later, earlier, explicitNo],
      exportedAt: exportedAt,
    );
    final json =
        jsonDecode(utf8.decode(artifact.bytes)) as Map<String, Object?>;
    final records = (json['records']! as List<Object?>)
        .cast<Map<String, Object?>>();

    expect(json['formatVersion'], 1);
    expect(json['exportedAt'], '2026-08-05T16:07:09.000Z');
    expect(records.map((record) => record['id']), [4, 7, 9]);
    expect(records.first, {
      'id': 4,
      'eventType': 'urination',
      'wokeFromSleep': true,
      'timestamp': '2026-08-05T14:00:00.000Z',
      'utcOffsetMinutes': -240,
      'localDate': '2026-08-05',
      'amount': 'large',
      'urgency': 'severe',
      'leakage': 'none',
      'bristolType': null,
      'notes': 'hydrated ✓',
      'extraDetails': {'futureScale': 2, 'flag': true},
      'createdAt': '2026-08-05T14:00:00.000Z',
      'updatedAt': '2026-08-05T14:00:00.000Z',
    });
    expect(records[1]['wokeFromSleep'], isFalse);
    expect(records.last['wokeFromSleep'], isNull);
    expect(artifact.fileName, 'body_flow_and_go_export_20260805_160709.json');
    expect(artifact.mimeType, 'application/json');
  });
}

BodyEvent _event({
  required int id,
  required EventType type,
  required DateTime occurredAtUtc,
  int utcOffsetMinutes = 0,
  EventAmount? amount,
  EventUrgency? urgency,
  LeakageLevel? leakage,
  int? bristolType,
  bool? wokeFromSleep,
  String? notes,
  Map<String, Object?> extraDetails = const {},
}) {
  final instant = occurredAtUtc.toUtc();
  return BodyEvent(
    id: id,
    eventType: type,
    occurredAtUtc: instant,
    utcOffsetMinutes: utcOffsetMinutes,
    localDate: CalendarDate.fromUtcAndOffset(instant, utcOffsetMinutes),
    amount: amount,
    urgency: urgency,
    leakage: leakage,
    bristolType: bristolType,
    wokeFromSleep: wokeFromSleep,
    notes: notes,
    extraDetails: extraDetails,
    createdAtUtc: instant,
    updatedAtUtc: instant,
  );
}
