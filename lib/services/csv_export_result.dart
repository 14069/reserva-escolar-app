class CsvExportResult {
  final bool success;
  final String message;
  final String? filePath;

  const CsvExportResult({
    required this.success,
    required this.message,
    this.filePath,
  });
}
