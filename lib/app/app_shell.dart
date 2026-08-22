import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import '../features/settings/domain/app_settings.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/terms_of_use_screen.dart';
import '../features/trends/presentation/trends_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;
  bool _termsPromptScheduled = false;

  static const _screens = <Widget>[
    HomeScreen(),
    HistoryScreen(),
    TrendsScreen(),
    SettingsScreen(),
  ];

  void _scheduleTermsPrompt(AppSettings settings) {
    if (settings.termsAccepted || _termsPromptScheduled) return;
    _termsPromptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => const TermsOfUseScreen(requireAcceptance: true),
        ),
      );
      if (!mounted) return;
      _termsPromptScheduled = false;
      final current = ref.read(settingsControllerProvider).value;
      if (current != null && !current.termsAccepted) {
        _scheduleTermsPrompt(current);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider).value;
    if (settings != null) _scheduleTermsPrompt(settings);
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: 'Log',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Trends',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
