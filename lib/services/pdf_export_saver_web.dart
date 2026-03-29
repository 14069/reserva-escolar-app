import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'pdf_export_result.dart';

Future<PdfExportResult> savePdfBytes({
  required List<int> bytes,
  required String fileName,
  String? title,
  String? subject,
  String? shareText,
}) async {
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(Uint8List.fromList(bytes), mimeType: 'application/pdf'),
        ],
        fileNameOverrides: [fileName],
        title: title,
        subject: subject,
        text: shareText,
        downloadFallbackEnabled: true,
      ),
    );

    return const PdfExportResult(
      success: true,
      message: 'Exportação iniciada. O arquivo PDF foi enviado para download.',
    );
  } catch (error) {
    return PdfExportResult(
      success: false,
      message: 'Não foi possível exportar o arquivo PDF: $error',
    );
  }
}
