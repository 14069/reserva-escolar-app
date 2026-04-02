import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class ApiClient {
  ApiClient({
    required this.baseUrl,
    required Logger logger,
  }) : _logger = logger;

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
    Future<http.Response> sendRequest() {
      return http.get(
        _buildUri(path, queryParameters: queryParameters),
        headers: _buildHeaders(),
      );
    }

    try {
      final response = await sendRequest().timeout(timeout);
      return _decodeResponse(requestName, response);
    } on TimeoutException catch (error, stackTrace) {
      _logger.e(requestName, error: error, stackTrace: stackTrace);
      return _failureResponse('Tempo de conexão esgotado. Tente novamente.');
    } on http.ClientException catch (error) {
      _logger.w('$requestName CLIENT EXCEPTION, retrying once...', error: error);
      try {
        final response = await sendRequest().timeout(timeout);
        return _decodeResponse(requestName, response);
      } on TimeoutException catch (retryError, retryStackTrace) {
        _logger.e(requestName, error: retryError, stackTrace: retryStackTrace);
        return _failureResponse('Tempo de conexão esgotado. Tente novamente.');
      } catch (retryError, retryStackTrace) {
        _logger.e(requestName, error: retryError, stackTrace: retryStackTrace);
        return _failureResponse('Não foi possível conectar ao servidor.');
      }
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
    try {
      final response = await http
          .post(
            _buildUri(path),
            headers: _buildHeaders(
              includeJsonContentType: includeJsonContentType,
            ),
            body: jsonEncode(body),
          )
          .timeout(timeout);

      return _decodeResponse(requestName, response);
    } on TimeoutException catch (error, stackTrace) {
      _logger.e(requestName, error: error, stackTrace: stackTrace);
      return _failureResponse('Tempo de conexão esgotado. Tente novamente.');
    } catch (error, stackTrace) {
      _logger.e(requestName, error: error, stackTrace: stackTrace);
      return _failureResponse('Não foi possível conectar ao servidor.');
    }
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

  Map<String, String> _buildHeaders({bool includeJsonContentType = false}) {
    final headers = <String, String>{};
    if (includeJsonContentType) {
      headers['Content-Type'] = 'application/json';
    }
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  void _logResponse(String requestName, http.Response response) {
    _logger.i('$requestName STATUS: ${response.statusCode}');
    if (kDebugMode) {
      _logger.i('$requestName BODY: ${_sanitizeResponseBody(response.body)}');
    }
  }

  Map<String, dynamic> _decodeResponse(
    String requestName,
    http.Response response,
  ) {
    _logResponse(requestName, response);

    Map<String, dynamic>? decodedPayload;

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        decodedPayload = decoded;
      } else if (decoded is Map) {
        decodedPayload = decoded.cast<String, dynamic>();
      }
    } on FormatException catch (error, stackTrace) {
      _logger.e(
        '$requestName INVALID JSON',
        error: error,
        stackTrace: stackTrace,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (decodedPayload != null) {
        return {
          ...decodedPayload,
          'success': false,
          'status_code': response.statusCode,
        };
      }
      return _failureResponse(
        'Erro do servidor (${response.statusCode}). Tente novamente.',
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

  String _sanitizeResponseBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final sanitized = Map<String, dynamic>.from(decoded);
        final data = sanitized['data'];
        if (data is Map<String, dynamic> && data.containsKey('api_token')) {
          sanitized['data'] = {...data, 'api_token': '***'};
        }
        return jsonEncode(sanitized);
      }
    } catch (_) {
      // Fall back to the raw body when it is not JSON.
    }
    return body;
  }
}
