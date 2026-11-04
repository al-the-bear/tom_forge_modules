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
| **Action Registry** | Editors publish available actions via descriptors; shell binds shortcuts. Actions use `<source>.<action>` naming (see §5.0). |
| **No Hidden Shortcuts** | Every shortcut is registered through the action/descriptor system and appears in the Shortcut Editor |
| **Shell is a Module** | The shell exposes its own actions (`forge.*`) through the same system as editors |

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

Every editor keeps its history on one stack, `tom_undo`'s
`TomUndoStack<E>` (`package:tom_undo/tom_undo.dart`), which
applies an entry first and moves it second, so a failed undo leaves the history
as it was. What differs is the entry:

| Editor | Entry on the stack | Location |
|--------|--------------------|----------|
| MD Editor | `MdEditOperation` | md_editor_controller.dart |
| Dart Editor | a before/after text change | dart_code_editor.dart |
| YAML Editor | `YamlEditOperation` | yaml_editor_controller.dart |
| Plain-text editor | its file's `ForgeFileSession`: `ForgeFileHistoryEntry` | file_session.dart |
| Standalone integrations | `TextUndoEntry` | base_standalone_integration.dart |
| File tabs (`ForgeFileSession`) | `ForgeFileHistoryEntry` | file_session.dart |

The shell's own history, `DefaultUndoManager`, runs on the same stack and holds
shell actions only; no editor pushes into it. The undo keys reach an editor
through the shell's binding table (`forge.edit.undo` / `forge.edit.redo`).

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
│  ForgeTextContext    │     │  ForgeAction (editing)       │
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

#### 3.3.2 ForgeAction (Unified)

All actions — both shell-level and editor-level — use the **same `ForgeAction` class** from `tom_forge_ui/lib/src/actions/forge_action.dart`. This eliminates the need for a separate editing action type.

For simple synchronous editing operations, use the `ForgeAction.editing()` factory:

```dart
/// From tom_forge_ui - the unified action class.
/// See forge_action.dart for full implementation.

// Simple editing action using factory constructor:
ForgeAction.editing(
  id: 'forge.edit.cut',
  label: 'Cut',
  icon: Icons.cut,
  shortcut: ForgeShortcutKey(key: LogicalKeyboardKey.keyX, primaryModifier: true),
  showInContextMenu: true,
  execute: () {
    // synchronous cut logic
    return true; // handled
  },
  isEnabled: () => controller.selection.isValid && !readOnly,
)

// Full action with async execute and undo:
ForgeAction(
  id: 'file.save',
  label: 'Save',
  icon: Icons.save,
  menu: ForgeMenuLocation.file,
  defaultShortcut: ForgeShortcutKey(key: LogicalKeyboardKey.keyS, primaryModifier: true),
  execute: (params) async {
    final uri = params['uri'] as Uri?;
    await fileSystem.save(uri);
    return SaveUndoInfo(uri: uri, previousContent: content);
  },
  isEnabled: () => document.isDirty,
  isVisible: () => true,
  undo: (undoInfo) async {
    final info = undoInfo as SaveUndoInfo;
    await fileSystem.write(info.uri, info.previousContent);
  },
)
```

**Key `ForgeAction` fields:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String` | Unique identifier (e.g., 'forge.edit.cut', 'dart.openReference') |
| `label` | `String` | Display label for menus |
| `icon` | `IconData?` | Optional icon |
| `menu` | `ForgeMenuLocation` | Where to show (file, edit, view, commandPalette, etc.) |
| `defaultShortcut` | `ForgeShortcutKey?` | Default keyboard shortcut (rebindable) |
| `showInContextMenu` | `bool` | Whether to show in context menus |
| `execute` | `Future<Object?> Function(Map)` | Action handler |
| `isEnabled` | `bool Function()` | Enable state |
| `isVisible` | `bool Function()` | Visibility state |
| `undo` | `Future<void> Function(Object)?` | Undo handler |

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
  final List<ForgeAction> customActions;

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
    
    widget.integration.registerAction(ForgeAction.editing(
      id: 'forge.edit.cut',
      label: 'Cut',
      shortcut: ForgeShortcutKey(
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

### 5.0 Action Naming Convention

All actions follow the naming pattern `<source>.<action>`:

| Prefix | Source | Examples |
|--------|--------|----------|
| `forge.` | Shell (global operations) | `forge.toggleLeftPanel`, `forge.commandPalette`, `forge.saveAll` |
| `forge.edit.` | Standard editing (all editors) | `forge.edit.cut`, `forge.edit.undo`, `forge.edit.moveLineUp` |
| `dart.` | Dart editor | `dart.triggerCompletion`, `dart.toggleComment` |
| `md.` | Markdown editor | `md.toggleBold`, `md.insertLink` |
| `yaml.` | YAML editor | `yaml.addKey`, `yaml.toggleTextMode` |

The **prefix acts as a routing category**: the shell uses the prefix to identify which module/editor handles an action. The Shortcut Editor and command palette group actions by prefix.

### 5.1 Required Actions

Every text-based editor (including ForgeTextField) must support these actions. They use the `forge.edit.` prefix:

| Action ID | Default Shortcut | Description |
|-----------|------------------|-------------|
| `forge.edit.cut` | ⌘X / Ctrl+X | Cut selection |
| `forge.edit.copy` | ⌘C / Ctrl+C | Copy selection |
| `forge.edit.paste` | ⌘V / Ctrl+V | Paste from clipboard |
| `forge.edit.selectAll` | ⌘A / Ctrl+A | Select all text |
| `forge.edit.undo` | ⌘Z / Ctrl+Z | Undo last change |
| `forge.edit.redo` | ⇧⌘Z / Shift+Ctrl+Z, also Ctrl+Y | Redo last undone change |
| `forge.edit.deleteLine` | ⇧⌘K / Shift+Ctrl+K | Delete current line |
| `forge.edit.duplicateLine` | ⌘D / Ctrl+D | Duplicate current line |
| `forge.edit.moveLineUp` | ⌥↑ / Alt+Up | Move line up |
| `forge.edit.moveLineDown` | ⌥↓ / Alt+Down | Move line down |
| `forge.edit.toggleComment` | ⌘/ / Ctrl+/ | Toggle line comment |

### 5.2 Optional Actions

Editors should provide these additional actions if meaningful for the editor type:

| Action ID | Suggested Shortcut | Description |
|-----------|-------------------|-------------|
| `<editor>.indentLine` | ⌘] / Ctrl+] | Indent line |
| `<editor>.outdentLine` | ⌘[ / Ctrl+[ | Outdent line |
| `<editor>.formatDocument` | ⌥⇧F / Alt+Shift+F | Format document |

### 5.3 Shell Actions

The shell (`TomForgeShellModule`) exposes its own actions through the same system as editors. Shell actions use the `forge.` prefix and are registered as `EditorActionDescriptor` instances:

| Action ID | Default Shortcut | Description |
|-----------|------------------|-------------|
| `forge.commandPalette` | ⌘P / Ctrl+P | Open command palette |
| `forge.toggleLeftPanel` | ⌘L / Ctrl+L | Toggle left panel |
| `forge.toggleRightPanel` | ⌘R / Ctrl+R | Toggle right panel |
| `forge.toggleBottomPanel` | ⌘B / Ctrl+B | Toggle bottom panel |
| `forge.find` | ⌘F / Ctrl+F | Find in focused component |
| `forge.saveAll` | ⌘S / Ctrl+S | Save all dirty editors |
| `forge.focusPanel1-4` | ⌘1-4 / Ctrl+1-4 | Focus middle panel slot |

There are **no hidden shortcuts**. Every shortcut — from the shell, modules, or editors — is registered through the action/descriptor system and appears in the Shortcut Editor.

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

// Register custom actions using ForgeAction.editing()
integration.registerAction(ForgeAction.editing(
  id: 'md.insertTable',
  label: 'Insert Table',
  shortcut: ForgeShortcutKey(key: LogicalKeyboardKey.keyT, alt: true),
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

// Register custom actions (same ForgeAction type used everywhere)
integration.registerAction(ForgeAction.editing(
  id: 'md.insertTable',
  label: 'Insert Table',
  shortcut: ForgeShortcutKey(key: LogicalKeyboardKey.keyT, alt: true),
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
3. Create `ForgeEditorIntegration` interface
4. Create standalone integrations:
   - `DartStandaloneIntegration`
   - `MdStandaloneIntegration`
   - `YamlStandaloneIntegration`
5. Create `ForgeTextField` widget
6. Create `StandardEditingActions` factory for Cut/Copy/Paste/Undo/Redo
7. Re-export `ForgeAction`, `ForgeShortcutKey` from tom_forge_ui

### 9.2 Phase 2: Update Editors

For each editor (MD, Dart, YAML):

1. Add `ForgeEditorIntegration` parameter (required)
2. Replace raw `TextField` usage with `ForgeTextField`
3. Move editor-specific settings to standalone integration defaults
4. Register editor-specific actions with integration (using `ForgeAction.editing()`)
5. Remove manual keyboard shortcut handling (use integration)
6. Implement `ForgeTextContext` for context discovery

### 9.3 Phase 3: Shell Integration (tom_forge_ui)

1. Create `ShellEditorIntegration` implementation
2. Update module adapters to create `ShellEditorIntegration`
3. Wire up shortcut rebinding via `ForgeShortcutManager`
4. Add context menu action discovery
5. Add editor configuration to Settings dialog

---

## 10. File Structure (Revised)

```
tom_forge_ui/lib/src/
  actions/
    forge_action.dart                        # EXISTING - unified action class
    forge_shortcut_binding.dart              # EXISTING - shortcut key

tom_editors_shared/lib/src/
  text_editing/                              # NEW folder
    forge_text_field.dart                    # ForgeTextField widget
    forge_text_context.dart                  # ForgeTextContext interface
    forge_text_settings.dart                 # ForgeTextSettings class
    forge_editor_integration.dart            # Base integration interface
    standard_editing_actions.dart            # Factory for Cut/Copy/Paste/Undo/Redo
    integrations/
      dart_standalone_integration.dart       # Dart editor standalone
      md_standalone_integration.dart         # Markdown editor standalone
      yaml_standalone_integration.dart       # YAML editor standalone

tom_forge_ui/lib/src/
  integrations/
    shell_editor_integration.dart            # Shell integration implementation
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

**ForgeAction**: The existing `ForgeAction` now includes a `ForgeAction.editing()` factory for simple synchronous editing operations, plus `defaultShortcut` and `showInContextMenu` fields. This unifies shell-level and editor-level actions into a single type.

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

  /// Get the list of registered actions.
  List<ForgeAction> get registeredActions;

  /// Register a new action (typically at editor startup).
  void registerAction(ForgeAction action);

  /// Execute an action by ID. Returns true if handled.
  bool executeAction(String actionId);

  /// Check if an action is enabled.
  bool isActionEnabled(String actionId);

  /// Get keyboard shortcut for an action (may be rebound in shell).
  ForgeShortcutKey? getShortcutFor(String actionId);

  /// Notify that text context has changed.
  void onContextChanged(ForgeTextContext context);

  /// Get additional context menu actions.
  List<ForgeAction> getContextMenuActions();

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

  final List<ForgeAction> _actions = [];
  final List<_UndoEntry> _undoStack = [];
  final List<_UndoEntry> _redoStack = [];

  @override
  List<ForgeAction> get registeredActions =>
      List.unmodifiable(_actions);

  @override
  void registerAction(ForgeAction action) {
    _actions.add(action);
  }

  @override
  bool executeAction(String actionId) {
    final action = _actions.firstWhere(
      (a) => a.id == actionId,
      orElse: () => throw StateError('Action not found: $actionId'),
    );
    if (action.isEnabled()) {
      action.execute({});
      return true;
    }
    return false;
  }

  @override
  bool isActionEnabled(String actionId) {
    final action = _actions.cast<ForgeAction?>().firstWhere(
      (a) => a?.id == actionId,
      orElse: () => null,
    );
    return action?.isEnabled() ?? false;
  }

  @override
  ForgeShortcutKey? getShortcutFor(String actionId) {
    final action = _actions.cast<ForgeAction?>().firstWhere(
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
  List<ForgeAction> getContextMenuActions() => const [];

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
  final List<ForgeAction> _editorActions = [];

  @override
  ForgeTextSettings get textSettings {
    // Get from shell configuration, with editor-specific overrides
    return _shellApi.config.getTextSettings(_editorId);
  }

  @override
  List<ForgeAction> get registeredActions =>
      List.unmodifiable(_editorActions);

  @override
  void registerAction(ForgeAction action) {
    _editorActions.add(action);
    // Also register with shell's action registry (same type, no bridging needed)
    _shellApi.actionRegistry.registerAction(action);
  }

  @override
  bool executeAction(String actionId) {
    // First check editor-specific actions
    final editorAction = _editorActions.cast<ForgeAction?>().firstWhere(
      (a) => a?.id == actionId,
      orElse: () => null,
    );
    if (editorAction != null && editorAction.isEnabled()) {
      editorAction.execute({});
      return true;
    }
    // Fall back to shell-level action
    return _shellApi.executeAction(actionId);
  }

  @override
  bool isActionEnabled(String actionId) {
    final action = _editorActions.cast<ForgeAction?>().firstWhere(
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
  List<ForgeAction> getContextMenuActions() {
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
tom_forge_ui/lib/src/
  actions/
    forge_action.dart                    # EXISTING - unified action class (with editing() factory)
    forge_shortcut_binding.dart          # EXISTING - shortcut key

tom_editors_shared/lib/src/
  text_editing/                          # NEW folder
    forge_text_field.dart                # ForgeTextField widget
    forge_text_context.dart              # ForgeTextContext interface
    forge_text_settings.dart             # ForgeTextSettings class
    forge_editor_integration.dart        # Base integration interface
    standard_editing_actions.dart        # Factory for Cut/Copy/Paste/Undo/Redo using ForgeAction
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
| Move/Delete/Duplicate Line | ✓ | ✓ |
| Keyboard shortcuts | ✓ (defaults) | ✓ (rebindable, scoped) |
| Context menus | ✓ (editor-only) | ✓ (shell-aware) |
| Font settings | ✓ (injected) | ✓ (from config) |
| Config panel | ✗ | ✓ |
| Action discovery | ✗ | ✓ (all actions visible) |
| Shortcut scoping | ✗ | ✓ (global vs editor-specific) |
| Selection sharing | ✗ | ✓ |

**Key benefits of the unified integration approach:**

1. **Same editor code** — No conditional logic for standalone vs shell
2. **Encapsulated differences** — Integration object handles all mode-specific behavior
3. **Compatible with existing interfaces** — Uses existing `ForgeShortcutKey`, adapts to `ForgeAction`
4. **Standalone keyboard shortcuts work** — Each standalone integration provides default shortcuts
5. **Shell shortcuts are rebindable** — ShellEditorIntegration queries the shortcut manager

---

## 16. Implementation Plan

This section provides a detailed, phased implementation plan for integrating the Forge Editor Base foundation across all editors.

### 16.1 Phase 1: Foundation in tom_editors_shared (Week 1)

Status: Completed (validated 2026-03-26)

Verification:

- Package: `tom_editors_shared`
- Analyzer: no issues
- Tests: 216 passing

#### 16.1.1 New Files to Create

| File | Purpose | Dependencies |
|------|---------|--------------|
| `lib/src/text_editing/forge_text_settings.dart` | Unified font/display settings | None |
| `lib/src/text_editing/forge_text_context.dart` | Text state interface for shell discovery | None |
| `lib/src/text_editing/forge_editor_integration.dart` | Base integration interface | ForgeTextSettings, ForgeTextContext |
| `lib/src/text_editing/forge_text_field.dart` | Wrapper widget for TextField | Integration, Settings |
| `lib/src/text_editing/standard_editing_actions.dart` | Factory for Cut/Copy/Paste/Undo/Redo | ForgeAction (re-exported) |
| `lib/src/text_editing/integrations/base_standalone_integration.dart` | Base standalone implementation | Integration interface |

#### 16.1.2 Re-exports from tom_forge_ui

Add to `tom_editors_shared.dart`:
```dart
// Re-export forge action types for standalone usage
export 'package:tom_forge_ui/src/actions/forge_action.dart'
    show ForgeAction, ForgeMenuLocation;
export 'package:tom_forge_ui/src/actions/forge_shortcut_binding.dart'
    show ForgeShortcutKey;
```

**Note:** This creates a dependency from tom_editors_shared → tom_forge_ui. If this is undesirable, the shared types (`ForgeShortcutKey`, `ForgeTextSettings`) should move to tom_editors_shared and tom_forge_ui should re-export them.

#### 16.1.3 ForgeTextSettings Implementation

Consolidate the overlapping settings from existing editors:

| Source | Class | Fields to Preserve |
|--------|-------|-------------------|
| tom_dart_editor | `FontSettings` | fontFamily, fontSize |
| tom_md_editor | `MdBasicTheme` | fontFamily, monoFontFamily, baseFontSize, lineHeight |
| tom_yaml_editor | `YamlEditorFontSettings` | keyFontFamily, valueFontFamily, keyFontSize, valueFontSize |

New unified class covers all use cases with sensible defaults.

#### 16.1.4 ForgeEditorIntegration Tasks

1. Define the abstract interface (see Section 13.1)
2. Create `BaseStandaloneIntegration` with local undo stack
3. Add `pushUndo(entry)` method for editors to record changes
4. Implement shortcut resolution using `ForgeShortcutKey.toActivator()`

#### 16.1.5 StandardEditingActions Factory

```dart
/// Creates standard editing actions for any text editor.
/// Action IDs use the forge.edit.* naming convention.
List<ForgeAction> createStandardEditingActions({
  required TextEditingController controller,
  required FocusNode focusNode,
  required bool Function() isReadOnly,
  required ForgeEditorIntegration integration,
}) {
  return [
    ForgeAction.editing(
      id: 'forge.edit.cut',
      label: 'Cut',
      shortcut: ForgeShortcutKey(key: LogicalKeyboardKey.keyX, primaryModifier: true),
      showInContextMenu: true,
      execute: () => _doCut(controller),
      isEnabled: () => !isReadOnly() && controller.selection.isValid,
    ),
    // ... copy, paste, selectAll, undo, redo, deleteLine,
    //     duplicateLine, moveLineUp, moveLineDown
  ];
}
```

#### 16.1.6 The undo stack

Standalone integrations keep a `TextUndoEntry` per change on `tom_forge_core`'s
`TomUndoStack`; undo applies the entry's old text and redo its new text:

```dart
final _history = TomUndoStack<TextUndoEntry>(maxEntries: 100);

_history.push(TextUndoEntry(oldText: before, newText: after));
_history.undo((e) => apply(e.oldText, e.oldSelection));
_history.redo((e) => apply(e.newText, e.newSelection));
```

---

### 16.2 Phase 2: tom_d4rt_editor / tom_dart_editor Adaptation (Week 2)

Status: Completed (validated 2026-03-26)

Verification:

- Package: `tom_dart_editor`
- Analyzer: no issues
- Tests: 3 passing

The Dart editor (`tom_dart_editor`) serves as the reference implementation since it has the most complex keyboard handling.

#### 16.2.1 Current State Analysis

| Aspect | Current Implementation | Target |
|--------|----------------------|--------|
| Text widget | `TextField` with `_HighlightingTextController` | Keep, wrap in `ForgeTextField` |
| Shortcut handling | `FocusNode.onKeyEvent` + `CompletionShortcutResolver` | Migrate to integration + `Shortcuts`/`Actions` |
| Undo/Redo | Local `_undoStack` / `_redoStack` | Use integration's `UndoHistory` |
| Theme | `DartEditorTheme.font: FontSettings` | Map to `ForgeTextSettings` |
| Context menu | Default `TextField` behavior | Extend with custom actions |

#### 16.2.2 Migration Steps

**Step 1: Add integration parameter**

```dart
class DartCodeEditor extends StatefulWidget {
  final DartCodeController controller;
  final DartEditorTheme? theme;
  final ForgeEditorIntegration? integration;  // NEW - optional for backward compat
  // ...
}
```

**Step 2: Create DartStandaloneIntegration**

```dart
class DartStandaloneIntegration extends BaseStandaloneIntegration {
  DartStandaloneIntegration({
    ForgeTextSettings? settings,
  }) : super(
    settings: settings ?? const ForgeTextSettings(
      fontFamily: 'JetBrains Mono',
      fontSize: 13.0,
      tabSize: 2,
      insertSpaces: true,
    ),
  );
}
```

**Step 3: Migrate CompletionShortcutResolver to ForgeActions**

| Current | New ForgeAction |
|---------|----------------|
| `CompletionShortcutAction.triggerCompletion` | `ForgeAction(id: 'dart.triggerCompletion', ...)` |
| `CompletionShortcutAction.openReference` | `ForgeAction(id: 'dart.openReference', ...)` |
| `CompletionShortcutAction.undo` | Standard `edit.undo` |
| `CompletionShortcutAction.redo` | Standard `edit.redo` |

**Step 4: Replace FocusNode.onKeyEvent**

Move from:
```dart
_focusNode = FocusNode(onKeyEvent: _handleKeyEvent);
```

To:
```dart
Shortcuts(
  shortcuts: buildEditorShortcutMap(integration), // rebuilt on integration.shortcutBindings
  child: Actions(
    actions: integration.buildActionMap(),
    child: TextField(...),
  ),
)
```

**Step 5: Wire up undo/redo**

Replace local stacks with integration:
```dart
// Before:
void _undo() {
  if (_undoStack.isEmpty) return;
  _redoStack.add(_textController.text);
  _textController.text = _undoStack.removeLast();
}

// After:
void _undo() {
  integration.undo();
}
```

**Step 6: Add ForgeTextContext implementation**

```dart
class DartTextContext implements ForgeTextContext {
  final DartCodeController controller;
  final TextEditingController textController;
  
  DartTextContext(this.controller, this.textController);
  
  @override
  String get text => controller.userCode;
  
  @override
  int get cursorOffset => textController.selection.baseOffset;
  
  @override
  int get currentLine {
    final offset = cursorOffset.clamp(0, text.length);
    return '\n'.allMatches(text.substring(0, offset)).length;
  }
  
  @override
  bool get isDirty => controller.userCode != _lastSavedCode;
  
  // ... etc
}
```

#### 16.2.3 Backward Compatibility

Keep the editor functional without an integration parameter:

```dart
ForgeEditorIntegration get _integration =>
    widget.integration ?? _defaultIntegration;

late final _defaultIntegration = DartStandaloneIntegration(
  settings: _settingsFromTheme(widget.theme),
);
```

---

### 16.3 Phase 3: tom_md_editor Adaptation (Week 2-3)

Status: Completed (validated 2026-03-26)

Verification:

- Package: `tom_md_editor`
- Analyzer: no issues
- Tests: 124 passing

#### 16.3.1 Current State Analysis

| Aspect | Current Implementation | Target |
|--------|----------------------|--------|
| Main widget | `MdEditor` with `MdRawTextEditor` | Add integration parameter |
| Shortcuts | `Shortcuts` + `Actions` in `MdEditor.build()` | Extract to integration |
| Undo/Redo | `MdEditorController` with `UndoHistory<MdEditOperation>` | Keep, bridge to integration |
| Context menu | Custom `contextMenuBuilder` in `MdRawTextEditor` | Extend with integration actions |
| Theme | `MdEditorTheme.basic: MdBasicTheme` | Map to `ForgeTextSettings` |

#### 16.3.2 Migration Steps

**Step 1: Add integration parameter to MdEditor**

```dart
class MdEditor extends StatefulWidget {
  final MdEditorController? controller;
  final ForgeEditorIntegration? integration;  // NEW
  // ...
}
```

**Step 2: Create MdStandaloneIntegration**

```dart
class MdStandaloneIntegration extends BaseStandaloneIntegration {
  final MdEditorController controller;
  
  MdStandaloneIntegration({
    required this.controller,
    ForgeTextSettings? settings,
  }) : super(settings: settings ?? const ForgeTextSettings(
    fontFamily: 'monospace',
    fontSize: 14.0,
    wordWrap: true,
    lineHeight: 1.6,
  ));
  
  @override
  void undo() => controller.undo();
  
  @override
  void redo() => controller.redo();
  
  @override
  bool get canUndo => controller.canUndo;
  
  @override
  bool get canRedo => controller.canRedo;
}
```

**Step 3: Extract shortcuts from MdEditor.build()**

Current inline shortcuts:
```dart
Shortcuts(
  shortcuts: <ShortcutActivator, Intent>{
    const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): const _UndoIntent(),
    // ...
  },
```

Move to:
```dart
// In integration
List<ForgeAction> get registeredActions => [
  ForgeAction.editing(id: 'forge.edit.undo', ...),
  ForgeAction.editing(id: 'forge.edit.redo', ...),
  ForgeAction.editing(id: 'forge.saveAll', ...),
  ForgeAction.editing(id: 'forge.find', ...),
];
```

**Step 4: Add markdown-specific actions**

```dart
// In MdStandaloneIntegration.initActions()
registerAction(ForgeAction.editing(
  id: 'md.insertTable',
  label: 'Insert Table',
  shortcut: ForgeShortcutKey(key: LogicalKeyboardKey.keyT, alt: true),
  showInContextMenu: true,
  execute: () => _insertTable(),
  isEnabled: () => !readOnly,
));

registerAction(ForgeAction.editing(
  id: 'md.toggleBold',
  label: 'Bold',
  shortcut: ForgeShortcutKey(key: LogicalKeyboardKey.keyB, primaryModifier: true),
  execute: () => _wrapSelection('**'),
  isEnabled: () => !readOnly,
));
```

**Step 5: Update MdRawTextEditor context menu**

```dart
// Current
contextMenuBuilder: (context, editableTextState) {
  // ... custom menu items
}

// Updated
contextMenuBuilder: (context, editableTextState) {
  final integrationActions = widget.integration?.getContextMenuActions() ?? [];
  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: editableTextState.contextMenuAnchors,
    buttonItems: [
      ...editableTextState.contextMenuButtonItems,
      if (integrationActions.isNotEmpty) const ContextMenuButtonItem.divider(),
      for (final action in integrationActions.where((a) => a.showInContextMenu))
        ContextMenuButtonItem(
          label: action.label,
          onPressed: action.isEnabled() ? () {
            action.execute({});
            editableTextState.hideToolbar();
          } : null,
        ),
    ],
  );
}
```

**Step 6: Implement ForgeTextContext**

```dart
class MdTextContext implements ForgeTextContext {
  final MdEditorController controller;
  
  MdTextContext(this.controller);
  
  @override
  String get text => controller.markdown;
  
  @override
  int get cursorOffset => controller.cursorOffset;
  
  @override
  bool get isDirty => controller.document.lastModified != null;
  
  @override
  bool get canUndo => controller.canUndo;
  
  @override
  bool get canRedo => controller.canRedo;
  
  // ...
}
```

---

### 16.4 Phase 4: tom_yaml_editor Adaptation (Week 3)

Status: Completed (validated 2026-03-26)

Verification:

- Package: `tom_yaml_editor`
- Analyzer: no issues
- Tests: 23 passing

#### 16.4.1 Current State Analysis

| Aspect | Current Implementation | Target |
|--------|----------------------|--------|
| Main widget | `YamlSchemaEditor` (tree-based, not TextField) | Add integration for actions only |
| Shortcuts | `KeyboardListener.onKeyEvent` in tree navigation | Preserve tree navigation, add action shortcuts |
| Undo/Redo | `YamlEditorController` with `UndoHistory<YamlEditOperation>` | Keep, bridge to integration |
| Context menu | Dialog-based `showMapContextMenu` / `showListContextMenu` | Extend with integration actions |
| Text editing | Inline embedded editors per node | Use ForgeTextField for embedded editors |

**Key difference:** YAML editor is tree-based, not a single text field. The integration applies to:
1. Editor-wide actions (undo/redo, save)
2. Embedded scalar editors (when editing string values inline)

#### 16.4.2 Migration Steps

**Step 1: Add integration parameter**

```dart
class YamlSchemaEditor extends StatefulWidget {
  final YamlEditorController controller;
  final ForgeEditorIntegration? integration;  // NEW
  // ...
}
```

**Step 2: Create YamlStandaloneIntegration**

```dart
class YamlStandaloneIntegration extends BaseStandaloneIntegration {
  final YamlEditorController controller;
  
  YamlStandaloneIntegration({
    required this.controller,
    ForgeTextSettings? settings,
  }) : super(settings: settings ?? const ForgeTextSettings(
    fontFamily: 'monospace',
    fontSize: 13.0,
    tabSize: 2,
  ));
  
  @override
  void undo() => controller.undo();
  
  @override
  void redo() => controller.redo();
  
  @override
  bool get canUndo => controller.canUndo;
  
  @override
  bool get canRedo => controller.canRedo;
}
```

**Step 3: Register YAML-specific actions**

```dart
// Editor-wide actions
registerAction(ForgeAction.editing(
  id: 'yaml.addKey',
  label: 'Add Key',
  shortcut: ForgeShortcutKey(key: LogicalKeyboardKey.keyN, primaryModifier: true),
  showInContextMenu: true,
  execute: () => _showAddKeyDialog(),
  isEnabled: () => !readOnly && selectedNode != null,
));

registerAction(ForgeAction.editing(
  id: 'yaml.removeKey',
  label: 'Remove Key',
  shortcut: ForgeShortcutKey(key: LogicalKeyboardKey.delete, primaryModifier: true),
  showInContextMenu: true,
  execute: () => _removeSelectedKey(),
  isEnabled: () => !readOnly && selectedNode?.canRemove ?? false,
));

registerAction(ForgeAction.editing(
  id: 'yaml.toggleTextMode',
  label: 'Toggle Text Mode',
  shortcut: ForgeShortcutKey(key: LogicalKeyboardKey.keyT, primaryModifier: true),
  execute: () => _toggleTextMode(),
  isEnabled: () => true,
));
```

**Step 4: Update context menus**

In `showMapContextMenu` and `showListContextMenu`:

```dart
// Add integration actions to menu
final integrationActions = integration?.getContextMenuActions() ?? [];
for (final action in integrationActions.where((a) => a.showInContextMenu && a.isEnabled())) {
  items.add(_menuItem(
    value: _IntegrationAction(action),
    icon: action.icon ?? Icons.play_arrow,
    label: action.label,
  ));
}
```

**Step 5: Use ForgeTextField in embedded editors**

Update the embedded string editors to use ForgeTextField:

```dart
// In StringEditor widget
ForgeTextField(
  controller: _textController,
  integration: widget.integration ?? _defaultIntegration,
  readOnly: widget.readOnly,
  customActions: [
    ForgeAction.editing(
      id: 'yaml.commitEdit',
      label: 'Commit',
      shortcut: ForgeShortcutKey(key: LogicalKeyboardKey.enter),
      execute: () => _commitValue(),
      isEnabled: () => true,
    ),
  ],
)
```

**Step 6: Preserve tree keyboard navigation**

The YAML editor's tree navigation (arrow keys, Enter, Space, Escape, Tab) should remain in `KeyboardListener`, not be converted to ForgeActions. These are navigation, not actions.

ForgeActions are for operations that:
- Can appear in command palette
- Can be rebound
- Can appear in context menus

---

### 16.5 Phase 5: Shell Integration (Week 4)

Status: Completed (2026-03-26)

Verification:

- Implemented in `tom_forge_ui/lib/src/integrations/shell_editor_integration.dart`
- Adapter wiring completed in `forge_md_editor.dart`, `forge_dart_editor.dart`, `forge_yaml_editor.dart`
- Settings dialog integration completed in `forge_configuration_dialog.dart`
- Tests: `tom_forge_ui/test/integration/shell_editor_integration_test.dart` (5/5 pass)
- Package validation: `flutter test` (44 pass), `dart analyze` (no issues)

#### 16.5.1 ShellEditorIntegration Implementation

Location: `tom_forge_ui/lib/src/integrations/shell_editor_integration.dart`

See Section 13.3 for full implementation. Key features:

1. Queries settings from `shellApi.getTextSettings(editorTypeId)`
2. Registers actions with `shellApi.actionRegistry`
3. Resolves shortcuts via `shellApi.shortcuts.getBinding()`
4. Reports context changes to `shellApi.systemState`
5. Gets context menu actions from `shellApi.getContextActionsFor()`

#### 16.5.2 Module Adapter Updates

Each editor's Forge module adapter creates the shell integration:

```dart
// In MdModuleAdapter
class MdForgeModule extends ForgeModule {
  @override
  ForgeComponent createEditor(Uri uri, ForgeShellApi shellApi) {
    final controller = MdEditorController(uri: uri);
    final integration = ShellEditorIntegration(
      shellApi: shellApi,
      editorId: 'md-editor-${uri.hashCode}',
    );
    
    return MdEditorComponent(
      controller: controller,
      integration: integration,
    );
  }
}
```

#### 16.5.3 Settings Dialog Integration

Add editor configuration panels to `ForgeConfigurationDialog`:

```dart
// Each editor implements EditorConfigurationProvider
class MdEditor implements EditorConfigurationProvider {
  @override
  String get editorTypeId => 'md';
  
  @override
  String get configurationTitle => 'Markdown';
  
  @override
  IconData get configurationIcon => Icons.description;
  
  @override
  Widget buildConfigurationPanel(
    BuildContext context,
    ForgeTextSettings currentSettings,
    ValueChanged<ForgeTextSettings> onSettingsChanged,
  ) {
    return MdConfigurationPanel(
      settings: currentSettings,
      onChanged: onSettingsChanged,
    );
  }
}
```

---

### 16.6 Testing Strategy

#### 16.6.1 Unit Tests (tom_editors_shared)

| Test File | Coverage |
|-----------|----------|
| `forge_text_settings_test.dart` | copyWith, toTextStyle, defaults |
| `forge_editor_integration_test.dart` | Action registration, shortcut resolution |
| `standard_editing_actions_test.dart` | Cut/copy/paste logic |
| `forge_text_field_test.dart` | Widget integration |

#### 16.6.2 Integration Tests (per editor)

| Editor | Test Focus |
|--------|------------|
| tom_dart_editor | Undo/redo, completion shortcut, context menu |
| tom_md_editor | Toolbar actions, section editing, undo/redo |
| tom_yaml_editor | Tree actions, embedded editor actions |

#### 16.6.3 Shell Integration Tests (tom_forge_ui)

| Test | Scenario |
|------|----------|
| Shortcut rebinding | User rebinds Cmd+S, editor respects new binding |
| Context menu discovery | Shell provides module actions in editor context menu |
| Settings persistence | Font changes in dialog apply to all editors |

Validation snapshot (2026-03-26):

- `tom_forge_ui`: analyzer clean, 44 tests passing
- `shell_editor_integration_test.dart`: 5/5 passing
- Cross-package validation completed for phases 1-5

---

### 16.7 Migration Checklist

#### 16.7.1 Per-Editor Checklist

- [x] Add `ForgeEditorIntegration? integration` parameter
- [x] Create `{Editor}StandaloneIntegration` class
- [x] Register standard editing actions (cut/copy/paste/undo/redo)
- [x] Register editor-specific actions
- [x] Implement `ForgeTextContext`
- [x] Update keyboard shortcut handling
- [x] Update context menu to include integration actions
- [x] Map existing theme/font settings to `ForgeTextSettings`
- [x] Add backward compatibility defaults
- [x] Update tests
- [x] Update documentation

#### 16.7.2 Shell Integration Checklist

- [x] Create `ShellEditorIntegration` implementation
- [x] Update module adapters to create shell integration
- [x] Wire up shortcut rebinding
- [x] Add context menu action discovery
- [x] Add editor configuration to Settings dialog
- [x] Test shell/standalone mode switching

---

### 16.8 Timeline Summary

| Week | Phase | Deliverables | Status |
|------|-------|--------------|--------|
| 1 | Foundation | ForgeTextSettings, ForgeTextContext, ForgeEditorIntegration, ForgeTextField, StandardEditingActions | Completed |
| 2 | Dart Editor | DartStandaloneIntegration, migrate shortcuts, undo/redo bridge | Completed |
| 2-3 | MD Editor | MdStandaloneIntegration, context menu integration | Completed |
| 3 | YAML Editor | YamlStandaloneIntegration, embedded editor updates | Completed |
| 4 | Shell Integration | ShellEditorIntegration, module adapters, settings dialog | Completed |

---

### 16.9 Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Breaking existing editor usage | Keep integration parameter optional with sensible defaults |
| Performance regression from layered shortcuts | Profile before/after; optimize if needed |
| Circular dependency (editors_shared ↔ forge_ui) | Move shared types to editors_shared if needed |
| Inconsistent undo granularity between editors | Document expected granularity; provide integration hooks |
| Complex context menu merging | Define clear precedence: editor actions → integration actions → shell actions |
