import 'dart:convert';

import '../domain/app_settings.dart';
import '../domain/settings_repository.dart';
import 'settings_store.dart';

/// Stores all settings as one versioned JSON document.
class LocalSettingsRepository implements SettingsRepository {
  const LocalSettingsRepository(this._store);

  static const String storageKey = 'golog.app_settings';

  final SettingsStore _store;

  @override
  Future<AppSettings> load() async {
    try {
      final encoded = await _store.readString(storageKey);
      if (encoded == null || encoded.trim().isEmpty) {
        return const AppSettings();
      }

      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) {
        return const AppSettings();
      }

      return AppSettings.fromJson(decoded);
    } on FormatException {
      return const AppSettings();
    } on TypeError {
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) {
    return _store.writeString(storageKey, jsonEncode(settings.toJson()));
  }
}
