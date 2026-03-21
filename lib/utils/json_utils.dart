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

List<Map<String, dynamic>> parseJsonObjectList(dynamic value) {
  if (value is! List) return const [];

  return value.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList();
}
