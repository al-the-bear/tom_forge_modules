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
- **`ForgeActionBar`**: a row of icon buttons in `ForgeActionGroup`s of
  `ForgeActionItem`s (id, icon, label, shortcut text, an enabled
  `ValueListenable<bool>`, `onInvoke`). Each button follows its enablement,
  groups are divided, and the buttons a narrow row cannot hold move into an
  overflow menu. Forge's title-bar action bar is one (the shell maps its
  action ids, the action and shortcut registries and the editors'
  enablement onto items); Webwork's icon bar is meant to be another.
- **`ForgeStatusBar`**: the status bar over `ForgeStatusItem`s — text or
  icon, alignment and priority, an optional `visible` listenable (the bar
  rebuilds when it changes), a colour, emphasis, or a widget of its own
  (`builder`, e.g. a countdown chip) — with an optional `rebuild` listenable
  and progress message. Forge's `StatusBarItem` is a `ForgeStatusItem` with
  an `isActive(ForgeSystemState)` filter; Forge's status bar controllers
  stay in the shell, which reads them from its module and application
  registries and hands the active items to this bar.
- **The shell's overlays and dialogs**: `ForgeInputBoxOverlay` (a text
  prompt at the top of the window, with validation; Enter answers the text,
  Escape or a click outside answers null), `ForgeQuickPickOverlay<T>` over
  `ForgeQuickPickItem<T>`s (a filtered pick list driven by the keyboard),
  `ForgeErrorRecoveryDialog` (retry, cancel and optionally overwrite, as
  `ErrorRecoveryAction`), and `ForgeFocusIndicator` (a focus ring for
  keyboard focus only, in the theme's `focusRing`). The overlays answer
  through a `Completer`; Forge's dialog manager shows them over the shell, an
  application in an `OverlayEntry` of its own.
- **`ForgeFixedListenable`**: a listenable whose value never changes, for an
  item whose state is known when it is built.

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

ForgeActionBar(
  groups: [
    ForgeActionGroup(
      id: 'edit',
      items: [
        ForgeActionItem(
          id: 'copy',
          icon: Icons.copy,
          label: 'Copy',
          shortcut: '⌘C',
          enabled: hasSelection, // a ValueListenable<bool>
          onInvoke: copy,
        ),
      ],
    ),
  ],
);

ForgeStatusBar(
  items: [
    ForgeStatusItem(text: lineAndColumn), // a ValueListenable<String>
    ForgeStatusItem(
      text: const ForgeFixedListenable('Syncing'),
      visible: syncing, // a ValueListenable<bool>
      alignment: StatusBarAlignment.right,
    ),
  ],
);
```

`example/` is a minimal app over the package (an action bar that changes a
counter, a status bar that shows it and a busy item while work runs, the
input box renaming the document and the quick pick setting the count); building it for macOS, the
web, iOS and Android shows the package builds on each.

## License

BSD-3-Clause, see [LICENSE](LICENSE).
