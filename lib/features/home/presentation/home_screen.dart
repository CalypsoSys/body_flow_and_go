import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/presentation/event_display.dart';
import '../../../shared/presentation/event_tile.dart';
import '../../events/domain/body_event.dart';
import '../../events/domain/event_draft.dart';
import '../../events/domain/event_enums.dart';
import '../../events/presentation/event_editor_screen.dart';
import '../../settings/domain/app_settings.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _logging = <EventType, bool>{};
  ({EventType type, bool wokeFromSleep, bool wokeFromNap})? _confirmedLog;
  Timer? _clockTimer;
  Timer? _confirmationTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _confirmationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeData = ref.watch(homeDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Body Flow & Go'),
        actions: [
          IconButton(
            tooltip: 'Add an earlier event',
            onPressed: () => _openManualEntry(context),
            icon: const Icon(Icons.add_alarm_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(homeDataProvider.future),
          child: ListView(
            key: const Key('home_scroll_view'),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                'Log now',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              _SplitQuickLogCard(
                type: EventType.urination,
                busyWokeFromSleep: _logging[EventType.urination],
                confirmedWokeFromSleep:
                    _confirmedLog?.type == EventType.urination
                    ? _confirmedLog?.wokeFromSleep
                    : null,
                awakeKey: const Key('log_urination_awake_button'),
                wokeFromSleepKey: const Key('log_urination_sleep_button'),
                napKey: const Key('log_urination_nap_button'),
                onNap: () => _log(
                  EventType.urination,
                  wokeFromSleep: true,
                  wokeFromNap: true,
                ),
                onLog: (wokeFromSleep) =>
                    _log(EventType.urination, wokeFromSleep: wokeFromSleep),
              ),
              const SizedBox(height: 14),
              _SplitQuickLogCard(
                type: EventType.bowelMovement,
                busyWokeFromSleep: _logging[EventType.bowelMovement],
                confirmedWokeFromSleep:
                    _confirmedLog?.type == EventType.bowelMovement
                    ? _confirmedLog?.wokeFromSleep
                    : null,
                awakeKey: const Key('log_bowel_awake_button'),
                wokeFromSleepKey: const Key('log_bowel_sleep_button'),
                onLog: (wokeFromSleep) =>
                    _log(EventType.bowelMovement, wokeFromSleep: wokeFromSleep),
              ),
              const SizedBox(height: 26),
              Text('Today', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              homeData.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) =>
                    _LoadError(onRetry: () => ref.invalidate(homeDataProvider)),
                data: (data) => _HomeSummary(
                  data: data,
                  nowUtc: ref.read(clockProvider)().toUtc(),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recent entries',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _openManualEntry(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Earlier time'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              homeData.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (data) => data.recentEvents.isEmpty
                    ? const _EmptyRecent()
                    : Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < data.recentEvents.length;
                              index++
                            ) ...[
                              EventTile(
                                event: data.recentEvents[index],
                                onTap: () => _openEditor(
                                  context,
                                  data.recentEvents[index],
                                ),
                              ),
                              if (index < data.recentEvents.length - 1)
                                const Divider(height: 1, indent: 64),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _log(
    EventType type, {
    required bool wokeFromSleep,
    bool wokeFromNap = false,
  }) async {
    if (_logging.containsKey(type)) return;
    setState(() => _logging[type] = wokeFromSleep);
    try {
      final now = ref.read(clockProvider)();
      final event = await ref
          .read(eventMutationsProvider)
          .add(
            EventDraft.fromRecordedLocalDateTime(
              eventType: type,
              recordedLocalDateTime: now,
              wokeFromSleep: wokeFromSleep,
              wokeFromNap: wokeFromNap,
            ),
          );
      final settings =
          ref.read(settingsControllerProvider).value ?? const AppSettings();
      if (settings.hapticFeedbackEnabled) {
        try {
          await ref.read(hapticCallbackProvider)();
        } catch (_) {
          // A haptic is confirmation only; persistence already succeeded.
        }
      }
      if (!mounted) return;
      final confirmedLog = (
        type: type,
        wokeFromSleep: wokeFromSleep,
        wokeFromNap: wokeFromNap,
      );
      setState(() => _confirmedLog = confirmedLog);
      _confirmationTimer?.cancel();
      _confirmationTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted && _confirmedLog == confirmedLog) {
          setState(() => _confirmedLog = null);
        }
      });
      _showLoggedConfirmation(event, settings);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the entry. Nothing was logged.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _logging.remove(type));
    }
  }

  void _showLoggedConfirmation(BodyEvent event, AppSettings settings) {
    final detailsEnabled = event.eventType == EventType.urination
        ? settings.urinationDetailsEnabled
        : settings.bowelMovementDetailsEnabled;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: Semantics(
          liveRegion: true,
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                '${event.eventType.displayName} logged: '
                '${event.wokeFromNap == true
                    ? 'Woke from nap'
                    : event.wokeFromSleep == true
                    ? 'Woke from sleep'
                    : 'Awake'}.',
              ),
              if (detailsEnabled)
                TextButton(
                  key: const Key('add_details_action'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.inversePrimary,
                  ),
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    _openEditor(context, event);
                  },
                  child: const Text('Add details'),
                ),
              TextButton(
                key: const Key('undo_log_action'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.inversePrimary,
                ),
                onPressed: () async {
                  messenger.hideCurrentSnackBar();
                  final removed = await ref
                      .read(eventMutationsProvider)
                      .delete(event.id);
                  if (mounted && removed) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Entry undone.')),
                    );
                  }
                },
                child: const Text('Undo'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openManualEntry(BuildContext context) {
    return Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const EventEditorScreen()));
  }

  Future<void> _openEditor(BuildContext context, BodyEvent event) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => EventEditorScreen(event: event)),
    );
  }
}

class _SplitQuickLogCard extends StatelessWidget {
  const _SplitQuickLogCard({
    required this.type,
    required this.busyWokeFromSleep,
    required this.confirmedWokeFromSleep,
    required this.awakeKey,
    required this.wokeFromSleepKey,
    this.napKey,
    this.onNap,
    required this.onLog,
  });

  final EventType type;
  final bool? busyWokeFromSleep;
  final bool? confirmedWokeFromSleep;
  final Key awakeKey;
  final Key wokeFromSleepKey;
  final Key? napKey;
  final VoidCallback? onNap;
  final ValueChanged<bool> onLog;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isUrination = type == EventType.urination;
    final background = isUrination
        ? colors.primaryContainer
        : colors.tertiaryContainer;
    final foreground = isUrination
        ? colors.onPrimaryContainer
        : colors.onTertiaryContainer;
    final busy = busyWokeFromSleep != null;

    return Semantics(
      container: true,
      label: '${type.displayName} quick logging',
      child: Card(
        color: background,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              child: Row(
                children: [
                  Icon(type.icon, size: 34, color: foreground),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      type.displayName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: foreground.withValues(alpha: 0.28),
            ),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _QuickLogOption(
                      key: awakeKey,
                      type: type,
                      wokeFromSleep: false,
                      icon: Icons.light_mode_outlined,
                      label: 'Awake',
                      foreground: foreground,
                      enabled: !busy,
                      busy: busyWokeFromSleep == false,
                      confirmed: confirmedWokeFromSleep == false,
                      onTap: () => onLog(false),
                    ),
                  ),
                  if (napKey != null && onNap != null) ...[
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: foreground.withValues(alpha: 0.28),
                    ),
                    Expanded(
                      child: _QuickLogOption(
                        key: napKey,
                        type: type,
                        wokeFromSleep: true,
                        icon: Icons.airline_seat_flat_outlined,
                        label: 'Woke from nap',
                        foreground: foreground,
                        enabled: !busy,
                        busy: false,
                        confirmed: false,
                        onTap: onNap!,
                      ),
                    ),
                  ],
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: foreground.withValues(alpha: 0.28),
                  ),
                  Expanded(
                    child: _QuickLogOption(
                      key: wokeFromSleepKey,
                      type: type,
                      wokeFromSleep: true,
                      icon: Icons.bedtime_outlined,
                      label: 'Woke from sleep',
                      foreground: foreground,
                      enabled: !busy,
                      busy: busyWokeFromSleep == true,
                      confirmed: confirmedWokeFromSleep == true,
                      onTap: () => onLog(true),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLogOption extends StatelessWidget {
  const _QuickLogOption({
    super.key,
    required this.type,
    required this.wokeFromSleep,
    required this.icon,
    required this.label,
    required this.foreground,
    required this.enabled,
    required this.busy,
    required this.confirmed,
    required this.onTap,
  });

  final EventType type;
  final bool wokeFromSleep;
  final IconData icon;
  final String label;
  final Color foreground;
  final bool enabled;
  final bool busy;
  final bool confirmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label:
          'Log ${type.displayName}, '
          '${wokeFromSleep ? 'woke from sleep' : 'while awake'}',
      hint: 'Creates an entry at the current time',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 92),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: ExcludeSemantics(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (busy)
                      SizedBox.square(
                        dimension: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: foreground,
                        ),
                      )
                    else
                      Icon(
                        confirmed ? Icons.check_circle_outline : icon,
                        size: 32,
                        color: foreground,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      confirmed ? 'Logged' : (busy ? 'Saving...' : 'Log now'),
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: foreground),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeSummary extends StatelessWidget {
  const _HomeSummary({required this.data, required this.nowUtc});

  final HomeData data;
  final DateTime nowUtc;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _CountCard(
            type: EventType.urination,
            count: data.urinationCountToday,
            lastEvent: data.lastUrination,
            nowUtc: nowUtc,
          ),
          _CountCard(
            type: EventType.bowelMovement,
            count: data.bowelMovementCountToday,
            lastEvent: data.lastBowelMovement,
            nowUtc: nowUtc,
          ),
        ];
        final nightWakeups = _NightWakeupsCard(count: data.nocturiaCountToday);
        if (constraints.maxWidth >= 560) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
              const SizedBox(width: 12),
              Expanded(child: nightWakeups),
            ],
          );
        }
        return Column(
          children: [
            cards[0],
            const SizedBox(height: 12),
            cards[1],
            const SizedBox(height: 12),
            nightWakeups,
          ],
        );
      },
    );
  }
}

class _NightWakeupsCard extends StatelessWidget {
  const _NightWakeupsCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.bedtime_outlined, size: 34),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count night ${count == 1 ? 'wake-up' : 'wake-ups'}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text('Woke from night sleep to urinate'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.type,
    required this.count,
    required this.lastEvent,
    required this.nowUtc,
  });

  final EventType type;
  final int count;
  final BodyEvent? lastEvent;
  final DateTime nowUtc;

  @override
  Widget build(BuildContext context) {
    final elapsed = lastEvent == null
        ? null
        : nowUtc.difference(lastEvent!.occurredAtUtc);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(type.icon, size: 34),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count today',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    elapsed == null
                        ? 'No ${type.shortName.toLowerCase()} entries yet'
                        : 'Last ${formatElapsed(elapsed)}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(
              Icons.history,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Your recent entries will appear here.'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Expanded(child: Text('Could not load today’s summary.')),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
