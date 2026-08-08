import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../events/domain/body_event.dart';
import '../domain/export_encoder.dart';
import '../domain/export_format.dart';
import 'share_gateway.dart';

typedef TempDirectoryProvider = Future<Directory> Function();

class ExportService {
  const ExportService({
    required this.encoder,
    required this.tempDirectoryProvider,
    required this.shareGateway,
  });

  factory ExportService.platform() => ExportService(
    encoder: const ExportEncoder(),
    tempDirectoryProvider: getTemporaryDirectory,
    shareGateway: const PlatformShareGateway(),
  );

  final ExportEncoder encoder;
  final TempDirectoryProvider tempDirectoryProvider;
  final ShareGateway shareGateway;

  static final RegExp _cachedExportFileName = RegExp(
    r'^body_flow_and_go_export_\d{8}_\d{6}\.(?:csv|json)$',
  );

  Future<File> exportAndShare({
    required ExportFormat format,
    required List<BodyEvent> events,
    required DateTime exportedAt,
    Rect? sharePositionOrigin,
  }) async {
    final artifact = encoder.encode(
      format: format,
      events: events,
      exportedAt: exportedAt,
    );
    final directory = await tempDirectoryProvider();
    await directory.create(recursive: true);
    await _clearCachedExportsIn(directory);
    final file = File(path.join(directory.path, artifact.fileName));
    await file.writeAsBytes(artifact.bytes, flush: true);
    await shareGateway.shareFile(
      file: file,
      mimeType: artifact.mimeType,
      subject: 'Body Flow & Go data export',
      sharePositionOrigin: sharePositionOrigin,
    );
    return file;
  }

  /// Removes only export files created by Body Flow & Go from its temporary
  /// directory. Files that the user shared or saved elsewhere are untouched.
  Future<void> clearCachedExports() async {
    final directory = await tempDirectoryProvider();
    if (!await directory.exists()) return;
    await _clearCachedExportsIn(directory);
  }

  Future<void> _clearCachedExportsIn(Directory directory) async {
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      if (!_cachedExportFileName.hasMatch(path.basename(entity.path))) continue;
      await entity.delete();
    }
  }
}
