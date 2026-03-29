import 'csv_export_result.dart';

Future<CsvExportResult> saveCsvBytes({
  required List<int> bytes,
  required String fileName,
  String? title,
  String? subject,
  String? shareText,
}) async {
  return const CsvExportResult(
    success: false,
    message: 'Exportação não suportada nesta plataforma.',
  );
}
