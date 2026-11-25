# tom_forge_core

Published on pub.dev as [`tom_forge_core` 2.0.0](https://pub.dev/packages/tom_forge_core).

Tom Forge's core: the types, service contracts and defaults the shell is
built from, in pure Dart. The file system the shell and its editors work on is
[`tom_file_system`](https://pub.dev/packages/tom_file_system), and the undo
stack under `DefaultUndoManager` is
[`tom_undo`](https://pub.dev/packages/tom_undo).

## What it holds

- **Types** — positions and ranges, diagnostics and their severities,
  decorations, editor options, the events and error codes the shell and its
  editors exchange, a listenable, and the workspace edit.
- **Documents and configuration** — `ForgeDocument`, `ForgeConfig` and the
  search configuration.
- **Configuration descriptions** — what a component can be configured in:
  `ForgeConfigurationDescription`, its `ForgeSettingsSection`s and typed
  `ForgeSetting`s (bool, int, double, string, choice, string list, path,
  colour, string map; `ForgeSettingKinds`), each with its storage location,
  default, constraints and `ForgeText` labels (a resource key with its
  English fallback). See *Configuration descriptions* below.
- **Service contracts** — clipboard, configuration, diagnostics, execution
  monitoring, notifications, output channels, progress, search, secret
  storage, terminals, undo, virtual documents, the performance contract and
  the quality gate: interfaces the Flutter shell (`tom_forge_ui`) implements
  or wires.
- **Defaults** — pure-Dart implementations of most of those services, an LRU
  cache and a retry policy, usable in a test or a headless tool.

Two entry points: `package:tom_forge_core/tom_forge_core.dart` for all of the
above, and `package:tom_forge_core/tom_forge_undo.dart` for the undo manager
alone. Neither reaches Flutter.

## Getting started

```yaml
dependencies:
  tom_forge_core: ^2.0.0
```

## Usage

```dart
import 'package:tom_forge_core/tom_forge_core.dart';

void main() {
  final pos = ForgeTextPosition(line: 1, column: 5);
  print('Position: $pos');
}
```

## Workspace edits

`forgeApplyWorkspaceEdit(fs, edit)` applies a `ForgeWorkspaceEdit` — text
edits by position and file operations, as an editor or a refactoring produces
them — to any `TomFileSystem` as one unit: every change, or, when one fails,
none of them. The file system itself does not know what a workspace edit is.

## `.gitignore` rules

`forgeLoadGitignores(fileSystem, root: folder)` reads every `.gitignore`
under a folder (default: the file system's root) of a `TomFileSystem` — on
disk, in memory or on the web — into one `TomGitignoreSet` from `tom_basics`
(`package:tom_basics/utilities.dart`), which parses and applies the rules;
Forge's part is only the walk. Paths in the set are relative to that folder.
The root's file comes first and deeper ones later, so a nested file decides
inside its folder. The walk never enters `.git`, a link or a folder the rules
already ignore, and passes over a file it cannot read.

```dart
final rules = await forgeLoadGitignores(TomLocalFileSystem('/path/to/ws'));
if (rules.isIgnored('build/output.js', isDirectory: false)) {
  // skip it
}
```

## Context-menu contributions

The pure-Dart model behind the shell's context menus
(`src/types/forge_context_menu.dart`):

- `ForgeContextTarget` — what a menu is opened on: a **kind** the producer
  owns (`forge.explorer.file`, `<module>.<unit>`), opaque **data**, and the
  target's own **items** (`ForgeContextMenuItem`: commands only the producer
  can perform, drawn after the contributed entries).
- `ForgeContextMenuContribution` — a module's declaration that one of its
  actions, named by id, is an entry at targets of a kind: `isApplicable`
  (absent when false), `label` and `unavailableReason` (disabled, with the
  reason as tooltip) all read the target. The shell resolves the action from
  its registry and runs it with the target under
  `ForgeContextTarget.parameterKey`.

A resolved entry is a `ForgeContextMenuEntry` (`src/types/forge_context_menu_entry.dart`):
id, label, enabled, reason, group and `run`; `children` makes it a submenu
(choosing it shows them), `checked` a checkable entry.

The drawing lives in `tom_forge_shared_ui` (`forgeContextMenuItems`,
`showForgeContextMenuEntries`) and `tom_forge_kit` (`ForgeContextMenuController`).

## Configuration descriptions

Every component with options describes them (`src/configuration/`); the
application only decides how they are shown:

- `ForgeConfigurationDescription` — a component's id, title, help and
  sections; `settingById`, `sectionById`, `contains`, and
  `problems({hooks})`, which lists for its author what is wrong with it (an
  id twice, two settings at one storage location, a default that breaks its
  own constraints, a condition on a setting it lacks, a hook the registry
  lacks).
- `ForgeSettingsSection` — the settings shown together (an application shows
  each as one tile): title, help, icon (`ForgeIconRef`, a glyph as data),
  `order` among all sections (`forgeOrderedSections`); its `entries` are
  settings and `ForgeSettingsGroup`s (a header with settings under it).
- `ForgeSetting<T>` — one typed entry: where its value is kept
  (`ForgeSettingStorage`: a document key and a path of map keys inside the
  document, so several settings share one document; the state store, or the
  `ForgeSettingBinding` it names; `none()` for an entry without a value),
  its label, help, default, `visibleWhen` / `enabledWhen`, `actions`, and
  `decode`, `encode`, `validate`, `check` and `read` (a stored value it
  refuses leaves the default in effect, with the reason). A new kind is a
  subclass with a kind id of its own and an editor registered under it.
- `ForgeText` — a user-visible string as a resource key with its English
  fallback and `{name}` parameters; `resolve(lookup)` fills it from any
  lookup; `ForgeText.literal` is never looked up. The validation messages
  are `ForgeConfigurationTexts` (`forge.configuration.validation.*`,
  `forge.configuration.hook.*`).

### The kinds and their stored form

| Kind | Class | Stored as |
| ---- | ----- | --------- |
| `bool`, `int`, `double` | `ForgeBoolSetting`, `ForgeIntSetting`, `ForgeDoubleSetting` | the value; numbers may be shown scaled (`scale`, `unit`) |
| `string`, `path`, `fontFamily` | `ForgeStringSetting`, `ForgePathSetting`, `ForgeFontFamilySetting` | the text; fonts offered by a choices provider |
| `choice` | `ForgeChoiceSetting` | the value; fixed choices and a `choicesProvider`, *none* as `""` |
| `stringList` | `ForgeStringListSetting` | a list (JSON text read too) |
| `color` | `ForgeColorSetting` | `#RRGGBB` / `#AARRGGBB` |
| `stringMap` | `ForgeStringMapSetting` | a map; keys normalised, laid over the defaults, `*` for every other key (`forge.files.typeDefaults`) |
| `keyBinding` | `ForgeKeyBindingSetting` | `{keyId, primaryModifier, control, shift, alt}` |
| `keyChord` | `ForgeKeyChordSetting` | `{firstKey, secondKey, moreKeys}` |
| `keyBindingTable` | `ForgeKeyBindingTableSetting` | action id → stroke (`forge.shortcuts.overrides`) or chord (`forge.shortcuts.chordOverrides`); deleted ids as a companion list (`forge.shortcuts.deletedBindings`) |
| `toolPath` | `ForgeToolPathSetting` | the path; empty not stored (`forge.tools.<id>.path`) |
| `action`, `status` | `ForgeActionSetting`, `ForgeStatusSetting` | nothing |
| `date`, `time`, `dateTime` | `ForgeDateSetting`, `ForgeTimeSetting`, `ForgeDateTimeSetting` | `YYYY-MM-DD`, `HH:MM`, ISO 8601 (`…Z` in UTC); none as `""` |

A key binding table's rows come from `forgeKeyBindingRows` (the catalogue's
defaults with the overrides and deletions laid over them) and its conflicts
from `forgeKeyBindingConflicts` (same keys in overlapping scopes, a binding
that begins another's chord; primary modifier and Control are the same keys
off macOS; `*.<suffix>` and its editors' actions are one family).

### Behaviour: hooks

A description stays const data: a setting names the behaviour it uses by
id, and the application or a module supplies it at run time in a
`ForgeSettingHooks` registry — `ForgeSettingAction` (a button: `run` →
`ForgeActionResult`), `ForgeSettingFlow` (a multi-step interaction such as a
sign-in or a one-time code: `ForgeFlowSession` answers `ForgeFlowStep`s the
UI draws), `ForgeSettingDetector` (`check` / `detect` a tool with
`ForgeDetectionHints`), `ForgeChoicesProvider`, `ForgeSettingStatusProvider`
(`current`, `watch`) and `ForgeActionCatalogue`. Each has a `ForgeCallback…`
form. A hook runs with a `ForgeSettingContext` and answers data; nothing
here depends on Flutter.

`tom_forge_kit` collects the descriptions and hooks of the registered modules
and keeps the values through its state-store port or the application's
bindings (`ForgeConfigurationValues`), from which the hooks run;
`tom_configuration_ui` draws a section as a tile.

## License

BSD-3-Clause — See [LICENSE](LICENSE) for details.

## Undo and redo

`ForgeUndoManager` is the shell's undo contract and `DefaultUndoManager` its
implementation, with `CompositeUndoEntry` for a `beginUndoGroup` /
`endUndoGroup` block; both run on `tom_undo`'s `TomUndoStack` and
`tomApplyAllAsync`. They are in **`package:tom_forge_core/tom_forge_undo.dart`**,
which reaches no `dart:io` and no Flutter.

An editor keeps its history on that stack rather than its own list.
