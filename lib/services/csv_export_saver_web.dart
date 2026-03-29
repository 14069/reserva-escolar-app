import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'csv_export_result.dart';

Future<CsvExportResult> saveCsvBytes({
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
          XFile.fromData(Uint8List.fromList(bytes), mimeType: 'text/csv'),
        ],
        fileNameOverrides: [fileName],
        title: title,
        subject: subject,
        text: shareText,
        downloadFallbackEnabled: true,
      ),
    );

    return const CsvExportResult(
      success: true,
      message: 'Exportação iniciada. O arquivo CSV foi enviado para download.',
    );
  } catch (error) {
    return CsvExportResult(
      success: false,
      message: 'Não foi possível exportar o arquivo CSV: $error',
    );
  }
}
