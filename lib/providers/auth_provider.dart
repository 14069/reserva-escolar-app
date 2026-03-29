import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';

class AuthProvider extends ChangeNotifier {
  static const _sessionUserKey = 'auth_session_user';

  Logger logger = Logger();
  UserModel? _user;
  bool _isLoading = false;
  bool _isLoggingOut = false;
  bool _isRestoringSession = true;

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

  Future<bool> login({
    required String schoolCode,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.login(
        schoolCode: schoolCode,
        email: email,
        password: password,
      );

      logger.i('RESPOSTA LOGIN: $response');

      if (response['success'] == true && response['data'] != null) {
        _user = UserModel.fromJson(response['data']);
        ApiService.setAuthToken(_user!.authToken);
        await _persistSession(_user!);
        await AnalyticsService.instance.logLoginSuccess(_user!);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _user = null;
      await _clearSession();
      await AnalyticsService.instance.logLoginFailure();
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      logger.e('ERRO LOGIN: $e');
      _user = null;
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

      if (storedUser == null || storedUser.isEmpty) {
        await _clearSession(prefs: prefs);
        return;
      }

      final decoded = jsonDecode(storedUser);
      if (decoded is! Map) {
        await _clearSession(prefs: prefs);
        return;
      }

      final restoredUser = UserModel.fromJson(decoded.cast<String, dynamic>());
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
    await prefs.setString(_sessionUserKey, jsonEncode(user.toJson()));
  }

  Future<void> _clearSession({SharedPreferences? prefs}) async {
    _user = null;
    ApiService.clearAuthToken();
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    await resolvedPrefs.remove(_sessionUserKey);
  }

  bool _isTokenExpired(UserModel user) {
    final expiresAt = DateTime.tryParse(user.authTokenExpiresAt);
    if (expiresAt == null) return false;
    return !expiresAt.isAfter(DateTime.now());
  }
}
