<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages).
-->

TODO: Put a short description of the package here that helps potential users
know whether this package might be useful for them.

## Features

TODO: List what your package can do. Maybe include images, gifs, or videos.

## Getting started

TODO: List prerequisites and provide or point to information on how to
start using the package.

## Usage

TODO: Include short and useful examples for package users. Add longer examples
to `/example` folder.

```dart
const like = 'sample';
```

## Context menus

The shell draws every module's context-menu contributions
(`ForgeModule.contextMenus`, the `tom_forge_core` model). `shell.contextMenus`
is a `ForgeContextMenuController`: `entriesFor(target)` resolves the
contributions keyed by a target's kind — in module order, grouped, each enabled
by the contribution's predicate and carrying its unavailable reason as a
tooltip while disabled, then the target's own items — and `show(target,
position)` has the mounted `ForgeShellScaffold` draw them. An editor says what
is under the pointer by implementing `ForgeContextTargetProvider`
(`contextTargetAt`, asked on a secondary tap in the editor area before the
generic Cut/Copy/Paste menu), or reports a unit it already handles the
right-click for through `show`. The built-in `ForgeFileExplorerView` appends
the contributions for `ForgeContextTarget.explorerFileKind` /
`explorerDirectoryKind` to its row menu when given `contextMenus:`. Entries
carry the key `forge-context-menu:<id>`. Guideline:
`../_copilot_guidelines/context_menu_contributions.md`; test:
`test/widgets/module_context_menu_test.dart`.

## External tools

The Configuration panel's *External Tools* section has one row per external
tool Forge uses (LibreOffice, later pandoc, Graphviz, ...): its path, the
detected version and state, *Save*, *Choose…*, *Check again* and
*Auto-detect* (every copy a wider search finds, with version and state, to
pick one). `tom_forge_ui` knows no tool: the module that owns one returns a
`ForgeExternalTool` descriptor from `ForgeModule.externalTools` (`id`, `name`,
`order` — LibreOffice is 0 —, `check(path)`, `autoDetect()`, the path hint and
download page). The path is kept as `forge.tools.<id>.path` in
`ForgePreferencesService` (`externalToolPath`, `setExternalToolPath`; empty
means the tool's detection searches), where the module's own detection reads
it (`ForgePreferencesService.instance.externalToolPath(id)`). Debug trail:
`kForgeExternalToolsDebug`, prefix `[FT]`; tests:
`test/widgets/external_tools_section_test.dart`.

## Platform support

Desktop and mobile. **Not the web**, and the reason is architectural rather than
a missing port — measured by `flutter build web` over `tom_forge_ui_test` on
2026-09-17, which dart2js refuses with the import chain it names itself:

```
main.dart
  => package:tom_forge_ui/tom_forge_ui.dart
  => src/widgets/forge_chord_overlay.dart
  => src/widgets/forge_shell_scaffold.dart
  => src/defaults/default_shell_api.dart
  => src/defaults/pty_terminal.dart
  => package:flutter_pty/flutter_pty.dart
  => dart:ffi
Error: Dart library 'dart:ffi' is not available on this platform.
```

`dart:ffi` is in **no** dart2js target of either `libraries.json` — unlike
`dart:io`, which is declared and merely throws at run time (see
`tom_dart_editor/README.md`, "Why `dart:io` compiles for the web and `dart:ffi`
does not"). So this is a real absence, not a stub.

And the thing behind it is a **pty**: `default_shell_api.dart` gives the shell a
real terminal, and a browser tab has no pseudo-terminal to give it. This is a
D33 §3.6 platform-matrix fact, not a defect to patch around — reaching web would
mean the shell's default terminal becoming optional, which is a product
decision about what a Forge shell *is*.

The editors it hosts are not affected and each proves it: `tom_dart_editor`,
`tom_md_editor`, `tom_yaml_editor` and `tom_flow_editor` all carry a default-on
`flutter build web` test (`package:tom_web_build_probe`). The forked
`flutter_inappwebview` under `tom_editors_shared`, long suspected of being the
web blocker, compiles — it is in `tom_dart_editor`'s green closure.

## Additional information

TODO: Tell users more about the package: where to find more information, how to
contribute to the package, how to file issues, what response they can expect
from the package authors, and more.
