# Tom Forge UI Test Application — Specification

**Version:** 1.0  
**Date:** 2025-07-23  
**Project:** `tom_forge_ui_test`  
**Dependencies:** `tom_forge_ui`, `tom_forge_core`, `tom_editors_shared`, `tom_md_editor`, `tom_dart_editor`, `tom_yaml_editor`  
**Companion:** [forge_panel_shell_concept.md](forge_panel_shell_concept.md), [forge_panel_shell_spec.md](forge_panel_shell_spec.md)

---

## Table of Contents

1. [Purpose and Scope](#1-purpose-and-scope)
2. [Application Overview](#2-application-overview)
3. [Architecture](#3-architecture)
4. [Shell Implementation](#4-shell-implementation)
5. [Service Implementations](#5-service-implementations)
6. [Views](#6-views)
7. [Editor Integration](#7-editor-integration)
8. [Layout and Panels](#8-layout-and-panels)
9. [Status Bar](#9-status-bar)
10. [Actions and Shortcuts](#10-actions-and-shortcuts)
11. [Sample Workspace](#11-sample-workspace)
12. [Implementation Phases](#12-implementation-phases)
13. [File Inventory](#13-file-inventory)

---

## 1. Purpose and Scope

### 1.1 Goals

The Tom Forge UI Test Application is a **minimal but functional demo IDE** that exercises the complete `tom_forge_ui` shell interface stack. It serves as:

- A **visual integration test** — verifying that all shell interfaces, editor adapters, service contracts, and layout behaviors work together in a running Flutter application.
- A **developer playground** — allowing interactive exploration of panel layouts, editor switching, file browsing, and service interactions.
- A **reference implementation** — demonstrating how to wire up concrete implementations of the abstract shell API for downstream adopters.

### 1.2 Non-Goals

- **Production quality UI** — The test app uses basic Material widgets. Polished theming, custom drawing, and accessibility compliance are out of scope.
- **Persistence across restarts** — State is ephemeral. No preferences, recent files, or layout persistence.
- **Plugin/module hot-loading** — Modules are registered at startup; no dynamic install/uninstall flow.
- **Full file system** — Uses an in-memory virtual file system seeded with sample files. No native OS file I/O.

---

## 2. Application Overview

### 2.1 What the User Sees

On launch, the test app presents a single-window IDE layout:

```
┌──────────────────────────────────────────────────────────┐
│  Title Bar: "Tom Forge Test IDE"            [─] [□] [×]  │
├──────────────────────────────────────────────────────────┤
│  Menu Bar: File │ Edit │ View │ Help                     │
├──────┬───────────────────────────────────┬───────────────┤
│      │  Tab Bar: [README.md ×] [main.d…] │              │
│  F   │ ─────────────────────────────────  │  Outline     │
│  i   │                                    │  ─────────── │
│  l   │      Editor Area                   │  # Heading 1 │
│  e   │      (active editor widget)        │    ## Sub    │
│      │                                    │    ## Sub    │
│  E   │                                    │              │
│  x   │                                    │              │
│  p   │                                    │              │
│  l   │                                    │              │
│  o   │                                    │              │
│  r   │                                    │              │
│  e   │                                    │              │
│  r   │                                    │              │
├──────┴───────────────────────────────────┴───────────────┤
│  Bottom: [Output] [Problems] [Search]                    │
│  > Output channel log lines …                            │
├──────────────────────────────────────────────────────────┤
│  Status Bar: Ln 12, Col 5 │ UTF-8 │ Markdown │ 0 errors │
└──────────────────────────────────────────────────────────┘
```

### 2.2 Supported Interactions

| Interaction | Description |
|-------------|-------------|
| **File Explorer** | Tree view of the virtual workspace. Click a file to open it in the appropriate editor. |
| **Open multiple files** | Each opened file appears as a tab in the middle panel. Click tabs to switch. |
| **Editor split** | Split the editor area into 2 side-by-side panels (via menu or action). |
| **Close editors** | Close button on tabs. Dirty indicator shown if file is modified. |
| **Outline view** | Right panel showing document outline (headings for Markdown, symbols for Dart, keys for YAML). |
| **Problems view** | Bottom panel tab listing diagnostics from all open editors. |
| **Output view** | Bottom panel tab showing log output from shell operations. |
| **Search view** | Bottom panel tab with workspace-wide text search and results list. |
| **Notifications** | Toast-style notifications for operations (file saved, errors). |
| **Status bar** | Cursor position, encoding, language, diagnostic count. |

---

## 3. Architecture

### 3.1 Package Dependencies

```
tom_forge_ui_test
├── tom_forge_ui          (shell interfaces, adapters, test module)
│   ├── tom_forge_core    (core types: positions, ranges, diagnostics, documents)
│   ├── tom_editors_shared (ForgeDocumentAdapter, PositionConverter)
│   ├── tom_md_editor     (MdEditor, MdEditorController)
│   ├── tom_dart_editor   (DartCodeEditor, DartCodeController)
│   └── tom_yaml_editor   (YamlSchemaEditor, YamlEditorController)
└── flutter (sdk)
```

### 3.2 Module Structure

The test app registers **two modules** with the shell:

1. **`TomForgeShellModule`** (from `tom_forge_ui`) — Contributes the three editor adapters (Markdown, Dart, YAML).
2. **`TestAppModule`** (new, in test app) — Contributes the views (File Explorer, Outline, Problems, Output, Search) and test-app-specific actions.

### 3.3 Source Layout

```
tom_forge_ui_test/lib/
├── main.dart                          # Entry point
├── src/
│   ├── app.dart                       # ForgeTestApp widget (MaterialApp)
│   ├── shell/
│   │   ├── test_shell_api.dart        # Concrete ForgeShellApi
│   │   ├── test_layout_controller.dart # Concrete ForgeLayoutController
│   │   ├── test_system_state.dart     # Concrete ForgeSystemState
│   │   ├── test_module_registry.dart  # Concrete ForgeModuleRegistry
│   │   └── test_status_bar.dart       # Concrete ForgeStatusBarController
│   ├── services/
│   │   ├── memory_file_system.dart    # In-memory TomFileSystem
│   │   ├── test_dialog_manager.dart   # ForgeDialogManager (Material dialogs)
│   │   ├── test_notification_manager.dart
│   │   ├── test_diagnostic_manager.dart
│   │   ├── test_output_manager.dart
│   │   ├── test_search_manager.dart
│   │   ├── test_clipboard.dart
│   │   ├── test_config_manager.dart
│   │   ├── test_progress_manager.dart
│   │   ├── test_undo_manager.dart
│   │   ├── test_outline_manager.dart
│   │   └── stub_services.dart         # Minimal stubs for remaining services
│   ├── views/
│   │   ├── file_explorer_view.dart    # ForgeView: tree-based file browser
│   │   ├── problems_view.dart         # ForgeView: diagnostic list
│   │   ├── output_view.dart           # ForgeView: output channel log
│   │   ├── search_view.dart           # ForgeView: workspace search
│   │   └── outline_view.dart          # ForgeView: document outline
│   ├── module/
│   │   └── test_app_module.dart       # ForgeModule for views + actions
│   ├── widgets/
│   │   ├── shell_scaffold.dart        # Main scaffold wiring panels together
│   │   ├── panel_widget.dart          # Sidebar/bottom panel with accordeon tabs
│   │   ├── editor_tab_bar.dart        # Middle panel tab bar
│   │   ├── status_bar_widget.dart     # Bottom status bar
│   │   └── notification_overlay.dart  # Toast overlay for notifications
│   └── sample/
│       └── workspace_seed.dart        # Sample file content constants
```

---

## 4. Shell Implementation

### 4.1 `TestShellApi`

Concrete implementation of `ForgeShellApi`. Constructed in `main.dart` and passed down via `InheritedWidget` or direct constructor injection.

```dart
class TestShellApi implements ForgeShellApi {
  // All 21 service getters return concrete test implementations.
  // Constructed eagerly at app startup.
}
```

**Wiring sequence in `main.dart`:**

1. Create `TomMemoryFileSystem` and seed with sample files.
2. Create all service instances.
3. Create `TestShellApi` aggregating all services.
4. Create and activate `TomForgeShellModule` — register a `ForgeMdEditor`, `ForgeDartEditor`, and `ForgeYamlEditor`.
5. Create and activate `TestAppModule` — register views.
6. Register both modules in `TestModuleRegistry`.
7. Run `ForgeTestApp` widget with the shell API.

### 4.2 `TestLayoutController`

Concrete `ForgeLayoutController` managing the widget tree layout.

**State:**

| Property | Type | Description |
|----------|------|-------------|
| `_leftPanelVisible` | `ValueNotifier<bool>` | Left sidebar visibility |
| `_rightPanelVisible` | `ValueNotifier<bool>` | Right sidebar visibility |
| `_bottomPanelVisible` | `ValueNotifier<bool>` | Bottom panel visibility |
| `_leftPanelWidth` | `ValueNotifier<double>` | Left sidebar width (default: 250) |
| `_rightPanelWidth` | `ValueNotifier<double>` | Right sidebar width (default: 220) |
| `_bottomPanelHeight` | `ValueNotifier<double>` | Bottom panel height (default: 180) |
| `_middlePanels` | `ValueNotifier<List<MiddlePanelState>>` | Open editors per panel |
| `_activeMiddlePanel` | `ValueNotifier<int>` | Active middle panel index |

**`MiddlePanelState`:**

```dart
class MiddlePanelState {
  final List<OpenEditorTab> tabs;
  int activeTabIndex;
}

class OpenEditorTab {
  final Uri uri;
  final ForgeEditor editor;
  final String title;
  bool isDirty;
}
```

**Key behaviors:**

- `openFile(Uri uri)` — Determine the appropriate editor via `canHandle` / `canHandleContent` iteration over registered editors. Create a new tab in the active middle panel (or reuse if the URI is already open). Update `TestSystemState.activeEditor`.
- `openEditor(ForgeEditor editor, Uri uri)` — Open a specific editor for a URI. Supports forcing a particular editor type.
- `splitMiddlePanel()` — Add a second `MiddlePanelState` if `middlePanels.length < 2`. Move the active tab to the new panel.
- `closeEditor(Uri uri)` — Remove the tab. If the editor is dirty, trigger a "save changes?" dialog via `TestDialogManager`.
- `revealInExplorer(Uri uri)` — Expand the file explorer tree to reveal the file and highlight it.

### 4.3 `TestSystemState`

Concrete `ForgeSystemState` backed by `ValueNotifier` and `StreamController` instances.

**Behavior:**

- `activeEditor` updates when a tab is focused, or `null` when all editors are closed.
- `openEditors` updates when tabs are opened/closed.
- `dirtyEditors` derived by filtering `openEditors` where `isDirty == true`.
- `diagnosticSummary` updates when `TestDiagnosticManager` collections change.
- `workspaceRootPath` returns `'/'` (virtual root).

### 4.4 `TestModuleRegistry`

Simple `Map<Type, ForgeModule>` backing. Registers `TomForgeShellModule` and `TestAppModule`.

### 4.5 `TestStatusBarController`

Collects `StatusBarItem` instances from all registered modules and the shell. Rebuilds `items` list when modules are added.

---

## 5. Service Implementations

### 5.1 `TomMemoryFileSystem` (TomFileSystem)

`tom_file_system`'s in-memory file system: files keyed by absolute path, with
revisions checked like on disk and no trash.

**Operations:**

| Method | Behavior |
|--------|----------|
| `read(Uri)` / `readText(Uri)` | Return the stored bytes with their revision, or the text. Throw if not found. |
| `write(Uri, bytes)` / `writeText(Uri, String)` | Store content, refusing a stale expected revision. Fire `onDidChange` and the watch. |
| `save(Uri)` | Fire `onWillSave`, then `onDidSave`. Mark editor clean via system state. |
| `delete(Uri)` | Remove the entry, a folder with what is in it. Fire `onDidChange`. |
| `exists(Uri)` | Check the file or folder. |
| `stat(Uri)` | Return the `TomFileEntry`: name, kind, size, modification time. |
| `list(Uri)` | List the entries directly in a folder. |
| `watch()` | Return a stream of every change made through it. |

**Seeding:** On construction, populate with the sample workspace files defined in `workspace_seed.dart` (see §11).

### 5.2 `TestDiagnosticManager` (ForgeDiagnosticManager)

- `createCollection(String name)` returns a `TestDiagnosticCollection` backed by a `Map<Uri, List<ForgeDiagnostic>>`.
- `all` aggregates diagnostics from all collections.
- `forUri(Uri)` filters by URI.
- Changes fire a stream that `TestSystemState` listens to for `diagnosticSummary` updates.

### 5.3 `TestOutputManager` (ForgeOutputChannelManager)

- `create(String name)` creates a `TestOutputChannel` that appends lines to an internal `List<String>`.
- `channels` returns all created channels.
- A `"Shell"` channel is created at startup for internal log messages.

### 5.4 `TestSearchManager` (ForgeSearchManager)

- `search(String query, ...)` scans all files in `TomMemoryFileSystem` for matches. Returns `List<ForgeSearchResult>`.
- Supports `isRegex`, `isCaseSensitive`, `isWholeWord` options.
- `searchStream(...)` wraps `search()` result in a single-emission stream.

### 5.5 `TestDialogManager` (ForgeDialogManager)

- `showQuickPick(items)` shows a `SimpleDialog` with a list of selectable items.
- `showInputBox(prompt)` shows an `AlertDialog` with a `TextField`.
- `showOpenDialog()` / `showSaveDialog()` show a simplified picker listing files from `TomMemoryFileSystem`.

### 5.6 `TestNotificationManager` (ForgeNotificationManager)

- `showInformation()`, `showWarning()`, `showError()` push notifications to a `ValueNotifier<List<Notification>>`.
- The `NotificationOverlay` widget listens and renders toast-style `SnackBar`-like popups that auto-dismiss after 4 seconds.
- Optional action buttons (e.g., "Open File") trigger callbacks.

### 5.7 `TestClipboard` (ForgeClipboard)

Wraps Flutter's `Clipboard.getData` / `Clipboard.setData` from `services.dart`.

### 5.8 `TestConfigManager` (ForgeConfigManager)

- `current` returns a `ForgeConfig` with default auto-save settings.
- `update()` replaces the config and fires `onDidChange`.
- `resetToDefaults()` restores the default `ForgeConfig`.

### 5.9 `TestProgressManager` (ForgeProgressManager)

- `withProgress<T>(title, task)` shows a `LinearProgressIndicator` in the status bar area while the task runs.
- The `ForgeProgressReporter` updates a `ValueNotifier<double>` for progress percentage.

### 5.10 `TestUndoManager` (ForgeUndoManager)

- Maintains a simple undo/redo stack of `UndoEntry` objects.
- `undo()` / `redo()` pop/push entries.
- `canUndo` / `canRedo` are `ValueNotifier<bool>`.

### 5.11 `TestOutlineManager` (ForgeOutlineManager)

- Holds a list of registered `ForgeOutlineProvider` instances.
- When the active editor changes, queries providers via `canProvide()` and `provideOutline()`.
- The result is exposed as a `ValueNotifier<List<ForgeOutlineItem>>` consumed by the Outline view.

### 5.12 Stub Services

Remaining services receive minimal no-op implementations in `stub_services.dart`:

| Service | Stub Behavior |
|---------|---------------|
| `ForgeTerminalManager` | `create()` returns a no-op `ForgeTerminal`. |
| `ForgeSecretStorage` | In-memory `Map<String, String>`. |
| `ForgeEnvironment` | `appName` returns `'Forge Test IDE'`. `openExternal()` logs to output. |
| `ForgeFileDecorationManager` | `registerProvider()` returns no-op disposable. |
| `ForgeVirtualDocumentManager` | `registerProvider()` returns no-op disposable. |
| `ForgeShortcutManager` | Returns empty bindings. |
| `ForgeModuleStorage` | In-memory `Map<String, Map<String, Object>>`. |

---

## 6. Views

### 6.1 File Explorer View

**Class:** `FileExplorerView extends ForgeView`

**Title:** "Explorer"  
**Icon:** `Icons.folder_outlined`

**Widget:** A `TreeView` (or nested `ExpansionTile` widgets) displaying the virtual file system hierarchy.

**Behavior:**

- On construction, reads the directory tree from `TomMemoryFileSystem.list()` starting at root.
- Directories are collapsible nodes. Files are leaf nodes.
- **Single-click** on a file calls `layout.openFile(uri)`.
- **Selected item** is highlighted. Tracks `systemState.selectedExplorerItems`.
- **Right-click** (long press on mobile) shows a context menu: "Open", "Open With…", "Delete", "Reveal in Editor".
- **File icons** by extension: `.md` → `Icons.description`, `.dart` → `Icons.code`, `.yaml` → `Icons.settings`, default → `Icons.insert_drive_file`.
- **Dirty indicator:** File names are rendered in *italic* if the file is currently dirty (open and modified).
- **Refresh:** Listens to `TomMemoryFileSystem.onDidChange` and rebuilds the tree.

### 6.2 Problems View

**Class:** `ProblemsView extends ForgeView`

**Title:** "Problems"  
**Icon:** `Icons.warning_amber_outlined`

**Widget:** A `ListView` of diagnostic entries grouped by file URI.

**Behavior:**

- Subscribes to `systemState.onDiagnosticsChanged`.
- Each entry shows: severity icon (error/warning/info), message, file name, line number.
- **Click** on an entry calls `layout.openFile(uri)` and positions the cursor at the diagnostic's range.
- **Badge:** The tab badge shows the total count of errors + warnings.

### 6.3 Output View

**Class:** `OutputView extends ForgeView`

**Title:** "Output"  
**Icon:** `Icons.terminal_outlined`

**Widget:** A scrollable text area showing the active output channel's content, with a dropdown to select between channels.

**Behavior:**

- Dropdown at the top lists `outputManager.channels` by name.
- Content area renders the selected channel's lines in a monospaced font.
- Auto-scrolls to the latest line when new content is appended.
- **Clear** button clears the selected channel.

### 6.4 Search View

**Class:** `SearchView extends ForgeView`

**Title:** "Search"  
**Icon:** `Icons.search`

**Widget:** A search input field followed by a results list.

**Behavior:**

- Text field with "Search in workspace" placeholder.
- Toggle buttons for: case-sensitive, whole word, regex.
- On submit (Enter or search button), calls `searchManager.search()`.
- Results are displayed as a grouped list: file URI header, then individual match lines with highlighted match text.
- **Click** on a result calls `layout.openFile(uri)` and reveals the match range.
- Result count shown in the view header (e.g., "Search — 12 results in 3 files").

### 6.5 Outline View

**Class:** `OutlineView extends ForgeView`

**Title:** "Outline"  
**Icon:** `Icons.account_tree_outlined`

**Widget:** A tree of `ForgeOutlineItem` entries for the active editor's document.

**Behavior:**

- Subscribes to `systemState.activeEditor` changes.
- When the active editor changes, queries `outlineManager` for outline items.
- Renders a nested tree: items have `label`, `kind` icon (function, class, field, etc.), and optional `detail`.
- **Click** on an item calls `activeEditor.revealRange(item.selectionRange)`.
- Empty state: "No outline available" when no provider matches the active editor.

---

## 7. Editor Integration

### 7.1 Editor Resolution

When `layout.openFile(uri)` is called, the layout controller resolves the editor:

1. Check file extension:
   - `.md`, `.markdown` → `ForgeMdEditor`
   - `.dart` → `ForgeDartEditor`
   - `.yaml`, `.yml` → `ForgeYamlEditor`
2. If extension is ambiguous, iterate registered editors and call `canHandle(uri)`. Pick the first `FileHandlingResult.exclusive` or `FileHandlingResult.handle` match.
3. If no editor matches, show a read-only text fallback (plain `Text` widget with monospaced font showing the raw file content).

### 7.2 Editor Lifecycle

| Event | Action |
|-------|--------|
| **File opened** | Create editor controller, load content from `TomMemoryFileSystem`, create adapter, add tab. |
| **Tab focused** | Set `systemState.activeEditor`. Notify outline manager. |
| **Content changed** | Mark tab dirty. Update `systemState.dirtyEditors`. |
| **Save (Ctrl+S)** | Write content to `TomMemoryFileSystem.save()`. Mark clean. Show notification. |
| **Close (clean)** | Remove tab. Dispose controller. |
| **Close (dirty)** | Show dialog: "Save changes to {filename}?" with Save / Don't Save / Cancel. |

### 7.3 Markdown Editor Integration

- **Controller:** `MdEditorController` from `tom_md_editor`.
- **Adapter:** `ForgeMdEditor` from `tom_forge_ui`.
- **Widget:** `MdEditor(controller: controller)`.
- **Outline:** Provides heading-based outline items (H1–H6 nesting).
- **Diagnostics:** None by default (Markdown has no schema validation in this test app).

### 7.4 Dart Editor Integration

- **Controller:** `DartCodeController` from `tom_dart_editor`.
- **Adapter:** `ForgeDartEditor` from `tom_forge_ui`.
- **Widget:** `DartCodeEditor(controller: controller)`.
- **Outline:** Provides symbol-based outline if an outline provider is registered.
- **Diagnostics:** A simple linter that flags lines exceeding 80 characters as warnings.

### 7.5 YAML Editor Integration

- **Controller:** `YamlEditorController` from `tom_yaml_editor`.
- **Adapter:** `ForgeYamlEditor` from `tom_forge_ui`.
- **Widget:** `YamlSchemaEditor(controller: controller)`.
- **Outline:** Provides top-level YAML key hierarchy as outline items.
- **Diagnostics:** Basic YAML parse error reporting if content is malformed.

---

## 8. Layout and Panels

### 8.1 Shell Scaffold

The `ShellScaffold` widget is the root layout widget. It composes the full IDE layout:

```
Column
├── TitleBar (app title + window controls)
├── MenuBar (File │ Edit │ View │ Help)
├── Expanded
│   └── Row
│       ├── LeftPanel (FileExplorerView)    [resizable, collapsible]
│       ├── VerticalDivider (drag handle)
│       ├── Expanded: MiddleArea
│       │   └── Column
│       │       ├── EditorTabBar
│       │       └── Expanded: active editor widget
│       ├── VerticalDivider (drag handle)
│       └── RightPanel (OutlineView)        [resizable, collapsible]
├── HorizontalDivider (drag handle)
├── BottomPanel                              [resizable, collapsible]
│   └── TabBar: [Problems] [Output] [Search]
└── StatusBar
```

### 8.2 Panel Behavior

| Panel | Default Size | Min | Max | Default Visibility |
|-------|-------------|-----|-----|--------------------|
| Left | 250px | 180px | 500px | Visible |
| Right | 220px | 150px | 400px | Visible |
| Bottom | 180px | 100px | 400px | Visible |

- Panels are resizable via drag handles (`GestureDetector` on dividers).
- Panels collapse/expand via View menu toggles or shortcut keys.
- Collapsed panels show only the icon strip (44px wide for side panels, 0px for bottom).

### 8.3 Middle Panel Split

- Default: 1 middle panel filling available width.
- "Split Editor" action (via menu or `Ctrl+\`): Adds a second panel. Both share equal width.
- Maximum 2 middle panels in the test app (concept allows 4, but 2 is sufficient for demo).
- Each panel has its own tab bar and active editor.
- Drag a tab from one panel to another to move it.

---

## 9. Status Bar

The status bar is a horizontal strip at the bottom of the window (height: 24px).

### 9.1 Segments

| Position | Content | Source |
|----------|---------|--------|
| Left | Cursor position: `Ln {line}, Col {col}` | Active editor's `cursorPosition` |
| Left | Encoding: `UTF-8` | Static for test app |
| Center | Language: `Markdown` / `Dart` / `YAML` | Active editor type |
| Right | Diagnostics: `{n} errors, {m} warnings` | `systemState.diagnosticSummary` |
| Right | Module name: `Tom Forge Editors` | Active module's `displayName` |

### 9.2 Interaction

- Click on language label → show quick pick to switch editor type (calls `layout.openFileWith()`).
- Click on diagnostics → toggle the Problems panel.

---

## 10. Actions and Shortcuts

### 10.1 File Menu Actions

| Action ID | Label | Shortcut | Behavior |
|-----------|-------|----------|----------|
| `file.save` | Save | `Ctrl+S` | Save active editor to `TomMemoryFileSystem`. |
| `file.saveAll` | Save All | `Ctrl+Shift+S` | Save all dirty editors. |
| `file.close` | Close Editor | `Ctrl+W` | Close active editor tab. |
| `file.closeAll` | Close All | `Ctrl+Shift+W` | Close all editor tabs. |

### 10.2 Edit Menu Actions

| Action ID | Label | Shortcut | Behavior |
|-----------|-------|----------|----------|
| `edit.undo` | Undo | `Ctrl+Z` | `undoManager.undo()` |
| `edit.redo` | Redo | `Ctrl+Shift+Z` | `undoManager.redo()` |
| `edit.find` | Find in File | `Ctrl+F` | Focus the active editor's built-in find bar (if supported). |
| `edit.findInFiles` | Find in Files | `Ctrl+Shift+F` | Focus the Search view and toggle bottom panel visible. |

### 10.3 View Menu Actions

| Action ID | Label | Shortcut | Behavior |
|-----------|-------|----------|----------|
| `view.toggleExplorer` | Toggle Explorer | `Ctrl+B` | Toggle left panel visibility. |
| `view.toggleOutline` | Toggle Outline | `Ctrl+Shift+O` | Toggle right panel visibility. |
| `view.toggleProblems` | Toggle Problems | `Ctrl+Shift+M` | Toggle bottom panel, activate Problems tab. |
| `view.toggleOutput` | Toggle Output | `Ctrl+Shift+U` | Toggle bottom panel, activate Output tab. |
| `view.splitEditor` | Split Editor | `Ctrl+\` | Split the middle panel. |

### 10.4 Help Menu Actions

| Action ID | Label | Shortcut | Behavior |
|-----------|-------|----------|----------|
| `help.about` | About | — | Show dialog with app name, version, and module list. |

---

## 11. Sample Workspace

The in-memory file system is seeded with the following directory structure:

```
/
├── README.md
├── pubspec.yaml
├── lib/
│   ├── main.dart
│   └── src/
│       ├── app.dart
│       └── utils.dart
├── test/
│   └── app_test.dart
└── doc/
    └── architecture.md
```

### 11.1 Sample File Contents

| File | Content Summary | Purpose |
|------|----------------|---------|
| `README.md` | ~40 lines of Markdown with headings, lists, code blocks, links | Test Markdown editor features, outline headings |
| `pubspec.yaml` | Standard Dart pubspec with name, version, dependencies, environment | Test YAML editor, key outline |
| `lib/main.dart` | ~30 lines with `main()`, imports, `runApp()` call | Test Dart editor, syntax highlighting |
| `lib/src/app.dart` | ~50 lines with a `StatelessWidget` class, `build()` method | Test Dart symbol outline |
| `lib/src/utils.dart` | ~25 lines with utility functions | Test multiple files of same type |
| `test/app_test.dart` | ~20 lines with a test group and assertions | Test Dart editor variant |
| `doc/architecture.md` | ~30 lines of Markdown with headings and a diagram | Test second Markdown file |

Content should be realistic but concise — enough to demonstrate editing, outline generation, and search results, but small enough to keep the seed data under 200 lines total.

---

## 12. Implementation Phases

### Phase 1: Core Shell Wiring

**Files:** `main.dart`, `app.dart`, `test_shell_api.dart`, `test_layout_controller.dart`, `test_system_state.dart`, `test_module_registry.dart`, `test_status_bar.dart`, `workspace_seed.dart`

**Deliverable:** App launches and shows the shell scaffold with empty panels. Sample workspace is loaded into `TomMemoryFileSystem`. Layout controller can open/close/resize panels.

### Phase 2: File System and Explorer

**Files:** `memory_file_system.dart`, `file_explorer_view.dart`, `test_app_module.dart`, `shell_scaffold.dart`, `panel_widget.dart`

**Deliverable:** Left panel shows the file tree. Clicking a file triggers `layout.openFile()` (editor area is still empty placeholder text).

### Phase 3: Editor Integration

**Files:** `editor_tab_bar.dart`, editor lifecycle logic in `test_layout_controller.dart`

**Deliverable:** Clicking a file opens the correct editor (MD, Dart, or YAML) in a tab. Multiple tabs work. Tab switching updates the active editor. Close button on tabs works. Dirty state is tracked and shown.

### Phase 4: Views and Services

**Files:** `problems_view.dart`, `output_view.dart`, `search_view.dart`, `outline_view.dart`, `test_diagnostic_manager.dart`, `test_output_manager.dart`, `test_search_manager.dart`, `test_outline_manager.dart`, `test_notification_manager.dart`, `notification_overlay.dart`

**Deliverable:** All five views functional. Problems view shows diagnostics. Output view shows shell log. Search works across files. Outline responds to active editor. Notifications appear as toasts.

### Phase 5: Actions, Status Bar, and Polish

**Files:** `status_bar_widget.dart`, `test_dialog_manager.dart`, `test_clipboard.dart`, `test_config_manager.dart`, `test_progress_manager.dart`, `test_undo_manager.dart`, `stub_services.dart`

**Deliverable:** Menu bar with all actions. Keyboard shortcuts work. Status bar shows cursor position, language, and diagnostics. Save/close workflows complete with dirty dialogs. All remaining services stubbed.

---

## 13. File Inventory

Complete list of files to create in `tom_forge_ui_test/lib/`:

| # | File | Type | Lines (est.) |
|---|------|------|------------|
| 1 | `main.dart` | Entry point + shell wiring | 80 |
| 2 | `src/app.dart` | `ForgeTestApp` MaterialApp | 40 |
| 3 | `src/shell/test_shell_api.dart` | Concrete `ForgeShellApi` | 80 |
| 4 | `src/shell/test_layout_controller.dart` | Layout + tab management | 250 |
| 5 | `src/shell/test_system_state.dart` | Observable system state | 200 |
| 6 | `src/shell/test_module_registry.dart` | Module map | 30 |
| 7 | `src/shell/test_status_bar.dart` | Status bar controller | 40 |
| 8 | `src/services/memory_file_system.dart` | In-memory FS | 200 |
| 9 | `src/services/test_dialog_manager.dart` | Material dialogs | 100 |
| 10 | `src/services/test_notification_manager.dart` | Toast notifications | 80 |
| 11 | `src/services/test_diagnostic_manager.dart` | Diagnostic collections | 100 |
| 12 | `src/services/test_output_manager.dart` | Output channels | 80 |
| 13 | `src/services/test_search_manager.dart` | Workspace search | 80 |
| 14 | `src/services/test_clipboard.dart` | Clipboard wrapper | 20 |
| 15 | `src/services/test_config_manager.dart` | Config manager | 40 |
| 16 | `src/services/test_progress_manager.dart` | Progress reporting | 50 |
| 17 | `src/services/test_undo_manager.dart` | Undo/redo stack | 60 |
| 18 | `src/services/test_outline_manager.dart` | Outline provider registry | 60 |
| 19 | `src/services/stub_services.dart` | Stubs for 7 remaining services | 120 |
| 20 | `src/views/file_explorer_view.dart` | File tree view | 150 |
| 21 | `src/views/problems_view.dart` | Diagnostic list | 100 |
| 22 | `src/views/output_view.dart` | Output channel view | 100 |
| 23 | `src/views/search_view.dart` | Search input + results | 150 |
| 24 | `src/views/outline_view.dart` | Document outline tree | 100 |
| 25 | `src/module/test_app_module.dart` | Module registering views + actions | 80 |
| 26 | `src/widgets/shell_scaffold.dart` | Root layout scaffold | 200 |
| 27 | `src/widgets/panel_widget.dart` | Resizable panel container | 120 |
| 28 | `src/widgets/editor_tab_bar.dart` | Tab bar with close/dirty | 120 |
| 29 | `src/widgets/status_bar_widget.dart` | Status bar segments | 100 |
| 30 | `src/widgets/notification_overlay.dart` | Toast overlay | 80 |
| 31 | `src/sample/workspace_seed.dart` | Sample file content constants | 120 |
| | **Total** | | **~2830** |
