import '../../../core/time/calendar_date.dart';
import 'event_enums.dart';
import 'event_rules.dart';

const Object _notProvided = Object();

/// A persisted bladder or bowel event.
///
/// UTC timestamps preserve the exact instant. [utcOffsetMinutes] and
/// [localDate] preserve how that instant was recorded for calendar grouping.
final class BodyEvent {
  BodyEvent({
    required this.id,
    required this.eventType,
    required DateTime occurredAtUtc,
    required int utcOffsetMinutes,
    required this.localDate,
    this.amount,
    this.urgency,
    this.leakage,
    this.wokeFromSleep,
    this.wokeFromNap,
    this.bristolType,
    this.notes,
    Map<String, Object?>? extraDetails,
    required DateTime createdAtUtc,
    required DateTime updatedAtUtc,
  }) : occurredAtUtc = EventRules.requireUtc(occurredAtUtc, 'occurredAtUtc'),
       utcOffsetMinutes = EventRules.requireUtcOffset(utcOffsetMinutes),
       extraDetails = EventRules.freezeExtraDetails(extraDetails),
       createdAtUtc = EventRules.requireUtc(createdAtUtc, 'createdAtUtc'),
       updatedAtUtc = EventRules.requireUtc(updatedAtUtc, 'updatedAtUtc') {
    if (id < 1) {
      throw ArgumentError.value(id, 'id', 'Must be a positive database id.');
    }
    EventRules.validateDetails(
      eventType: eventType,
      leakage: leakage,
      bristolType: bristolType,
    );
    final expectedLocalDate = CalendarDate.fromUtcAndOffset(
      this.occurredAtUtc,
      this.utcOffsetMinutes,
    );
    if (localDate != expectedLocalDate) {
      throw ArgumentError.value(
        localDate,
        'localDate',
        'Must match occurredAtUtc plus utcOffsetMinutes '
            '(${expectedLocalDate.format()}).',
      );
    }
    if (this.updatedAtUtc.isBefore(this.createdAtUtc)) {
      throw ArgumentError.value(
        updatedAtUtc,
        'updatedAtUtc',
        'Must not be earlier than createdAtUtc.',
      );
    }
  }

  final int id;
  final EventType eventType;
  final DateTime occurredAtUtc;
  final int utcOffsetMinutes;
  final CalendarDate localDate;
  final EventAmount? amount;
  final EventUrgency? urgency;
  final LeakageLevel? leakage;

  /// Whether this event woke the user from sleep; `null` means not recorded.
  ///
  /// This sleep context applies to every event type. Only urination events
  /// marked `true` are considered nocturia in trend summaries.
  final bool? wokeFromSleep;
  /// Whether this event followed waking from a nap.
  final bool? wokeFromNap;
  final int? bristolType;
  final String? notes;
  final Map<String, Object?>? extraDetails;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  /// The recorded wall-clock components represented without device conversion.
  ///
  /// Dart has no fixed-offset DateTime type, so this remains UTC-tagged while
  /// its components contain the recorded wall time. Format its components
  /// directly; do not call `toLocal()` on this value.
  DateTime get recordedLocalDateTime {
    return occurredAtUtc.add(Duration(minutes: utcOffsetMinutes));
  }

  /// Creates a modified immutable event.
  ///
  /// Nullable detail fields accept an explicit `null`, allowing edit screens
  /// to clear a value. If the instant or offset changes and [localDate] is not
  /// supplied, the recorded date is recalculated automatically.
  BodyEvent copyWith({
    int? id,
    EventType? eventType,
    DateTime? occurredAtUtc,
    int? utcOffsetMinutes,
    CalendarDate? localDate,
    Object? amount = _notProvided,
    Object? urgency = _notProvided,
    Object? leakage = _notProvided,
    Object? wokeFromSleep = _notProvided,
    Object? wokeFromNap = _notProvided,
    Object? bristolType = _notProvided,
    Object? notes = _notProvided,
    Object? extraDetails = _notProvided,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
  }) {
    final nextOccurredAtUtc = occurredAtUtc ?? this.occurredAtUtc;
    final nextUtcOffsetMinutes = utcOffsetMinutes ?? this.utcOffsetMinutes;
    final shouldRecalculateDate =
        occurredAtUtc != null || utcOffsetMinutes != null;

    return BodyEvent(
      id: id ?? this.id,
      eventType: eventType ?? this.eventType,
      occurredAtUtc: nextOccurredAtUtc,
      utcOffsetMinutes: nextUtcOffsetMinutes,
      localDate:
          localDate ??
          (shouldRecalculateDate
              ? CalendarDate.fromUtcAndOffset(
                  nextOccurredAtUtc,
                  nextUtcOffsetMinutes,
                )
              : this.localDate),
      amount: identical(amount, _notProvided)
          ? this.amount
          : amount as EventAmount?,
      urgency: identical(urgency, _notProvided)
          ? this.urgency
          : urgency as EventUrgency?,
      leakage: identical(leakage, _notProvided)
          ? this.leakage
          : leakage as LeakageLevel?,
      wokeFromSleep: identical(wokeFromSleep, _notProvided)
          ? this.wokeFromSleep
          : wokeFromSleep as bool?,
      wokeFromNap: identical(wokeFromNap, _notProvided)
          ? this.wokeFromNap
          : wokeFromNap as bool?,
      bristolType: identical(bristolType, _notProvided)
          ? this.bristolType
          : bristolType as int?,
      notes: identical(notes, _notProvided) ? this.notes : notes as String?,
      extraDetails: identical(extraDetails, _notProvided)
          ? this.extraDetails
          : extraDetails as Map<String, Object?>?,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }
}
