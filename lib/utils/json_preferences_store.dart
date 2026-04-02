import 'package:shared_preferences/shared_preferences.dart';

import 'json_utils.dart';

class JsonPreferencesStore {
  JsonPreferencesStore({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferencesLoader;

  Future<void> setBool(String key, bool value) async {
    final preferences = await _preferencesLoader();
    await preferences.setBool(key, value);
  }

  Future<bool?> getBool(String key) async {
    final preferences = await _preferencesLoader();
    return preferences.getBool(key);
  }

  Future<void> setString(String key, String value) async {
    final preferences = await _preferencesLoader();
    await preferences.setString(key, value);
  }

  Future<String?> getString(String key) async {
    final preferences = await _preferencesLoader();
    return preferences.getString(key);
  }

  Future<void> remove(String key) async {
    final preferences = await _preferencesLoader();
    await preferences.remove(key);
  }

  Future<void> setObject<T>(
    String key,
    T value,
    Map<String, dynamic> Function(T value) toJson,
  ) async {
    await setString(key, encodeJsonObject(toJson(value)));
  }

  Future<T?> getObject<T>(
    String key,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    final storedValue = await getString(key);
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
}
