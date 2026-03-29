import 'dart:io';

import 'package:path_provider/path_provider.dart';
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
    final directory = await _resolveExportDirectory();
    final path = '${directory.path}${Platform.pathSeparator}$fileName';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);

    if (!Platform.isLinux) {
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            title: title,
            subject: subject,
            text: shareText,
          ),
        );
      } catch (_) {
        // Mantém a exportação válida mesmo se a plataforma não abrir o compartilhamento.
      }
    }

    return PdfExportResult(
      success: true,
      message: 'Arquivo PDF salvo em $path',
      filePath: path,
    );
  } catch (error) {
    return PdfExportResult(
      success: false,
      message: 'Não foi possível exportar o arquivo PDF: $error',
    );
  }
}

Future<Directory> _resolveExportDirectory() async {
  final downloadsDirectory = await getDownloadsDirectory();
  if (downloadsDirectory != null) {
    return downloadsDirectory;
  }

  try {
    return await getApplicationDocumentsDirectory();
  } catch (_) {
    return getTemporaryDirectory();
  }
}
