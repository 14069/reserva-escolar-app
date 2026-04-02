import '../utils/json_utils.dart';

class ApiActionResult {
  const ApiActionResult({
    required this.success,
    this.message,
    this.statusCode,
  });

  final bool success;
  final String? message;
  final int? statusCode;

  factory ApiActionResult.fromJson(Map<String, dynamic> json) {
    return ApiActionResult(
      success: json['success'] == true,
      message: parseJsonStringOrNull(json['message']),
      statusCode: parseJsonIntOrNull(json['status_code']),
    );
  }
}

class ApiDataResponse<T> extends ApiActionResult {
  const ApiDataResponse({
    required super.success,
    super.message,
    super.statusCode,
    this.data,
  });

  final T? data;

  factory ApiDataResponse.fromJson(
    Map<String, dynamic> json, {
    T? Function(Map<String, dynamic> data)? dataParser,
  }) {
    final rawData = _asJsonMap(json['data']);

    return ApiDataResponse<T>(
      success: json['success'] == true,
      message: parseJsonStringOrNull(json['message']),
      statusCode: parseJsonIntOrNull(json['status_code']),
      data: rawData == null || dataParser == null ? null : dataParser(rawData),
    );
  }
}

class ApiItemsResponse<T> extends ApiActionResult {
  const ApiItemsResponse({
    required super.success,
    super.message,
    super.statusCode,
    required this.items,
  });

  final List<T> items;

  factory ApiItemsResponse.fromJson(
    Map<String, dynamic> json, {
    required T Function(Map<String, dynamic> item) itemParser,
  }) {
    final rawItems = json['data'];

    return ApiItemsResponse<T>(
      success: json['success'] == true,
      message: parseJsonStringOrNull(json['message']),
      statusCode: parseJsonIntOrNull(json['status_code']),
      items: rawItems is! List
          ? List<T>.empty(growable: false)
          : rawItems
                .whereType<Map>()
                .map((item) => itemParser(item.cast<String, dynamic>()))
                .toList(growable: false),
    );
  }
}

class ApiListResponse<T, S> extends ApiActionResult {
  const ApiListResponse({
    required super.success,
    super.message,
    super.statusCode,
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
    required this.hasNextPage,
    this.summary,
  });

  final List<T> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;
  final bool hasNextPage;
  final S? summary;

  factory ApiListResponse.fromJson(
    Map<String, dynamic> json, {
    required T Function(Map<String, dynamic> item) itemParser,
    S? Function(Map<String, dynamic> summary)? summaryParser,
  }) {
    final meta = _asJsonMap(json['meta']) ?? const <String, dynamic>{};
    final summary = _asJsonMap(meta['summary']);
    final rawItems = json['data'];

    return ApiListResponse<T, S>(
      success: json['success'] == true,
      message: parseJsonStringOrNull(json['message']),
      statusCode: parseJsonIntOrNull(json['status_code']),
      items: rawItems is! List
          ? List<T>.empty(growable: false)
          : rawItems
                .whereType<Map>()
                .map((item) => itemParser(item.cast<String, dynamic>()))
                .toList(growable: false),
      page: parseJsonInt(meta['page']),
      pageSize: parseJsonInt(meta['page_size']),
      total: parseJsonInt(meta['total']),
      totalPages: parseJsonInt(meta['total_pages']),
      hasNextPage: meta['has_next_page'] == true,
      summary: summary == null || summaryParser == null
          ? null
          : summaryParser(summary),
    );
  }
}

Map<String, dynamic>? _asJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  return null;
}
