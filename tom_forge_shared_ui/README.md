# Tom Forge Shared UI

The look Forge's shell and the applications beside it share, without the
shell itself:

- **`ForgeShellTheme`**: the shell's colour tokens as a `ThemeExtension`
  (panel surface and divider, active tab, drop zones, section header, status
  bar, chord popup, shortcut keys, focus ring) in three sets: `dark()`,
  `light()` and `highContrast()`. `ForgeShellTheme.forMode(mode,
  platformBrightness:, highContrast:)` picks one; `ThemeMode.system` follows
  the platform's brightness.
- **`forgeThemeData(brightness, highContrast:)`**: a Material `ThemeData`
  with the matching shell theme in its `extensions:`.
- **`ForgeDimensions`**: panel sizes, bar heights, divider hit target, icon
  sizes.
- **`ForgeAnimations`**: transition durations and curves, all zero and
  linear while `reduceMotion` is set.

It depends on Flutter and `tom_ui_support` only: no terminal, no editors, no
webview, no native plugin, so it builds for every Flutter platform, the web
included. `tom_forge_shell` depends on it and re-exports it, so code that
imports `package:tom_forge_shell` or `package:tom_forge_ui` sees the same
names; Webwork takes it without the shell.

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart';

MaterialApp(
  themeMode: ThemeMode.system,
  theme: forgeThemeData(Brightness.light),
  darkTheme: forgeThemeData(Brightness.dark),
  highContrastTheme: forgeThemeData(Brightness.light, highContrast: true),
  highContrastDarkTheme: forgeThemeData(Brightness.dark, highContrast: true),
  home: Builder(
    builder: (context) {
      final shell = Theme.of(context).extension<ForgeShellTheme>()!;
      return ColoredBox(color: shell.panelSurface);
    },
  ),
);
```

`example/` is a minimal app over the package; building it for macOS, the
web, iOS and Android shows the package builds on each.

## License

BSD-3-Clause, see [LICENSE](LICENSE).
