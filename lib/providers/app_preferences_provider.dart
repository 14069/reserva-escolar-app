import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
