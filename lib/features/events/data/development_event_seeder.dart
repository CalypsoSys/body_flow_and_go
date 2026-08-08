import '../domain/event_draft.dart';
import '../domain/event_enums.dart';
import '../domain/event_query.dart';
import '../domain/event_repository.dart';

typedef LocalClock = DateTime Function();

/// Adds clearly synthetic, relative records for opted-in development builds.
///
/// The caller must explicitly pass `enabled: true`. Existing databases are
/// never modified, which prevents sample records from mixing with user data.
final class DevelopmentEventSeeder {
  DevelopmentEventSeeder(this._repository, {LocalClock? clock})
    : _clock = clock ?? DateTime.now;

  final EventRepository _repository;
  final LocalClock _clock;

  /// Returns the number of inserted records.
  Future<int> seedIfEnabled({required bool enabled}) async {
    if (!enabled) {
      return 0;
    }
    final existing = await _repository.query(EventQuery(limit: 1));
    if (existing.isNotEmpty) {
      return 0;
    }

    final anchor = _clock();
    final samples = <_DevelopmentSample>[
      const _DevelopmentSample(
        age: Duration(minutes: 35),
        eventType: EventType.urination,
        amount: EventAmount.medium,
        urgency: EventUrgency.mild,
      ),
      const _DevelopmentSample(
        age: Duration(hours: 3, minutes: 20),
        eventType: EventType.urination,
        amount: EventAmount.large,
        urgency: EventUrgency.none,
      ),
      const _DevelopmentSample(
        age: Duration(hours: 7),
        eventType: EventType.bowelMovement,
        amount: EventAmount.medium,
        urgency: EventUrgency.mild,
        wokeFromSleep: true,
        bristolType: 4,
      ),
      const _DevelopmentSample(
        age: Duration(hours: 10, minutes: 40),
        eventType: EventType.urination,
        amount: EventAmount.small,
        urgency: EventUrgency.moderate,
        leakage: LeakageLevel.drops,
        wokeFromSleep: true,
      ),
      const _DevelopmentSample(
        age: Duration(days: 1, hours: 2),
        eventType: EventType.urination,
        amount: EventAmount.medium,
      ),
      const _DevelopmentSample(
        age: Duration(days: 1, hours: 9),
        eventType: EventType.bowelMovement,
        amount: EventAmount.small,
        bristolType: 3,
      ),
      const _DevelopmentSample(
        age: Duration(days: 2, hours: 5),
        eventType: EventType.urination,
        amount: EventAmount.large,
      ),
      const _DevelopmentSample(
        age: Duration(days: 4, hours: 4),
        eventType: EventType.bowelMovement,
        amount: EventAmount.medium,
        bristolType: 5,
      ),
      const _DevelopmentSample(
        age: Duration(days: 6, hours: 1),
        eventType: EventType.urination,
        amount: EventAmount.medium,
      ),
    ];

    for (final sample in samples) {
      final recordedTime = anchor.subtract(sample.age);
      await _repository.add(
        EventDraft.fromRecordedLocalDateTime(
          eventType: sample.eventType,
          recordedLocalDateTime: recordedTime,
          amount: sample.amount,
          urgency: sample.urgency,
          leakage: sample.leakage,
          wokeFromSleep: sample.wokeFromSleep,
          bristolType: sample.bristolType,
          notes: 'Development sample',
          extraDetails: const {'developmentSeed': true},
        ),
      );
    }
    return samples.length;
  }
}

final class _DevelopmentSample {
  const _DevelopmentSample({
    required this.age,
    required this.eventType,
    this.amount,
    this.urgency,
    this.leakage,
    this.wokeFromSleep,
    this.bristolType,
  });

  final Duration age;
  final EventType eventType;
  final EventAmount? amount;
  final EventUrgency? urgency;
  final LeakageLevel? leakage;
  final bool? wokeFromSleep;
  final int? bristolType;
}
