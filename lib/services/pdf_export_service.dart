import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'csv_export_service.dart';
import 'pdf_export_result.dart';
import 'pdf_export_saver_stub.dart'
    if (dart.library.io) 'pdf_export_saver_io.dart'
    if (dart.library.html) 'pdf_export_saver_web.dart';
import '../utils/app_formatters.dart';

class PdfExportSummaryStat {
  const PdfExportSummaryStat({
    required this.label,
    required this.value,
    this.accentColor = const PdfColor.fromInt(0xFF0F766E),
  });

  final String label;
  final String value;
  final PdfColor accentColor;
}

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
    List<String>? contextLines,
    List<PdfExportSummaryStat>? summaryStats,
    List<double>? columnFlexes,
    String? footerNote,
    bool landscape = true,
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
      contextLines: contextLines,
      summaryStats: summaryStats,
      columnFlexes: columnFlexes,
      footerNote: footerNote,
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
    List<String>? contextLines,
    List<PdfExportSummaryStat>? summaryStats,
    List<double>? columnFlexes,
    String? footerNote,
    bool landscape = true,
  }) async {
    final theme = await _loadTheme();
    final document = pw.Document();
    final generatedAt = AppFormatters.formatDateTime(DateTime.now());
    final normalizedContextLines = contextLines
        ?.map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final normalizedSummaryStats = summaryStats
        ?.where(
          (stat) =>
              stat.label.trim().isNotEmpty && stat.value.trim().isNotEmpty,
        )
        .toList(growable: false);
    final normalizedFooterNote = footerNote?.trim();
    final pdfRows = rows
        .map(
          (row) => List<String>.generate(
            headers.length,
            (index) => index < row.length ? (row[index] ?? '').toString() : '',
          ),
        )
        .toList();
    final compactTable = headers.length >= 10;
    final denseTable = headers.length >= 12;
    final headerFontSize = denseTable
        ? 8.0
        : compactTable
        ? 8.8
        : 10.0;
    final cellFontSize = denseTable
        ? 7.3
        : compactTable
        ? 8.0
        : 9.0;
    final cellPadding = pw.EdgeInsets.symmetric(
      horizontal: denseTable ? 4 : 6,
      vertical: denseTable ? 4 : 5,
    );
    final resolvedColumnWidths =
        columnFlexes != null && columnFlexes.length == headers.length
        ? <int, pw.TableColumnWidth>{
            for (var index = 0; index < columnFlexes.length; index += 1)
              index: pw.FlexColumnWidth(columnFlexes[index]),
          }
        : null;

    document.addPage(
      pw.MultiPage(
        pageFormat: landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: theme,
        footer: (context) => _buildFooter(
          pageNumber: context.pageNumber,
          pagesCount: context.pagesCount,
          footerNote: normalizedFooterNote,
        ),
        build: (context) => [
          _buildHeaderCard(
            title: title,
            subtitle: subtitle,
            generatedAt: generatedAt,
          ),
          if (normalizedContextLines != null &&
              normalizedContextLines.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _buildContextSection(normalizedContextLines),
          ],
          if (normalizedSummaryStats != null &&
              normalizedSummaryStats.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _buildSummarySection(normalizedSummaryStats),
          ],
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFEAF5F3),
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'Registros exportados',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF0F4C47),
                    ),
                  ),
                ),
                pw.Text(
                  '${pdfRows.length}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF0F766E),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: pdfRows,
            columnWidths: resolvedColumnWidths,
            headerStyle: pw.TextStyle(
              fontSize: headerFontSize,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            cellStyle: pw.TextStyle(
              fontSize: cellFontSize,
              color: const PdfColor.fromInt(0xFF102A2A),
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF0F766E),
            ),
            headerAlignment: pw.Alignment.centerLeft,
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: cellPadding,
            headerPadding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 7,
            ),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF5F8F7),
            ),
            rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
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

  static pw.Widget _buildHeaderCard({
    required String title,
    String? subtitle,
    required String generatedAt,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(18),
      decoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF4FBF9),
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(16)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 68,
            height: 5,
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF0F766E),
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(99)),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          if (subtitle != null && subtitle.trim().isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              subtitle.trim(),
              style: const pw.TextStyle(
                fontSize: 11,
                color: PdfColor.fromInt(0xFF355B5B),
              ),
            ),
          ],
          pw.SizedBox(height: 8),
          pw.Text(
            'Gerado em $generatedAt',
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColor.fromInt(0xFF5F6B6B),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildContextSection(List<String> contextLines) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFD7E7E4)),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Contexto da exportação',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: contextLines
                .map(
                  (line) => pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFF6FAF9),
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(99)),
                    ),
                    child: pw.Text(
                      line,
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColor.fromInt(0xFF234444),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummarySection(
    List<PdfExportSummaryStat> summaryStats,
  ) {
    const itemsPerRow = 3;
    const spacing = 10.0;

    final rows = <List<PdfExportSummaryStat>>[];
    for (var i = 0; i < summaryStats.length; i += itemsPerRow) {
      final end = (i + itemsPerRow < summaryStats.length)
          ? i + itemsPerRow
          : summaryStats.length;
      rows.add(summaryStats.sublist(i, end));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Resumo executivo',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) pw.SizedBox(height: spacing),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (var j = 0; j < rows[i].length; j++) ...[
                if (j > 0) pw.SizedBox(width: spacing),
                _buildSummaryStatCard(rows[i][j]),
              ],
            ],
          ),
        ],
      ],
    );
  }

  static pw.Widget _buildSummaryStatCard(PdfExportSummaryStat stat) {
    return pw.Container(
      width: 148,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8FBFA),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFD7E7E4)),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 22,
            height: 4,
            decoration: pw.BoxDecoration(
              color: stat.accentColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(99)),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            stat.value,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: stat.accentColor,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            stat.label,
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColor.fromInt(0xFF436060),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter({
    required int pageNumber,
    required int pagesCount,
    String? footerNote,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              footerNote != null && footerNote.isNotEmpty
                  ? footerNote
                  : 'Documento gerado automaticamente pelo Reserva Escolar.',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColor.fromInt(0xFF6B7B7B),
              ),
            ),
          ),
          pw.Text(
            'Página $pageNumber de $pagesCount',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColor.fromInt(0xFF6B7B7B),
            ),
          ),
        ],
      ),
    );
  }

  static Future<pw.ThemeData> _loadTheme() async {
    if (_baseFont == null || _boldFont == null) {
      final baseFontData = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
      final boldFontData = await rootBundle.load(
        'assets/fonts/DejaVuSans-Bold.ttf',
      );
      _baseFont = pw.Font.ttf(baseFontData);
      _boldFont = pw.Font.ttf(boldFontData);
    }

    return pw.ThemeData.withFont(base: _baseFont!, bold: _boldFont!);
  }
}
