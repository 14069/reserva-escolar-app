import 'dart:convert';

import 'csv_export_result.dart';
import 'csv_export_saver_stub.dart'
    if (dart.library.io) 'csv_export_saver_io.dart'
    if (dart.library.html) 'csv_export_saver_web.dart';

class CsvExportService {
  CsvExportService._();

  static Future<CsvExportResult> exportRows({
    required String filePrefix,
    required List<String> headers,
    required List<List<Object?>> rows,
    String? title,
    String? subject,
    String? shareText,
    String? subtitle,
    List<String>? contextLines,
    List<List<Object?>>? summaryRows,
  }) async {
    if (rows.isEmpty) {
      return const CsvExportResult(
        success: false,
        message: 'Não há dados para exportar no momento.',
      );
    }

    final fileName = _buildFileName(filePrefix);
    final csv = buildCsv(
      headers: headers,
      rows: rows,
      title: title,
      subtitle: subtitle,
      contextLines: contextLines,
      summaryRows: summaryRows,
    );
    final bytes = utf8.encode('\uFEFF$csv');

    return saveCsvBytes(
      bytes: bytes,
      fileName: fileName,
      title: title,
      subject: subject,
      shareText: shareText,
    );
  }

  static String buildCsv({
    required List<String> headers,
    required List<List<Object?>> rows,
    String? title,
    String? subtitle,
    List<String>? contextLines,
    List<List<Object?>>? summaryRows,
  }) {
    final normalizedContextLines = contextLines
        ?.map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final normalizedSummaryRows = summaryRows
        ?.where(
          (row) => row.any((cell) => cell != null && '$cell'.trim().isNotEmpty),
        )
        .toList(growable: false);

    final lines = <String>[_joinCells(headers), ...rows.map(_joinCells)];

    final appendixRows = <List<Object?>>[];
    final trimmedTitle = title?.trim() ?? '';
    final trimmedSubtitle = subtitle?.trim() ?? '';

    if (trimmedTitle.isNotEmpty) {
      appendixRows.add(['Documento', trimmedTitle]);
    }
    if (trimmedSubtitle.isNotEmpty) {
      appendixRows.add(['Recorte', trimmedSubtitle]);
    }
    if (normalizedContextLines != null && normalizedContextLines.isNotEmpty) {
      appendixRows.add(const ['Contexto da exportação', '']);
      appendixRows.addAll(
        normalizedContextLines.map((line) => ['Contexto', line]),
      );
    }
    if (normalizedSummaryRows != null && normalizedSummaryRows.isNotEmpty) {
      appendixRows.add(const ['Resumo executivo', '']);
      appendixRows.addAll(normalizedSummaryRows);
    }

    if (appendixRows.isNotEmpty) {
      lines.add('');
      lines.addAll(appendixRows.map(_joinCells));
    }

    return lines.join('\r\n');
  }

  static String sanitizeFilePrefix(String value) {
    final normalized = value.trim().toLowerCase();
    final replaced = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final sanitized = replaced.replaceAll(RegExp(r'_+'), '_');
    return sanitized.replaceAll(RegExp(r'^_|_$'), '');
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
    final sanitizedPrefix = sanitizeFilePrefix(filePrefix);
    final prefix = sanitizedPrefix.isEmpty ? 'exportacao' : sanitizedPrefix;
    return '${prefix}_$timestamp.csv';
  }

  static String _escapeCell(Object? value) {
    final text = (value ?? '').toString();
    final escaped = text.replaceAll('"', '""');
    final needsQuotes =
        escaped.contains(';') ||
        escaped.contains('"') ||
        escaped.contains('\n') ||
        escaped.contains('\r');

    if (needsQuotes) {
      return '"$escaped"';
    }

    return escaped;
  }

  static String _joinCells(List<Object?> row) {
    return row.map(_escapeCell).join(';');
  }
}
