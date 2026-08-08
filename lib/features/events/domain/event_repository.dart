import 'body_event.dart';
import 'event_draft.dart';
import 'event_query.dart';

/// Storage-independent access to body events.
abstract interface class EventRepository {
  /// Persists [draft] and returns the database-assigned event.
  Future<BodyEvent> add(EventDraft draft);

  Future<BodyEvent?> findById(int id);

  /// Returns events matching [query], or all events newest-first when omitted.
  Future<List<BodyEvent>> query([EventQuery? query]);

  /// Replaces editable fields on [id], preserving its creation timestamp.
  ///
  /// Throws [StateError] if the event no longer exists.
  Future<BodyEvent> update(int id, EventDraft draft);

  /// Returns whether an event was removed.
  Future<bool> deleteById(int id);

  Future<void> deleteAll();

  /// Returns every event in stable oldest-first order for deterministic export.
  Future<List<BodyEvent>> allForExport();
}
