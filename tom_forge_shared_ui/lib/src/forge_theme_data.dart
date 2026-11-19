import 'package:flutter/material.dart';

import 'forge_shell_theme.dart';

/// The Material theme of a Forge application with [ForgeShellTheme]
/// installed in its `extensions:`: [ForgeShellTheme.light] or
/// [ForgeShellTheme.dark] for [brightness], [ForgeShellTheme.highContrast]
/// (on a dark colour scheme, as its tokens are) when [highContrast] is set.
///
/// An application hands `MaterialApp` one for each slot, so the
/// user's [ThemeMode] and the platform decide among them:
///
/// ```dart
/// MaterialApp(
///   themeMode: preferences.themeMode,
///   theme: forgeThemeData(Brightness.light, highContrast: preferences.highContrast),
///   darkTheme: forgeThemeData(Brightness.dark, highContrast: preferences.highContrast),
///   highContrastTheme: forgeThemeData(Brightness.light, highContrast: true),
///   highContrastDarkTheme: forgeThemeData(Brightness.dark, highContrast: true),
/// )
/// ```
ThemeData forgeThemeData(
  Brightness brightness, {
  bool highContrast = false,
  Color seedColor = Colors.blue,
}) {
  final shellTheme = highContrast
      ? ForgeShellTheme.highContrast()
      : ForgeShellTheme.forMode(
          brightness == Brightness.light ? ThemeMode.light : ThemeMode.dark,
        );
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: highContrast ? Brightness.dark : brightness,
    ),
    useMaterial3: true,
    extensions: <ThemeExtension<dynamic>>[shellTheme],
  );
}
