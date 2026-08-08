import '../../../core/time/calendar_date.dart';

class TrendRange {
  TrendRange({required this.start, required this.end}) {
    if (start.compareTo(end) > 0) {
      throw ArgumentError.value(
        end,
        'end',
        'The trend range end must not be before its start.',
      );
    }
  }

  final CalendarDate start;
  final CalendarDate end;

  int get dayCount => _asUtc(end).difference(_asUtc(start)).inDays + 1;

  bool contains(CalendarDate date) =>
      date.compareTo(start) >= 0 && date.compareTo(end) <= 0;

  Iterable<CalendarDate> get dates sync* {
    final first = _asUtc(start);
    for (var offset = 0; offset < dayCount; offset++) {
      final date = first.add(Duration(days: offset));
      yield CalendarDate(date.year, date.month, date.day);
    }
  }

  static DateTime _asUtc(CalendarDate date) =>
      DateTime.utc(date.year, date.month, date.day);
}
