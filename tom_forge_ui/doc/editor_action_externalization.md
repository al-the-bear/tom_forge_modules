# Editor Action Externalization — Architecture

**Date:** 2026-04-06 (proposed), 2026-04-07 (implemented Phase 1-3, updated)  
**Status:** Implemented (Phase 1-3); Phase 4 pending  
**Companion:** [forge_panel_shell_concept.md](forge_panel_shell_concept.md) (§8 Modules, §11 Shortcuts), [forge_editor_base.md](forge_editor_base.md) (§3 Proposed Architecture)

---

## 1. Problem Statement

The current architecture creates shortcut conflicts when multiple editors register their own keyboard bindings with the shell. Each editor:

1. **Defines its own shortcuts** in action classes (`DartEditorActions`, `MdEditorActions`, `YamlEditorActions`)
2. **Registers them with the shell** via `ShellEditorIntegration._registerWithShell()` → `shortcutManager.rebind()`
3. **Also handles shortcuts locally** via Flutter `Shortcuts`/`Actions` widgets or `onKeyEvent` callbacks

This dual registration causes:

- **Shortcut collisions** — when two editors define the same key differently
- **Deferred override fragility** — user customizations (chords, rebound keys) are consumed and lost when modules re-register on editor switch
- **Inconsistent handling** — standard editing actions (`cut/copy/paste/undo/redo`) are explicitly excluded from shell registration via `_editorInternalActions`, while editor-specific actions go through the shell. The boundary between "editor-internal" and "shell-managed" is implicit and hardcoded
- **No disable switch** — when an editor runs inside the shell, its internal shortcut handling cannot be turned off; the shell cannot fully own the keyboard

These problems compound with each new editor added to the system.

### 1.1 Affected Components

| Component | Role | Current Shortcut Behavior |
|-----------|------|--------------------------|
| `DartCodeEditor` | Code editing with syntax highlighting | `Shortcuts` widget + `onKeyEvent`; 7 custom actions with shortcuts |
| `MdEditor` | Markdown editing with preview | `Shortcuts` + `Actions` widgets; 9 custom actions with shortcuts |
| `YamlSchemaEditor` | Tree-based YAML editing | `KeyboardListener.onKeyEvent`; 5 custom actions with shortcuts |
| `ShellEditorIntegration` | Bridges editor actions to shell | Selectively registers non-internal actions with shell shortcut manager |
| `DefaultShortcutManager` | Shell-level shortcut binding | Manages bindings, deferred overrides, chord state |

---

## 2. Proposed Architecture

### 2.1 Core Principle: Shell Owns All Shortcuts

Editors **expose action descriptors** (what they can do) but **do not bind shortcuts**. The shell is the single owner of all keyboard bindings. Editors receive action invocations from the shell and execute them in their current context.

### 2.1.1 Action Naming Convention

All actions follow the naming pattern `<source>.<action>`:

| Prefix | Source | Examples |
|--------|--------|----------|
| `forge.` | Shell (global operations) | `forge.toggleLeftPanel`, `forge.commandPalette`, `forge.saveAll` |
| `forge.edit.` | Standard editing (all editors) | `forge.edit.cut`, `forge.edit.undo`, `forge.edit.moveLineUp` |
| `dart.` | Dart editor | `dart.triggerCompletion`, `dart.toggleComment` |
| `md.` | Markdown editor | `md.toggleBold`, `md.insertLink` |
| `yaml.` | YAML editor | `yaml.addKey`, `yaml.toggleTextMode` |
| `flow.` | Flow editor | `flow.addNode`, `flow.autoLayout` |

The **prefix acts as a routing category**: when the shell dispatches an action, the prefix identifies which module/editor handles it. The Shortcut Editor (concept §11.6) and command palette group actions by prefix.

### 2.1.2 Shortcut Scope

When a user rebinds a shortcut in the Shortcut Editor, they choose the **scope**:

- **Global** — shortcut is active regardless of which editor is focused
- **Editor-specific** — shortcut is active only when a specific editor type has focus (e.g., "Dart Editor only")

This allows the same key combination to trigger different actions in different editors without conflict. For example, `Ctrl+T` can mean "Toggle Text Mode" in the YAML editor and be unbound (or rebound to something else) in the Dart editor.

### 2.1.3 Shell as Action Source

The shell (`TomForgeShellModule`) exposes its own actions through the same descriptor system as any editor module. Shell actions use the `forge.` prefix and appear in the command palette and Shortcut Editor alongside editor actions. There are **no hidden, hardcoded shortcuts** — every shortcut is registered through the action/descriptor system.

Shell action descriptors include:

| Action ID | Label | Default Shortcut | Context |
|-----------|-------|------------------|---------|
| `forge.commandPalette` | Command Palette | `Cmd+P` | Global |
| `forge.commandPaletteFull` | Command Palette (Full) | `F1` | Global |
| `forge.toggleLeftPanel` | Toggle Left Panel | `Cmd+L` | Global |
| `forge.toggleRightPanel` | Toggle Right Panel | `Cmd+R` | Global |
| `forge.toggleBottomPanel` | Toggle Bottom Panel | `Cmd+B` | Global |
| `forge.find` | Find | `Cmd+F` | When component is focused |
| `forge.focusPanel1` | Focus Panel 1 | `Cmd+1` | Global |
| `forge.focusPanel2` | Focus Panel 2 | `Cmd+2` | Global |
| `forge.focusPanel3` | Focus Panel 3 | `Cmd+3` | Global |
| `forge.focusPanel4` | Focus Panel 4 | `Cmd+4` | Global |
| `forge.focusNextPanel` | Focus Next Panel | `Cmd+]` | Global |
| `forge.focusPrevPanel` | Focus Previous Panel | `Cmd+[` | Global |
| `forge.saveAll` | Save All | `Cmd+S` | Global |

### 2.2 Three-Layer Model

```
┌──────────────────────────────────────────────────────────────────┐
│  Layer 1: Action Descriptors (editor-owned)                      │
│                                                                  │
│  Each editor exposes a static list of EditorActionDescriptor      │
│  objects: id, label, icon, category, description, contextRule.   │
│  No shortcuts. No handlers. Pure metadata.                       │
└──────────────────────────────────┬───────────────────────────────┘
                                   │ published at module activation
                                   ▼
┌──────────────────────────────────────────────────────────────────┐
│  Layer 2: Shortcut Binding (shell-owned)                         │
│                                                                  │
│  The shell assigns default shortcuts to descriptors during       │
│  module registration. User preferences override defaults.        │
│  Binding table is the single source of truth.                    │
└──────────────────────────────────┬───────────────────────────────┘
                                   │ key event → action dispatch
                                   ▼
┌──────────────────────────────────────────────────────────────────┐
│  Layer 3: Action Execution (editor-owned)                        │
│                                                                  │
│  Shell dispatches action by ID to the focused editor's           │
│  integration. Editor executes the action in its current context  │
│  (selection, cursor, document state).                            │
└──────────────────────────────────────────────────────────────────┘
```

### 2.3 Editor Action Descriptor

A new lightweight class replaces the current pattern where editors define `ForgeAction` instances with both shortcuts and execution logic:

```dart
/// Metadata-only description of an action an editor can perform.
/// No shortcut binding, no execution callback.
class EditorActionDescriptor {
  /// Unique action ID (e.g., 'dart.triggerCompletion').
  final String id;

  /// Human-readable label (e.g., 'Trigger Completion').
  final String label;

  /// Optional icon for menus and command palette.
  final IconData? icon;

  /// Category for grouping in command palette and shortcut editor
  /// (e.g., 'Dart Editor', 'Markdown', 'YAML').
  final String category;

  /// One-line description for tooltip/shortcut editor
  /// (e.g., 'Show autocomplete suggestions at cursor position').
  final String? description;

  /// When this action is conceptually available.
  /// Used by the shell to evaluate isEnabled without calling the editor.
  final ActionContext contextRule;

  /// Whether this action should appear in the editor's context menu.
  final bool showInContextMenu;

  /// The default shortcut the editor suggests for this action.
  /// The shell MAY use this as the initial binding, but is not required to.
  /// When shortcuts are disabled (shell mode), this is ignored.
  final ForgeShortcutKey? suggestedShortcut;

  /// Alternative shortcuts the editor suggests (e.g., Alt+Space for completion).
  final List<ForgeShortcutKey> suggestedAlternatives;

  const EditorActionDescriptor({
    required this.id,
    required this.label,
    this.icon,
    required this.category,
    this.description,
    this.contextRule = ActionContext.editorFocused,
    this.showInContextMenu = false,
    this.suggestedShortcut,
    this.suggestedAlternatives = const [],
  });
}

/// Context in which an action is available.
enum ActionContext {
  /// Always available regardless of focus.
  global,

  /// Available when any editor is focused.
  editorFocused,

  /// Available when a text editor (not tree editor) is focused.
  textEditorFocused,

  /// Available when the editor has a non-empty text selection.
  hasSelection,

  /// Available when the document is not read-only.
  editable,
}
```

### 2.4 Editor Integration Changes

The `ForgeEditorIntegration` interface gains a descriptor-based contract:

```dart
abstract class ForgeEditorIntegration {
  // --- NEW: Descriptor-based API ---

  /// All actions this editor can perform, as descriptors (metadata only).
  /// Called once during integration setup. The list is static for the
  /// editor type — it does not change at runtime.
  List<EditorActionDescriptor> get actionDescriptors;

  /// Execute an action by ID in the editor's current context.
  /// Returns true if the action was handled.
  bool executeAction(String actionId);

  /// Query whether an action is currently enabled (dynamic state).
  /// Called by the shell before dispatch and for UI state (menu dimming).
  bool isActionEnabled(String actionId);

  // --- Existing API (unchanged) ---

  ForgeTextContext? get textContext;
  bool get hasFocus;
  void requestFocus();
  // ... text manipulation methods remain unchanged
}
```

### 2.5 Shortcut Disable Switch

Editors receive a configuration flag that controls whether they handle keyboard shortcuts internally:

```dart
/// In editor widget constructors:
DartCodeEditor({
  // ... existing parameters
  this.handleShortcuts = true,  // true for standalone, false when shell-integrated
});

MdEditor({
  // ... existing parameters
  this.handleShortcuts = true,
});

YamlSchemaEditor({
  // ... existing parameters
  this.handleShortcuts = true,
});
```

When `handleShortcuts` is `false`:

- The editor does **not** wrap its content in `Shortcuts`/`Actions` widgets
- The editor does **not** install `onKeyEvent` handlers for action shortcuts (navigation keys like arrow keys, Tab, Enter remain active)
- The editor still registers action handlers via `registerAction()` — but only for execution, not for keyboard interception
- All shortcut-to-action routing comes from the shell

When `handleShortcuts` is `true` (standalone mode):

- The editor uses suggested shortcuts from its descriptors to build local `Shortcuts`/`Actions` widgets
- Behavior is identical to today's standalone mode

### 2.5.1 Three Usage Modes

The `handleShortcuts` flag together with `actionDescriptors` supports three distinct embedding scenarios:

| Mode | `handleShortcuts` | Integration | Who binds shortcuts | Example |
|------|-------------------|-------------|---------------------|---------|
| **Standalone** | `true` | `*StandaloneIntegration` | Editor itself (from `suggestedShortcut`) | Editor widget used directly in any Flutter app |
| **Embedded in custom host** | `true` or `false` | Custom `ForgeEditorIntegration` impl | Host reads `actionDescriptors`, binds as it sees fit; sets `handleShortcuts: false` if host owns keys | Editor embedded in Worktracker, Webwork, or any non-Forge tool |
| **Shell-integrated** | `false` | `ShellEditorIntegration` | Forge shell exclusively | Editor running inside Tom Forge |

For the **embedded in custom host** scenario, the host app:

1. Creates the editor widget with `handleShortcuts: false`
2. Reads `integration.actionDescriptors` to discover available actions
3. Binds shortcuts in whatever system the host uses (its own `Shortcuts` widget, platform shortcuts, etc.)
4. Dispatches to `integration.executeAction(actionId)` when the user triggers a shortcut

This makes editors fully reusable components that any Flutter application can integrate — they expose what they can do (descriptors), accept action invocations (executeAction), and let the host decide how to trigger them.

### 2.6 Shell-Side Registration Flow

During module activation, the shell processes editor action descriptors:

```
Module.activate(shell)
  └─ for each editor in module.editors:
       └─ for each descriptor in editor.integration.actionDescriptors:
            ├─ Register action in ForgeActionRegistry (wrapping editor.executeAction)
            ├─ Assign default shortcut from descriptor.suggestedShortcut
            ├─ Apply user preference override (if any)
            └─ Register alternative shortcuts from descriptor.suggestedAlternatives
```

The `ShellEditorIntegration` bridge simplifies significantly — it no longer needs:

- `_editorInternalActions` exclusion list
- `_resolveAction()` fallback pool with hardcoded action lists
- `_registerWithShell()` wrapping logic

Instead, it reads descriptors from the editor and forwards `executeAction()` calls from the shell.

### 2.7 Standard Editing Actions

The standard editing actions use the `forge.edit.` prefix and are **required for all text-based editors**. The shell assigns default shortcuts from concept §11.1.3:

| Action ID | Label | Default Shortcut | Context |
|-----------|-------|------------------|---------|
| `forge.edit.cut` | Cut | `Cmd+X` | hasSelection |
| `forge.edit.copy` | Copy | `Cmd+C` | hasSelection |
| `forge.edit.paste` | Paste | `Cmd+V` | editable |
| `forge.edit.selectAll` | Select All | `Cmd+A` | editorFocused |
| `forge.edit.undo` | Undo | `Cmd+Z` | editorFocused |
| `forge.edit.redo` | Redo | `Shift+Cmd+Z`; also `Ctrl+Y` on Windows and Linux | editorFocused |
| `forge.edit.deleteLine` | Delete Line | `Shift+Cmd+K` | textEditorFocused |
| `forge.edit.duplicateLine` | Duplicate Line | `Cmd+D` | textEditorFocused |
| `forge.edit.moveLineUp` | Move Line Up | `Alt+↑` | textEditorFocused |
| `forge.edit.moveLineDown` | Move Line Down | `Alt+↓` | textEditorFocused |
| `forge.edit.toggleComment` | Toggle Comment | `Cmd+/` | textEditorFocused |

These are defined as `EditorActionDescriptor` instances in `StandardEditingActions.descriptors` (in `tom_editors_shared`). Each editor's standalone integration overrides `actionDescriptors` to include them. The shell's `ShellEditorIntegration` receives them via the `descriptors` setter when the adapter creates the integration.

Tree-based editors (like the YAML tree editor) implement the subset that applies to their editing model — at minimum `undo` and `redo`. Cut/copy/paste may also apply if the editor supports clipboard operations on tree nodes.

**Important:** Flutter's `EditableText` widget has built-in handling for `Ctrl+C`/`Ctrl+V`/etc. When `handleShortcuts` is `false`, the editor must ensure its `TextField` does not conflict with shell-dispatched actions. This is handled by:

1. Shell intercepts the key event first (via `FocusScope` above editors)
2. Shell dispatches to the focused editor's `executeAction()`
3. Editor executes the operation on its controller directly (e.g., `controller.copy()`)
4. The key event does not propagate to `TextField`'s built-in handler

---

## 3. Editor-by-Editor Impact Analysis

### 3.1 Dart Editor (`tom_dart_editor`)

**Current state:**
- 7 custom actions defined in `DartEditorActions` with hardcoded shortcuts
- `_registerActions()` in `DartCodeEditor` registers handlers with integration
- `_buildShortcutMap()` converts actions to Flutter `Shortcuts` widget entries
- Local `onKeyEvent` also handles some key processing

**Changes needed:**

| Area | Change |
|------|--------|
| `DartEditorActions` | Retain only Dart-specific actions (triggerCompletion, openReference); deleteLine, duplicateLine, moveLineUp/Down, toggleComment moved to `StandardEditingActions` |
| `DartCodeEditor._registerActions()` | Simplify to register handlers only (no shortcut map building) |
| `DartCodeEditor._buildShortcutMap()` | Conditional: only build when `handleShortcuts == true` |
| `DartCodeEditor.build()` | Conditional: wrap in `Shortcuts`/`Actions` only when `handleShortcuts == true` |
| `DartStandaloneIntegration` | Add `actionDescriptors` getter returning standard + Dart descriptors |

**Action descriptors (2 custom + 11 standard = 13 total):**

| ID | Label | Category | Suggested Shortcut | Context |
|----|-------|----------|--------------------|---------|
| `dart.triggerCompletion` | Trigger Completion | Dart Editor | `Ctrl+Space` | editorFocused |
| `dart.openReference` | Open Reference | Dart Editor | *(none)* | editorFocused |
| + 11 standard editing actions (`forge.edit.*`) | | Standard | per §11.1.3 | varies |

### 3.2 Markdown Editor (`tom_md_editor`)

**Current state:**
- 9 custom actions defined in `MdEditorActions` with hardcoded shortcuts
- `MdEditor._registerActions()` registers handlers
- Uses `Shortcuts`/`Actions` widgets for keyboard handling

**Changes needed:**

| Area | Change |
|------|--------|
| `MdEditorActions` | Convert to `EditorActionDescriptor` list |
| `MdEditor._registerActions()` | Simplify to handler registration only |
| `MdEditor.build()` | Conditional `Shortcuts`/`Actions` wrapping |
| `MdStandaloneIntegration` | Add `actionDescriptors` getter |

**Action descriptors (7 custom + 11 standard = 18 total):**

| ID | Label | Category | Suggested Shortcut | Context |
|----|-------|----------|--------------------|---------|
| `md.toggleBold` | Toggle Bold | Markdown | `Ctrl+B` | editable |
| `md.toggleItalic` | Toggle Italic | Markdown | `Ctrl+I` | editable |
| `md.toggleCode` | Toggle Code | Markdown | `Ctrl+E` | editable |
| `md.insertLink` | Insert Link | Markdown | `Ctrl+K` | editable |
| `md.insertTable` | Insert Table | Markdown | `Alt+T` | editable |
| `md.insertHeading` | Insert Heading | Markdown | `Alt+H` | editable |
| `md.toggleList` | Toggle List | Markdown | `Alt+L` | editable |
| + 11 standard editing actions (`forge.edit.*`) | | Standard | per §11.1.3 | varies |

**Note:** `Cmd+B` is used for the Markdown Bold action (`md.toggleBold`) when the Markdown editor is focused. The shell's `forge.toggleBottomPanel` (`Cmd+B`) is a global action. The scope system (§2.1.2) resolves this: when a Markdown editor has focus, `Cmd+B` triggers Bold; otherwise it toggles the bottom panel. Users can rebind either action in the Shortcut Editor.

### 3.3 YAML Editor (`tom_yaml_editor`)

**Current state:**
- 5 custom actions defined in `YamlEditorActions` with hardcoded shortcuts
- Only `undo/redo` registered in `YamlStandaloneIntegration.supportedActions`
- Tree navigation (arrow keys, Enter, Escape, Tab) handled in `KeyboardListener.onKeyEvent` — these are **not actions** and remain editor-internal
- `YamlStandaloneIntegration` implements `ForgeEditorIntegration` directly (not text-based)

**Changes needed:**

| Area | Change |
|------|--------|
| `YamlEditorActions` | Convert to `EditorActionDescriptor` list |
| `YamlSchemaEditor` | Add `handleShortcuts` parameter; conditional key handling for action shortcuts vs. navigation |
| `YamlStandaloneIntegration` | Add `actionDescriptors` getter with YAML + undo/redo descriptors |

**Action descriptors (3 custom + 2 standard = 5 total):**

| ID | Label | Category | Suggested Shortcut | Context |
|----|-------|----------|--------------------|---------|
| `yaml.addKey` | Add Key | YAML Editor | `Ctrl+N` | editable |
| `yaml.removeKey` | Remove Key | YAML Editor | `Ctrl+Delete` | editable |
| `yaml.toggleTextMode` | Toggle Text Mode | YAML Editor | `Ctrl+T` | editorFocused |
| `forge.edit.undo` | Undo | Standard | `Ctrl+Z` | editorFocused |
| `forge.edit.redo` | Redo | Standard | `Shift+Ctrl+Z`, `Ctrl+Y` | editorFocused |

**Note:** The YAML editor is tree-based, not text-based. It registers only `undo/redo` from standard actions because cut/copy/paste, delete/duplicate line, and move line up/down operate on text selections, which don't apply to tree node editing. Tree navigation keys (arrows, Tab, Enter, Escape, Space) remain in the editor's `KeyboardListener` regardless of the `handleShortcuts` flag — they are navigation, not actions.

**Note:** `yaml.toggleTextMode` switches between the tree view (structured key/value editing) and raw text mode (plain YAML source). When in raw text mode, all standard text editing actions (`forge.edit.*`) become available because the editor is then operating as a text editor.

**Note:** Save (`Cmd+S`) and Find (`Cmd+F`) are shell-level actions (`forge.saveAll`, `forge.find`) — editors do not register their own save/find actions. The shell handles these globally.

### 3.4 Flow Editor (`tom_flow_editor`)

Currently a minimal placeholder. When implemented, it follows the same pattern: expose `EditorActionDescriptor` list, accept `handleShortcuts` flag.

---

## 4. ShellEditorIntegration Simplification

### 4.1 Current Complexity

`ShellEditorIntegration` currently:

1. Maintains `_editorInternalActions` exclusion set (6 hardcoded action IDs)
2. Has `_resolveAction()` with a hardcoded pool of **all possible actions across all editors** (22 actions from Dart + MD + YAML + Standard)
3. Wraps each action in a `ForgeAction` whose `execute` calls the editor's handler (the shell and the editors share one `ForgeAction` type, `tom_editors_shared`'s)
4. Decides per-action whether to register with shell or handle internally
5. Returns `null` from `getShortcutForAction()` for chord bindings to prevent editor interception

### 4.2 Proposed Simplification

After externalization, `ShellEditorIntegration` becomes a thin bridge:

```dart
class ShellEditorIntegration implements ForgeEditorIntegration {
  final ForgeShellApi _shellApi;
  final String editorId;
  final String editorTypeId;

  // Action handlers registered by the editor widget
  final Map<String, VoidCallback> _handlers = {};
  final Map<String, bool Function()> _enabledQueries = {};

  @override
  List<EditorActionDescriptor> get actionDescriptors =>
      _descriptors;  // Set during setup

  @override
  bool executeAction(String actionId) {
    final handler = _handlers[actionId];
    if (handler == null) return false;
    handler();
    return true;
  }

  @override
  bool isActionEnabled(String actionId) {
    return _enabledQueries[actionId]?.call() ?? false;
  }

  /// Called by editor widget to register action handlers.
  void registerHandler(String actionId, VoidCallback handler,
      {bool Function()? isEnabled}) {
    _handlers[actionId] = handler;
    if (isEnabled != null) _enabledQueries[actionId] = isEnabled;
  }

  @override
  ForgeShortcutKey? getShortcutForAction(String actionId) {
    // Always return the shell's effective binding — no local shortcuts
    final binding = _shellApi.shortcuts.getBinding(actionId);
    if (binding == null || binding.isChord) return null;
    return binding.key;
  }

  // ... text context, focus, text manipulation methods unchanged
}
```

**Eliminated:**
- `_editorInternalActions` set
- `_resolveAction()` method and its hardcoded action pool
- `_registerWithShell()` method
- `_knownActions` cache

### 4.3 Module Registration Change

`DefaultModuleRegistry.register()` currently iterates `module.shortcuts` for rebinding. With externalization, it also processes editor action descriptors:

```dart
void register(ForgeModule module) {
  // ... existing module registration ...

  // Register editor action descriptors with shell
  for (final editor in module.editors) {
    final integration = editor.integration;
    if (integration == null) continue;

    for (final descriptor in integration.actionDescriptors) {
      // Create shell action wrapping the editor's executeAction
      final shellAction = ForgeAction(
        id: descriptor.id,
        label: descriptor.label,
        icon: descriptor.icon,
        menu: ForgeMenuLocation.commandPalette,
        execute: (_) async {
          integration.executeAction(descriptor.id);
          return null;
        },
        isEnabled: () => integration.isActionEnabled(descriptor.id),
        isVisible: () => _isEditorFocused(editor),
      );

      actionRegistry.registerAction(shellAction);

      // Bind suggested shortcut (if any) as default
      if (descriptor.suggestedShortcut != null) {
        shortcutManager.rebind(shellAction, descriptor.suggestedShortcut!);
      }

      // Register alternative shortcuts
      for (final alt in descriptor.suggestedAlternatives) {
        shortcutManager.addAlternativeBinding(descriptor.id, alt);
      }
    }
  }
}
```

---

## 5. Deferred Override Problem Resolution

The current deferred override system exists because:

1. User preferences are loaded at shell startup
2. Editor modules register actions later (during `activate()`)
3. Editor widgets register action handlers even later (during `initState()`)

With externalization, this timing issue is simplified:

- **Action descriptors** are available at module activation time (static metadata)
- **Shell binds shortcuts** immediately using descriptors + user preferences
- **Action handlers** are registered when editor widget mounts, but this only affects `executeAction()` dispatch — not shortcut bindings
- **No deferred maps needed** — the shell has all descriptor metadata at activation time; user preferences apply directly to the binding table

The `_deferredShortcutOverrides` and `_deferredChordOverrides` maps in `DefaultShortcutManager` can be removed once all editors are migrated.

---

## 6. Migration Strategy

### 6.1 Phase 1: Add Infrastructure (non-breaking) — ✅ Implemented

1. ✅ Added `EditorActionDescriptor` class and `ActionContext` enum to `tom_editors_shared`
2. ✅ Added `actionDescriptors` getter to `ForgeEditorIntegration` (default returns empty list)
3. ✅ Added `handleShortcuts` parameter to all three editor widgets (default `true`)
4. ✅ Added static `descriptors` lists to all four action classes

### 6.2 Phase 2: Migrate Editors — ✅ Implemented

For each editor (YAML → MD → Dart):

1. ✅ Defined `EditorActionDescriptor` list in each action class
2. ✅ Overrode `actionDescriptors` in all standalone integrations
3. ✅ When `handleShortcuts == false`, editor skips shortcut widget setup
4. ✅ Verified standalone mode (`handleShortcuts: true`) and shell mode (`handleShortcuts: false`)
5. ✅ All editor-specific tests pass

### 6.3 Phase 3: Simplify Shell Integration — ✅ Implemented

1. ✅ Updated `ShellEditorIntegration` to use descriptor-based `_resolveAction()` lookup
2. ✅ Replaced hardcoded action pool with `actionDescriptors`-based resolution
3. ✅ Added `descriptors` setter to `ShellEditorIntegration`
4. ✅ Wired descriptors in all four forge adapters (YAML, Dart, MD, plain text)
5. ✅ All 693 tests pass across 6 packages

### 6.4 Phase 4: Shell Action Externalization — Pending

Externalize the shell's own shortcuts so they participate in the same system:

1. Create `ShellActionDescriptors` class with descriptors for all `forge.*` actions (§2.1.3)
2. Move shell shortcuts from hardcoded `_buildShortcuts()` in `ForgeShellScaffold` to descriptor-based registration
3. Ensure `TomForgeShellModule` exposes `actionDescriptors` via the module contract
4. Move `deleteLine`, `duplicateLine`, `moveLineUp`, `moveLineDown`, `toggleComment` from `DartEditorActions` to `StandardEditingActions`
5. Update all editors to include the expanded standard actions in their descriptor lists
6. Add shortcut scope support (global vs editor-specific) to `DefaultShortcutManager`
7. Update Shortcut Editor UI to show scope selection
8. Remove all remaining hardcoded shortcut-to-Intent mappings from `ForgeShellScaffold`

### 6.5 Phase 5: Update Documentation — Pending

1. ✅ Updated `forge_panel_shell_concept.md` §8.2 (module contract), §11 (shortcuts)
2. ✅ Updated `forge_editor_base.md` §5 (standard actions)
3. Update `forge_feature_checklist.md` §10 (actions and shortcut framework)
4. Update editor `how_to_embed.md` docs (standalone vs. shell mode)

---

## 7. Testing Strategy

### 7.1 Per-Editor Tests

For each editor, verify both modes:

| Test | `handleShortcuts: true` | `handleShortcuts: false` |
|------|--------------------------|--------------------------|
| Action execution via key press | Editor handles directly | No response (shell would handle) |
| Action execution via `executeAction()` | Works | Works |
| `isActionEnabled()` returns correct state | Works | Works |
| `actionDescriptors` returns complete list | All descriptors present | All descriptors present |
| Navigation keys (arrows, Tab, Enter) | Work | Work (not affected by flag) |

### 7.2 Shell Integration Tests

| Test | Expected |
|------|----------|
| Module activation registers all descriptors | Shell has all action IDs |
| User preferences override suggested shortcuts | Binding table reflects preferences |
| Shell key event dispatches to focused editor | Editor receives `executeAction()` call |
| Editor switch updates available actions | Previous editor's actions dimmed/hidden |
| Chord binding bypasses editor shortcuts | Editor's `getShortcutForAction()` returns null |
| Standard editing actions work through shell | Shell dispatches to editor, not `TextField` built-in |

---

## 8. Cross-Reference to Existing Documents

| Document | Affected Section | Nature of Change |
|----------|-----------------|------------------|
| [forge_panel_shell_concept.md](forge_panel_shell_concept.md) | §8.2 Module Contract | Added `actionDescriptors` to module contract; shell is a module |
| [forge_panel_shell_concept.md](forge_panel_shell_concept.md) | §11.1 Shortcut Architecture | Added action naming convention (§11.1.1), shell-as-action-source (§11.1.2), standard text editing actions (§11.1.3) |
| [forge_panel_shell_concept.md](forge_panel_shell_concept.md) | §11.3 Shell Shortcuts | Separated shell shortcuts from text editing shortcuts; added `Cmd+B` for bottom panel; added action IDs |
| [forge_panel_shell_concept.md](forge_panel_shell_concept.md) | §11.6 Shortcut Editor | Added scope selection (global vs editor-specific) |
| [forge_editor_base.md](forge_editor_base.md) | §1.1 Design Principles | Reinforced "Action Registry" principle |
| [forge_editor_base.md](forge_editor_base.md) | §3.3 Core Interfaces | Added `EditorActionDescriptor` specification |
| [forge_editor_base.md](forge_editor_base.md) | §5 Standard Actions | Expanded required actions: added moveLineUp/Down, duplicateLine; aligned action IDs with `forge.edit.*` naming |
| [forge_feature_checklist.md](forge_feature_checklist.md) | §10 Actions and Shortcut Framework | Add descriptor-based registration rows |
| [dart_editor_usage_guide.md](../../tom_dart_editor/doc/dart_editor_usage_guide.md) | Embedding section | Document `handleShortcuts` parameter |
| [how_to_embed.md](../../tom_yaml_editor/doc/how_to_embed.md) | Integration section | Document `handleShortcuts` parameter |
