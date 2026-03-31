import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';

class AuthProvider extends ChangeNotifier {
  static const _sessionUserKey = 'auth_session_user';
  static const _sessionTokenKey = 'auth_session_token';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Logger logger = Logger();
  UserModel? _user;
  bool _isLoading = false;
  bool _isLoggingOut = false;
  bool _isRestoringSession = true;
  String? _lastErrorMessage;

  AuthProvider({bool restoreSessionOnInit = true}) {
    if (restoreSessionOnInit) {
      unawaited(_restoreSession());
    } else {
      _isRestoringSession = false;
    }
  }

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggingOut => _isLoggingOut;
  bool get isRestoringSession => _isRestoringSession;
  bool get isAuthenticated => _user != null;
  String? get lastErrorMessage => _lastErrorMessage;

  Future<bool> login({
    required String schoolCode,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _lastErrorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.login(
        schoolCode: schoolCode,
        email: email,
        password: password,
      );

      if (response['success'] == true && response['data'] != null) {
        _user = UserModel.fromJson(response['data']);
        ApiService.setAuthToken(_user!.authToken);
        await _persistSession(_user!);
        await AnalyticsService.instance.logLoginSuccess(_user!);
        logger.i('LOGIN OK: user_id=${_user!.id}, role=${_user!.role}');
        _isLoading = false;
        _lastErrorMessage = null;
        notifyListeners();
        return true;
      }

      _user = null;
      _lastErrorMessage =
          (response['message'] as String?)?.trim().isNotEmpty == true
          ? (response['message'] as String).trim()
          : 'Falha no login. Verifique código da escola, email e senha.';
      await _clearSession();
      await AnalyticsService.instance.logLoginFailure();
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      logger.e('ERRO LOGIN: $e');
      _user = null;
      _lastErrorMessage = 'Não foi possível entrar agora. Tente novamente.';
      await _clearSession();
      await AnalyticsService.instance.logLoginFailure();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    if (_isLoggingOut) return;

    _isLoggingOut = true;
    notifyListeners();

    try {
      await ApiService.logout();
    } catch (e) {
      logger.w('ERRO LOGOUT: $e');
    }

    await AnalyticsService.instance.logLogout();
    await _clearSession();
    _isLoggingOut = false;
    notifyListeners();
  }

  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUser = prefs.getString(_sessionUserKey);
      final storedToken = await _secureStorage.read(key: _sessionTokenKey);

      if (storedUser == null ||
          storedUser.isEmpty ||
          storedToken == null ||
          storedToken.isEmpty) {
        await _clearSession(prefs: prefs);
        return;
      }

      final decoded = jsonDecode(storedUser);
      if (decoded is! Map) {
        await _clearSession(prefs: prefs);
        return;
      }

      final restoredUser = UserModel.fromJson(
        decoded.cast<String, dynamic>(),
      ).copyWith(authToken: storedToken);
      if (restoredUser.authToken.isEmpty || _isTokenExpired(restoredUser)) {
        await _clearSession(prefs: prefs);
        return;
      }

      _user = restoredUser;
      ApiService.setAuthToken(restoredUser.authToken);
    } catch (error, stackTrace) {
      logger.e(
        'ERRO AO RESTAURAR SESSAO',
        error: error,
        stackTrace: stackTrace,
      );
      await _clearSession();
    } finally {
      _isRestoringSession = false;
      notifyListeners();
    }
  }

  Future<void> _persistSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final sanitizedUser = Map<String, dynamic>.from(user.toJson())
      ..remove('api_token');
    await prefs.setString(_sessionUserKey, jsonEncode(sanitizedUser));
    await _secureStorage.write(key: _sessionTokenKey, value: user.authToken);
  }

  Future<void> _clearSession({SharedPreferences? prefs}) async {
    _user = null;
    ApiService.clearAuthToken();
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    await resolvedPrefs.remove(_sessionUserKey);
    await _secureStorage.delete(key: _sessionTokenKey);
  }

  bool _isTokenExpired(UserModel user) {
    final expiresAt = DateTime.tryParse(user.authTokenExpiresAt);
    if (expiresAt == null) return false;
    return !expiresAt.isAfter(DateTime.now());
  }
}
