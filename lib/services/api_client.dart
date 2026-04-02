import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../utils/json_utils.dart';

class ApiClient {
  ApiClient({required this.baseUrl, required Logger logger}) : _logger = logger;

  final String baseUrl;
  final Logger _logger;

  String? _authToken;

  void setAuthToken(String? authToken) {
    _authToken = (authToken == null || authToken.isEmpty) ? null : authToken;
  }

  void clearAuthToken() {
    _authToken = null;
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    required String requestName,
    Map<String, dynamic>? queryParameters,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final uri = _buildUri(path, queryParameters: queryParameters);

    Future<Response<dynamic>> sendRequest() {
      return _createDio().getUri<dynamic>(
        uri,
        options: _buildOptions(timeout: timeout),
      );
    }

    try {
      final response = await sendRequest().timeout(timeout);
      return _decodeResponse(requestName, response);
    } on DioException catch (error, stackTrace) {
      if (_shouldRetry(error)) {
        _logger.w('$requestName DIO EXCEPTION, retrying once...', error: error);
        try {
          final response = await sendRequest().timeout(timeout);
          return _decodeResponse(requestName, response);
        } on DioException catch (retryError, retryStackTrace) {
          return _handleDioException(requestName, retryError, retryStackTrace);
        } on TimeoutException catch (retryError, retryStackTrace) {
          _logger.e(
            requestName,
            error: retryError,
            stackTrace: retryStackTrace,
          );
          return _failureResponse(
            'Tempo de conexão esgotado. Tente novamente.',
          );
        } catch (retryError, retryStackTrace) {
          _logger.e(
            requestName,
            error: retryError,
            stackTrace: retryStackTrace,
          );
          return _failureResponse('Não foi possível conectar ao servidor.');
        }
      }

      return _handleDioException(requestName, error, stackTrace);
    } on TimeoutException catch (error, stackTrace) {
      _logger.e(requestName, error: error, stackTrace: stackTrace);
      return _failureResponse('Tempo de conexão esgotado. Tente novamente.');
    } catch (error, stackTrace) {
      _logger.e(requestName, error: error, stackTrace: stackTrace);
      return _failureResponse('Não foi possível conectar ao servidor.');
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    required String requestName,
    required Map<String, dynamic> body,
    bool includeJsonContentType = true,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final uri = _buildUri(path);

    try {
      final response = await _createDio()
          .postUri<dynamic>(
            uri,
            data: jsonEncode(body),
            options: _buildOptions(
              timeout: timeout,
              includeJsonContentType: includeJsonContentType,
            ),
          )
          .timeout(timeout);

      return _decodeResponse(requestName, response);
    } on DioException catch (error, stackTrace) {
      return _handleDioException(requestName, error, stackTrace);
    } on TimeoutException catch (error, stackTrace) {
      _logger.e(requestName, error: error, stackTrace: stackTrace);
      return _failureResponse('Tempo de conexão esgotado. Tente novamente.');
    } catch (error, stackTrace) {
      _logger.e(requestName, error: error, stackTrace: stackTrace);
      return _failureResponse('Não foi possível conectar ao servidor.');
    }
  }

  Dio _createDio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        responseType: ResponseType.json,
        validateStatus: (_) => true,
      ),
    );
  }

  Uri _buildUri(String path, {Map<String, dynamic>? queryParameters}) {
    final uri = Uri.parse('$baseUrl/$path');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    return uri.replace(
      queryParameters: queryParameters.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  bool _shouldRetry(DioException error) {
    return error.type == DioExceptionType.connectionError ||
        (error.type == DioExceptionType.unknown &&
            error.error is SocketException);
  }

  Map<String, dynamic> _handleDioException(
    String requestName,
    DioException error,
    StackTrace stackTrace,
  ) {
    _logger.e(requestName, error: error, stackTrace: stackTrace);

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return _failureResponse('Tempo de conexão esgotado. Tente novamente.');
      case DioExceptionType.badResponse:
        try {
          if (error.response != null) {
            return _decodeResponse(requestName, error.response!);
          }
        } catch (_) {
          // Fall through to generic failure response when no response exists.
        }
        return _failureResponse('Erro do servidor. Tente novamente.');
      case DioExceptionType.cancel:
        return _failureResponse('Requisição cancelada.');
      case DioExceptionType.badCertificate:
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return _failureResponse('Não foi possível conectar ao servidor.');
    }
  }

  Options _buildOptions({
    required Duration timeout,
    bool includeJsonContentType = false,
  }) {
    final headers = <String, String>{};
    if (includeJsonContentType) {
      headers['Content-Type'] = 'application/json';
    }
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    return Options(
      headers: headers,
      sendTimeout: timeout,
      receiveTimeout: timeout,
    );
  }

  void _logResponse(String requestName, Response<dynamic> response) {
    _logger.i('$requestName STATUS: ${response.statusCode ?? 0}');
    if (kDebugMode) {
      _logger.i('$requestName BODY: ${_sanitizeResponseBody(response.data)}');
    }
  }

  Map<String, dynamic> _decodeResponse(
    String requestName,
    Response<dynamic> response,
  ) {
    _logResponse(requestName, response);

    final decodedPayload = _extractPayload(requestName, response.data);
    final statusCode = response.statusCode ?? 0;

    if (statusCode < 200 || statusCode >= 300) {
      if (decodedPayload != null) {
        return {...decodedPayload, 'success': false, 'status_code': statusCode};
      }
      return _failureResponse(
        'Erro do servidor ($statusCode). Tente novamente.',
      );
    }

    if (decodedPayload != null) {
      return decodedPayload;
    }
    return _failureResponse('Resposta inválida do servidor.');
  }

  Map<String, dynamic> _failureResponse(String message) {
    return {'success': false, 'message': message};
  }

  Map<String, dynamic>? _extractPayload(String requestName, dynamic data) {
    try {
      return decodeJsonObjectOrNull(data);
    } on FormatException catch (error, stackTrace) {
      _logger.e(
        '$requestName INVALID JSON',
        error: error,
        stackTrace: stackTrace,
      );
    }

    return null;
  }

  String _sanitizeResponseBody(dynamic data) {
    try {
      final jsonMap = parseJsonMapOrNull(data) ?? decodeJsonObjectOrNull(data);
      if (jsonMap != null) {
        final sanitized = Map<String, dynamic>.from(jsonMap);
        final payloadData = parseJsonMapOrNull(sanitized['data']);
        if (payloadData != null && payloadData.containsKey('api_token')) {
          sanitized['data'] = {...payloadData, 'api_token': '***'};
        }
        return jsonEncode(sanitized);
      }
    } catch (_) {
      // Fall back to the raw body when it is not JSON.
    }
    return data?.toString() ?? '';
  }
}
