import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/time/calendar_date.dart';
import '../../features/events/domain/body_event.dart';
import '../../features/events/domain/event_enums.dart';

extension EventTypeDisplay on EventType {
  String get displayName => switch (this) {
    EventType.urination => 'Urination',
    EventType.bowelMovement => 'Bowel movement',
  };

  String get shortName => switch (this) {
    EventType.urination => 'Urination',
    EventType.bowelMovement => 'Bowel',
  };

  IconData get icon => switch (this) {
    EventType.urination => Icons.water_drop_outlined,
    EventType.bowelMovement => Icons.circle_outlined,
  };
}

extension EventAmountDisplay on EventAmount {
  String get displayName => switch (this) {
    EventAmount.small => 'Small',
    EventAmount.medium => 'Medium',
    EventAmount.large => 'Large',
  };
}

extension EventUrgencyDisplay on EventUrgency {
  String get displayName => switch (this) {
    EventUrgency.none => 'None',
    EventUrgency.mild => 'Mild',
    EventUrgency.moderate => 'Moderate',
    EventUrgency.severe => 'Severe',
  };
}

extension LeakageDisplay on LeakageLevel {
  String get displayName => switch (this) {
    LeakageLevel.none => 'None',
    LeakageLevel.drops => 'Drops',
    LeakageLevel.moderate => 'Moderate',
    LeakageLevel.large => 'Large',
  };
}

String formatEventTime(BodyEvent event) {
  return DateFormat.jm().format(event.recordedLocalDateTime);
}

String formatCalendarDate(CalendarDate date) {
  return DateFormat.yMMMMd().format(date.asUtcMidnight);
}

String formatCompactDate(CalendarDate date) {
  return DateFormat.MMMd().format(date.asUtcMidnight);
}

String formatElapsed(Duration duration) {
  if (duration.isNegative) return 'just now';
  if (duration.inMinutes < 1) return 'just now';
  if (duration.inHours < 1) {
    final minutes = duration.inMinutes;
    return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
  }
  if (duration.inDays < 1) {
    final hours = duration.inHours;
    return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
  }
  final days = duration.inDays;
  return '$days ${days == 1 ? 'day' : 'days'} ago';
}

String eventDetailsSummary(BodyEvent event) {
  final details = <String>[
    if (event.amount != null) event.amount!.displayName,
    if (event.urgency != null) '${event.urgency!.displayName} urgency',
    if (event.leakage != null) '${event.leakage!.displayName} leakage',
    if (event.wokeFromSleep != null)
      event.wokeFromSleep! ? 'Woke from sleep' : 'Did not wake from sleep',
    if (event.bristolType != null) 'Bristol ${event.bristolType}',
  ];
  return details.join(' · ');
}
