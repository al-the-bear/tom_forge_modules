# Forge Editor Base - Unified Text Editing Foundation

## 1. Overview

This document specifies a **unified text editing foundation** for the Tom Forge ecosystem. The goal is to provide a shared set of widgets and interfaces that:

1. Enable tight integration with the Tom Forge Shell (context menus, actions, keyboard shortcuts, configuration)
2. Allow editors to remain fully functional as standalone components
3. Unify font settings, undo/redo, and standard editing operations but keep the ability to use editor specific actions with their own keyboard shortcuts (like auto-complete in the dart editor or opening the reference in the dart editor)
4. Support editor context discovery (selections, cursor position, state) for shell features

### 1.1 Design Principles

| Principle | Description |
|-----------|-------------|
| **Standalone First** | Editors must work without the shell; shell integration is optional |
| **Interface Contracts** | Define interfaces that the shell understands; implementations vary |
| **Configuration Injection** | Font settings and preferences are injected, not hardcoded |
| **Action Registry** | Editors publish available actions; shell binds shortcuts |

---

## 2. Current State Analysis

### 2.1 Text Input Widget Usage

| Editor | Primary Widget | Notes |
|--------|----------------|-------|
| MD Editor | `TextField` with `MdSyntaxHighlightController` | Single multiline field |
| Dart Editor | `TextField` with `_HighlightingTextController` | Single multiline field |
| YAML Editor | Multiple `TextField` widgets in tree structure | Structured editing |
| tom_editors_shared | `TextEditorCore` using `TextField` | Shared foundation |

TextEditorCore seems the right place to incorporate this.

### 2.2 Keyboard Shortcut Approaches

| Editor | Approach | Location |
|--------|----------|----------|
| MD Editor | `Shortcuts` + `Actions` widgets | md_editor.dart |
| Dart Editor | `FocusNode.onKeyEvent` callback | dart_code_editor.dart |
| YAML Editor | `KeyboardListener.onKeyEvent` | yaml_schema_editor.dart |

**Problem**: No unified approach — each editor handles shortcuts differently.

### 2.3 Context Menu Approaches

| Editor | Approach | Location |
|--------|----------|----------|
| MD Editor | Custom `contextMenuBuilder` on `TextField` | md_raw_text_editor.dart |
| Dart Editor | Default `TextField` behavior | N/A |
| YAML Editor | Dialog-based `YamlNodeActions` | node_actions.dart |

**Problem**: No way for the shell to discover available context actions. 

### 2.4 Undo/Redo Approaches

| Editor | Approach | Location |
|--------|----------|----------|
| MD Editor | Controller methods (`_controller.undo()`) | md_editor.dart |
| Dart Editor | Local stack (`_undoStack`/`_redoStack`) | dart_code_editor.dart |
| YAML Editor | `UndoHistory<YamlEditOperation>` from shared | yaml_editor_controller.dart |

**Problem**: Different undo granularity and APIs.

### 2.5 Font Configuration Approaches

| Editor | Configuration Class | Applied To |
|--------|---------------------|------------|
| MD Editor | `MdBasicTheme` | `TextStyle` |
| Dart Editor | `FontSettings` via `DartEditorTheme` | `TextStyle` |
| YAML Editor | `YamlEditorFontSettings` | `TextStyle` |

**Problem**: Three different configuration classes with overlapping concerns.

---

## 3. Proposed Architecture

### 3.1 Package Location

The unified foundation should live in **tom_editors_shared** since:
- It's already a dependency of all editors
- It doesn't depend on tom_forge_ui (no shell coupling)
- Editors can use it standalone or with shell integration

### 3.2 Component Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                    ForgeTextField                           │
│  (Wrapper around TextField with context discovery)          │
└──────────────────────────────────────────────────────────────┘
           │ uses                        │ uses
           ▼                             ▼
┌──────────────────────┐     ┌──────────────────────────────┐
│  ForgeTextContext    │     │  ForgeEditingActions         │
│  (Selection, cursor, │     │  (Cut, Copy, Paste, Undo,    │
│   document state)    │     │   Redo, Delete Line, etc.)   │
└──────────────────────┘     └──────────────────────────────┘
           │                             │
           ▼                             ▼
┌──────────────────────────────────────────────────────────────┐
│                    ForgeTextSettings                         │
│  (Font family, size, line height, tab size, etc.)            │
└──────────────────────────────────────────────────────────────┘
```

The settings structure must support base settings for all editors, but optional adaptation for each editor. 

### 3.3 Core Interfaces

#### 3.3.1 ForgeTextContext

Provides the shell with information about the current editing state.

```dart
/// Interface for discovering text editing context.
///
/// Implemented by editors to expose their state to the shell.
abstract interface class ForgeTextContext {
  /// Current text content.
  String get text;

  /// Current selection(s). Multiple for column selection.
  List<TextSelection> get selections;

  /// Primary cursor position.
  int get cursorOffset;

  /// Current line number (0-based).
  int get currentLine;

  /// Current column number (0-based).
  int get currentColumn;

  /// Whether the document has been modified.
  bool get isDirty;

  /// Whether undo is available.
  bool get canUndo;

  /// Whether redo is available.
  bool get canRedo;

  /// Stream of context changes.
  Stream<ForgeTextContext> get onContextChanged;
}
```

#### 3.3.2 ForgeEditingAction

A lightweight editing action for local editor operations. This is **intentionally simpler** than `ForgeAction` (which exists in tom_forge_ui for shell-level actions). The `ShellEditorIntegration` bridges these to full `ForgeAction` instances when needed.

```dart
/// A lightweight editing action that can be bound to keyboard shortcuts.
///
/// Unlike ForgeAction (shell-level), this is synchronous and focused on
/// immediate text editing operations. The shell integration bridges
/// these to ForgeAction when running inside the shell.
class ForgeEditingAction {
  /// Unique identifier (e.g., 'edit.cut', 'edit.deleteLine', 'dart.openReference').
  final String id;

  /// Display label for menus.
  final String label;

  /// Default keyboard shortcut (uses existing ForgeShortcutKey from tom_forge_ui).
  /// Can be rebound by shell.
  final ForgeShortcutKey? defaultShortcut;

  /// Whether this action appears in context menus.
  final bool showInContextMenu;

  /// Action executor. Returns true if handled.
  final bool Function() execute;

  /// Whether the action is currently available.
  final bool Function() isEnabled;

  const ForgeEditingAction({
    required this.id,
    required this.label,
    this.defaultShortcut,
    this.showInContextMenu = false,
    required this.execute,
    required this.isEnabled,
  });

  /// Converts to a ForgeAction for shell integration.
  ForgeAction toForgeAction({
    ForgeMenuLocation menu = ForgeMenuLocation.edit,
    IconData? icon,
  }) => ForgeAction(
    id: id,
    label: label,
    icon: icon,
    menu: menu,
    execute: (_) async {
      execute();
      return null;
    },
    isEnabled: isEnabled,
    isVisible: () => true,
    shortcut: defaultShortcut != null
        ? ForgeShortcutBinding(
            action: this as dynamic, // Will be replaced with actual action
            key: defaultShortcut!,
          )
        : null,
  );
}
```

#### 3.3.3 ForgeTextSettings

Unified configuration for text display. Can be used for default and per editor, setting per editor is optional.

```dart
/// Text editor display settings.
class ForgeTextSettings {
  /// Font family for code/text content.
  final String fontFamily;

  /// Secondary font for UI elements (comments, labels).
  final String? uiFontFamily;

  /// Base font size in logical pixels.
  final double fontSize;

  /// Line height multiplier.
  final double lineHeight;

  /// Tab size in spaces.
  final int tabSize;

  /// Whether to insert spaces instead of tabs.
  final bool insertSpaces;

  /// Whether to show whitespace characters.
  final bool showWhitespace;

  /// Whether to enable word wrap.
  final bool wordWrap;

  const ForgeTextSettings({
    this.fontFamily = 'monospace',
    this.uiFontFamily,
    this.fontSize = 14.0,
    this.lineHeight = 1.4,
    this.tabSize = 2,
    this.insertSpaces = true,
    this.showWhitespace = false,
    this.wordWrap = true,
  });

  /// Creates a copy with specified fields replaced.
  ForgeTextSettings copyWith({
    String? fontFamily,
    String? uiFontFamily,
    double? fontSize,
    double? lineHeight,
    int? tabSize,
    bool? insertSpaces,
    bool? showWhitespace,
    bool? wordWrap,
  }) => ForgeTextSettings(
    fontFamily: fontFamily ?? this.fontFamily,
    uiFontFamily: uiFontFamily ?? this.uiFontFamily,
    fontSize: fontSize ?? this.fontSize,
    lineHeight: lineHeight ?? this.lineHeight,
    tabSize: tabSize ?? this.tabSize,
    insertSpaces: insertSpaces ?? this.insertSpaces,
    showWhitespace: showWhitespace ?? this.showWhitespace,
    wordWrap: wordWrap ?? this.wordWrap,
  );

  /// Converts to a TextStyle.
  TextStyle toTextStyle({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    height: lineHeight,
    color: color,
  );
}
```

---

## 4. Widget Implementation

### 4.1 ForgeTextField

The core widget that wraps `TextField` with additional capabilities.

```dart
/// A text field with Forge integration capabilities.
///
/// Can be used standalone or integrated with the Forge shell.
/// The integration object determines behavior differences.
class ForgeTextField extends StatefulWidget {
  /// The text editing controller.
  final TextEditingController controller;

  /// Focus node for keyboard input.
  final FocusNode? focusNode;

  /// Editor integration (standalone or shell).
  /// Provides settings, actions, and context handling.
  final ForgeEditorIntegration integration;

  /// Whether the field is read-only.
  final bool readOnly;

  /// Maximum number of lines (null = unlimited).
  final int? maxLines;

  /// Callback when text changes.
  final ValueChanged<String>? onChanged;

  /// Custom context menu builder.
  /// If provided, fully replaces default behavior.
  final EditableTextContextMenuBuilder? contextMenuBuilder;

  /// Additional actions beyond the defaults.
  /// These are merged with standard cut/copy/paste/undo/redo.
  final List<ForgeEditingAction> customActions;

  const ForgeTextField({
    super.key,
    required this.controller,
    required this.integration,
    this.focusNode,
    this.readOnly = false,
    this.maxLines,
    this.onChanged,
    this.contextMenuBuilder,
    this.customActions = const [],
  });

  @override
  State<ForgeTextField> createState() => _ForgeTextFieldState();
}
```

The widget uses the integration for settings and shortcut resolution:

```dart
class _ForgeTextFieldState extends State<ForgeTextField> {
  late final Map<ShortcutActivator, Intent> _shortcuts;

  ForgeTextSettings get _settings => widget.integration.textSettings;

  @override
  void initState() {
    super.initState();
    _registerDefaultActions();
    _buildShortcuts();
  }

  void _registerDefaultActions() {
    // Register standard editing actions with the integration
    final controller = widget.controller;
    
    widget.integration.registerAction(ForgeEditingAction(
      id: 'edit.cut',
      label: 'Cut',
      defaultShortcut: ForgeShortcutKey(
        key: LogicalKeyboardKey.keyX,
        primaryModifier: true,
      ),
      showInContextMenu: true,
      execute: () {
        // Cut implementation
        return true;
      },
      isEnabled: () => !widget.readOnly && controller.selection.isValid,
    ));

    // ... register copy, paste, undo, redo, deleteLine, etc.
  }

  void _buildShortcuts() {
    _shortcuts = {};
    for (final action in widget.integration.registeredActions) {
      final key = widget.integration.getShortcutFor(action.id);
      if (key != null) {
        _shortcuts[key.toActivator()] = _ActionIntent(action.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: _shortcuts,
      child: Actions(
        actions: {
          _ActionIntent: CallbackAction<_ActionIntent>(
            onInvoke: (intent) {
              widget.integration.executeAction(intent.actionId);
              return null;
            },
          ),
        },
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          readOnly: widget.readOnly,
          maxLines: widget.maxLines,
          onChanged: widget.onChanged,
          style: _settings.toTextStyle(),
          contextMenuBuilder: widget.contextMenuBuilder ??
              _buildDefaultContextMenu,
        ),
      ),
    );
  }
}
```

---

## 5. Standard Actions

### 5.1 Required Actions

Every ForgeTextField must support these actions:

| Action ID | Default Shortcut | Description |
|-----------|------------------|-------------|
| `edit.cut` | ⌘X / Ctrl+X | Cut selection |
| `edit.copy` | ⌘C / Ctrl+C | Copy selection |
| `edit.paste` | ⌘V / Ctrl+V | Paste from clipboard |
| `edit.undo` | ⌘Z / Ctrl+Z | Undo last change |
| `edit.redo` | ⌘⇧Z / Ctrl+Y | Redo last undone change |
| `edit.selectAll` | ⌘A / Ctrl+A | Select all text |
| `edit.deleteLine` | ⌘Y / Ctrl+Y | Delete current line |

### 5.2 Optional Actions

Editors must also provide additional actions:

| Action ID | Suggested Shortcut | Description |
|-----------|-------------------|-------------|
| `edit.duplicateLine` | ⌘D / Ctrl+D | Duplicate current line |
| `edit.moveLineUp` | ⌥↑ / Alt+Up | Move line up |
| `edit.moveLineDown` | ⌥↓ / Alt+Down | Move line down |


Editors should also provide additional actions if this makes sense in the editor:

| Action ID | Suggested Shortcut | Description |
|-----------|-------------------|-------------|
| `edit.indentLine` | ⌘] / Ctrl+] | Indent line |
| `edit.outdentLine` | ⌘[ / Ctrl+[ | Outdent line |
| `edit.toggleComment` | ⌘/ / Ctrl+/ | Toggle line comment |
| `edit.formatDocument` | ⌥⇧F / Alt+Shift+F | Format document |

---

## 6. Context Menu Integration

### 6.1 Default Context Menu

When no custom `contextMenuBuilder` is provided:

```dart
Widget _buildDefaultContextMenu(
  BuildContext context,
  EditableTextState editableTextState,
) {
  final allActions = [
    ...standardActions,
    ...widget.customActions,
    ...widget.integration?.getContextMenuActions() ?? [],
  ];

  final contextActions = allActions
      .where((a) => a.showInContextMenu && a.isEnabled())
      .toList();

  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: editableTextState.contextMenuAnchors,
    buttonItems: [
      // Standard items
      ...editableTextState.contextMenuButtonItems,
      // Separator if we have custom items
      if (contextActions.isNotEmpty) const ContextMenuButtonItem.divider(),
      // Custom items
      for (final action in contextActions)
        ContextMenuButtonItem(
          label: action.label,
          onPressed: () {
            action.execute();
            editableTextState.hideToolbar();
          },
        ),
    ],
  );
}
```

### 6.2 Shell-Aware Context Menu

For integration with the shell:

1. Editor calls `integration.getContextMenuActions()` to get shell-provided items
2. Shell queries registered modules for relevant context actions
3. Actions are filtered by the current `ForgeTextContext`
4. Combined menu is displayed

When not integrated the integration feature just return no items.

---

## 7. Configuration Panel Support

### 7.1 EditorConfigurationProvider

Editors expose their configuration panels through this interface:

```dart
/// Interface for editors to provide configuration UI.
abstract interface class EditorConfigurationProvider {
  /// Unique identifier for this editor type.
  String get editorTypeId;

  /// Display name for the configuration section.
  String get configurationTitle;

  /// Icon for the configuration section.
  IconData get configurationIcon;

  /// Builds the configuration panel widget.
  Widget buildConfigurationPanel(
    BuildContext context,
    ForgeTextSettings currentSettings,
    ValueChanged<ForgeTextSettings> onSettingsChanged,
  );
}
```

### 7.2 Shell Configuration Integration

The shell's Settings dialog can discover and display editor configuration:

```dart
// In ForgeConfigurationDialog
for (final editor in shellApi.registeredEditorTypes) {
  final configProvider = editor as EditorConfigurationProvider?;
  if (configProvider != null) {
    tabs.add(Tab(
      icon: Icon(configProvider.configurationIcon),
      text: configProvider.configurationTitle,
    ));
    tabViews.add(configProvider.buildConfigurationPanel(
      context,
      currentSettings,
      (newSettings) => _saveEditorSettings(configProvider.editorTypeId, newSettings),
    ));
  }
}
```

---

## 8. Standalone vs Integrated Usage

### 8.1 Standalone Usage (No Shell)

```dart
// In md_editor.dart (standalone mode)
// Use the editor-specific standalone integration
final integration = MdStandaloneIntegration(
  settings: ForgeTextSettings(
    fontFamily: theme.fontFamily,
    fontSize: theme.baseFontSize,
  ),
);

// Register custom actions
integration.registerAction(ForgeEditingAction(
  id: 'md.insertTable',
  label: 'Insert Table',
  defaultShortcut: ForgeShortcutKey(key: LogicalKeyboardKey.keyT, alt: true),
  showInContextMenu: true,
  execute: () => _insertTable(),
  isEnabled: () => !readOnly,
));

// Use with ForgeTextField
ForgeTextField(
  controller: _textController,
  integration: integration,
  customActions: integration.registeredActions,
)

// Keyboard shortcuts work automatically via the integration
```

### 8.2 Integrated Usage (With Shell)

```dart
// In shell adapter module
// Use shell integration which bridges to ForgeShellApi
final integration = ShellEditorIntegration(
  shellApi: shellApi,
  editorId: 'md-editor-${document.id}',
);

// Register custom actions (will be bridged to shell's ForgeAction registry)
integration.registerAction(ForgeEditingAction(
  id: 'md.insertTable',
  label: 'Insert Table',
  defaultShortcut: ForgeShortcutKey(key: LogicalKeyboardKey.keyT, alt: true),
  showInContextMenu: true,
  execute: () => _insertTable(),
  isEnabled: () => !readOnly,
));

// Same widget, same API
ForgeTextField(
  controller: _textController,
  integration: integration,
  customActions: integration.registeredActions,
)

// Shell can rebind shortcuts, show actions in command palette, etc.
```

### 8.3 Key Difference

The **only difference** is which integration object is passed:

| Aspect | Standalone | Shell |
|--------|-----------|-------|
| Integration class | `MdStandaloneIntegration` | `ShellEditorIntegration` |
| Settings source | Constructor parameter | Shell config system |
| Undo/Redo | Local stack | Shell's unified manager |
| Shortcut rebinding | No | Yes |
| Context menu extras | None | From registered modules |
| Action discovery | No | Yes (command palette) |

---

## 9. Migration Path

### 9.1 Phase 1: Create Foundation (tom_editors_shared)

1. Create `ForgeTextSettings` class
2. Create `ForgeTextContext` interface
3. Create `ForgeEditingAction` class (lightweight, sync)
4. Create `ForgeEditorIntegration` interface
5. Create standalone integrations:
   - `DartStandaloneIntegration`
   - `MdStandaloneIntegration`
   - `YamlStandaloneIntegration`
6. Create `ForgeTextField` widget
7. Create `StandardEditingActions` factory for Cut/Copy/Paste/Undo/Redo

### 9.2 Phase 2: Update Editors

For each editor (MD, Dart, YAML):

1. Add `ForgeEditorIntegration` parameter (required)
2. Replace raw `TextField` usage with `ForgeTextField`
3. Move editor-specific settings to standalone integration defaults
4. Register editor-specific actions with integration
5. Remove manual keyboard shortcut handling (use integration)
6. Implement `ForgeTextContext` for context discovery

### 9.3 Phase 3: Shell Integration (tom_forge_ui)

1. Create `ShellEditorIntegration` implementation
2. Bridge `ForgeEditingAction` to `ForgeAction` in registry
3. Update module adapters to create `ShellEditorIntegration`
4. Wire up shortcut rebinding via `ForgeShortcutManager`
5. Add context menu action discovery
6. Add editor configuration to Settings dialog

---

## 10. File Structure (Revised)

```
tom_editors_shared/lib/src/
  text_editing/                              # NEW folder
    forge_text_field.dart                    # ForgeTextField widget
    forge_text_context.dart                  # ForgeTextContext interface
    forge_text_settings.dart                 # ForgeTextSettings class
    forge_editing_action.dart                # ForgeEditingAction class
    forge_editor_integration.dart            # Base integration interface
    standard_editing_actions.dart            # Factory for Cut/Copy/Paste/Undo/Redo
    integrations/
      dart_standalone_integration.dart       # Dart editor standalone
      md_standalone_integration.dart         # Markdown editor standalone
      yaml_standalone_integration.dart       # YAML editor standalone

tom_forge_ui/lib/src/
  integrations/
    shell_editor_integration.dart            # Shell integration implementation
    editor_action_bridge.dart                # Bridges ForgeEditingAction to ForgeAction
```

---

## 11. Appendix: Shortcut Key Reference

### 11.1 ForgeShortcutKey (Existing)

The `ForgeShortcutKey` class **already exists** in `tom_forge_ui/lib/src/actions/forge_shortcut_binding.dart`:

```dart
// EXISTING in tom_forge_ui - DO NOT REDEFINE
class ForgeShortcutKey {
  final LogicalKeyboardKey key;
  final bool primaryModifier;  // Cmd on macOS, Ctrl on Windows/Linux
  final bool shift;
  final bool alt;

  const ForgeShortcutKey({
    required this.key,
    this.primaryModifier = false,
    this.shift = false,
    this.alt = false,
  });
}
```

### 11.2 Extension for SingleActivator

Add a conversion extension (if not already present):

```dart
extension ForgeShortcutKeyExtension on ForgeShortcutKey {
  /// Converts to Flutter's SingleActivator.
  SingleActivator toActivator() {
    final isMacOS = Platform.isMacOS;
    return SingleActivator(
      key,
      control: !isMacOS && primaryModifier,
      meta: isMacOS && primaryModifier,
      alt: alt,
      shift: shift,
    );
  }
}
```

### 11.3 Platform Adaptation

The standard actions use `primaryModifier` which resolves to:
- **macOS**: ⌘ (Command)
- **Windows/Linux**: Ctrl

This ensures consistent behavior across platforms while respecting platform conventions.

---

## 12. Compatibility with Existing Interfaces

### 12.1 Existing tom_forge_ui Interfaces

The following interfaces already exist in `tom_forge_ui`:

| Interface | Location | Notes |
|-----------|----------|-------|
| `ForgeAction` | `actions/forge_action.dart` | Async execute, returns `Object?`, has `undo` |
| `ForgeShortcutKey` | `actions/forge_shortcut_binding.dart` | Uses `primaryModifier` (not separate ctrl/meta) |
| `ForgeShortcutBinding` | `actions/forge_shortcut_binding.dart` | Links action to key with context |
| `ForgeShortcutManager` | `services/forge_shortcut_manager.dart` | Global rebinding and conflict detection |
| `ForgeModule` | `module/forge_module.dart` | Registration interface |
| `ForgeComponent` | `components/forge_component.dart` | Base with actions/shortcuts lists |

### 12.2 Required Alignment

**ForgeShortcutKey**: The existing interface uses `primaryModifier` which automatically resolves to Cmd on macOS or Ctrl on Windows/Linux. The concept document should use this existing class, not define a new one.

```dart
// EXISTING in tom_forge_ui - use this, don't redefine
class ForgeShortcutKey {
  final LogicalKeyboardKey key;
  final bool primaryModifier;  // Cmd on macOS, Ctrl otherwise
  final bool shift;
  final bool alt;
  // ...
}
```

**ForgeAction vs ForgeEditingAction**: The existing `ForgeAction` is async with menu placement, visibility, and undo support. For text editing, we create a lightweight adapter that bridges to `ForgeAction` when integrated with the shell.

---

## 13. Unified Integration Approach

The key insight is that editors should use the **same API** regardless of whether they run standalone or integrated with the shell. The difference is encapsulated in an **integration object** that provides context-specific behavior.

### 13.1 ForgeEditorIntegration Interface

```dart
/// Base interface for editor integration.
///
/// This is the single interface editors use for all integration points.
/// Different implementations provide standalone vs shell behavior.
abstract interface class ForgeEditorIntegration {
  /// Get text display settings.
  ForgeTextSettings get textSettings;

  /// Get the list of registered editing actions.
  List<ForgeEditingAction> get registeredActions;

  /// Register a new action (typically at editor startup).
  void registerAction(ForgeEditingAction action);

  /// Execute an action by ID. Returns true if handled.
  bool executeAction(String actionId);

  /// Check if an action is enabled.
  bool isActionEnabled(String actionId);

  /// Get keyboard shortcut for an action (may be rebound in shell).
  ForgeShortcutKey? getShortcutFor(String actionId);

  /// Notify that text context has changed.
  void onContextChanged(ForgeTextContext context);

  /// Get additional context menu actions.
  List<ForgeEditingAction> getContextMenuActions();

  /// Handle undo operation.
  void undo();

  /// Handle redo operation.
  void redo();

  /// Whether undo is available.
  bool get canUndo;

  /// Whether redo is available.
  bool get canRedo;
}
```

### 13.2 Standalone Integrations

Each editor provides a standalone integration that works without the shell:

```dart
/// Standalone integration for the Dart editor.
///
/// Provides keyboard shortcuts and undo/redo without shell dependency.
class DartStandaloneIntegration implements ForgeEditorIntegration {
  DartStandaloneIntegration({
    ForgeTextSettings? settings,
  }) : textSettings = settings ?? const ForgeTextSettings(
    fontFamily: 'JetBrains Mono',
    fontSize: 13.0,
    tabSize: 2,
  );

  @override
  final ForgeTextSettings textSettings;

  final List<ForgeEditingAction> _actions = [];
  final List<_UndoEntry> _undoStack = [];
  final List<_UndoEntry> _redoStack = [];

  @override
  List<ForgeEditingAction> get registeredActions =>
      List.unmodifiable(_actions);

  @override
  void registerAction(ForgeEditingAction action) {
    _actions.add(action);
  }

  @override
  bool executeAction(String actionId) {
    final action = _actions.firstWhere(
      (a) => a.id == actionId,
      orElse: () => throw StateError('Action not found: $actionId'),
    );
    if (action.isEnabled()) {
      return action.execute();
    }
    return false;
  }

  @override
  bool isActionEnabled(String actionId) {
    final action = _actions.cast<ForgeEditingAction?>().firstWhere(
      (a) => a?.id == actionId,
      orElse: () => null,
    );
    return action?.isEnabled() ?? false;
  }

  @override
  ForgeShortcutKey? getShortcutFor(String actionId) {
    final action = _actions.cast<ForgeEditingAction?>().firstWhere(
      (a) => a?.id == actionId,
      orElse: () => null,
    );
    return action?.defaultShortcut;
  }

  @override
  void onContextChanged(ForgeTextContext context) {
    // No-op for standalone — no shell to notify
  }

  @override
  List<ForgeEditingAction> getContextMenuActions() => const [];

  @override
  void undo() {
    if (_undoStack.isEmpty) return;
    final entry = _undoStack.removeLast();
    _redoStack.add(entry);
    entry.undo();
  }

  @override
  void redo() {
    if (_redoStack.isEmpty) return;
    final entry = _redoStack.removeLast();
    _undoStack.add(entry);
    entry.redo();
  }

  @override
  bool get canUndo => _undoStack.isNotEmpty;

  @override
  bool get canRedo => _redoStack.isNotEmpty;

  /// Push an undo-able operation.
  void pushUndo(_UndoEntry entry) {
    _undoStack.add(entry);
    _redoStack.clear();
  }
}

class _UndoEntry {
  final void Function() undo;
  final void Function() redo;
  _UndoEntry({required this.undo, required this.redo});
}
```

Similarly for other editors:

```dart
/// Standalone integration for the Markdown editor.
class MdStandaloneIntegration implements ForgeEditorIntegration {
  MdStandaloneIntegration({
    ForgeTextSettings? settings,
  }) : textSettings = settings ?? const ForgeTextSettings(
    fontFamily: 'monospace',
    fontSize: 14.0,
    wordWrap: true,
  );
  // ... same structure as DartStandaloneIntegration
}

/// Standalone integration for the YAML editor.
class YamlStandaloneIntegration implements ForgeEditorIntegration {
  YamlStandaloneIntegration({
    ForgeTextSettings? settings,
  }) : textSettings = settings ?? const ForgeTextSettings(
    fontFamily: 'monospace',
    fontSize: 14.0,
    tabSize: 2,
    insertSpaces: true,
  );
  // ... same structure as DartStandaloneIntegration
}
```

### 13.3 Shell Integration

When running inside the Tom Forge Shell:

```dart
/// Shell integration that bridges to ForgeShellApi.
///
/// Provides full shell features: rebindable shortcuts, shared undo,
/// context menus from modules, and configuration from preferences.
class ShellEditorIntegration implements ForgeEditorIntegration {
  ShellEditorIntegration({
    required ForgeShellApi shellApi,
    required String editorId,
  }) : _shellApi = shellApi,
       _editorId = editorId;

  final ForgeShellApi _shellApi;
  final String _editorId;
  final List<ForgeEditingAction> _editorActions = [];

  @override
  ForgeTextSettings get textSettings {
    // Get from shell configuration, with editor-specific overrides
    return _shellApi.config.getTextSettings(_editorId);
  }

  @override
  List<ForgeEditingAction> get registeredActions =>
      List.unmodifiable(_editorActions);

  @override
  void registerAction(ForgeEditingAction action) {
    _editorActions.add(action);
    // Also register with shell's action registry
    _shellApi.actionRegistry.registerEditorAction(_editorId, action);
  }

  @override
  bool executeAction(String actionId) {
    // First check editor-specific actions
    final editorAction = _editorActions.cast<ForgeEditingAction?>().firstWhere(
      (a) => a?.id == actionId,
      orElse: () => null,
    );
    if (editorAction != null && editorAction.isEnabled()) {
      return editorAction.execute();
    }
    // Fall back to shell-level action
    return _shellApi.executeAction(actionId);
  }

  @override
  bool isActionEnabled(String actionId) {
    final action = _editorActions.cast<ForgeEditingAction?>().firstWhere(
      (a) => a?.id == actionId,
      orElse: () => null,
    );
    return action?.isEnabled() ?? _shellApi.isActionEnabled(actionId);
  }

  @override
  ForgeShortcutKey? getShortcutFor(String actionId) {
    // Shell may have rebound the shortcut
    return _shellApi.shortcuts.getBinding(actionId)?.key;
  }

  @override
  void onContextChanged(ForgeTextContext context) {
    // Notify shell of selection changes for status bar, outline, etc.
    _shellApi.systemState.updateEditorContext(_editorId, context);
  }

  @override
  List<ForgeEditingAction> getContextMenuActions() {
    // Query modules for applicable context actions
    return _shellApi.getContextActionsFor(_editorId);
  }

  @override
  void undo() => _shellApi.undoManager.undo();

  @override
  void redo() => _shellApi.undoManager.redo();

  @override
  bool get canUndo => _shellApi.undoManager.canUndo.value;

  @override
  bool get canRedo => _shellApi.undoManager.canRedo.value;
}
```

### 13.4 Unified Editor Usage

With this approach, editor code looks identical regardless of integration:

```dart
class DartCodeEditor extends StatefulWidget {
  final ForgeEditorIntegration integration;
  // ...

  const DartCodeEditor({
    super.key,
    required this.integration,  // Same parameter in both modes
  });
}

// STANDALONE USAGE:
DartCodeEditor(
  integration: DartStandaloneIntegration(
    settings: ForgeTextSettings(fontFamily: 'Fira Code'),
  ),
)

// SHELL USAGE:
DartCodeEditor(
  integration: ShellEditorIntegration(
    shellApi: shellApi,
    editorId: 'dart-editor-1',
  ),
)
```

### 13.5 Keyboard Shortcut Handling

The editor widget uses the integration to resolve shortcuts:

```dart
class _DartCodeEditorState extends State<DartCodeEditor> {
  late final Map<ShortcutActivator, Intent> _shortcuts;

  @override
  void initState() {
    super.initState();
    _buildShortcuts();
  }

  void _buildShortcuts() {
    _shortcuts = {};
    for (final action in widget.integration.registeredActions) {
      final key = widget.integration.getShortcutFor(action.id);
      if (key != null) {
        _shortcuts[key.toActivator()] = _ActionIntent(action.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: _shortcuts,
      child: Actions(
        actions: {
          _ActionIntent: CallbackAction<_ActionIntent>(
            onInvoke: (intent) {
              widget.integration.executeAction(intent.actionId);
              return null;
            },
          ),
        },
        child: // ... rest of editor
      ),
    );
  }
}

class _ActionIntent extends Intent {
  final String actionId;
  const _ActionIntent(this.actionId);
}
```

---

## 14. File Structure (Revised)

```
tom_editors_shared/lib/src/
  text_editing/                          # NEW folder
    forge_text_field.dart                # ForgeTextField widget
    forge_text_context.dart              # ForgeTextContext interface
    forge_text_settings.dart             # ForgeTextSettings class
    forge_editing_action.dart            # ForgeEditingAction class
    forge_editor_integration.dart        # Base integration interface
    standard_editing_actions.dart        # Default Cut/Copy/Paste/Undo/Redo
    integrations/
      dart_standalone_integration.dart
      md_standalone_integration.dart
      yaml_standalone_integration.dart

tom_forge_ui/lib/src/
  integrations/
    shell_editor_integration.dart        # Shell integration implementation
```

---

## 15. Summary

The Forge Editor Base provides:

| Feature | Standalone | With Shell |
|---------|------------|------------|
| Text editing | ✓ | ✓ |
| Syntax highlighting | ✓ | ✓ |
| Undo/Redo | ✓ (local stack) | ✓ (shell unified) |
| Cut/Copy/Paste | ✓ | ✓ |
| Keyboard shortcuts | ✓ (defaults) | ✓ (rebindable) |
| Context menus | ✓ (editor-only) | ✓ (shell-aware) |
| Font settings | ✓ (injected) | ✓ (from config) |
| Config panel | ✗ | ✓ |
| Action discovery | ✗ | ✓ |
| Selection sharing | ✗ | ✓ |

**Key benefits of the unified integration approach:**

1. **Same editor code** — No conditional logic for standalone vs shell
2. **Encapsulated differences** — Integration object handles all mode-specific behavior
3. **Compatible with existing interfaces** — Uses existing `ForgeShortcutKey`, adapts to `ForgeAction`
4. **Standalone keyboard shortcuts work** — Each standalone integration provides default shortcuts
5. **Shell shortcuts are rebindable** — ShellEditorIntegration queries the shortcut manager
