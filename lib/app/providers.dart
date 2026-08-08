import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/time/calendar_date.dart';
import '../features/events/data/development_event_seeder.dart';
import '../features/events/data/sqlite_event_repository.dart';
import '../features/events/domain/body_event.dart';
import '../features/events/domain/event_draft.dart';
import '../features/events/domain/event_enums.dart';
import '../features/events/domain/event_query.dart';
import '../features/events/domain/event_repository.dart';
import '../features/export/data/export_service.dart';
import '../features/feedback/data/http_feedback_repository.dart';
import '../features/feedback/domain/feedback_repository.dart';
import '../features/settings/data/local_settings_repository.dart';
import '../features/settings/data/shared_preferences_settings_store.dart';
import '../features/settings/domain/app_settings.dart';
import '../features/settings/domain/settings_repository.dart';

typedef AppClock = DateTime Function();
typedef HapticCallback = Future<void> Function();

final clockProvider = Provider<AppClock>((ref) => DateTime.now);

final hapticCallbackProvider = Provider<HapticCallback>(
  (ref) => HapticFeedback.lightImpact,
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return SQLiteEventRepository(ref.watch(appDatabaseProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return LocalSettingsRepository(SharedPreferencesSettingsStore());
});

final exportServiceProvider = Provider<ExportService>(
  (ref) => ExportService.platform(),
);

final feedbackRepositoryProvider = Provider<FeedbackRepository>(
  (ref) => HttpFeedbackRepository.production(),
);

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
      SettingsController.new,
    );

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() {
    return ref.watch(settingsRepositoryProvider).load();
  }

  Future<void> saveSettings(AppSettings settings) async {
    final previous = state;
    state = AsyncData(settings);
    try {
      await ref.read(settingsRepositoryProvider).save(settings);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

final eventRevisionProvider = NotifierProvider<EventRevision, int>(
  EventRevision.new,
);

class EventRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final applicationStartupProvider = FutureProvider<void>((ref) async {
  final repository = ref.watch(eventRepositoryProvider);
  const seedEnabled = bool.fromEnvironment('GOLOG_SEED_DATA');
  await DevelopmentEventSeeder(
    repository,
    clock: ref.watch(clockProvider),
  ).seedIfEnabled(enabled: seedEnabled);
});

final eventMutationsProvider = Provider<EventMutations>(EventMutations.new);

enum DeleteAllEventsResult { complete, cachedExportCleanupFailed }

class EventMutations {
  const EventMutations(this._ref);

  final Ref _ref;

  Future<BodyEvent> add(EventDraft draft) async {
    final event = await _ref.read(eventRepositoryProvider).add(draft);
    _ref.read(eventRevisionProvider.notifier).bump();
    return event;
  }

  Future<BodyEvent> update(int id, EventDraft draft) async {
    final event = await _ref.read(eventRepositoryProvider).update(id, draft);
    _ref.read(eventRevisionProvider.notifier).bump();
    return event;
  }

  Future<bool> delete(int id) async {
    final deleted = await _ref.read(eventRepositoryProvider).deleteById(id);
    if (deleted) _ref.read(eventRevisionProvider.notifier).bump();
    return deleted;
  }

  Future<DeleteAllEventsResult> deleteAll() async {
    await _ref.read(eventRepositoryProvider).deleteAll();
    _ref.read(eventRevisionProvider.notifier).bump();
    try {
      await _ref.read(exportServiceProvider).clearCachedExports();
      return DeleteAllEventsResult.complete;
    } catch (_) {
      return DeleteAllEventsResult.cachedExportCleanupFailed;
    }
  }
}

final homeDataProvider = FutureProvider<HomeData>((ref) async {
  ref.watch(eventRevisionProvider);
  final startup = ref.watch(applicationStartupProvider.future);
  final repository = ref.watch(eventRepositoryProvider);
  final now = ref.watch(clockProvider)();
  final today = CalendarDate.fromRecordedWallDate(now);
  await startup;

  final results = await Future.wait<List<BodyEvent>>([
    repository.query(EventQuery(limit: 5)),
    repository.query(EventQuery(fromDate: today, throughDate: today)),
    repository.query(EventQuery(eventTypes: {EventType.urination}, limit: 1)),
    repository.query(
      EventQuery(eventTypes: {EventType.bowelMovement}, limit: 1),
    ),
  ]);

  final todayEvents = results[1];
  return HomeData(
    recentEvents: results[0],
    urinationCountToday: todayEvents
        .where((event) => event.eventType == EventType.urination)
        .length,
    bowelMovementCountToday: todayEvents
        .where((event) => event.eventType == EventType.bowelMovement)
        .length,
    lastUrination: results[2].firstOrNull,
    lastBowelMovement: results[3].firstOrNull,
  );
});

final allEventsProvider = FutureProvider<List<BodyEvent>>((ref) async {
  ref.watch(eventRevisionProvider);
  final repository = ref.watch(eventRepositoryProvider);
  final startup = ref.watch(applicationStartupProvider.future);
  await startup;
  return repository.query();
});

final eventByIdProvider = FutureProvider.family<BodyEvent?, int>((ref, id) {
  ref.watch(eventRevisionProvider);
  return ref.watch(eventRepositoryProvider).findById(id);
});

class HomeData {
  const HomeData({
    required this.recentEvents,
    required this.urinationCountToday,
    required this.bowelMovementCountToday,
    required this.lastUrination,
    required this.lastBowelMovement,
  });

  final List<BodyEvent> recentEvents;
  final int urinationCountToday;
  final int bowelMovementCountToday;
  final BodyEvent? lastUrination;
  final BodyEvent? lastBowelMovement;
}
