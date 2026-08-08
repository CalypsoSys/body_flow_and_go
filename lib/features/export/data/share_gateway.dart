import 'dart:io';
import 'dart:ui';

import 'package:share_plus/share_plus.dart';

abstract interface class ShareGateway {
  Future<void> shareFile({
    required File file,
    required String mimeType,
    required String subject,
    Rect? sharePositionOrigin,
  });
}

class PlatformShareGateway implements ShareGateway {
  const PlatformShareGateway();

  @override
  Future<void> shareFile({
    required File file,
    required String mimeType,
    required String subject,
    Rect? sharePositionOrigin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType)],
        subject: subject,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}
