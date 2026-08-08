import 'package:flutter_test/flutter_test.dart';
import 'package:golog/features/settings/domain/app_settings.dart';

void main() {
  group('AppSettings', () {
    test('uses privacy-friendly product defaults', () {
      const settings = AppSettings();

      expect(settings.urinationDetailsEnabled, isTrue);
      expect(settings.bowelMovementDetailsEnabled, isTrue);
      expect(settings.hapticFeedbackEnabled, isTrue);
      expect(settings.themePreference, AppThemePreference.system);
    });

    test('copyWith changes only supplied fields', () {
      const original = AppSettings();

      final changed = original.copyWith(
        bowelMovementDetailsEnabled: false,
        themePreference: AppThemePreference.dark,
      );

      expect(changed.urinationDetailsEnabled, isTrue);
      expect(changed.bowelMovementDetailsEnabled, isFalse);
      expect(changed.hapticFeedbackEnabled, isTrue);
      expect(changed.themePreference, AppThemePreference.dark);
    });

    test('serializes to stable versioned values and round-trips', () {
      const settings = AppSettings(
        urinationDetailsEnabled: false,
        bowelMovementDetailsEnabled: false,
        hapticFeedbackEnabled: false,
        themePreference: AppThemePreference.light,
      );

      final json = settings.toJson();

      expect(json, <String, Object>{
        'version': 1,
        'urinationDetailsEnabled': false,
        'bowelMovementDetailsEnabled': false,
        'hapticFeedbackEnabled': false,
        'themePreference': 'light',
      });
      expect(AppSettings.fromJson(json), settings);
    });

    test('uses defaults for missing and invalid fields', () {
      final settings = AppSettings.fromJson(<String, Object?>{
        'urinationDetailsEnabled': false,
        'bowelMovementDetailsEnabled': 'no',
        'hapticFeedbackEnabled': null,
        'themePreference': 'sepia',
      });

      expect(settings.urinationDetailsEnabled, isFalse);
      expect(settings.bowelMovementDetailsEnabled, isTrue);
      expect(settings.hapticFeedbackEnabled, isTrue);
      expect(settings.themePreference, AppThemePreference.system);
    });
  });
}
