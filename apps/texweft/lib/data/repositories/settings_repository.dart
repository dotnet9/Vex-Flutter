import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SettingsRepository {
  Future<Map<String, Object?>> load();
  Future<void> save(Map<String, Object?> value);
}

final class NativeSettingsRepository implements SettingsRepository {
  final _preferences = SharedPreferencesAsync();
  Future<void> _pending = Future.value();
  @override
  Future<Map<String, Object?>> load() async {
    final raw = await _preferences.getString('workspace-v1');
    if (raw == null) return {};
    try {
      return Map<String, Object?>.from(jsonDecode(raw) as Map);
    } on FormatException {
      return {};
    }
  }

  @override
  Future<void> save(Map<String, Object?> value) {
    final snapshot = jsonEncode(value);
    return _pending = _pending
        .catchError((Object _) {})
        .then((_) => _preferences.setString('workspace-v1', snapshot));
  }
}
