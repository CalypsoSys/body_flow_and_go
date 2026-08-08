import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golog/app/providers.dart';
import 'package:golog/app/theme.dart';
import 'package:golog/features/events/domain/body_event.dart';
import 'package:golog/features/events/domain/event_draft.dart';
import 'package:golog/features/events/domain/event_enums.dart';
import 'package:golog/features/events/domain/event_query.dart';
import 'package:golog/features/events/domain/event_repository.dart';
import 'package:golog/features/events/presentation/event_editor_screen.dart';
import 'package:golog/features/home/presentation/home_screen.dart';
import 'package:golog/features/settings/domain/app_settings.dart';
import 'package:golog/features/settings/domain/settings_repository.dart';

void main() {
  final now = DateTime(2026, 8, 5, 9, 30);

  testWidgets('one tap logs at the current time and undo removes that entry', (
    tester,
  ) async {
    final repository = _FakeEventRepository();
    var hapticCount = 0;
    await tester.pumpWidget(
      _testApp(
        repository: repository,
        now: now,
        onHaptic: () async => hapticCount++,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Body Flow & Go'), findsOneWidget);
    await tester.tap(find.byKey(const Key('log_urination_awake_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.events, hasLength(1));
    expect(repository.events.single.eventType, EventType.urination);
    expect(repository.events.single.occurredAtUtc, now.toUtc());
    expect(repository.events.single.wokeFromSleep, isFalse);
    expect(hapticCount, 1);
    expect(find.text('Urination logged: Awake.'), findsOneWidget);
    expect(find.byKey(const Key('undo_log_action')), findsOneWidget);

    await tester.tap(find.byKey(const Key('undo_log_action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.events, isEmpty);
    expect(find.text('Entry undone.'), findsOneWidget);
  });

  testWidgets('bowel movement logs once and Add details opens the editor', (
    tester,
  ) async {
    final repository = _FakeEventRepository();
    await tester.pumpWidget(
      _testApp(repository: repository, now: now, onHaptic: () async {}),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('log_bowel_sleep_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.events, hasLength(1));
    expect(repository.events.single.eventType, EventType.bowelMovement);
    expect(repository.events.single.wokeFromSleep, isTrue);
    expect(find.byKey(const Key('add_details_action')), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_details_action')));
    await tester.pumpAndSettle();

    expect(find.text('Edit event'), findsOneWidget);
    final sleepContext = find.byKey(const Key('woke_from_sleep_control'));
    expect(sleepContext, findsOneWidget);
    expect(
      tester.widget<DropdownButtonFormField<bool?>>(sleepContext).initialValue,
      isTrue,
    );
    await tester.scrollUntilVisible(find.text('Bristol Stool Scale'), 160);
    expect(find.text('Bristol Stool Scale'), findsOneWidget);
  });

  testWidgets('woke-from-sleep urination is recorded by the initial one tap', (
    tester,
  ) async {
    final repository = _FakeEventRepository();
    await tester.pumpWidget(
      _testApp(repository: repository, now: now, onHaptic: () async {}),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('log_urination_sleep_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.events.single.wokeFromSleep, isTrue);
    expect(find.text('Urination logged: Woke from sleep.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_details_action')));
    await tester.pumpAndSettle();

    expect(find.text('Woke from sleep (nocturia)'), findsOneWidget);
    expect(
      find.text(
        'Choose Yes if the need to urinate woke you. '
        'It is okay to leave this unrecorded.',
      ),
      findsOneWidget,
    );

    final wokeFromSleepControl = find.byKey(
      const Key('woke_from_sleep_control'),
    );
    await tester.ensureVisible(wokeFromSleepControl);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<bool?>>(wokeFromSleepControl)
          .initialValue,
      isTrue,
    );
    final saveButton = find.byKey(const Key('save_event_button'));
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.events.single.wokeFromSleep, isTrue);
    expect(find.text('Woke from sleep'), findsWidgets);
  });

  testWidgets('editing preserves sleep context when the event type changes', (
    tester,
  ) async {
    final repository = _FakeEventRepository();
    final event = await repository.add(
      EventDraft.fromRecordedLocalDateTime(
        eventType: EventType.urination,
        recordedLocalDateTime: now,
        wokeFromSleep: true,
      ),
    );
    await tester.pumpWidget(
      _testEditorApp(repository: repository, now: now, event: event),
    );
    await tester.pumpAndSettle();

    var control = find.byKey(const Key('woke_from_sleep_control'));
    expect(control, findsOneWidget);
    expect(
      tester.widget<DropdownButtonFormField<bool?>>(control).initialValue,
      isTrue,
    );

    await tester.tap(find.text('Bowel movement'));
    await tester.pump();
    control = find.byKey(const Key('woke_from_sleep_control'));
    expect(control, findsOneWidget);
    expect(
      tester.widget<DropdownButtonFormField<bool?>>(control).initialValue,
      isTrue,
    );
    expect(find.text('Woke from sleep'), findsOneWidget);

    await tester.tap(find.text('Urination'));
    await tester.pump();
    control = find.byKey(const Key('woke_from_sleep_control'));
    expect(control, findsOneWidget);
    expect(
      tester.widget<DropdownButtonFormField<bool?>>(control).initialValue,
      isTrue,
    );
  });

  testWidgets('recent entries distinguish an explicit awake event', (
    tester,
  ) async {
    final repository = _FakeEventRepository();
    await tester.pumpWidget(
      _testApp(repository: repository, now: now, onHaptic: () async {}),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('log_urination_awake_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.events.single.wokeFromSleep, isFalse);
    await tester.scrollUntilVisible(find.text('Did not wake from sleep'), 200);
    expect(find.text('Did not wake from sleep'), findsOneWidget);
  });

  testWidgets('home logging controls remain usable at large text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeEventRepository();
    await tester.pumpWidget(
      _testApp(
        repository: repository,
        now: now,
        onHaptic: () async {},
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('log_urination_awake_button')), findsOneWidget);
    expect(find.byKey(const Key('log_urination_sleep_button')), findsOneWidget);
    expect(find.byKey(const Key('log_bowel_awake_button')), findsOneWidget);
    expect(find.byKey(const Key('log_bowel_sleep_button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp({
  required _FakeEventRepository repository,
  required DateTime now,
  required Future<void> Function() onHaptic,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return ProviderScope(
    overrides: [
      eventRepositoryProvider.overrideWithValue(repository),
      settingsRepositoryProvider.overrideWithValue(_FakeSettingsRepository()),
      clockProvider.overrideWithValue(() => now),
      hapticCallbackProvider.overrideWithValue(onHaptic),
    ],
    child: MaterialApp(
      theme: buildLightTheme(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: const HomeScreen(),
      ),
    ),
  );
}

Widget _testEditorApp({
  required _FakeEventRepository repository,
  required DateTime now,
  required BodyEvent event,
}) {
  return ProviderScope(
    overrides: [
      eventRepositoryProvider.overrideWithValue(repository),
      settingsRepositoryProvider.overrideWithValue(_FakeSettingsRepository()),
      clockProvider.overrideWithValue(() => now),
      hapticCallbackProvider.overrideWithValue(() async {}),
    ],
    child: MaterialApp(
      theme: buildLightTheme(),
      home: EventEditorScreen(event: event),
    ),
  );
}

class _FakeSettingsRepository implements SettingsRepository {
  AppSettings settings = const AppSettings();

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings settings) async {
    this.settings = settings;
  }
}

class _FakeEventRepository implements EventRepository {
  final List<BodyEvent> events = [];
  int _nextId = 1;

  @override
  Future<BodyEvent> add(EventDraft draft) async {
    final nowUtc = DateTime.utc(2026, 8, 5, 13, 30);
    final event = BodyEvent(
      id: _nextId++,
      eventType: draft.eventType,
      occurredAtUtc: draft.occurredAtUtc,
      utcOffsetMinutes: draft.utcOffsetMinutes,
      localDate: draft.localDate,
      amount: draft.amount,
      urgency: draft.urgency,
      leakage: draft.leakage,
      wokeFromSleep: draft.wokeFromSleep,
      bristolType: draft.bristolType,
      notes: draft.notes,
      extraDetails: draft.extraDetails,
      createdAtUtc: nowUtc,
      updatedAtUtc: nowUtc,
    );
    events.add(event);
    return event;
  }

  @override
  Future<bool> deleteById(int id) async {
    final before = events.length;
    events.removeWhere((event) => event.id == id);
    return events.length != before;
  }

  @override
  Future<void> deleteAll() async => events.clear();

  @override
  Future<BodyEvent?> findById(int id) async {
    for (final event in events) {
      if (event.id == id) return event;
    }
    return null;
  }

  @override
  Future<List<BodyEvent>> query([EventQuery? query]) async {
    final effective = query ?? EventQuery();
    var result = events.where((event) {
      return (effective.eventTypes.isEmpty ||
              effective.eventTypes.contains(event.eventType)) &&
          (effective.fromDate == null ||
              event.localDate.compareTo(effective.fromDate!) >= 0) &&
          (effective.throughDate == null ||
              event.localDate.compareTo(effective.throughDate!) <= 0);
    }).toList();
    result.sort((left, right) {
      final comparison = left.occurredAtUtc.compareTo(right.occurredAtUtc);
      final stable = comparison == 0 ? left.id.compareTo(right.id) : comparison;
      return effective.newestFirst ? -stable : stable;
    });
    if (effective.limit != null && result.length > effective.limit!) {
      result = result.take(effective.limit!).toList();
    }
    return result;
  }

  @override
  Future<BodyEvent> update(int id, EventDraft draft) async {
    final index = events.indexWhere((event) => event.id == id);
    if (index < 0) throw StateError('Missing event');
    final previous = events[index];
    final updated = BodyEvent(
      id: id,
      eventType: draft.eventType,
      occurredAtUtc: draft.occurredAtUtc,
      utcOffsetMinutes: draft.utcOffsetMinutes,
      localDate: draft.localDate,
      amount: draft.amount,
      urgency: draft.urgency,
      leakage: draft.leakage,
      wokeFromSleep: draft.wokeFromSleep,
      bristolType: draft.bristolType,
      notes: draft.notes,
      extraDetails: draft.extraDetails,
      createdAtUtc: previous.createdAtUtc,
      updatedAtUtc: previous.updatedAtUtc.add(const Duration(seconds: 1)),
    );
    events[index] = updated;
    return updated;
  }

  @override
  Future<List<BodyEvent>> allForExport() =>
      query(EventQuery(newestFirst: false));
}
