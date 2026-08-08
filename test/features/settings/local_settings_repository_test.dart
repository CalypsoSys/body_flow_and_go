import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:golog/features/settings/data/local_settings_repository.dart';
import 'package:golog/features/settings/data/settings_store.dart';
import 'package:golog/features/settings/domain/app_settings.dart';

void main() {
  group('LocalSettingsRepository', () {
    late InMemorySettingsStore store;
    late LocalSettingsRepository repository;

    setUp(() {
      store = InMemorySettingsStore();
      repository = LocalSettingsRepository(store);
    });

    test('returns defaults when no settings have been saved', () async {
      expect(await repository.load(), const AppSettings());
    });

    test('saves and loads every setting', () async {
      const expected = AppSettings(
        urinationDetailsEnabled: false,
        bowelMovementDetailsEnabled: false,
        hapticFeedbackEnabled: false,
        themePreference: AppThemePreference.dark,
      );

      await repository.save(expected);

      expect(await repository.load(), expected);
      expect(store.values.keys, contains(LocalSettingsRepository.storageKey));
    });

    test('loads a partial document with defaults for omitted values', () async {
      store.values[LocalSettingsRepository.storageKey] = jsonEncode(
        <String, Object>{
          'version': 1,
          'urinationDetailsEnabled': false,
          'themePreference': 'light',
        },
      );

      expect(
        await repository.load(),
        const AppSettings(
          urinationDetailsEnabled: false,
          themePreference: AppThemePreference.light,
        ),
      );
    });

    test('returns defaults for malformed JSON', () async {
      store.values[LocalSettingsRepository.storageKey] = '{not json';

      expect(await repository.load(), const AppSettings());
    });

    test('returns defaults for a non-object JSON value', () async {
      store.values[LocalSettingsRepository.storageKey] = '[true, false]';

      expect(await repository.load(), const AppSettings());
    });

    test(
      'returns defaults when the backing value has the wrong type',
      () async {
        store.readError = TypeError();

        expect(await repository.load(), const AppSettings());
      },
    );

    test('defaults only fields with corrupt values', () async {
      store.values[LocalSettingsRepository.storageKey] =
          jsonEncode(<String, Object>{
            'version': 1,
            'urinationDetailsEnabled': 'false',
            'bowelMovementDetailsEnabled': false,
            'hapticFeedbackEnabled': 0,
            'themePreference': 'unknown',
          });

      expect(
        await repository.load(),
        const AppSettings(bowelMovementDetailsEnabled: false),
      );
    });
  });
}

class InMemorySettingsStore implements SettingsStore {
  final Map<String, String> values = <String, String>{};
  Object? readError;

  @override
  Future<String?> readString(String key) async {
    final error = readError;
    if (error != null) {
      throw error;
    }

    return values[key];
  }

  @override
  Future<void> writeString(String key, String value) async {
    values[key] = value;
  }
}
