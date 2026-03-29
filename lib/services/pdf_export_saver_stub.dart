import 'pdf_export_result.dart';

Future<PdfExportResult> savePdfBytes({
  required List<int> bytes,
  required String fileName,
  String? title,
  String? subject,
  String? shareText,
}) async {
  return const PdfExportResult(
    success: false,
    message: 'Exportação não suportada nesta plataforma.',
  );
}
