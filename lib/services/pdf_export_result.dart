class PdfExportResult {
  final bool success;
  final String message;
  final String? filePath;

  const PdfExportResult({
    required this.success,
    required this.message,
    this.filePath,
  });
}
