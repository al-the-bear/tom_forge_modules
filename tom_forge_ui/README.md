# Tom Forge UI

Forge's panel shell with everything a desktop Forge needs, as one library.
`package:tom_forge_ui/tom_forge_ui.dart` re-exports five packages:

| Package | What it is | Depends on |
| --- | --- | --- |
| `tom_forge_shell` | The shell core: `ForgeShellApi` and its default services, the scaffold, panels, tab bar, menus, command palette, configuration, the built-in views and the plain-text editor; builds for the web | Flutter, `tom_forge_core`, `tom_editors_shared` (webview-free), `tom_file_system`, `tom_file_session`, `shared_preferences` |
| `tom_forge_terminal` | PTY-backed and process-backed terminals and the terminal view | the core, `flutter_pty`, the `xterm` fork |
| `tom_forge_code_editors` | The Markdown, Dart and YAML editor adapters, the Dart outline provider, and the editor types the layout controller opens those files with | the core, `tom_md_editor`, `tom_dart_editor`, `tom_yaml_editor` |
| `tom_forge_platform_secrets` | Secret storage in the platform keychain | the core, `flutter_secure_storage` |
| `tom_forge_desktop_host` | The native file dialogs, the machine's shells and folders, the workspace folder above a picked folder, `.forge/` kept out of git, the workspace folder selector | the core, `file_picker`, `file_selector`, `dart:io` |

The core builds without the other four, for the web too: without them a
shell has no terminals, keeps secrets in memory, opens every file as plain
text and picks no files or folders. They plug in as `ForgeShellComponents` —
a terminal-manager factory, a terminal view, a secret-storage factory, editor
types, the file pickers, the host environment — which a shell takes when it is
made:

```dart
import 'package:tom_forge_ui/tom_forge_ui.dart';

// Hand one shell its parts ...
final shell = DefaultShellApi.withDefaultsAndFileSystem(
  fileSystem: fileSystem,
  appName: 'My Forge',
  navigatorKey: navigatorKey,
  components: forgeDesktopComponents,
);

// ... or register them once at start, for every shell made afterwards.
void main() {
  useForgeDesktopComponents();
  runApp(const MyApp());
}
```

A test package registers them in its `test/flutter_test_config.dart`
(`useForgeDesktopComponents()` in `testExecutable`), as this package's own
suites do. A host that wants the shell where the terminal or the editors do
not build depends on `tom_forge_shell` alone and registers only the parts it
has.

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

## Find in non-text editors

The shell's find bar (`editor.find`, Cmd+F) serves text editors and every
editor that implements `ForgeFindTarget`: `find(query, caseSensitive:,
wholeWord:)`, `findNext`, `findPrevious`, `clearFind` and a `findStatus`
(`ForgeFindStatus`: current match, total, searching) the bar's counter shows.
For such an editor Find is enabled, the query goes to the editor as it is
typed, next and previous move its matches, Replace is not offered, and closing
the bar (or switching to another editor) clears its search. An editor whose
own keys catch Cmd+F runs the shell's `editor.find` action. Test:
`test/widgets/find_target_test.dart`.

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
