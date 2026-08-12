import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../shared/presentation/event_display.dart';
import '../../settings/domain/app_settings.dart';
import '../domain/body_event.dart';
import '../domain/event_draft.dart';
import '../domain/event_enums.dart';

class EventEditorScreen extends ConsumerStatefulWidget {
  const EventEditorScreen({
    super.key,
    this.event,
    this.initialType = EventType.urination,
  });

  final BodyEvent? event;
  final EventType initialType;

  @override
  ConsumerState<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends ConsumerState<EventEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _notesController;
  late EventType _eventType;
  late DateTime _wallDateTime;
  EventAmount? _amount;
  EventUrgency? _urgency;
  LeakageLevel? _leakage;
  int? _bristolType;
  bool? _wokeFromSleep;
  bool? _wokeFromNap;
  bool _timeWasChanged = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _eventType = event?.eventType ?? widget.initialType;
    final wall = event?.recordedLocalDateTime ?? DateTime.now();
    _wallDateTime = DateTime(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
      wall.second,
    );
    _amount = event?.amount;
    _urgency = event?.urgency;
    _leakage = event?.leakage;
    _bristolType = event?.bristolType;
    _wokeFromSleep = event?.wokeFromSleep;
    _wokeFromNap = event?.wokeFromNap;
    _notesController = TextEditingController(text: event?.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  bool _hasStoredOptionalDetails(BodyEvent? event) {
    return event?.amount != null ||
        event?.urgency != null ||
        event?.leakage != null ||
        event?.bristolType != null ||
        (event?.notes?.isNotEmpty ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(settingsControllerProvider).value ?? const AppSettings();
    final optionalEnabled = _eventType == EventType.urination
        ? settings.urinationDetailsEnabled
        : settings.bowelMovementDetailsEnabled;
    final showOptionalDetails =
        optionalEnabled || _hasStoredOptionalDetails(widget.event);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.event == null ? 'Add an earlier event' : 'Edit event',
        ),
        actions: [
          if (widget.event != null)
            IconButton(
              tooltip: 'Delete event',
              onPressed: _saving ? null : _confirmDelete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                'Event type',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<EventType>(
                segments: EventType.values
                    .map(
                      (type) => ButtonSegment<EventType>(
                        value: type,
                        icon: Icon(type.icon),
                        label: Text(type.displayName),
                      ),
                    )
                    .toList(),
                selected: {_eventType},
                onSelectionChanged: (selection) {
                  setState(() {
                    _eventType = selection.single;
                    if (_eventType == EventType.urination) {
                      _bristolType = null;
                    } else {
                      _leakage = null;
                      _wokeFromNap = null;
                    }
                  });
                },
              ),
              const SizedBox(height: 24),
              Text('When', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: const Text('Date'),
                      trailing: Text(DateFormat.yMMMd().format(_wallDateTime)),
                      onTap: _pickDate,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.schedule_outlined),
                      title: const Text('Time'),
                      trailing: Text(DateFormat.jm().format(_wallDateTime)),
                      onTap: _pickTime,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Sleep context',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<bool?>(
                key: const Key('woke_from_sleep_control'),
                initialValue: _wokeFromSleep,
                decoration: InputDecoration(
                  labelText: _eventType == EventType.urination
                      ? 'Woke from sleep (nocturia)'
                      : 'Woke from sleep',
                  helperText: _eventType == EventType.urination
                      ? 'Choose Yes if the need to urinate woke you. '
                            'It is okay to leave this unrecorded.'
                      : 'Choose Yes if you woke from sleep for this bowel '
                            'movement. It is okay to leave this unrecorded.',
                  helperMaxLines: 2,
                ),
                items: const [
                  DropdownMenuItem<bool?>(
                    value: null,
                    child: Text('Not recorded'),
                  ),
                  DropdownMenuItem<bool?>(
                    value: true,
                    child: Text('Yes', key: Key('woke_from_sleep_yes')),
                  ),
                  DropdownMenuItem<bool?>(
                    value: false,
                    child: Text('No', key: Key('woke_from_sleep_no')),
                  ),
                ],
                onChanged: (value) => setState(() {
                  _wokeFromSleep = value;
                  if (value != true) _wokeFromNap = null;
                }),
              ),
              if (_eventType == EventType.urination) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  key: const Key('woke_from_nap_control'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Woke from nap'),
                  subtitle: const Text(
                    'Counts toward urination, but not nocturia.',
                  ),
                  value: _wokeFromNap == true,
                  onChanged: _wokeFromSleep == true
                      ? (value) => setState(
                          () => _wokeFromNap = value ? true : null,
                        )
                      : null,
                ),
              ],
              if (showOptionalDetails) ...[
                const SizedBox(height: 24),
                Text(
                  'Optional details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<EventAmount?>(
                  initialValue: _amount,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  items: [
                    const DropdownMenuItem<EventAmount?>(
                      value: null,
                      child: Text('Not recorded'),
                    ),
                    ...EventAmount.values.map(
                      (value) => DropdownMenuItem<EventAmount?>(
                        value: value,
                        child: Text(value.displayName),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _amount = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<EventUrgency?>(
                  initialValue: _urgency,
                  decoration: const InputDecoration(labelText: 'Urgency'),
                  items: [
                    const DropdownMenuItem<EventUrgency?>(
                      value: null,
                      child: Text('Not recorded'),
                    ),
                    ...EventUrgency.values.map(
                      (value) => DropdownMenuItem<EventUrgency?>(
                        value: value,
                        child: Text(value.displayName),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _urgency = value),
                ),
                const SizedBox(height: 12),
                if (_eventType == EventType.urination) ...[
                  DropdownButtonFormField<LeakageLevel?>(
                    initialValue: _leakage,
                    decoration: const InputDecoration(labelText: 'Leakage'),
                    items: [
                      const DropdownMenuItem<LeakageLevel?>(
                        value: null,
                        child: Text('Not recorded'),
                      ),
                      ...LeakageLevel.values.map(
                        (value) => DropdownMenuItem<LeakageLevel?>(
                          value: value,
                          child: Text(value.displayName),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _leakage = value),
                  ),
                ] else
                  DropdownButtonFormField<int?>(
                    initialValue: _bristolType,
                    decoration: const InputDecoration(
                      labelText: 'Bristol Stool Scale',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Not recorded'),
                      ),
                      ...List.generate(
                        7,
                        (index) => DropdownMenuItem<int?>(
                          value: index + 1,
                          child: Text('Type ${index + 1}'),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _bristolType = value),
                  ),
                TextFormField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    hintText: 'Optional',
                    alignLabelWithHint: true,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 20),
                Text(
                  'Optional amount, symptom, and note fields are hidden in '
                  'Settings. Time, type, and sleep context can still be edited '
                  'here.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 28),
              FilledButton.icon(
                key: const Key('save_event_button'),
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  widget.event == null ? 'Add event' : 'Save changes',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      initialDate: _wallDateTime.isAfter(now) ? now : _wallDateTime,
    );
    if (selected == null) return;
    setState(() {
      _wallDateTime = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _wallDateTime.hour,
        _wallDateTime.minute,
        _wallDateTime.second,
      );
      _timeWasChanged = true;
    });
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_wallDateTime),
    );
    if (selected == null) return;
    setState(() {
      _wallDateTime = DateTime(
        _wallDateTime.year,
        _wallDateTime.month,
        _wallDateTime.day,
        selected.hour,
        selected.minute,
      );
      _timeWasChanged = true;
    });
  }

  EventDraft _buildDraft() {
    final event = widget.event;
    if (event != null && !_timeWasChanged) {
      return EventDraft(
        eventType: _eventType,
        occurredAtUtc: event.occurredAtUtc,
        utcOffsetMinutes: event.utcOffsetMinutes,
        amount: _amount,
        urgency: _urgency,
        leakage: _eventType == EventType.urination ? _leakage : null,
        wokeFromSleep: _wokeFromSleep,
        wokeFromNap: _wokeFromNap,
        bristolType: _eventType == EventType.bowelMovement
            ? _bristolType
            : null,
        notes: _notesController.text,
        extraDetails: event.extraDetails,
      );
    }
    return EventDraft.fromRecordedLocalDateTime(
      eventType: _eventType,
      recordedLocalDateTime: _wallDateTime,
      amount: _amount,
      urgency: _urgency,
      leakage: _eventType == EventType.urination ? _leakage : null,
      wokeFromSleep: _wokeFromSleep,
      wokeFromNap: _wokeFromNap,
      bristolType: _eventType == EventType.bowelMovement ? _bristolType : null,
      notes: _notesController.text,
      extraDetails: event?.extraDetails,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final now = ref.read(clockProvider)();
    final draft = _buildDraft();
    if (draft.occurredAtUtc.isAfter(now.toUtc())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The event time cannot be in the future.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final mutations = ref.read(eventMutationsProvider);
      if (widget.event == null) {
        await mutations.add(draft);
      } else {
        await mutations.update(widget.event!.id, draft);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the event. Try again.')),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this event?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await ref.read(eventMutationsProvider).delete(widget.event!.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete the event.')),
      );
    }
  }
}
