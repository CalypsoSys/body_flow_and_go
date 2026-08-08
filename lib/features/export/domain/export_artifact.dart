import 'dart:typed_data';

class ExportArtifact {
  const ExportArtifact({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  final String fileName;
  final String mimeType;
  final Uint8List bytes;
}
