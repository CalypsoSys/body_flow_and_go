import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golog/app/providers.dart';
import 'package:golog/core/time/calendar_date.dart';
import 'package:golog/features/events/domain/body_event.dart';
import 'package:golog/features/events/domain/event_enums.dart';
import 'package:golog/features/events/domain/event_repository.dart';
import 'package:golog/features/export/data/export_service.dart';
import 'package:golog/features/export/data/share_gateway.dart';
import 'package:golog/features/export/domain/export_encoder.dart';
import 'package:golog/features/export/domain/export_format.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory tempDirectory;
  late _RecordingShareGateway shareGateway;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'golog_export_service_test_',
    );
    shareGateway = _RecordingShareGateway();
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('writes UTF-8 bytes to the injected directory before sharing', () async {
    final instant = DateTime.utc(2026, 8, 5, 12);
    final event = BodyEvent(
      id: 1,
      eventType: EventType.urination,
      occurredAtUtc: instant,
      utcOffsetMinutes: 0,
      localDate: CalendarDate(2026, 8, 5),
      notes: 'Unicode: café ✓',
      createdAtUtc: instant,
      updatedAtUtc: instant,
    );
    final service = ExportService(
      encoder: const ExportEncoder(),
      tempDirectoryProvider: () async => tempDirectory,
      shareGateway: shareGateway,
    );
    const shareOrigin = Rect.fromLTWH(10, 20, 30, 40);

    final file = await service.exportAndShare(
      format: ExportFormat.csv,
      events: [event],
      exportedAt: DateTime.utc(2026, 8, 5, 12, 34, 56),
      sharePositionOrigin: shareOrigin,
    );

    expect(file.path, endsWith('body_flow_and_go_export_20260805_123456.csv'));
    expect(await file.exists(), isTrue);
    expect(await file.readAsString(encoding: utf8), contains('café ✓'));
    expect(shareGateway.file?.path, file.path);
    expect(shareGateway.mimeType, 'text/csv');
    expect(shareGateway.subject, 'Body Flow & Go data export');
    expect(shareGateway.sharePositionOrigin, shareOrigin);
    expect(shareGateway.fileExistedWhenShared, isTrue);
  });

  test('a new export removes older app exports only', () async {
    final oldCsv = File(
      path.join(
        tempDirectory.path,
        'body_flow_and_go_export_20260801_010203.csv',
      ),
    );
    final oldJson = File(
      path.join(
        tempDirectory.path,
        'body_flow_and_go_export_20260802_040506.json',
      ),
    );
    final unrelated = File(
      path.join(tempDirectory.path, 'other_app_export.csv'),
    );
    final similarName = File(
      path.join(
        tempDirectory.path,
        'body_flow_and_go_export_20260802_040506.json.backup',
      ),
    );
    final matchingDirectory = Directory(
      path.join(
        tempDirectory.path,
        'body_flow_and_go_export_20260803_070809.csv',
      ),
    );
    final nestedExport = File(
      path.join(
        matchingDirectory.path,
        'body_flow_and_go_export_20260803_070809.csv',
      ),
    );
    await oldCsv.writeAsString('old csv');
    await oldJson.writeAsString('old json');
    await unrelated.writeAsString('unrelated');
    await similarName.writeAsString('similar');
    await matchingDirectory.create();
    await nestedExport.writeAsString('nested');
    final service = ExportService(
      encoder: const ExportEncoder(),
      tempDirectoryProvider: () async => tempDirectory,
      shareGateway: shareGateway,
    );

    final current = await service.exportAndShare(
      format: ExportFormat.csv,
      events: const [],
      exportedAt: DateTime.utc(2026, 8, 5, 12, 34, 56),
    );

    expect(await oldCsv.exists(), isFalse);
    expect(await oldJson.exists(), isFalse);
    expect(await current.exists(), isTrue);
    expect(await unrelated.exists(), isTrue);
    expect(await similarName.exists(), isTrue);
    expect(await matchingDirectory.exists(), isTrue);
    expect(await nestedExport.exists(), isTrue);
  });

  test('clearCachedExports removes only exact app export files', () async {
    final csv = File(
      path.join(
        tempDirectory.path,
        'body_flow_and_go_export_20260801_010203.csv',
      ),
    );
    final json = File(
      path.join(
        tempDirectory.path,
        'body_flow_and_go_export_20260802_040506.json',
      ),
    );
    final wrongExtension = File(
      path.join(
        tempDirectory.path,
        'body_flow_and_go_export_20260802_040506.txt',
      ),
    );
    final unrelated = File(path.join(tempDirectory.path, 'notes.txt'));
    await csv.writeAsString('csv');
    await json.writeAsString('json');
    await wrongExtension.writeAsString('wrong extension');
    await unrelated.writeAsString('unrelated');
    final service = ExportService(
      encoder: const ExportEncoder(),
      tempDirectoryProvider: () async => tempDirectory,
      shareGateway: shareGateway,
    );

    await service.clearCachedExports();

    expect(await csv.exists(), isFalse);
    expect(await json.exists(), isFalse);
    expect(await wrongExtension.exists(), isTrue);
    expect(await unrelated.exists(), isTrue);
  });

  test('delete-all mutation clears cached exports and event records', () async {
    final cachedExport = File(
      path.join(
        tempDirectory.path,
        'body_flow_and_go_export_20260801_010203.csv',
      ),
    );
    final unrelated = File(path.join(tempDirectory.path, 'keep-me.txt'));
    await cachedExport.writeAsString('health data');
    await unrelated.writeAsString('unrelated');
    final repository = _DeleteAllRecordingRepository();
    final service = ExportService(
      encoder: const ExportEncoder(),
      tempDirectoryProvider: () async => tempDirectory,
      shareGateway: shareGateway,
    );
    final container = ProviderContainer(
      overrides: [
        eventRepositoryProvider.overrideWithValue(repository),
        exportServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(eventMutationsProvider).deleteAll();

    expect(result, DeleteAllEventsResult.complete);
    expect(repository.deleteAllCalled, isTrue);
    expect(await cachedExport.exists(), isFalse);
    expect(await unrelated.exists(), isTrue);
    expect(container.read(eventRevisionProvider), 1);
  });

  test('cache failure does not prevent delete-all event deletion', () async {
    final repository = _DeleteAllRecordingRepository();
    final service = ExportService(
      encoder: const ExportEncoder(),
      tempDirectoryProvider: () => throw StateError('cache unavailable'),
      shareGateway: shareGateway,
    );
    final container = ProviderContainer(
      overrides: [
        eventRepositoryProvider.overrideWithValue(repository),
        exportServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(eventMutationsProvider).deleteAll();

    expect(result, DeleteAllEventsResult.cachedExportCleanupFailed);
    expect(repository.deleteAllCalled, isTrue);
    expect(container.read(eventRevisionProvider), 1);
  });
}

class _RecordingShareGateway implements ShareGateway {
  File? file;
  String? mimeType;
  String? subject;
  Rect? sharePositionOrigin;
  bool fileExistedWhenShared = false;

  @override
  Future<void> shareFile({
    required File file,
    required String mimeType,
    required String subject,
    Rect? sharePositionOrigin,
  }) async {
    this.file = file;
    this.mimeType = mimeType;
    this.subject = subject;
    this.sharePositionOrigin = sharePositionOrigin;
    fileExistedWhenShared = await file.exists();
  }
}

class _DeleteAllRecordingRepository implements EventRepository {
  bool deleteAllCalled = false;

  @override
  Future<void> deleteAll() async {
    deleteAllCalled = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
