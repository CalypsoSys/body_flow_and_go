/// A calendar day without a time zone or time-of-day component.
///
/// Body Flow & Go stores this value alongside each UTC timestamp so history and
/// daily summaries remain attached to the day on which the event was recorded,
/// even if the user later travels to another time zone.
final class CalendarDate implements Comparable<CalendarDate> {
  CalendarDate(this.year, this.month, this.day) {
    if (year < 1 || year > 9999) {
      throw ArgumentError.value(year, 'year', 'Must be between 1 and 9999.');
    }
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'Must be between 1 and 12.');
    }

    final daysInMonth = DateTime.utc(year, month + 1, 0).day;
    if (day < 1 || day > daysInMonth) {
      throw ArgumentError.value(
        day,
        'day',
        'Must be valid for the supplied year and month.',
      );
    }
  }

  /// Parses the stable database representation `yyyy-MM-dd`.
  factory CalendarDate.parse(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      throw FormatException('Calendar date must use yyyy-MM-dd.', value);
    }

    try {
      return CalendarDate(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    } on ArgumentError {
      throw FormatException('Calendar date is not valid.', value);
    }
  }

  /// Uses the visible components of a recorded wall-clock date/time.
  ///
  /// No time-zone conversion is performed. This is intentional for values
  /// whose components already describe the wall time shown to the user.
  factory CalendarDate.fromRecordedWallDate(DateTime recordedWallDate) {
    return CalendarDate(
      recordedWallDate.year,
      recordedWallDate.month,
      recordedWallDate.day,
    );
  }

  /// Derives the recorded calendar day from a UTC instant and stored offset.
  factory CalendarDate.fromUtcAndOffset(
    DateTime occurredAtUtc,
    int utcOffsetMinutes,
  ) {
    if (!occurredAtUtc.isUtc) {
      throw ArgumentError.value(
        occurredAtUtc,
        'occurredAtUtc',
        'Must be a UTC DateTime.',
      );
    }
    if (utcOffsetMinutes < -1440 || utcOffsetMinutes > 1440) {
      throw RangeError.range(utcOffsetMinutes, -1440, 1440, 'utcOffsetMinutes');
    }

    final wallTime = occurredAtUtc.add(Duration(minutes: utcOffsetMinutes));
    return CalendarDate.fromRecordedWallDate(wallTime);
  }

  final int year;
  final int month;
  final int day;

  /// Returns the stable ISO-style database representation.
  String format() {
    final yearText = year.toString().padLeft(4, '0');
    final monthText = month.toString().padLeft(2, '0');
    final dayText = day.toString().padLeft(2, '0');
    return '$yearText-$monthText-$dayText';
  }

  /// A UTC midnight useful for calendar arithmetic, not an event instant.
  DateTime get asUtcMidnight => DateTime.utc(year, month, day);

  @override
  int compareTo(CalendarDate other) {
    final yearComparison = year.compareTo(other.year);
    if (yearComparison != 0) {
      return yearComparison;
    }
    final monthComparison = month.compareTo(other.month);
    if (monthComparison != 0) {
      return monthComparison;
    }
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarDate &&
        year == other.year &&
        month == other.month &&
        day == other.day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => format();
}
