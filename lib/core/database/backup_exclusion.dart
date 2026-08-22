import 'dart:io';

import 'package:flutter/services.dart';

const _channel = MethodChannel('com.calypsosystems.golog/storage');

/// Keeps the local health database out of iCloud/device backups on iOS.
/// Other platforms retain their normal platform-specific backup behavior.
Future<void> excludeDatabaseFromBackup(String databasePath) async {
  if (!Platform.isIOS) return;
  try {
    await _channel.invokeMethod<void>('excludeDatabaseFromBackup', {
      'path': databasePath,
    });
  } on MissingPluginException {
    // Tests and unsupported platform hosts do not register the iOS channel.
  } on PlatformException {
    // A backup policy failure must not prevent the app from opening its local database.
  }
}
