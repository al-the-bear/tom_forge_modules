# Forge Editor Base - Unified Text Editing Foundation

## 1. Overview

This document specifies a **unified text editing foundation** for the Tom Forge ecosystem. The goal is to provide a shared set of widgets and interfaces that:

1. Enable tight integration with the Tom Forge Shell (context menus, keyboard shortcuts, configuration)
2. Allow editors to remain fully functional as standalone components
3. Unify font settings, undo/redo, and standard editing operations
4. Support editor context discovery (selections, cursor position, state) for shell features

### 1.1 Design Principles

| Principle | Description |
|-----------|-------------|
| **Standalone First** | Editors must work without the shell; shell integration is optional |
| **Composition Over Inheritance** | Use mixins and wrapper widgets, not deep inheritance hierarchies |
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

Represents a single editing action that can be bound to shortcuts.

```dart
/// An editing action that can be bound to keyboard shortcuts.
class ForgeEditingAction {
  /// Unique identifier (e.g., 'edit.cut', 'edit.deleteLine').
  final String id;

  /// Display label for menus.
  final String label;

  /// Default keyboard shortcut (can be rebound by shell).
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
}
```

#### 3.3.3 ForgeTextSettings

Unified configuration for text display.

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
/// A text field with Forge shell integration capabilities.
///
/// Can be used standalone or integrated with the Forge shell.
/// When standalone, it provides standard TextField behavior.
/// When integrated, it exposes context and actions to the shell.
class ForgeTextField extends StatefulWidget {
  /// The text editing controller.
  final TextEditingController controller;

  /// Focus node for keyboard input.
  final FocusNode? focusNode;

  /// Text display settings.
  final ForgeTextSettings settings;

  /// Whether the field is read-only.
  final bool readOnly;

  /// Maximum number of lines (null = unlimited).
  final int? maxLines;

  /// Callback when text changes.
  final ValueChanged<String>? onChanged;

  /// Optional shell integration provider.
  /// When null, the field operates standalone.
  final ForgeTextFieldIntegration? integration;

  /// Custom context menu builder.
  /// If provided, fully replaces default behavior.
  final EditableTextContextMenuBuilder? contextMenuBuilder;

  /// Additional actions beyond the defaults.
  /// These are merged with standard cut/copy/paste/undo/redo.
  final List<ForgeEditingAction> customActions;

  const ForgeTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.settings = const ForgeTextSettings(),
    this.readOnly = false,
    this.maxLines,
    this.onChanged,
    this.integration,
    this.contextMenuBuilder,
    this.customActions = const [],
  });

  @override
  State<ForgeTextField> createState() => _ForgeTextFieldState();
}
```

### 4.2 ForgeTextFieldIntegration

Optional integration layer for shell connectivity.

```dart
/// Integration layer between ForgeTextField and the shell.
///
/// Editors create this to enable shell features without
/// hard dependencies on shell classes.
abstract interface class ForgeTextFieldIntegration {
  /// Called when the text context changes.
  void onContextChanged(ForgeTextContext context);

  /// Called to get additional context menu items from the shell.
  List<ForgeEditingAction> getContextMenuActions();

  /// Called to get the current text settings from configuration.
  ForgeTextSettings? getCurrentSettings();

  /// Called when the editor registers its available actions.
  void registerActions(List<ForgeEditingAction> actions);
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

Editors may provide additional actions:

| Action ID | Suggested Shortcut | Description |
|-----------|-------------------|-------------|
| `edit.duplicateLine` | ⌘⇧D / Ctrl+Shift+D | Duplicate current line |
| `edit.moveLineUp` | ⌥↑ / Alt+Up | Move line up |
| `edit.moveLineDown` | ⌥↓ / Alt+Down | Move line down |
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

When integrated with the shell:

1. Editor calls `integration.getContextMenuActions()` to get shell-provided items
2. Shell queries registered modules for relevant context actions
3. Actions are filtered by the current `ForgeTextContext`
4. Combined menu is displayed

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
ForgeTextField(
  controller: _textController,
  settings: ForgeTextSettings(
    fontFamily: theme.fontFamily,
    fontSize: theme.baseFontSize,
  ),
  customActions: [
    ForgeEditingAction(
      id: 'md.insertTable',
      label: 'Insert Table',
      showInContextMenu: true,
      execute: () => _insertTable(),
      isEnabled: () => !readOnly,
    ),
  ],
)
```

### 8.2 Integrated Usage (With Shell)

```dart
// In shell adapter module
ForgeTextField(
  controller: _textController,
  settings: _shellApi.config.textSettings,
  integration: _ShellTextFieldIntegration(
    shellApi: _shellApi,
    editor: this,
  ),
  customActions: [
    ForgeEditingAction(
      id: 'md.insertTable',
      label: 'Insert Table',
      defaultShortcut: ForgeShortcutKey(key: LogicalKeyboardKey.keyT, alt: true),
      showInContextMenu: true,
      execute: () => _insertTable(),
      isEnabled: () => !readOnly,
    ),
  ],
)
```

---

## 9. Migration Path

### 9.1 Phase 1: Create Foundation (tom_editors_shared)

1. Create `ForgeTextSettings` class
2. Create `ForgeTextContext` interface
3. Create `ForgeEditingAction` class
4. Create `ForgeTextField` widget
5. Create `ForgeTextFieldIntegration` interface
6. Create `EditorConfigurationProvider` interface
7. Update existing `TextEditorCore` to use `ForgeTextField` internally

### 9.2 Phase 2: Update Editors

For each editor (MD, Dart, YAML):

1. Create adapter settings class that converts to `ForgeTextSettings`
2. Replace raw `TextField` usage with `ForgeTextField`
3. Implement `ForgeTextContext` for context discovery
4. Register standard actions via `ForgeEditingAction`
5. Move editor-specific shortcuts to `customActions`
6. Implement `EditorConfigurationProvider`

### 9.3 Phase 3: Shell Integration (tom_forge_ui)

1. Create shell-side `ForgeTextFieldIntegration` implementation
2. Update module adapters to use new integration
3. Add editor configuration to Settings dialog
4. Wire up action discovery for command palette
5. Connect keyboard shortcut rebinding

---

## 10. File Structure

```
tom_editors_shared/lib/src/
  text_editing/                          # NEW folder
    forge_text_field.dart                # ForgeTextField widget
    forge_text_context.dart              # ForgeTextContext interface
    forge_text_settings.dart             # ForgeTextSettings class
    forge_editing_action.dart            # ForgeEditingAction class
    forge_text_field_integration.dart    # Integration interface
    editor_configuration_provider.dart   # Config panel interface
    standard_editing_actions.dart        # Default Cut/Copy/Paste/Undo/Redo
```

---

## 11. Appendix: Shortcut Key Reference

### 11.1 ForgeShortcutKey Structure

```dart
/// Represents a keyboard shortcut key combination.
class ForgeShortcutKey {
  final LogicalKeyboardKey key;
  final bool ctrl;
  final bool meta;    // Cmd on macOS
  final bool alt;
  final bool shift;

  const ForgeShortcutKey({
    required this.key,
    this.ctrl = false,
    this.meta = false,
    this.alt = false,
    this.shift = false,
  });

  /// Gets the platform-appropriate primary modifier.
  bool get primaryModifier => Platform.isMacOS ? meta : ctrl;

  /// Converts to Flutter's SingleActivator.
  SingleActivator toActivator() => SingleActivator(
    key,
    control: ctrl,
    meta: meta,
    alt: alt,
    shift: shift,
  );
}
```

### 11.2 Platform Adaptation

The standard actions use `primaryModifier` which resolves to:
- **macOS**: ⌘ (Command)
- **Windows/Linux**: Ctrl

This ensures consistent behavior across platforms while respecting platform conventions.

---

## 12. Summary

The Forge Editor Base provides:

| Feature | Standalone | With Shell |
|---------|------------|------------|
| Text editing | ✓ | ✓ |
| Syntax highlighting | ✓ | ✓ |
| Undo/Redo | ✓ (internal) | ✓ (unified) |
| Cut/Copy/Paste | ✓ | ✓ |
| Custom shortcuts | ✓ (local) | ✓ (rebindable) |
| Context menus | ✓ (custom) | ✓ (shell-aware) |
| Font settings | ✓ (injected) | ✓ (from config) |
| Config panel | ✗ | ✓ |
| Action discovery | ✗ | ✓ |
| Selection sharing | ✗ | ✓ |

This architecture ensures editors remain usable outside the shell while enabling rich integration when available.
