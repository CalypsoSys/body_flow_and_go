import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../export/domain/export_format.dart';
import '../../feedback/presentation/feedback_screen.dart';
import '../domain/app_settings.dart';
import 'privacy_screen.dart';

const _appVersion = String.fromEnvironment(
  'BODY_FLOW_AND_GO_APP_VERSION',
  defaultValue: '1.0.1+3',
);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _exporting = false;
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final settingsValue = ref.watch(settingsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        top: false,
        child: settingsValue.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: FilledButton.icon(
              onPressed: () => ref.invalidate(settingsControllerProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Try loading settings again'),
            ),
          ),
          data: (settings) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              const _SectionHeading('Logging details'),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.water_drop_outlined),
                      title: const Text('Urination details'),
                      subtitle: const Text(
                        'Amount, leakage, urgency, sleep context, and notes',
                      ),
                      value: settings.urinationDetailsEnabled,
                      onChanged: (value) => _saveSettings(
                        settings.copyWith(urinationDetailsEnabled: value),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    SwitchListTile(
                      secondary: const Icon(Icons.circle_outlined),
                      title: const Text('Bowel movement details'),
                      subtitle: const Text(
                        'Bristol type, amount, urgency, sleep context, and notes',
                      ),
                      value: settings.bowelMovementDetailsEnabled,
                      onChanged: (value) => _saveSettings(
                        settings.copyWith(bowelMovementDetailsEnabled: value),
                      ),
                    ),
                  ],
                ),
              ),
              const _SectionHeading('Feedback & appearance'),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.vibration_outlined),
                      title: const Text('Haptic feedback'),
                      subtitle: const Text('Confirm successful one-tap logs'),
                      value: settings.hapticFeedbackEnabled,
                      onChanged: (value) => _saveSettings(
                        settings.copyWith(hapticFeedbackEnabled: value),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.brightness_6_outlined),
                      title: const Text('Theme'),
                      subtitle: Text(_themeLabel(settings.themePreference)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _chooseTheme(settings),
                    ),
                  ],
                ),
              ),
              const _SectionHeading('Your data'),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.table_view_outlined),
                      title: const Text('Export CSV'),
                      subtitle: const Text('Spreadsheet-friendly record list'),
                      trailing: _exporting
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.ios_share_outlined),
                      enabled: !_exporting && !_deleting,
                      onTap: () => _export(ExportFormat.csv),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.data_object_outlined),
                      title: const Text('Export JSON'),
                      subtitle: const Text('Complete structured backup'),
                      trailing: _exporting
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.ios_share_outlined),
                      enabled: !_exporting && !_deleting,
                      onTap: () => _export(ExportFormat.json),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: Icon(
                        Icons.delete_forever_outlined,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        'Delete all data',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      subtitle: const Text('Permanently remove every event'),
                      enabled: !_deleting && !_exporting,
                      onTap: _confirmDeleteAll,
                    ),
                  ],
                ),
              ),
              const _SectionHeading('About'),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      key: const Key('send_feedback_tile'),
                      leading: const Icon(Icons.feedback_outlined),
                      title: const Text('Send feedback'),
                      subtitle: const Text('Optional message to the developer'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => const FeedbackScreen(),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.shield_outlined),
                      title: const Text('Privacy information'),
                      subtitle: const Text('Local storage and data handling'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => const PrivacyScreen(),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Body Flow & Go $_appVersion'),
                      subtitle: Text(
                        'Personal tracking tool — not medical diagnosis',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveSettings(AppSettings settings) async {
    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .saveSettings(settings);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save that setting.')),
      );
    }
  }

  Future<void> _chooseTheme(AppSettings settings) async {
    final selection = await showModalBottomSheet<AppThemePreference>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Choose theme',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            for (final preference in AppThemePreference.values)
              ListTile(
                leading: Icon(
                  preference == settings.themePreference
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(_themeLabel(preference)),
                onTap: () => Navigator.pop(context, preference),
              ),
          ],
        ),
      ),
    );
    if (selection != null) {
      await _saveSettings(settings.copyWith(themePreference: selection));
    }
  }

  String _themeLabel(AppThemePreference preference) => switch (preference) {
    AppThemePreference.system => 'Use device setting',
    AppThemePreference.light => 'Light',
    AppThemePreference.dark => 'Dark',
  };

  Future<void> _export(ExportFormat format) async {
    setState(() => _exporting = true);
    try {
      final events = await ref.read(eventRepositoryProvider).allForExport();
      if (!mounted) return;
      final renderObject = context.findRenderObject();
      Rect? origin;
      if (renderObject is RenderBox && renderObject.hasSize) {
        origin = renderObject.localToGlobal(Offset.zero) & renderObject.size;
      }
      await ref
          .read(exportServiceProvider)
          .exportAndShare(
            format: format,
            events: events,
            exportedAt: ref.read(clockProvider)().toUtc(),
            sharePositionOrigin: origin,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create the export.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('Delete every event?'),
        content: const Text(
          'All urination and bowel movement records will be permanently '
          'deleted from this device. Settings will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    try {
      final result = await ref.read(eventMutationsProvider).deleteAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result == DeleteAllEventsResult.complete
                  ? 'All event data was deleted.'
                  : 'Events were deleted, but cached exports could not be '
                        'cleared.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete the data.')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
