import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'csv_export_service.dart';
import 'pdf_export_result.dart';
import 'pdf_export_saver_stub.dart'
    if (dart.library.io) 'pdf_export_saver_io.dart'
    if (dart.library.html) 'pdf_export_saver_web.dart';

class PdfExportService {
  PdfExportService._();

  static pw.Font? _baseFont;
  static pw.Font? _boldFont;

  static Future<PdfExportResult> exportTable({
    required String filePrefix,
    required String title,
    required List<String> headers,
    required List<List<Object?>> rows,
    String? subject,
    String? shareText,
    String? subtitle,
    bool landscape = false,
  }) async {
    if (rows.isEmpty) {
      return const PdfExportResult(
        success: false,
        message: 'Não há dados para exportar no momento.',
      );
    }

    final bytes = await buildPdfBytes(
      title: title,
      headers: headers,
      rows: rows,
      subtitle: subtitle,
      landscape: landscape,
    );
    final fileName = _buildFileName(filePrefix);

    return savePdfBytes(
      bytes: bytes,
      fileName: fileName,
      title: title,
      subject: subject,
      shareText: shareText,
    );
  }

  static Future<List<int>> buildPdfBytes({
    required String title,
    required List<String> headers,
    required List<List<Object?>> rows,
    String? subtitle,
    bool landscape = false,
  }) async {
    final theme = await _loadTheme();
    final document = pw.Document();
    final generatedAt = _formatDateTime(DateTime.now());
    final pdfRows = rows
        .map(
          (row) => List<String>.generate(
            headers.length,
            (index) => index < row.length ? (row[index] ?? '').toString() : '',
          ),
        )
        .toList();

    document.addPage(
      pw.MultiPage(
        pageFormat: landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: theme,
        build: (context) => [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (subtitle != null && subtitle.trim().isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              subtitle.trim(),
              style: const pw.TextStyle(fontSize: 11),
            ),
          ],
          pw.SizedBox(height: 6),
          pw.Text(
            'Gerado em $generatedAt',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: pdfRows,
            headerStyle: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF0F766E),
            ),
            headerAlignment: pw.Alignment.centerLeft,
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 5,
            ),
            headerPadding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 7,
            ),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF5F8F7),
            ),
          ),
        ],
      ),
    );

    return document.save();
  }

  static String _buildFileName(String filePrefix) {
    final now = DateTime.now();
    final timestamp =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final sanitizedPrefix = CsvExportService.sanitizeFilePrefix(filePrefix);
    final prefix = sanitizedPrefix.isEmpty ? 'exportacao' : sanitizedPrefix;
    return '${prefix}_$timestamp.pdf';
  }

  static String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString().padLeft(4, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  static Future<pw.ThemeData> _loadTheme() async {
    if (_baseFont == null || _boldFont == null) {
      final baseFontData = await rootBundle.load(
        'assets/fonts/DejaVuSans.ttf',
      );
      final boldFontData = await rootBundle.load(
        'assets/fonts/DejaVuSans-Bold.ttf',
      );
      _baseFont = pw.Font.ttf(baseFontData);
      _boldFont = pw.Font.ttf(boldFontData);
    }

    return pw.ThemeData.withFont(base: _baseFont!, bold: _boldFont!);
  }
}
