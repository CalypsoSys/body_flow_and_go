import 'dart:collection';

import 'event_enums.dart';

/// Shared invariants for event models and persistence boundaries.
abstract final class EventRules {
  static DateTime requireUtc(DateTime value, String argumentName) {
    if (!value.isUtc) {
      throw ArgumentError.value(value, argumentName, 'Must be a UTC DateTime.');
    }
    return value;
  }

  static int requireUtcOffset(int value) {
    if (value < -1440 || value > 1440) {
      throw RangeError.range(value, -1440, 1440, 'utcOffsetMinutes');
    }
    return value;
  }

  static void validateDetails({
    required EventType eventType,
    required LeakageLevel? leakage,
    required int? bristolType,
  }) {
    if (bristolType != null && (bristolType < 1 || bristolType > 7)) {
      throw RangeError.range(bristolType, 1, 7, 'bristolType');
    }
    if (eventType == EventType.urination && bristolType != null) {
      throw ArgumentError.value(
        bristolType,
        'bristolType',
        'Bristol type only applies to bowel movements.',
      );
    }
    if (eventType == EventType.bowelMovement && leakage != null) {
      throw ArgumentError.value(
        leakage,
        'leakage',
        'Leakage only applies to urination events.',
      );
    }
  }

  static String? normalizeNotes(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static Map<String, Object?>? freezeExtraDetails(Map<String, Object?>? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return UnmodifiableMapView(Map<String, Object?>.from(value));
  }
}
