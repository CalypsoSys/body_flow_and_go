import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/time/calendar_date.dart';
import '../../../shared/presentation/event_display.dart';
import '../../../shared/presentation/event_tile.dart';
import '../../events/domain/body_event.dart';
import '../../events/domain/event_enums.dart';
import '../../events/presentation/event_editor_screen.dart';

enum _HistoryTypeFilter { both, urination, bowelMovement }

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _HistoryTypeFilter _typeFilter = _HistoryTypeFilter.both;
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(allEventsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            tooltip: 'Add an earlier event',
            onPressed: _openManualEntry,
            icon: const Icon(Icons.add_alarm_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openManualEntry,
        icon: const Icon(Icons.add),
        label: const Text('Add earlier'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildFilters(context),
            const Divider(height: 1),
            Expanded(
              child: events.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => _HistoryError(
                  onRetry: () => ref.invalidate(allEventsProvider),
                ),
                data: (allEvents) {
                  final filtered = _filterEvents(allEvents);
                  if (filtered.isEmpty) {
                    return const _EmptyHistory();
                  }
                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(allEventsProvider.future),
                    child: _GroupedHistoryList(
                      events: filtered,
                      onEventTap: _openEditor,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Both'),
            selected: _typeFilter == _HistoryTypeFilter.both,
            onSelected: (_) =>
                setState(() => _typeFilter = _HistoryTypeFilter.both),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            avatar: const Icon(Icons.water_drop_outlined, size: 18),
            label: const Text('Urination'),
            selected: _typeFilter == _HistoryTypeFilter.urination,
            onSelected: (_) =>
                setState(() => _typeFilter = _HistoryTypeFilter.urination),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            avatar: const Icon(Icons.circle_outlined, size: 18),
            label: const Text('Bowel'),
            selected: _typeFilter == _HistoryTypeFilter.bowelMovement,
            onSelected: (_) =>
                setState(() => _typeFilter = _HistoryTypeFilter.bowelMovement),
          ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.date_range_outlined, size: 18),
            label: Text(_dateRangeLabel()),
            onPressed: _pickDateRange,
          ),
          if (_dateRange != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Clear date range',
              onPressed: () => setState(() => _dateRange = null),
              icon: const Icon(Icons.close),
            ),
          ],
        ],
      ),
    );
  }

  String _dateRangeLabel() {
    final range = _dateRange;
    if (range == null) return 'Any date';
    final start = DateFormat.MMMd().format(range.start);
    final end = DateFormat.MMMd().format(range.end);
    return start == end ? start : '$start – $end';
  }

  List<BodyEvent> _filterEvents(List<BodyEvent> events) {
    final from = _dateRange == null
        ? null
        : CalendarDate.fromRecordedWallDate(_dateRange!.start);
    final through = _dateRange == null
        ? null
        : CalendarDate.fromRecordedWallDate(_dateRange!.end);

    return events
        .where((event) {
          final typeMatches = switch (_typeFilter) {
            _HistoryTypeFilter.both => true,
            _HistoryTypeFilter.urination =>
              event.eventType == EventType.urination,
            _HistoryTypeFilter.bowelMovement =>
              event.eventType == EventType.bowelMovement,
          };
          final dateMatches =
              (from == null || event.localDate.compareTo(from) >= 0) &&
              (through == null || event.localDate.compareTo(through) <= 0);
          return typeMatches && dateMatches;
        })
        .toList(growable: false);
  }

  Future<void> _pickDateRange() async {
    final now = ref.read(clockProvider)();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      initialDateRange: _dateRange,
      helpText: 'Filter history by date',
    );
    if (selected != null) setState(() => _dateRange = selected);
  }

  Future<void> _openManualEntry() {
    return Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const EventEditorScreen()));
  }

  Future<void> _openEditor(BodyEvent event) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => EventEditorScreen(event: event)),
    );
  }
}

class _GroupedHistoryList extends StatelessWidget {
  const _GroupedHistoryList({required this.events, required this.onEventTap});

  final List<BodyEvent> events;
  final ValueChanged<BodyEvent> onEventTap;

  @override
  Widget build(BuildContext context) {
    final groups = <CalendarDate, List<BodyEvent>>{};
    for (final event in events) {
      groups.putIfAbsent(event.localDate, () => []).add(event);
    }
    final dates = groups.keys.toList()
      ..sort((left, right) => right.compareTo(left));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
      itemCount: dates.length,
      itemBuilder: (context, index) {
        final date = dates[index];
        final dayEvents = groups[date]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  formatCalendarDate(date),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (
                      var eventIndex = 0;
                      eventIndex < dayEvents.length;
                      eventIndex++
                    ) ...[
                      EventTile(
                        event: dayEvents[eventIndex],
                        onTap: () => onEventTap(dayEvents[eventIndex]),
                      ),
                      if (eventIndex < dayEvents.length - 1)
                        const Divider(height: 1, indent: 64),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 54,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No matching entries',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Try another filter, or add an earlier event.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Try loading history again'),
      ),
    );
  }
}
