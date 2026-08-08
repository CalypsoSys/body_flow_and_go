import 'app_settings.dart';

/// Persists and retrieves user settings independently of the UI.
abstract interface class SettingsRepository {
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}
