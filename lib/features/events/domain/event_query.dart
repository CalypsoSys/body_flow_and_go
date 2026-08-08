import '../../../core/time/calendar_date.dart';
import 'event_enums.dart';

/// Filters and ordering for event history queries.
///
/// Date boundaries are inclusive and use each event's recorded local date.
/// An empty [eventTypes] set means both currently supported event types.
final class EventQuery {
  EventQuery({
    Set<EventType> eventTypes = const <EventType>{},
    this.fromDate,
    this.throughDate,
    this.limit,
    this.newestFirst = true,
  }) : eventTypes = Set<EventType>.unmodifiable(eventTypes) {
    if (fromDate != null &&
        throughDate != null &&
        fromDate!.compareTo(throughDate!) > 0) {
      throw ArgumentError('fromDate must not be after throughDate.');
    }
    if (limit != null && limit! < 1) {
      throw ArgumentError.value(limit, 'limit', 'Must be positive.');
    }
  }

  final Set<EventType> eventTypes;
  final CalendarDate? fromDate;
  final CalendarDate? throughDate;
  final int? limit;
  final bool newestFirst;
}
