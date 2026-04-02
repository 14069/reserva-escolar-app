import 'dart:convert';

int parseJsonInt(dynamic value, {int defaultValue = 0}) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? defaultValue;
}

int? parseJsonIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value.toString());
}

String parseJsonString(dynamic value, {String defaultValue = ''}) {
  if (value == null) return defaultValue;
  final text = value.toString();
  return text == 'null' ? defaultValue : text;
}

String? parseJsonStringOrNull(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty || text == 'null') {
    return null;
  }
  return text;
}

Map<String, dynamic>? parseJsonMapOrNull(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  return null;
}

Map<String, dynamic>? decodeJsonObjectOrNull(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    final decoded = jsonDecode(value);
    return parseJsonMapOrNull(decoded);
  }

  return parseJsonMapOrNull(value);
}

List<Map<String, dynamic>> parseJsonObjectList(dynamic value) {
  if (value is! List) return const [];

  return value
      .whereType<Map>()
      .map((item) => item.cast<String, dynamic>())
      .toList();
}
