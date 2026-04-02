import '../utils/json_utils.dart';

class ApiListMeta<S> {
  const ApiListMeta({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
    required this.hasNextPage,
    this.summary,
  });

  final int page;
  final int pageSize;
  final int total;
  final int totalPages;
  final bool hasNextPage;
  final S? summary;

  factory ApiListMeta.fromJson(
    Map<String, dynamic> json, {
    S? Function(Map<String, dynamic> summary)? summaryParser,
  }) {
    final summary = parseJsonMapOrNull(json['summary']);

    return ApiListMeta<S>(
      page: parseJsonInt(json['page']),
      pageSize: parseJsonInt(json['page_size']),
      total: parseJsonInt(json['total']),
      totalPages: parseJsonInt(json['total_pages']),
      hasNextPage: json['has_next_page'] == true,
      summary: summary == null || summaryParser == null
          ? null
          : summaryParser(summary),
    );
  }
}

class ApiActionResult {
  const ApiActionResult({required this.success, this.message, this.statusCode});

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
    final rawData = parseJsonMapOrNull(json['data']);

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
    return ApiItemsResponse<T>(
      success: json['success'] == true,
      message: parseJsonStringOrNull(json['message']),
      statusCode: parseJsonIntOrNull(json['status_code']),
      items: parseJsonObjectList(json['data'])
          .map(itemParser)
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
    required this.meta,
  });

  final List<T> items;
  final ApiListMeta<S> meta;

  int get page => meta.page;
  int get pageSize => meta.pageSize;
  int get total => meta.total;
  int get totalPages => meta.totalPages;
  bool get hasNextPage => meta.hasNextPage;
  S? get summary => meta.summary;

  factory ApiListResponse.fromJson(
    Map<String, dynamic> json, {
    required T Function(Map<String, dynamic> item) itemParser,
    S? Function(Map<String, dynamic> summary)? summaryParser,
  }) {
    final metaJson = parseJsonMapOrNull(json['meta']) ?? const <String, dynamic>{};

    return ApiListResponse<T, S>(
      success: json['success'] == true,
      message: parseJsonStringOrNull(json['message']),
      statusCode: parseJsonIntOrNull(json['status_code']),
      items: parseJsonObjectList(json['data'])
          .map(itemParser)
          .toList(growable: false),
      meta: ApiListMeta<S>.fromJson(metaJson, summaryParser: summaryParser),
    );
  }
}
