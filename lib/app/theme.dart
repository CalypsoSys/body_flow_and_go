import 'package:flutter/material.dart';

const _lightSeed = Color(0xFF28656A);
const _darkSeed = Color(0xFF83CDD0);

ThemeData buildLightTheme() => _buildTheme(
  ColorScheme.fromSeed(
    seedColor: _lightSeed,
    brightness: Brightness.light,
    surface: const Color(0xFFF8FAF8),
  ),
);

ThemeData buildDarkTheme() => _buildTheme(
  ColorScheme.fromSeed(
    seedColor: _darkSeed,
    brightness: Brightness.dark,
    surface: const Color(0xFF111616),
  ),
);

ThemeData _buildTheme(ColorScheme colors) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    visualDensity: VisualDensity.standard,
  );

  return base.copyWith(
    scaffoldBackgroundColor: colors.surface,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
      titleTextStyle: base.textTheme.headlineSmall?.copyWith(
        color: colors.onSurface,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colors.surfaceContainerLow,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerLowest,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      labelTextStyle: WidgetStatePropertyAll(
        base.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(color: colors.outlineVariant),
  );
}
