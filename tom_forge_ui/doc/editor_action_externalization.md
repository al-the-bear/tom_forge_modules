# Editor Action Externalization — Architecture Proposal

**Date:** 2026-04-06  
**Status:** Proposal  
**Companion:** [forge_panel_shell_concept.md](forge_panel_shell_concept.md) (§8 Modules, §11 Shortcuts), [forge_editor_base.md](forge_editor_base.md) (§3 Proposed Architecture)

---

## 1. Problem Statement

The current architecture creates shortcut conflicts when multiple editors register their own keyboard bindings with the shell. Each editor:

1. **Defines its own shortcuts** in action classes (`DartEditorActions`, `MdEditorActions`, `YamlEditorActions`)
2. **Registers them with the shell** via `ShellEditorIntegration._registerWithShell()` → `shortcutManager.rebind()`
3. **Also handles shortcuts locally** via Flutter `Shortcuts`/`Actions` widgets or `onKeyEvent` callbacks

This dual registration causes:

- **Shortcut collisions** — when two editors define the same key (e.g., `Ctrl+Y` is "deleteLine" in Dart but "Delete line" at shell level)
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
- `_toShellAction()` / `_toShellShortcut()` conversion methods

Instead, it reads descriptors from the editor and forwards `executeAction()` calls from the shell.

### 2.7 Standard Editing Actions

The six standard editing actions (`cut/copy/paste/selectAll/undo/redo`) follow the same pattern — they become descriptors with `ActionContext.textEditorFocused` (or `hasSelection` for cut/copy). The shell binds them to concept §11.3 shortcuts (`Cmd+X`, `Cmd+C`, `Cmd+V`, `Cmd+A`, `Cmd+U`, `Cmd+Z`).

The current `_editorInternalActions` exclusion in `ShellEditorIntegration` is eliminated. The shell owns all shortcut bindings, including standard editing operations.

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
| `DartEditorActions` | Convert factory methods to `EditorActionDescriptor` list; move shortcuts to `suggestedShortcut` field |
| `DartCodeEditor._registerActions()` | Simplify to register handlers only (no shortcut map building) |
| `DartCodeEditor._buildShortcutMap()` | Conditional: only build when `handleShortcuts == true` |
| `DartCodeEditor.build()` | Conditional: wrap in `Shortcuts`/`Actions` only when `handleShortcuts == true` |
| `DartStandaloneIntegration` | Add `actionDescriptors` getter returning standard + Dart descriptors |

**Action descriptors (7 custom + 6 standard = 13 total):**

| ID | Label | Category | Suggested Shortcut | Context |
|----|-------|----------|--------------------|---------|
| `dart.triggerCompletion` | Trigger Completion | Dart Editor | `Ctrl+Space` | editorFocused |
| `dart.openReference` | Open Reference | Dart Editor | *(none)* | editorFocused |
| `dart.toggleComment` | Toggle Comment | Dart Editor | `Ctrl+/` | editable |
| `dart.deleteLine` | Delete Line | Dart Editor | `Ctrl+Y` | editable |
| `dart.duplicateLine` | Duplicate Line | Dart Editor | `Ctrl+D` | editable |
| `dart.moveLineUp` | Move Line Up | Dart Editor | `Alt+↑` | editable |
| `dart.moveLineDown` | Move Line Down | Dart Editor | `Alt+↓` | editable |
| + 6 standard editing actions | | Standard | per §11.3 | varies |

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

**Action descriptors (9 custom + 6 standard = 15 total):**

| ID | Label | Category | Suggested Shortcut | Context |
|----|-------|----------|--------------------|---------|
| `md.toggleBold` | Toggle Bold | Markdown | `Ctrl+B` | editable |
| `md.toggleItalic` | Toggle Italic | Markdown | `Ctrl+I` | editable |
| `md.toggleCode` | Toggle Code | Markdown | `Ctrl+E` | editable |
| `md.insertLink` | Insert Link | Markdown | `Ctrl+K` | editable |
| `md.insertTable` | Insert Table | Markdown | `Alt+T` | editable |
| `md.insertHeading` | Insert Heading | Markdown | `Alt+H` | editable |
| `md.toggleList` | Toggle List | Markdown | `Alt+L` | editable |
| `md.save` | Save | Markdown | `Ctrl+S` | editorFocused |
| `md.search` | Search | Markdown | `Ctrl+F` | editorFocused |
| + 6 standard editing actions | | Standard | per §11.3 | varies |

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

**Action descriptors (5 custom + 2 standard = 7 total):**

| ID | Label | Category | Suggested Shortcut | Context |
|----|-------|----------|--------------------|---------|
| `yaml.addKey` | Add Key | YAML Editor | `Ctrl+N` | editable |
| `yaml.removeKey` | Remove Key | YAML Editor | `Ctrl+Delete` | editable |
| `yaml.toggleTextMode` | Toggle Text Mode | YAML Editor | `Ctrl+T` | editorFocused |
| `yaml.save` | Save | YAML Editor | `Ctrl+S` | editorFocused |
| `yaml.search` | Search | YAML Editor | `Ctrl+F` | editorFocused |
| `forge.edit.undo` | Undo | Standard | `Ctrl+U` | editorFocused |
| `forge.edit.redo` | Redo | Standard | `Ctrl+Z` | editorFocused |

**Note:** The YAML editor registers only `undo/redo` from standard actions (no cut/copy/paste/selectAll) because it is tree-based, not text-based. Tree navigation keys (arrows, Tab, Enter, Escape, Space) remain in the editor's `KeyboardListener` regardless of the `handleShortcuts` flag — they are navigation, not actions.

### 3.4 Flow Editor (`tom_flow_editor`)

Currently a minimal placeholder. When implemented, it follows the same pattern: expose `EditorActionDescriptor` list, accept `handleShortcuts` flag.

---

## 4. ShellEditorIntegration Simplification

### 4.1 Current Complexity

`ShellEditorIntegration` currently:

1. Maintains `_editorInternalActions` exclusion set (6 hardcoded action IDs)
2. Has `_resolveAction()` with a hardcoded pool of **all possible actions across all editors** (22 actions from Dart + MD + YAML + Standard)
3. Wraps each action in a shell-compatible `ForgeAction` via `_toShellAction()`
4. Converts shortcut keys between shared and shell formats via `_toShellShortcut()`
5. Decides per-action whether to register with shell or handle internally
6. Returns `null` from `getShortcutForAction()` for chord bindings to prevent editor interception

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
    return _toSharedShortcut(binding.key);
  }

  // ... text context, focus, text manipulation methods unchanged
}
```

**Eliminated:**
- `_editorInternalActions` set
- `_resolveAction()` method and its hardcoded action pool
- `_registerWithShell()` method
- `_toShellAction()` conversion
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
        menu: ForgeMenuLocation.none,
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

### 6.1 Phase 1: Add Infrastructure (non-breaking)

1. Add `EditorActionDescriptor` class to `tom_editors_shared`
2. Add `actionDescriptors` getter to `ForgeEditorIntegration` (default returns empty list)
3. Add `handleShortcuts` parameter to all three editor widgets (default `true`)
4. No behavioral changes — everything works as before

### 6.2 Phase 2: Migrate Editors One by One

For each editor (recommended order: YAML → MD → Dart):

1. Define `EditorActionDescriptor` list in the action class
2. Override `actionDescriptors` in the standalone integration
3. When `handleShortcuts == false`, skip shortcut widget setup
4. Verify standalone mode still works (`handleShortcuts: true`)
5. Verify shell mode works (`handleShortcuts: false`)
6. Update tests for both modes

### 6.3 Phase 3: Simplify Shell Integration

1. Update `ShellEditorIntegration` to use descriptor-based registration
2. Remove `_editorInternalActions`, `_resolveAction()`, `_registerWithShell()`
3. Update `DefaultModuleRegistry` to process descriptors
4. Remove deferred override maps from `DefaultShortcutManager`
5. Update all shortcut-related tests

### 6.4 Phase 4: Update Documentation

1. Update `forge_panel_shell_concept.md` §11 (shortcut architecture)
2. Update `forge_editor_base.md` §3 (component hierarchy)
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
| [forge_panel_shell_concept.md](forge_panel_shell_concept.md) | §8.2 Module Contract | Add `actionDescriptors` to module/integration contract |
| [forge_panel_shell_concept.md](forge_panel_shell_concept.md) | §11.1 Shortcut Architecture | Clarify shell-owned binding model |
| [forge_panel_shell_concept.md](forge_panel_shell_concept.md) | §11.5 Component-Specific Shortcuts | Describe `handleShortcuts` switch |
| [forge_editor_base.md](forge_editor_base.md) | §1.1 Design Principles | Reinforce "Action Registry" principle |
| [forge_editor_base.md](forge_editor_base.md) | §3.3 Core Interfaces | Add `EditorActionDescriptor` specification |
| [forge_feature_checklist.md](forge_feature_checklist.md) | §10 Actions and Shortcut Framework | Add descriptor-based registration rows |
| [dart_editor_usage_guide.md](../tom_dart_editor/doc/dart_editor_usage_guide.md) | Embedding section | Document `handleShortcuts` parameter |
| [how_to_embed.md](../tom_yaml_editor/doc/how_to_embed.md) | Integration section | Document `handleShortcuts` parameter |
