import '../../../core/time/calendar_date.dart';
import 'event_enums.dart';
import 'event_rules.dart';

const Object _notProvided = Object();

/// Validated input for creating or editing an event.
final class EventDraft {
  EventDraft({
    required this.eventType,
    required DateTime occurredAtUtc,
    required int utcOffsetMinutes,
    this.amount,
    this.urgency,
    this.leakage,
    this.wokeFromSleep,
    this.bristolType,
    String? notes,
    Map<String, Object?>? extraDetails,
  }) : occurredAtUtc = EventRules.requireUtc(occurredAtUtc, 'occurredAtUtc'),
       utcOffsetMinutes = EventRules.requireUtcOffset(utcOffsetMinutes),
       notes = EventRules.normalizeNotes(notes),
       extraDetails = EventRules.freezeExtraDetails(extraDetails) {
    EventRules.validateDetails(
      eventType: eventType,
      leakage: leakage,
      bristolType: bristolType,
    );
  }

  /// Creates a draft from a real local or UTC DateTime.
  ///
  /// This convenience factory captures the DateTime's offset before converting
  /// the exact instant to UTC.
  factory EventDraft.fromRecordedLocalDateTime({
    required EventType eventType,
    required DateTime recordedLocalDateTime,
    EventAmount? amount,
    EventUrgency? urgency,
    LeakageLevel? leakage,
    bool? wokeFromSleep,
    int? bristolType,
    String? notes,
    Map<String, Object?>? extraDetails,
  }) {
    return EventDraft(
      eventType: eventType,
      occurredAtUtc: recordedLocalDateTime.toUtc(),
      utcOffsetMinutes: recordedLocalDateTime.timeZoneOffset.inMinutes,
      amount: amount,
      urgency: urgency,
      leakage: leakage,
      wokeFromSleep: wokeFromSleep,
      bristolType: bristolType,
      notes: notes,
      extraDetails: extraDetails,
    );
  }

  final EventType eventType;
  final DateTime occurredAtUtc;
  final int utcOffsetMinutes;
  final EventAmount? amount;
  final EventUrgency? urgency;
  final LeakageLevel? leakage;

  /// Whether this event woke the user from sleep; `null` means not recorded.
  final bool? wokeFromSleep;
  final int? bristolType;
  final String? notes;
  final Map<String, Object?>? extraDetails;

  CalendarDate get localDate {
    return CalendarDate.fromUtcAndOffset(occurredAtUtc, utcOffsetMinutes);
  }

  EventDraft copyWith({
    EventType? eventType,
    DateTime? occurredAtUtc,
    int? utcOffsetMinutes,
    Object? amount = _notProvided,
    Object? urgency = _notProvided,
    Object? leakage = _notProvided,
    Object? wokeFromSleep = _notProvided,
    Object? bristolType = _notProvided,
    Object? notes = _notProvided,
    Object? extraDetails = _notProvided,
  }) {
    return EventDraft(
      eventType: eventType ?? this.eventType,
      occurredAtUtc: occurredAtUtc ?? this.occurredAtUtc,
      utcOffsetMinutes: utcOffsetMinutes ?? this.utcOffsetMinutes,
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
      bristolType: identical(bristolType, _notProvided)
          ? this.bristolType
          : bristolType as int?,
      notes: identical(notes, _notProvided) ? this.notes : notes as String?,
      extraDetails: identical(extraDetails, _notProvided)
          ? this.extraDetails
          : extraDetails as Map<String, Object?>?,
    );
  }
}
