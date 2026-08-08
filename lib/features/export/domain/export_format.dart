enum ExportFormat {
  csv('csv', 'text/csv'),
  json('json', 'application/json');

  const ExportFormat(this.fileExtension, this.mimeType);

  final String fileExtension;
  final String mimeType;
}
