/// The color theme Body Flow & Go should use.
enum AppThemePreference {
  system('system'),
  light('light'),
  dark('dark');

  const AppThemePreference(this.storageValue);

  /// A deliberately stable value used by local persistence.
  final String storageValue;

  static AppThemePreference fromStorageValue(Object? value) {
    for (final preference in values) {
      if (preference.storageValue == value) {
        return preference;
      }
    }

    return AppThemePreference.system;
  }
}

/// User-configurable application behavior.
///
/// Every field has a safe default so settings written by an older app version
/// continue to load when new preferences are introduced.
class AppSettings {
  const AppSettings({
    this.urinationDetailsEnabled = true,
    this.bowelMovementDetailsEnabled = true,
    this.hapticFeedbackEnabled = true,
    this.themePreference = AppThemePreference.system,
  });

  static const int serializationVersion = 1;

  static const String _versionKey = 'version';
  static const String _urinationDetailsKey = 'urinationDetailsEnabled';
  static const String _bowelMovementDetailsKey = 'bowelMovementDetailsEnabled';
  static const String _hapticFeedbackKey = 'hapticFeedbackEnabled';
  static const String _themePreferenceKey = 'themePreference';

  final bool urinationDetailsEnabled;
  final bool bowelMovementDetailsEnabled;
  final bool hapticFeedbackEnabled;
  final AppThemePreference themePreference;

  AppSettings copyWith({
    bool? urinationDetailsEnabled,
    bool? bowelMovementDetailsEnabled,
    bool? hapticFeedbackEnabled,
    AppThemePreference? themePreference,
  }) {
    return AppSettings(
      urinationDetailsEnabled:
          urinationDetailsEnabled ?? this.urinationDetailsEnabled,
      bowelMovementDetailsEnabled:
          bowelMovementDetailsEnabled ?? this.bowelMovementDetailsEnabled,
      hapticFeedbackEnabled:
          hapticFeedbackEnabled ?? this.hapticFeedbackEnabled,
      themePreference: themePreference ?? this.themePreference,
    );
  }

  /// Converts these settings to versioned, JSON-compatible primitive values.
  Map<String, Object> toJson() {
    return <String, Object>{
      _versionKey: serializationVersion,
      _urinationDetailsKey: urinationDetailsEnabled,
      _bowelMovementDetailsKey: bowelMovementDetailsEnabled,
      _hapticFeedbackKey: hapticFeedbackEnabled,
      _themePreferenceKey: themePreference.storageValue,
    };
  }

  /// Reads known fields and supplies defaults for missing or invalid values.
  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      urinationDetailsEnabled: _readBool(json, _urinationDetailsKey, true),
      bowelMovementDetailsEnabled: _readBool(
        json,
        _bowelMovementDetailsKey,
        true,
      ),
      hapticFeedbackEnabled: _readBool(json, _hapticFeedbackKey, true),
      themePreference: AppThemePreference.fromStorageValue(
        json[_themePreferenceKey],
      ),
    );
  }

  static bool _readBool(Map<String, Object?> json, String key, bool fallback) {
    final value = json[key];
    return value is bool ? value : fallback;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AppSettings &&
            other.urinationDetailsEnabled == urinationDetailsEnabled &&
            other.bowelMovementDetailsEnabled == bowelMovementDetailsEnabled &&
            other.hapticFeedbackEnabled == hapticFeedbackEnabled &&
            other.themePreference == themePreference;
  }

  @override
  int get hashCode => Object.hash(
    urinationDetailsEnabled,
    bowelMovementDetailsEnabled,
    hapticFeedbackEnabled,
    themePreference,
  );

  @override
  String toString() {
    return 'AppSettings('
        'urinationDetailsEnabled: $urinationDetailsEnabled, '
        'bowelMovementDetailsEnabled: $bowelMovementDetailsEnabled, '
        'hapticFeedbackEnabled: $hapticFeedbackEnabled, '
        'themePreference: $themePreference)';
  }
}
