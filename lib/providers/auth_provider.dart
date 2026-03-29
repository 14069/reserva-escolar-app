import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';

class AuthProvider extends ChangeNotifier {
  Logger logger = Logger();
  UserModel? _user;
  bool _isLoading = false;
  bool _isLoggingOut = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggingOut => _isLoggingOut;
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
        await AnalyticsService.instance.logLoginSuccess(_user!);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _user = null;
      ApiService.clearAuthToken();
      await AnalyticsService.instance.logLoginFailure();
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      logger.e('ERRO LOGIN: $e');
      _user = null;
      ApiService.clearAuthToken();
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
    } finally {
      _isLoggingOut = false;
    }

    await AnalyticsService.instance.logLogout();
    _user = null;
    ApiService.clearAuthToken();
    notifyListeners();
  }
}
