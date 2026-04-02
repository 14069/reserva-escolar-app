import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/json_utils.dart';

class AppPreferencesProvider extends ChangeNotifier {
  static const _confirmLogoutKey = 'confirm_logout_before_exit';
  static const _personalGreetingKey = 'prefer_personal_greeting';
  static const _themeModeKey = 'app_theme_mode';

  bool _confirmLogoutBeforeExit = true;
  bool _preferPersonalGreeting = false;
  ThemeMode _themeMode = ThemeMode.light;
  bool _isLoaded = false;

  AppPreferencesProvider() {
    _load();
  }

  bool get confirmLogoutBeforeExit => _confirmLogoutBeforeExit;
  bool get preferPersonalGreeting => _preferPersonalGreeting;
  ThemeMode get themeMode => _themeMode;
  bool get isLoaded => _isLoaded;

  Future<void> setConfirmLogoutBeforeExit(bool value) async {
    if (_confirmLogoutBeforeExit == value) return;

    _confirmLogoutBeforeExit = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_confirmLogoutKey, value);
  }

  Future<void> setPreferPersonalGreeting(bool value) async {
    if (_preferPersonalGreeting == value) return;

    _preferPersonalGreeting = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_personalGreetingKey, value);
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (_themeMode == value) return;

    _themeMode = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, value.name);
  }

  Future<void> setStringPreference(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<String?> getStringPreference(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> removePreference(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<void> setObjectPreference<T>(
    String key,
    T value,
    Map<String, dynamic> Function(T value) toJson,
  ) async {
    await setStringPreference(key, jsonEncode(toJson(value)));
  }

  Future<T?> getObjectPreference<T>(
    String key,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    final storedValue = await getStringPreference(key);
    if (storedValue == null || storedValue.trim().isEmpty) {
      return null;
    }

    try {
      final jsonMap = decodeJsonObjectOrNull(storedValue);
      if (jsonMap == null) return null;
      return fromJson(jsonMap);
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _confirmLogoutBeforeExit = prefs.getBool(_confirmLogoutKey) ?? true;
    _preferPersonalGreeting = prefs.getBool(_personalGreetingKey) ?? false;
    _themeMode = _themeModeFromString(prefs.getString(_themeModeKey));
    _isLoaded = true;
    notifyListeners();
  }

  ThemeMode _themeModeFromString(String? value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }
}
