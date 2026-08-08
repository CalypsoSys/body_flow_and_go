import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/domain/app_settings.dart';
import 'app_shell.dart';
import 'providers.dart';
import 'theme.dart';

class BodyFlowAndGoApp extends ConsumerWidget {
  const BodyFlowAndGoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference =
        ref.watch(settingsControllerProvider).value?.themePreference ??
        AppThemePreference.system;
    final themeMode = switch (preference) {
      AppThemePreference.system => ThemeMode.system,
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.dark => ThemeMode.dark,
    };

    return MaterialApp(
      title: 'Body Flow & Go',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      home: const AppShell(),
    );
  }
}
