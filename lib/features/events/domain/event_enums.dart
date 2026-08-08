/// The event categories currently understood by Body Flow & Go.
///
/// The explicit values are part of the database and export contract. Do not
/// derive persisted values from enum names.
enum EventType {
  urination('urination'),
  bowelMovement('bowel_movement');

  const EventType(this.storageValue);

  final String storageValue;

  static EventType fromStorage(String value) {
    return values.firstWhere(
      (candidate) => candidate.storageValue == value,
      orElse: () => throw FormatException('Unknown event type.', value),
    );
  }
}

/// Optional user-estimated amount.
enum EventAmount {
  small('small'),
  medium('medium'),
  large('large');

  const EventAmount(this.storageValue);

  final String storageValue;

  static EventAmount fromStorage(String value) {
    return values.firstWhere(
      (candidate) => candidate.storageValue == value,
      orElse: () => throw FormatException('Unknown event amount.', value),
    );
  }
}

/// Optional urgency at the time of an event.
enum EventUrgency {
  none('none'),
  mild('mild'),
  moderate('moderate'),
  severe('severe');

  const EventUrgency(this.storageValue);

  final String storageValue;

  static EventUrgency fromStorage(String value) {
    return values.firstWhere(
      (candidate) => candidate.storageValue == value,
      orElse: () => throw FormatException('Unknown event urgency.', value),
    );
  }
}

/// Optional leakage associated with a urination event.
enum LeakageLevel {
  none('none'),
  drops('drops'),
  moderate('moderate'),
  large('large');

  const LeakageLevel(this.storageValue);

  final String storageValue;

  static LeakageLevel fromStorage(String value) {
    return values.firstWhere(
      (candidate) => candidate.storageValue == value,
      orElse: () => throw FormatException('Unknown leakage level.', value),
    );
  }
}
