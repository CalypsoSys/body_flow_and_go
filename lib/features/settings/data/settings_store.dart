/// Minimal key-value storage contract used by the settings repository.
///
/// Keeping this interface small makes persistence replaceable and allows
/// repository tests to run without platform channels.
abstract interface class SettingsStore {
  Future<String?> readString(String key);

  Future<void> writeString(String key, String value);
}
