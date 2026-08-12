import 'dart:convert';
import 'dart:typed_data';

import '../../events/domain/body_event.dart';
import 'export_artifact.dart';
import 'export_format.dart';

class ExportEncoder {
  const ExportEncoder();

  static const csvColumns = <String>[
    'Date',
    'Time',
    'Event type',
    'Woke from sleep',
    'Amount',
    'Urgency',
    'Leakage',
    'Bristol type',
    'Notes',
  ];

  ExportArtifact encode({
    required ExportFormat format,
    required List<BodyEvent> events,
    required DateTime exportedAt,
  }) {
    final sortedEvents = [...events]..sort(_compareEvents);
    final content = switch (format) {
      ExportFormat.csv => _encodeCsv(sortedEvents),
      ExportFormat.json => _encodeJson(sortedEvents, exportedAt),
    };

    return ExportArtifact(
      fileName: _fileName(format, exportedAt),
      mimeType: format.mimeType,
      bytes: Uint8List.fromList(utf8.encode(content)),
    );
  }

  String _encodeCsv(List<BodyEvent> events) {
    final rows = <List<String>>[
      csvColumns,
      for (final event in events)
        [
          event.localDate.format(),
          _formatRecordedTime(event),
          event.eventType.storageValue,
          _formatSleepContext(event),
          event.amount?.storageValue ?? '',
          event.urgency?.storageValue ?? '',
          event.leakage?.storageValue ?? '',
          event.bristolType?.toString() ?? '',
          event.notes ?? '',
        ],
    ];

    return '${rows.map(_encodeCsvRow).join('\r\n')}\r\n';
  }

  String _encodeJson(List<BodyEvent> events, DateTime exportedAt) {
    final envelope = <String, Object?>{
      'formatVersion': 1,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'records': [for (final event in events) _jsonRecord(event)],
    };
    return '${const JsonEncoder.withIndent('  ').convert(envelope)}\n';
  }

  Map<String, Object?> _jsonRecord(BodyEvent event) => <String, Object?>{
    'id': event.id,
    'eventType': event.eventType.storageValue,
    'wokeFromSleep': event.wokeFromSleep,
    'wokeFromNap': event.wokeFromNap,
    'timestamp': event.occurredAtUtc.toUtc().toIso8601String(),
    'utcOffsetMinutes': event.utcOffsetMinutes,
    'localDate': event.localDate.format(),
    'amount': event.amount?.storageValue,
    'urgency': event.urgency?.storageValue,
    'leakage': event.leakage?.storageValue,
    'bristolType': event.bristolType,
    'notes': event.notes,
    'extraDetails': event.extraDetails,
    'createdAt': event.createdAtUtc.toUtc().toIso8601String(),
    'updatedAt': event.updatedAtUtc.toUtc().toIso8601String(),
  };

  String _encodeCsvRow(List<String> values) =>
      values.map(_escapeCsvField).join(',');

  String _formatWokeFromSleep(bool? wokeFromSleep) => switch (wokeFromSleep) {
    true => 'yes',
    false => 'no',
    null => '',
  };

  String _formatSleepContext(BodyEvent event) {
    if (event.wokeFromNap == true) return 'nap';
    return _formatWokeFromSleep(event.wokeFromSleep);
  }

  String _escapeCsvField(String value) {
    if (!value.contains(RegExp(r'[,"\r\n]'))) {
      return value;
    }
    return '"${value.replaceAll('"', '""')}"';
  }

  String _formatRecordedTime(BodyEvent event) {
    final wallTime = event.recordedLocalDateTime;
    return '${_twoDigits(wallTime.hour)}:${_twoDigits(wallTime.minute)}:'
        '${_twoDigits(wallTime.second)}${_formatOffset(event.utcOffsetMinutes)}';
  }

  String _formatOffset(int totalMinutes) {
    final sign = totalMinutes < 0 ? '-' : '+';
    final absoluteMinutes = totalMinutes.abs();
    return '$sign${_twoDigits(absoluteMinutes ~/ 60)}:'
        '${_twoDigits(absoluteMinutes % 60)}';
  }

  String _fileName(ExportFormat format, DateTime exportedAt) {
    final timestamp = exportedAt.toUtc();
    final date =
        '${timestamp.year.toString().padLeft(4, '0')}'
        '${_twoDigits(timestamp.month)}${_twoDigits(timestamp.day)}';
    final time =
        '${_twoDigits(timestamp.hour)}${_twoDigits(timestamp.minute)}'
        '${_twoDigits(timestamp.second)}';
    return 'body_flow_and_go_export_${date}_$time.${format.fileExtension}';
  }

  int _compareEvents(BodyEvent left, BodyEvent right) {
    final instantComparison = left.occurredAtUtc.compareTo(right.occurredAtUtc);
    return instantComparison != 0
        ? instantComparison
        : left.id.compareTo(right.id);
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
