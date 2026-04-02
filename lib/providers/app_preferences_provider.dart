import 'package:flutter/material.dart';

import '../utils/json_preferences_store.dart';

class AppPreferencesProvider extends ChangeNotifier {
  static const _confirmLogoutKey = 'confirm_logout_before_exit';
  static const _personalGreetingKey = 'prefer_personal_greeting';
  static const _themeModeKey = 'app_theme_mode';

  bool _confirmLogoutBeforeExit = true;
  bool _preferPersonalGreeting = false;
  ThemeMode _themeMode = ThemeMode.light;
  bool _isLoaded = false;
  final JsonPreferencesStore _preferencesStore = JsonPreferencesStore();

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

    await _preferencesStore.setBool(_confirmLogoutKey, value);
  }

  Future<void> setPreferPersonalGreeting(bool value) async {
    if (_preferPersonalGreeting == value) return;

    _preferPersonalGreeting = value;
    notifyListeners();

    await _preferencesStore.setBool(_personalGreetingKey, value);
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (_themeMode == value) return;

    _themeMode = value;
    notifyListeners();

    await _preferencesStore.setString(_themeModeKey, value.name);
  }

  Future<void> setStringPreference(String key, String value) async {
    await _preferencesStore.setString(key, value);
  }

  Future<String?> getStringPreference(String key) async {
    return _preferencesStore.getString(key);
  }

  Future<void> removePreference(String key) async {
    await _preferencesStore.remove(key);
  }

  Future<void> setObjectPreference<T>(
    String key,
    T value,
    Map<String, dynamic> Function(T value) toJson,
  ) async {
    await _preferencesStore.setObject(key, value, toJson);
  }

  Future<T?> getObjectPreference<T>(
    String key,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    return _preferencesStore.getObject(key, fromJson);
  }

  Future<void> _load() async {
    _confirmLogoutBeforeExit =
        await _preferencesStore.getBool(_confirmLogoutKey) ?? true;
    _preferPersonalGreeting =
        await _preferencesStore.getBool(_personalGreetingKey) ?? false;
    _themeMode = _themeModeFromString(
      await _preferencesStore.getString(_themeModeKey),
    );
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
