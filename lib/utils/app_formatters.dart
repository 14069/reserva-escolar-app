import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  static final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');
  static final DateFormat _shortDateFormatter = DateFormat('dd/MM');
  static final DateFormat _dateTimeFormatter = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _sessionExpiryFormatter = DateFormat(
    "dd/MM/yyyy 'as' HH:mm",
  );
  static final DateFormat _apiDateFormatter = DateFormat('yyyy-MM-dd');
  static final DateFormat _apiTimestampFormatter = DateFormat(
    'yyyy-MM-dd HH:mm:ss',
  );

  static String formatDate(DateTime value) => _dateFormatter.format(value);

  static String formatShortDate(DateTime value) =>
      _shortDateFormatter.format(value);

  static String formatDateTime(DateTime value) =>
      _dateTimeFormatter.format(value);

  static String formatApiDate(DateTime value) => _apiDateFormatter.format(value);

  static String formatApiTimestamp(DateTime value) =>
      _apiTimestampFormatter.format(value);

  static String formatDateString(
    String rawValue, {
    String emptyFallback = '',
    bool toLocal = false,
    bool assumeUtcIfNoOffset = false,
  }) {
    final parsed = _parseDateTime(
      rawValue,
      toLocal: toLocal,
      assumeUtcIfNoOffset: assumeUtcIfNoOffset,
    );
    if (parsed == null) {
      final trimmed = rawValue.trim();
      return trimmed.isEmpty ? emptyFallback : rawValue;
    }

    return formatDate(parsed);
  }

  static String formatDateTimeString(
    String rawValue, {
    String emptyFallback = '',
    bool toLocal = false,
    bool assumeUtcIfNoOffset = false,
  }) {
    final parsed = _parseDateTime(
      rawValue,
      toLocal: toLocal,
      assumeUtcIfNoOffset: assumeUtcIfNoOffset,
    );
    if (parsed == null) {
      final trimmed = rawValue.trim();
      return trimmed.isEmpty ? emptyFallback : rawValue;
    }

    return formatDateTime(parsed);
  }

  static String formatSessionExpiry(
    String rawValue, {
    String emptyFallback = 'Nao informado',
  }) {
    final parsed = _parseDateTime(
      rawValue,
      toLocal: true,
      assumeUtcIfNoOffset: false,
    );
    if (parsed == null) {
      final trimmed = rawValue.trim();
      return trimmed.isEmpty ? emptyFallback : rawValue;
    }

    return _sessionExpiryFormatter.format(parsed);
  }

  static DateTime? _parseDateTime(
    String rawValue, {
    required bool toLocal,
    required bool assumeUtcIfNoOffset,
  }) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) return null;

    final parsed = assumeUtcIfNoOffset && !_hasExplicitTimezone(trimmed)
        ? DateTime.tryParse(_normalizeUtcDateTimeString(trimmed))
        : DateTime.tryParse(trimmed);
    if (parsed == null) return null;

    return toLocal ? parsed.toLocal() : parsed;
  }

  static bool _hasExplicitTimezone(String value) {
    final upperValue = value.toUpperCase();
    if (upperValue.endsWith('Z')) return true;
    return RegExp(r'(?:[+-]\d{2}:\d{2}|[+-]\d{4})$').hasMatch(value);
  }

  static String _normalizeUtcDateTimeString(String value) {
    final normalized = value.contains(' ') ? value.replaceFirst(' ', 'T') : value;
    return '${normalized}Z';
  }
}
