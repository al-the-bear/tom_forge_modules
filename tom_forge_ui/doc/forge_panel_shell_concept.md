# Tom Forge Panel Shell — Concept Document

**Project:** tom_forge_ui  
**Component:** Panel Shell Framework  
**Date:** 2026-03-24  
**Status:** Concept (v2)

---

## 1. Overview

The Tom Forge Panel Shell is a desktop-optimized, multi-panel application framework for composing visual development tools. It provides a VS Code-inspired window layout with applications, editors, views, and configurable panel arrangements — all within a single Flutter window.

The framework lives in `tom_forge_ui` (library) with a test/demo application in `tom_forge_app`.

### Terminology

| Term | Definition |
|------|-----------|
| **Workspace** | The root folder opened by the user (equivalent to a VS Code workspace folder). Contains source files, configuration, and a `.forge/` folder for state and file revisions. |
| **Application** | A named arrangement of panels, components, and shortcuts. Multiple applications can be open simultaneously. Switching between applications does not close the previous one. Analogous to a VS Code "workspace configuration" but kept alive in memory. |
| **Component** | An editor or view that plugs into the shell. |
| **Extension** | A group of related components, actions, and shortcuts that registers with the shell. |
| **Shell** | The top-level framework that manages panels, focus, menus, shortcuts, and state. |

### Design Principles

- **Single window, multi-application** — applications switch via a dropdown; all remain alive in memory simultaneously
- **Component-based** — editors and views are self-contained widgets that plug into the shell
- **Multi-render components** — a component can appear in multiple locations; each UI copy has its own UI state (scroll position, selection), but all copies share the same data state
- **Drag-and-drop layout** — users rearrange components freely between panels
- **Extension-driven** — functionality is packaged as extensions (groups of components + actions + shortcuts) with deep shell access
- **VS Code-inspired API, more powerful** — no plugin sandboxing; extensions can deeply modify shell behavior
- **Auto-save by default** — files save on focus loss or after 1-second idle
- **File revisioning** — the `.forge/` folder in the workspace tracks file revisions and shell state
- **Code-configured** — initial layout is declarative in Dart; comprehensive runtime configurability; changes persist

---

## 2. Window Structure

```
┌─────────────────────────────────────────────────────────────────────┐
│  ◀ ▶   │        🔍 Application Title              │ [Application ▾]│  Title Bar
├────┬────────────────────────────────────────────────────────┬───────┤
│    │  ┌─ Menu Bar ──────────────────────────────────────┐   │       │
│    │  │ File  Edit  View  Extensions…  Help             │   │       │
│    │  └─────────────────────────────────────────────────┘   │       │
│ L  │   ┌─ Tab1 ─┬─ Tab2 ─┐  ┌─ Tab3 ─┬─ Tab4 ─┐          │  R    │
│ E  │   │        │         │  │        │         │          │  I    │
│ F  │   │  Middle Panel 1  │  │  Middle Panel 2  │          │  G    │
│ T  │   │   (Editors)      │  │   (Editors)      │          │  H    │
│    │   │                  │  │                  │          │  T    │
│ P  │   └──────────────────┘  └──────────────────┘          │       │
│ A  │   (up to 4 middle panels in a row)                    │  P    │
│ N  ├────────────────────────────────────────────────────────┤  A    │
│ E  │                                                        │  N    │
│ L  │   ┌─ Tab ─┬─ Tab ─┐                                   │  E    │
│    │   │  Bottom Panel (accordeon sections)                 │  L    │
│ ┄┄ │   └────────────────────────────────────────────────────┘       │
│ ⚙  │                                                               │
├────┴────────────────────────────────────────────────────────┴───────┤
│  Status Line: context-sensitive information                         │  Status Bar
└─────────────────────────────────────────────────────────────────────┘
```

**Note:** The left panel always has a built-in **Configuration** tab (⚙) pinned at the bottom of the icon strip. It is not draggable or removable.

### 2.1 Title Bar

| Element | Position | Behavior |
|---------|----------|----------|
| **Back / Forward arrows** | Left | Navigate history for components that support it (e.g., browser views, help panels). Disabled when the focused component has no history. |
| **Search field** | Center | Displays the application title centered with a search-lens icon prefix. Tapping activates search mode (command palette style, see §11). The field serves dual purpose: application title display and quick search/command entry. |
| **Application dropdown** | Right of search | Dropdown selector to switch between configured applications. Shows the current application name. All applications remain alive in memory when switching (see §6). |

### 2.2 Left Panel (Multipanel)

- **Position:** Left edge, full height between title bar and status bar
- **Width:** User-adjustable via drag handle on the right edge
- **Tabs:** Vertical icon strip on the left edge; clicking an icon activates that tab
- **Tab content:** Accordeon structure with collapsible sections (see §3)
- **Tab management:** "+" button near the bottom of the icon strip to add tabs (user picks icon + title)
- **Configuration tab (⚙):** Always the bottom-most icon in the strip. Not draggable, not removable. Contains built-in configuration views (see §9). Separated from user tabs by a subtle divider line.

### 2.3 Right Panel (Multipanel)

- Mirror of the left panel, with icon strip on the right edge
- Width adjustable via drag handle on the left edge
- Same tab + accordeon structure as the left panel

### 2.4 Middle Panels (1–4 Editor Panels)

- **Position:** Center area between left and right panels, above the bottom panel
- **Count:** 1 to 4 panels arranged horizontally, separated by drag handles
- **Tabs:** Horizontal tab bar on top of each panel, showing component title + close button (for editors)
- **Content:** One active component per panel, selected by tab
- **Opening new panels:** Dragging a component to the edge of an existing middle panel splits and creates a new panel. An overlay guides the user during drag.
- **Closing panels:** When the last tab in a middle panel is closed, the panel collapses

### 2.5 Bottom Panel (Multipanel)

- **Position:** Below the middle panels, spanning the full width between left and right panels
- **Height:** User-adjustable via drag handle on the top edge
- **Tabs:** Horizontal tab bar with icon + text titles
- **Tab content:** Accordeon structure with collapsible sections (see §3)
- **Tab management:** "+" button at the right of the tab bar

### 2.6 Status Bar

- **Position:** Bottom of the window, full width
- **Content:** Segmented status line with items contributed by:
  - The application (global status: workspace name, connection state, etc.)
  - The focused component (file path, cursor position, language mode, etc.)
- **Interaction:** Status items can be clickable (e.g., click language mode to change it)

---

## 3. Accordeon Layout (Left / Right / Bottom Panels)

Each tab in the left, right, and bottom panels contains an **accordeon** — a vertical stack of collapsible sections.

### 3.1 Section Header

**Left/Right panels:**
- Open section: title displayed horizontally, triangle icon pointing **down**
- Collapsed section: title displayed horizontally, triangle icon pointing **right**
- Pin icon: allows keeping multiple sections open simultaneously

**Bottom panel:**
- Open section: title displayed **horizontally** in a header area
- Collapsed section: title displayed **vertically** (text flows top to bottom) as a narrow strip
- Pin icon: same pinning behavior

### 3.2 Layout Rules

| Rule | Description |
|------|-------------|
| **Mutual exclusivity** | By default, opening one section collapses others in the same tab |
| **Pinning** | Clicking the pin icon on a section keeps it open when another section opens |
| **Space distribution** | When multiple sections are pinned open, they share space equally, respecting preferred height/width constraints |
| **Separator drag** | Drag handles between pinned-open sections allow manual size adjustment |
| **Single section** | If a tab has only one section, it is always open and cannot be collapsed; no collapse controls are shown |
| **Empty sections** | A section with no component shows an empty placeholder (allows drop targets) |

### 3.3 Component Size Hints

Components in accordeon sections provide size hints:

```dart
abstract class ForgeComponentSizeHints {
  /// Minimum size the component needs to be functional.
  double get minSize;

  /// Preferred size for comfortable display.
  double get preferredSize;

  /// Maximum useful size (beyond this, extra space is wasted).
  double get maxSize;
}
```

- `minSize` — the accordeon will not shrink a section below this
- `preferredSize` — used for initial/equilibrium sizing when multiple sections share space
- `maxSize` — extra space beyond this is allocated to other sections
- "Size" means height in left/right panels, width in the bottom panel

---

## 4. Components: Editors and Views

### 4.1 Component Types

| Type | Closable | Multi-Render | Data State Sharing | UI State | Primary Location |
|------|----------|--------------|--------------------|----------|------------------|
| **Editor** | Yes (× button) | Yes (SHIFT+drag creates UI copy) | By URI — all copies share one data model | Each copy has own scroll position, cursor, selection | Middle panels |
| **View** | No | Yes (SHIFT+drag creates UI copy) | By type — all copies share one data model | Each copy has own scroll position, expansion state | Left / right / bottom panels |

### 4.2 Component Identity and Multi-Render

- **Editors** are identified by a **URI** (`Uri`). The URI can represent a file path, a virtual resource, or any addressable entity. All editor instances with the same URI share the same **data state** (document content, dirty flag, undo history).
- **Views** are identified by their **type** (Dart `Type`). All instances of the same view type share the same **data state**.

**Multi-render model:**

A single logical component can be rendered in multiple locations simultaneously. Each rendered instance is called a **UI copy**. There is always one **main component** (the first instance created) and zero or more UI copies.

- **Data state** (document content, problem list, search results) is shared across all copies and the main component. Changes in one copy are immediately visible in all others.
- **UI state** (scroll position, cursor position, selection highlight, collapsed/expanded sections) is **independent per copy**. Each copy maintains its own UI state.
- **Creating a UI copy:** Hold **SHIFT** while dragging a component tab or section header. The original stays in place; a new UI copy appears at the drop location.
- **Regular drag** (without SHIFT) **moves** the component — the original location is vacated.
- **Closing a UI copy** disposes only that copy's UI state. The main component and other copies remain unaffected. If the main component is closed and UI copies exist, the oldest UI copy becomes the new main component.
- **Focus:** Each UI copy is independently focusable. The shell tracks which copy has focus for keyboard shortcuts and menu actions.

### 4.3 Component Contract

Every component implements:

```dart
abstract class ForgeComponent extends Widget {
  /// Unique type identifier for this component kind.
  String get componentTypeId;

  /// Display title for tabs and headers.
  String get title;

  /// Optional subtitle shown in small font under accordeon titles.
  String? get titleExtension;

  /// Icon for tab display.
  IconData get icon;

  /// Whether this is an editor (closable) or a view (not closable).
  bool get isEditor;

  /// For editors: the URI this editor is associated with.
  Uri? get uri;

  /// Size hints for accordeon layout.
  ForgeComponentSizeHints get sizeHints;

  /// Whether this component supports back/forward navigation.
  bool get supportsHistory;

  /// Whether this component supports multi-render (UI copies).
  /// Default: true. Set to false for components that cannot be rendered
  /// in parallel (e.g., terminal emulator with exclusive pty).
  bool get supportsMultiRender => true;

  /// Actions this component contributes to the menu and command palette.
  List<ForgeAction> get actions => [];

  /// Shortcut bindings this component contributes when focused.
  List<ForgeShortcutBinding> get shortcuts => [];
}
```

### 4.4 Component Registration

Components are registered with the shell so it knows what's available. Registration happens through extensions (see §8) or directly:

```dart
class ForgeComponentRegistry {
  /// Register a view factory. View type ID → factory function.
  void registerView(String typeId, ForgeViewFactory factory);

  /// Register an editor factory. Editor type ID → factory function.
  void registerEditor(String typeId, ForgeEditorFactory factory);

  /// Get all registered view types.
  List<ForgeComponentDescriptor> get viewTypes;

  /// Get all registered editor types.
  List<ForgeComponentDescriptor> get editorTypes;
}
```

---

## 5. Drag and Drop

### 5.1 Within Side/Bottom Panels

- **Move component between sections:** Drag a section header within the same tab's accordeon to reorder
- **Move component between tabs:** Drag a section header to another tab's area in the same panel
- **Move component between panels:** Drag from left → right, left → bottom, etc.
- **Empty accordeon:** When all components leave a tab, the tab persists (empty placeholder) so components can be dragged back

### 5.2 Into Middle Panels

- When dragging a component over the middle area, an **overlay** appears showing drop zones:
  - Drop on an existing middle panel's tab bar → adds as a new tab
  - Drop on the left/right/top/bottom edge of a middle panel → splits and creates a new middle panel (up to 4)
- Works for both views and editors

### 5.3 Tab-Level Drag

- Entire tabs (with all their accordeon sections) can be dragged between left, right, and bottom panels
- Tabs **cannot** be dragged to the middle panels (middle panels use individual component tabs, not accordeon tabs)

---

## 6. Application Model

### 6.1 Terminology Recap

- **Workspace** = the root folder on disk. Contains source files, `.forge/` folder, etc.
- **Application** = a named panel layout + component arrangement. Multiple applications exist within one shell instance. They remain alive simultaneously.

### 6.2 Structure

```dart
class TomForgeShell {
  /// The workspace root directory (selected at startup).
  final Directory workspace;

  /// The configuration directory. Either ~/.forge (global) or
  /// <workspace>/.forge (local). Selected at startup.
  final Directory configDirectory;

  /// All applications available in this shell.
  final List<ForgeApplication> applications;

  /// Global component registry (populated by extensions).
  final ForgeComponentRegistry registry;

  /// Application-level status bar items.
  final List<StatusBarItem> globalStatusItems;

  /// Registered extensions.
  final List<ForgeExtension> extensions;

  /// The .forge folder manager (uses configDirectory).
  final ForgeFolderManager forgeFolder;

  /// System state controller.
  final ForgeSystemState systemState;
}

class ForgeApplication {
  /// Display title (shown in search bar and application dropdown).
  final String title;

  /// Icon for the application dropdown.
  final IconData? icon;

  /// Components available in this application.
  final List<ForgeComponentDescriptor> components;

  /// Initial layout configuration.
  final ApplicationLayout layout;

  /// Whether this application is currently active (visible).
  bool get isActive;

  /// Whether this application's layout state is preserved in memory.
  /// Always true — applications are never disposed when switching.
  bool get isAlive => true;
}

class ApplicationLayout {
  final PanelConfig leftPanel;
  final PanelConfig rightPanel;
  final PanelConfig bottomPanel;
  final List<MiddlePanelConfig> middlePanels;
}

class PanelConfig {
  /// Initial width (left/right) or height (bottom) in logical pixels.
  final double initialSize;

  /// Tabs in this panel.
  final List<PanelTabConfig> tabs;
}

class PanelTabConfig {
  final String title;
  final IconData icon;

  /// Accordeon sections in this tab.
  final List<AccordeonSectionConfig> sections;
}

class AccordeonSectionConfig {
  /// The component to display in this section.
  final String componentTypeId;

  /// For editors: the URI to open.
  final Uri? uri;

  /// Whether this section starts pinned open.
  final bool initiallyPinned;
}

class MiddlePanelConfig {
  /// Initial flex factor for horizontal space distribution.
  final double flex;

  /// Components (tabs) in this middle panel.
  final List<MiddleTabConfig> tabs;
}

class MiddleTabConfig {
  final String componentTypeId;
  final Uri? uri;
}
```

### 6.3 Application Switching

- Switching applications does **not** close the previous application. All applications remain alive in memory with their full layout state preserved.
- The dropdown shows all applications; the active one is highlighted.
- Applications can optionally share components. A component instance opened in Application A can also appear in Application B if both reference the same URI/type. The data state is shared; each application holds its own UI copy.
- No save-on-switch is required by default. Since applications stay alive, unsaved editors remain unsaved across switches. This behavior is configurable: an application can opt into save-on-deactivate if desired.
- Switching is instantaneous — the shell swaps the visible panel tree but does not rebuild widgets from scratch.

---

## 7. Menu System

### 7.1 Menu Structure

The menu bar sits below the title bar and above the middle panels. It has a **fixed top-level structure** with menu items automatically populated from components, views, extensions, and the shell itself.

**Fixed top-level menus:**

| Menu | Source | Contents |
|------|--------|----------|
| **File** | Shell + editors | New, Open, Save, Save All, Close, Recent, Quit |
| **Edit** | Focused component | Undo, Redo, Cut, Copy, Paste, Find, Replace |
| **View** | Shell | Toggle panels, zoom, appearance, layout |
| **Go** | Shell + focused component | Go-to-file, go-to-line, go-to-symbol, back/forward |
| **Extensions** | Extensions | Each extension can contribute a submenu here |
| **Help** | Shell | About, keyboard shortcuts reference, documentation |

### 7.2 Action-Based Menu Population

Menu items are **actions** (`ForgeAction`). Components, views, and extensions register actions with the shell. Each action declares which menu it belongs to:

```dart
class ForgeAction {
  /// Unique action identifier (e.g., 'editor.save', 'flow.runNode').
  final String id;

  /// Display label in menus.
  final String label;

  /// Optional icon.
  final IconData? icon;

  /// Which top-level menu this action belongs to.
  final ForgeMenuLocation menu;

  /// Group within the menu (items in the same group are separated by dividers).
  final String? group;

  /// Sort order within group.
  final int priority;

  /// Callback when the action is triggered.
  final VoidCallback execute;

  /// Whether the action is currently enabled. Evaluated dynamically.
  final bool Function() isEnabled;

  /// Whether the action is currently visible. Evaluated dynamically.
  final bool Function() isVisible;

  /// Shortcut binding (optional — displayed next to the menu item).
  final ForgeShortcutBinding? shortcut;
}

enum ForgeMenuLocation { file, edit, view, go, extensions, help }
```

### 7.3 Menu Configurability

The menu structure is one of the configuration views in the built-in Configuration tab (see §9). Users can:

- **Reorder** menu items within a menu
- **Hide** specific menu items
- **Add custom entries** that execute shell commands or component actions
- **Fixed entries** (File → Quit, Help → About, etc.) cannot be removed but can be reordered

Menu configuration is persisted per workspace in the `.forge/` folder.

### 7.4 Context Menus

Context menus are dynamically composed from the **system state** (see §10). Components register context menu contributions that are shown/hidden based on what is focused, selected, or hovered:

```dart
class ForgeContextMenuContribution {
  final String actionId;

  /// When to show this item. Evaluated against current system state.
  final bool Function(ForgeSystemState state) isApplicable;
}
```

---

## 8. Extension System

### 8.1 Concept

An **extension** is a cohesive group of related functionality that registers with the shell. Extensions are the primary way to add editors, views, actions, and shortcuts to Tom Forge. Unlike VS Code extensions, Tom Forge extensions run in the same Dart isolate as the shell — there is no sandboxing. Extensions have full access to the shell API and can deeply modify behavior.

### 8.2 Extension Contract

```dart
abstract class ForgeExtension {
  /// Unique extension identifier.
  String get id;

  /// Display name for the extension.
  String get displayName;

  /// Called when the extension is activated. The shell reference provides
  /// full access to the shell API — registration, state, services, etc.
  void activate(ForgeShellApi shell);

  /// Called when the extension is deactivated (shutdown).
  void deactivate();

  /// Components this extension provides.
  List<ForgeComponentDescriptor> get components;

  /// Actions this extension contributes.
  List<ForgeAction> get actions;

  /// Shortcut bindings this extension contributes.
  List<ForgeShortcutBinding> get shortcuts;
}
```

### 8.3 Example: Form Editor Extension

```dart
class TomFormEditorExtension extends ForgeExtension {
  late final ForgeShellApi _shell;

  @override
  String get id => 'tom.form_editor';

  @override
  String get displayName => 'Tom Form Editor';

  @override
  void activate(ForgeShellApi shell) {
    _shell = shell;

    // Register an editor for .form.yaml files
    shell.registry.registerEditor(
      'tom.form_editor',
      (uri) => TomFormEditor(shell: shell, uri: uri),
    );

    // Register a properties view that shows form field properties
    shell.registry.registerView(
      'tom.form_properties',
      () => TomFormPropertiesView(shell: shell),
    );

    // Register a file association — .form.yaml → form editor
    shell.fileAssociations.register(
      pattern: '*.form.yaml',
      editorTypeId: 'tom.form_editor',
    );

    // Listen to selection changes in the form editor
    shell.systemState.onSelectionChanged.listen((selection) {
      if (selection.componentTypeId == 'tom.form_editor') {
        // Update the properties view with the selected field
      }
    });
  }

  @override
  void deactivate() {}

  @override
  List<ForgeComponentDescriptor> get components => [
    ForgeComponentDescriptor(
      typeId: 'tom.form_editor',
      displayName: 'Form Editor',
      icon: Icons.dynamic_form,
      isEditor: true,
    ),
    ForgeComponentDescriptor(
      typeId: 'tom.form_properties',
      displayName: 'Form Properties',
      icon: Icons.settings,
      isEditor: false,
    ),
  ];

  @override
  List<ForgeAction> get actions => [
    ForgeAction(
      id: 'tom.form_editor.addField',
      label: 'Add Form Field',
      menu: ForgeMenuLocation.extensions,
      group: 'tom.form_editor',
      priority: 0,
      execute: () => _addField(),
      isEnabled: () => _shell.systemState.focusedComponentTypeId == 'tom.form_editor',
      isVisible: () => _shell.systemState.focusedComponentTypeId == 'tom.form_editor',
    ),
  ];

  @override
  List<ForgeShortcutBinding> get shortcuts => [];
}
```

### 8.4 Extension Lifecycle

1. Extensions are declared in the `TomForgeShell` configuration
2. `activate()` is called during shell startup, in dependency order
3. Extensions can reference each other via `shell.extensions.get<T>()`
4. `deactivate()` is called during shell shutdown, in reverse order

### 8.5 Shell API Surface

The `ForgeShellApi` passed to extensions provides:

```dart
abstract class ForgeShellApi {
  /// Component registration.
  ForgeComponentRegistry get registry;

  /// System state — focus, selection, open editors, problems, etc.
  ForgeSystemState get systemState;

  /// Menu and action registration.
  ForgeActionRegistry get actions;

  /// Shortcut manager.
  ForgeShortcutManager get shortcuts;

  /// File system access (routed through .forge revisioning).
  ForgeFileSystem get fileSystem;

  /// Layout control — open/close panels, focus components, etc.
  ForgeLayoutController get layout;

  /// Status bar item registration.
  ForgeStatusBarController get statusBar;

  /// File association registry (file pattern → editor type).
  ForgeFileAssociationRegistry get fileAssociations;

  /// Extension cross-references.
  ForgeExtensionRegistry get extensions;

  /// Output channel creation.
  ForgeOutputChannelManager get output;

  /// Problem (diagnostic) registration.
  ForgeDiagnosticManager get diagnostics;

  /// Configuration access.
  ForgeConfigManager get config;
}
```

---

## 9. Configuration System

### 9.1 Built-In Configuration Tab

The left panel always contains a pinned **Configuration tab** (⚙ icon) at the bottom of its icon strip. This tab is:

- **Not draggable** — it cannot be moved to other panels
- **Not removable** — it is always present
- **Accordeon-based** — contains multiple collapsible configuration sections

### 9.2 Configuration Views

The Configuration tab contains these sections (as accordeon items):

| Section | Description |
|---------|-------------|
| **General** | Application-wide settings: auto-save, theme, font size, tab size |
| **Menu** | Menu structure editor: reorder, hide, add custom entries (see §7.3) |
| **Shortcuts** | Shortcut editor: view all bindings, rebind, detect conflicts (see §11.5) |
| **Extensions** | List of loaded extensions, enable/disable, extension-specific settings |
| **Layout** | Panel visibility, default sizes, reset to defaults |
| **File Types** | File association editor (pattern → editor mapping) |

### 9.3 Code-Based Configuration

Configuration is defined in code and can be overridden at runtime. The code-configured values serve as defaults:

```dart
class ForgeConfig {
  /// Auto-save behavior.
  final AutoSaveConfig autoSave;

  /// Shortcut trigger key configuration.
  final ShortcutConfig shortcuts;

  /// Theme and appearance.
  final ThemeConfig theme;

  /// File revisioning behavior.
  final RevisioningConfig revisioning;
}

class AutoSaveConfig {
  /// Whether auto-save is enabled. Default: true.
  final bool enabled;

  /// Delay after last keystroke before saving. Default: 1 second.
  final Duration idleDelay;

  /// Whether to save on focus loss. Default: true.
  final bool saveOnFocusLoss;
}
```

### 9.4 Configuration Persistence

- Configuration changes made via the Configuration tab are saved to `.forge/config.json`
- Code-configured values are defaults; runtime changes override them
- Reset option: restore to code-configured defaults

---

## 10. System State API

### 10.1 Overview

The system state API provides a comprehensive, real-time view of the shell's current state. It is the foundation for:

- **Menu/action enablement** — actions show, hide, or disable based on state
- **Context menus** — items appear based on what's focused/selected
- **Extension logic** — extensions react to state changes
- **Shortcut context** — shortcuts are active only in relevant contexts

### 10.2 State Properties

```dart
abstract class ForgeSystemState {
  // --- Focus ---

  /// The currently focused component's type ID (null if no component is focused).
  String? get focusedComponentTypeId;

  /// The currently focused component instance (null if none).
  ForgeComponent? get focusedComponent;

  /// Whether the focused component is the main instance or a UI copy.
  bool get isFocusedComponentMain;

  /// The panel location of the focused component.
  ForgePanelLocation? get focusedPanelLocation;

  // --- Editors ---

  /// All currently open editor URIs.
  List<Uri> get openEditorUris;

  /// The active editor URI (the editor with focus, or last focused).
  Uri? get activeEditorUri;

  /// URIs of editors with unsaved changes.
  List<Uri> get dirtyEditorUris;

  /// Whether any editor has unsaved changes.
  bool get hasUnsavedChanges;

  // --- Explorer / Selection ---

  /// Currently selected files/folders in the explorer view.
  List<Uri> get selectedExplorerItems;

  /// The file/folder currently hovered in the explorer.
  Uri? get hoveredExplorerItem;

  // --- Problems ---

  /// Current diagnostic count by severity.
  DiagnosticSummary get diagnosticSummary;

  /// All registered diagnostics.
  List<ForgeDiagnostic> get diagnostics;

  // --- Workspace ---

  /// Root directory of the current workspace.
  Directory get workspaceRoot;

  /// Whether the .forge folder is initialized.
  bool get isForgeFolderInitialized;

  // --- Application ---

  /// The currently active application.
  ForgeApplication get activeApplication;

  /// All applications.
  List<ForgeApplication> get applications;

  // --- Streams ---

  /// Fires when focus changes.
  Stream<FocusChangeEvent> get onFocusChanged;

  /// Fires when an editor's dirty state changes.
  Stream<DirtyStateEvent> get onDirtyStateChanged;

  /// Fires when explorer selection changes.
  Stream<SelectionChangeEvent> get onSelectionChanged;

  /// Fires when diagnostics change.
  Stream<DiagnosticChangeEvent> get onDiagnosticsChanged;

  /// Fires when any open editor list changes.
  Stream<EditorListChangeEvent> get onEditorsChanged;
}
```

### 10.3 Action Visibility and Enablement

Actions dynamically evaluate their `isVisible` and `isEnabled` callbacks against the current system state. The shell re-evaluates these whenever the relevant state changes:

```dart
// Example: "Save" is only enabled when the active editor is dirty.
ForgeAction(
  id: 'file.save',
  label: 'Save',
  menu: ForgeMenuLocation.file,
  isEnabled: () => systemState.activeEditorUri != null &&
      systemState.dirtyEditorUris.contains(systemState.activeEditorUri),
  isVisible: () => true,
  execute: () => shell.fileSystem.save(systemState.activeEditorUri!),
);
```

---

## 11. Keyboard Shortcuts

### 11.1 Two-Key Shortcut System

Tom Forge uses a **two-key shortcut system** to avoid conflicting with VS Code shortcuts (since Tom Forge may run as an embedded panel or alongside VS Code during development):

1. **Primary modifier shortcuts** — Standard shortcuts with CMD (macOS) or CTRL (Windows/Linux) that apply to universal operations.
2. **Trigger key shortcuts** — A dedicated trigger key (default: unmodified key like `Space` or `\``) opens a shortcut popup. The second key executes the action.

### 11.2 Trigger Key Flow

```
User presses trigger key (e.g., Space when no text field is focused)
    ↓
Shortcut popup appears below the search bar:
┌───────────────────────────────────────┐
│ [E] Explorer  [T] Terminal  [O] Output│
│ [P] Problems  [S] Search   [H] Help  │
│ [1] Panel 1   [2] Panel 2  [3] ...   │
│                                       │
│         Press key or ESC to cancel    │
└───────────────────────────────────────┘
    ↓
User presses the second key
    ↓
Action executes, popup closes
```

- The popup shows available actions with their keybindings
- **ESC** or clicking outside cancels the popup
- The trigger key is configurable (see §9.2)
- The popup only appears when no text input field is focused (to avoid interfering with typing)

### 11.3 Primary Modifier Shortcuts

These use CMD (macOS) / CTRL (Windows/Linux) and are always active:

| Shortcut | Action | Context |
|----------|--------|---------|
| `Cmd+P` | Open command palette (search bar) | Global |
| `Cmd+L` | Toggle left panel | Global |
| `Cmd+R` | Toggle right panel | Global |
| `Cmd+F` | Find in focused component | When component is focused |
| `Cmd+1` | Focus middle panel 1 | Global |
| `Cmd+2` | Focus middle panel 2 | Global |
| `Cmd+3` | Focus middle panel 3 | Global |
| `Cmd+4` | Focus middle panel 4 | Global |
| `Cmd+S` | Save active editor | When editor is focused |
| `Cmd+X` | Cut | When text is selected |
| `Cmd+C` | Copy | When text is selected |
| `Cmd+V` | Paste | When text input is focused |
| `Cmd+Y` | Delete line | When text editor is focused |
| `Cmd+Z` | Undo | When editor is focused |
| `Cmd+Shift+Z` | Redo | When editor is focused |
| `Cmd+W` | Close active editor tab | When editor is focused |
| `Cmd+Shift+T` | Reopen last closed editor | Global |
| `Cmd+[` / `Cmd+]` | Navigate back / forward | When component supports history |
| `Cmd+Tab` | Cycle through open editors | Global |
| `` Ctrl+` `` | Focus terminal view | Global |

### 11.4 Main Component vs UI Copy Focus

When a shortcut targets a component (e.g., `Cmd+S`), it applies to the **focused UI copy** of that component, not necessarily the main component. The distinction matters for:

- **Save** — saves the document regardless of which UI copy is focused (data state is shared)
- **Find** — opens find in the specific UI copy that has focus (UI state is per-copy)
- **Scroll** — affects only the focused copy's viewport

### 11.5 Shortcut Editor

The Shortcut Editor (in the Configuration tab, see §9.2) provides:

- **Full listing** of all registered shortcuts (from shell, extensions, components)
- **Conflict detection** — highlights when two shortcuts use the same key combination
- **Rebinding** — click a shortcut row, then press the desired key combination
- **Reset** — restore individual or all shortcuts to defaults
- **Search/filter** — find shortcuts by action name, key, or extension
- **Context column** — shows when each shortcut is active (global, editor-focused, component-specific)

---

## 12. Auto-Save and File Revisioning

### 12.1 Auto-Save

Auto-save is **enabled by default**. Files save automatically:

- **On focus loss** — when the user clicks outside the editor or switches to another editor/panel
- **After idle delay** — 1 second after the last keystroke (configurable)
- **On application switch** — optionally, when switching between applications

Auto-save can be disabled globally or per file type in the Configuration tab.

### 12.2 The .forge Folder

The `.forge/` folder lives in the **workspace root directory** (the opened folder). It stores:

```
.forge/
  config.json           # Runtime configuration overrides
  state/
    layout.json         # Current panel layout per application
    open-editors.json   # Open editor URIs per application
    recent.json         # Recently opened files
  revisions/
    <hash>/             # File revisions keyed by content hash
      metadata.json     # Timestamp, URI, description
      content           # File content snapshot
  undo/
    <uri-hash>/         # Per-file undo history
      stack.json        # Undo/redo stack metadata
```

### 12.3 File Revisioning

The shell **routes all file access** through `ForgeFileSystem`, which transparently manages revisions:

- **On save:** a revision snapshot is created automatically. Sequential identical saves (same content) do not create duplicate revisions.
- **Revision limit:** configurable (default: 50 revisions per file). Oldest revisions are pruned.
- **Viewing history:** the built-in File History view shows all revisions for a file, with diff/restore options.
- **Restore:** any revision can be restored. Restoring creates a new revision (non-destructive).

### 12.4 Undo System

Undo/redo operates at two levels:

1. **Editor-level undo** — standard text/content undo within the editor (Cmd+Z / Cmd+Shift+Z). This is per-editor and uses the data state's undo stack.
2. **File-level undo** — reverts to a previous file revision. Access via the File History view or command palette.

Both levels are stored in `.forge/` for persistence across sessions.

### 12.5 .forge Folder Location

The `.forge/` folder location depends on the **configuration directory** chosen at startup (see §13):

| Config directory | .forge location | Use case |
|-----------------|----------------|----------|
| `~/.forge` (global) | `~/.forge/` | Shared config across projects; revisions/state stored globally per workspace path |
| `<workspace>/.forge` (local) | `<workspace>/.forge/` | Project-specific config; revisions travel with the project |

When using the global `~/.forge`, workspace-specific data (revisions, layout, open editors) is stored in a subdirectory keyed by the workspace path hash: `~/.forge/workspaces/<hash>/`.

When using the local `<workspace>/.forge`, the `.forge/` folder should be added to `.gitignore` (Tom Forge suggests this during initialization).

---

## 13. Startup Dialog

### 13.1 Overview

When Tom Forge launches, it shows a **startup dialog** before the shell is rendered. The dialog lets the user pick or confirm two directories:

1. **Workspace directory** — the root folder to open
2. **Configuration directory** — where `.forge/` data (revisions, state, config) is stored

The shell remembers both directories using **platform application preferences** (`SharedPreferences` / native key-value store) so the dialog can pre-populate on subsequent launches.

### 13.2 Workspace Directory Selection

**Default detection logic** (in priority order):

1. **Remembered path** — if the user previously chose a workspace, pre-fill that path
2. **Walk up from CWD** — starting from the current working directory, walk up the directory hierarchy looking for a `.forge/` folder. Stop at the first match. Skip `~/.forge` (the global config directory is not a workspace).
3. **CWD itself** — if no `.forge/` is found, default to the current working directory
4. **No default** — if CWD is the home directory or root, leave the field empty

**UI:**

```
┌─────────────────────────────────────────────────────────┐
│                    Tom Forge Setup                       │
│                                                         │
│  Workspace Directory                                    │
│  ┌─────────────────────────────────────────────┐ [📁]   │
│  │ /Users/alex/projects/my_app                 │        │
│  └─────────────────────────────────────────────┘        │
│  ℹ Found .forge/ at /Users/alex/projects/my_app         │
│                                                         │
│  Configuration Storage                                  │
│  ○ Global (~/.forge)          ● Project (.forge/)       │
│  ┌─────────────────────────────────────────────┐ [📁]   │
│  │ /Users/alex/projects/my_app/.forge           │        │
│  └─────────────────────────────────────────────┘        │
│                                                         │
│  ☑ Remember these settings                              │
│                                                         │
│  Recent Workspaces                                      │
│  ├─ /Users/alex/projects/my_app       (last opened)     │
│  ├─ /Users/alex/projects/other_proj                     │
│  └─ /Users/alex/work/client_proj                        │
│                                                         │
│              [ Cancel ]  [ Open Workspace ]              │
└─────────────────────────────────────────────────────────┘
```

### 13.3 Configuration Directory Selection

**Options:**

| Option | Directory | Description |
|--------|-----------|-------------|
| **Global** | `~/.forge/` | Default on first launch. Config is shared across all workspaces. Workspace-specific data is stored in `~/.forge/workspaces/<hash>/`. |
| **Project** | `<workspace>/.forge/` | Config travels with the project. Good for teams or project-specific tooling setups. |
| **Custom** | User-chosen path | Advanced: user picks any directory via the folder picker. |

**Default:** `~/.forge` on first launch. If the startup dialog detects an existing `<workspace>/.forge/` folder, it switches the default to Project.

### 13.4 Remembered Preferences

The shell stores these values in **platform application preferences** (not in `.forge/`, since `.forge/` hasn't been resolved yet at startup time):

```dart
class ForgeStartupPreferences {
  /// Last opened workspace directory.
  String? lastWorkspacePath;

  /// Configuration directory mode for the last workspace.
  /// 'global' | 'project' | 'custom'
  String? lastConfigMode;

  /// Custom config directory path (only when mode is 'custom').
  String? lastCustomConfigPath;

  /// Whether to skip the dialog and use remembered settings.
  bool rememberSettings;

  /// Recent workspace paths (most recent first, max 10).
  List<String> recentWorkspaces;
}
```

Stored via `SharedPreferences` (Flutter) or equivalent platform key-value store, keyed under `forge.startup.*`.

### 13.5 Startup Flow

```
App launches
  ↓
Load ForgeStartupPreferences
  ↓
┌─ rememberSettings == true AND lastWorkspacePath is valid?
│   YES → Skip dialog, open shell with remembered paths
│   NO  → Show startup dialog with pre-filled defaults
└─
  ↓
User confirms or changes workspace + config directory
  ↓
Save updated preferences
  ↓
Initialize ForgeFolderManager with chosen paths
  ↓
┌─ .forge/ folder exists at chosen config location?
│   YES → Load existing config, state, revisions
│   NO  → Create .forge/ folder structure
│         If project mode: suggest adding .forge/ to .gitignore
└─
  ↓
Activate extensions, build shell, render
```

### 13.6 Command-Line Override

The startup dialog can be bypassed via command-line arguments:

```
tom_forge --workspace /path/to/project
tom_forge --workspace /path/to/project --config global
tom_forge --workspace /path/to/project --config /custom/path
```

When `--workspace` is provided, the dialog is skipped and the shell opens directly. If `--config` is omitted, the remembered preference for that workspace is used (or `global` as fallback).

---

## 14. Built-In Views

### 14.1 Initial Implementation (v1)

These views ship with the panel shell framework:

| View | Type ID | Description | Default Panel |
|------|---------|-------------|---------------|
| **Terminal** | `forge.terminal` | Embedded terminal emulator (pty-based on desktop). Multiple terminal instances managed as tabs within the view. | Bottom |
| **Output** | `forge.output` | Read-only text output channel. Components can write to named output channels (dropdown to select channel). Shows timestamped, scrollable log output. | Bottom |
| **Problems** | `forge.problems` | Aggregated diagnostics list (errors, warnings, info). Components register problem providers. Click-to-navigate to source location. Filterable by severity and source. | Bottom |
| **Explorer** | `forge.explorer` | File/resource tree browser. Shows workspace files, supports open/rename/delete. Double-click opens in editor. | Left |
| **Search** | `forge.search` | Full-text search across workspace files. Shows results grouped by file with match highlighting. Click navigates to match. | Left |
| **Outline** | `forge.outline` | Structural outline of the active editor's content (sections, classes, functions — editor-dependent). Follows focus. Click navigates within the editor. | Left |
| **File History** | `forge.file_history` | Revision history for the active file. Shows timestamps, diffs, restore options. Reads from `.forge/revisions/`. | Right |

### 14.2 Suggested for Later

| View | Type ID | Description | Rationale |
|------|---------|-------------|-----------|
| **Debug Console** | `forge.debug` | Interactive debug output and evaluation | Needed once D4rt integration lands |
| **Git / Source Control** | `forge.scm` | Git status, staging, commit, diff | Common development need |
| **Notifications** | `forge.notifications` | System and component notifications with history | Better than toast-only |
| **Minimap** | `forge.minimap` | Thumbnail overview of the active editor | Useful for large files |
| **Properties** | `forge.properties` | Context-sensitive property editor for the selected item | Useful for visual editors (flow editor, form editor) |
| **Preview** | `forge.preview` | Live preview of the active editor's content (markdown, flow diagram) | Already exists in tom_md_editor |
| **Help** | `forge.help` | Contextual documentation browser | Supports back/forward history |
| **Execution Monitor** | `forge.execution` | Real-time flow execution display (node states, timing, logs) | Core for the flow editor |

### 14.3 View Responsibilities

Each built-in view is a self-contained package-level widget. The panel shell provides:

- **View host:** wraps the view widget, provides the accordeon section header, handles drag
- **Service locator:** views access shared services (file system, diagnostics, terminal manager) via the `ForgeShellApi` provider
- **Focus tracking:** the shell notifies views when the active editor changes (for outline, properties, etc.)
- **Multi-render:** views that support multi-render (e.g., Outline) can appear in multiple panels simultaneously

---

## 15. Status Bar

### 15.1 Structure

```
┌──────────────────────────────────────────────────────────────────────┐
│ ⚡ Ready  │  main ↗  │  Ln 42, Col 17  │  UTF-8  │  Dart  │  2 ⚠  │
└──────────────────────────────────────────────────────────────────────┘
 ← global items →       ← active component items →        ← global →
```

### 15.2 Status Bar Items

```dart
class StatusBarItem {
  final String id;
  final String text;
  final IconData? icon;
  final StatusBarAlignment alignment; // left, center, right
  final int priority; // higher = closer to edge
  final VoidCallback? onTap;
  final String? tooltip;
}
```

- **Global items:** contributed by the shell (connection status, application info, problem count)
- **Component items:** contributed by the focused component (cursor position, file encoding, language)
- Items are reactive — they update via `ValueNotifier` or stream

---

## 16. Application Setup (Code-Configured)

### 16.1 Example

```dart
void main() {
  // Define extensions
  final formEditorExtension = TomFormEditorExtension();
  final flowEditorExtension = TomFlowEditorExtension();

  final shell = TomForgeShell(
    workspace: Directory.current,
    extensions: [formEditorExtension, flowEditorExtension],
    config: ForgeConfig(
      autoSave: AutoSaveConfig(enabled: true, idleDelay: Duration(seconds: 1)),
      revisioning: RevisioningConfig(maxRevisionsPerFile: 50),
    ),
    applications: [
      ForgeApplication(
        title: 'Tom Flow',
        layout: ApplicationLayout(
          leftPanel: PanelConfig(
            initialSize: 260,
            tabs: [
              PanelTabConfig(
                title: 'Explorer',
                icon: Icons.folder,
                sections: [
                  AccordeonSectionConfig(componentTypeId: 'forge.explorer'),
                  AccordeonSectionConfig(componentTypeId: 'forge.outline'),
                ],
              ),
              PanelTabConfig(
                title: 'Search',
                icon: Icons.search,
                sections: [
                  AccordeonSectionConfig(componentTypeId: 'forge.search'),
                ],
              ),
            ],
          ),
          rightPanel: PanelConfig(
            initialSize: 240,
            tabs: [
              PanelTabConfig(
                title: 'Properties',
                icon: Icons.settings,
                sections: [
                  AccordeonSectionConfig(componentTypeId: 'forge.properties'),
                  AccordeonSectionConfig(componentTypeId: 'forge.file_history'),
                ],
              ),
            ],
          ),
          bottomPanel: PanelConfig(
            initialSize: 200,
            tabs: [
              PanelTabConfig(
                title: 'Terminal',
                icon: Icons.terminal,
                sections: [
                  AccordeonSectionConfig(componentTypeId: 'forge.terminal'),
                ],
              ),
              PanelTabConfig(
                title: 'Output',
                icon: Icons.output,
                sections: [
                  AccordeonSectionConfig(componentTypeId: 'forge.output'),
                  AccordeonSectionConfig(componentTypeId: 'forge.problems'),
                ],
              ),
            ],
          ),
          middlePanels: [
            MiddlePanelConfig(
              flex: 1,
              tabs: [
                MiddleTabConfig(
                  componentTypeId: 'tom.flow_editor',
                  uri: Uri.file('example.queue.yaml'),
                ),
              ],
            ),
          ],
        ),
      ),
      ForgeApplication(title: 'Tom D4rt Scripting'),
      ForgeApplication(title: 'Tom Worktracker'),
    ],
  );

  runApp(TomForgeShellApp(shell: shell));
}
```

### 16.2 Layout Persistence

- Layout changes (panel sizes, component positions, tab order) are persisted per application in `.forge/state/layout.json`
- On startup: load persisted layout; fall back to code-configured defaults
- Reset option: restore to code-configured defaults
- Applications that were open when the shell was last closed are restored on next launch

---

## 17. Implementation Architecture

### 17.1 Package Structure

```
tom_forge_ui/
  lib/
    tom_forge_ui.dart               # Barrel export
    src/
      shell/
        forge_shell.dart            # Top-level shell widget
        forge_shell_api.dart        # ForgeShellApi interface
        title_bar.dart              # Title bar with nav, search, application dropdown
        menu_bar.dart               # Menu bar with action-driven menus
        status_bar.dart             # Status bar
        application_switcher.dart   # Application dropdown + switch logic
      panels/
        panel_host.dart             # Generic panel host (left/right/bottom)
        middle_panel_host.dart      # Middle editor panel area
        accordeon.dart              # Accordeon widget with sections
        accordeon_section.dart      # Single collapsible section
        panel_tab_bar.dart          # Tab bar for side/bottom panels
        editor_tab_bar.dart         # Tab bar for middle panels
        drag_overlay.dart           # Drop zone overlay for drag-and-drop
        resizable_divider.dart      # Drag handle for panel resizing
      components/
        forge_component.dart        # Component base class / interface
        component_host.dart         # Wraps a component in a panel section
        component_registry.dart     # Registration and factory lookup
        component_state.dart        # Shared data state + per-copy UI state
        multi_render_manager.dart   # Track main component vs UI copies
      extensions/
        forge_extension.dart        # Extension base class
        extension_registry.dart     # Extension lifecycle and cross-references
      models/
        application_model.dart      # TomForgeShell, ForgeApplication
        layout_model.dart           # PanelConfig, TabConfig, etc.
        status_bar_model.dart       # StatusBarItem
        action_model.dart           # ForgeAction, ForgeMenuLocation
        shortcut_model.dart         # ForgeShortcutBinding, trigger key config
      startup/
        startup_dialog.dart         # Workspace + config directory picker
        startup_preferences.dart    # ForgeStartupPreferences (SharedPreferences)
        workspace_detector.dart     # Walk-up .forge detection logic
      services/
        layout_persistence.dart     # Save/load layout state to .forge/
        focus_service.dart          # Track active component, notify listeners
        history_service.dart        # Back/forward navigation per component
        system_state.dart           # ForgeSystemState implementation
        auto_save_service.dart      # Auto-save timer + focus-loss detection
        forge_file_system.dart      # File access routed through revisioning
        forge_folder_manager.dart   # .forge/ folder initialization and access
        revision_manager.dart       # File revision storage and retrieval
        shortcut_manager.dart       # Shortcut registration, trigger key, conflicts
        action_registry.dart        # Menu action registration and evaluation
        config_manager.dart         # Configuration load/save/defaults
      config/
        forge_config.dart           # ForgeConfig, AutoSaveConfig, etc.
        config_views/
          general_config_view.dart
          menu_config_view.dart
          shortcut_config_view.dart
          extension_config_view.dart
          layout_config_view.dart
          filetype_config_view.dart
      views/                        # Built-in views
        terminal_view.dart
        output_view.dart
        problems_view.dart
        explorer_view.dart
        search_view.dart
        outline_view.dart
        file_history_view.dart
```

### 17.2 State Management

- **Shell state:** `ForgeShellController` (a `ChangeNotifier`) manages the overall layout, active application, panel sizes, and component placement
- **System state:** `ForgeSystemState` provides reactive access to focus, editors, selection, diagnostics, and more. Used by actions, menus, and extensions.
- **Component data state:** Each component type manages its own data state internally. The shell provides a `ForgeComponentStateManager` that maps URIs/types to shared data state objects.
- **Component UI state:** Each UI copy maintains its own `ForgeComponentUiState` (scroll position, cursor, selection). Managed by `MultiRenderManager`.
- **Reactive updates:** `ValueListenable` pattern consistent with other Tom Forge components

### 17.3 Widget Tree (Simplified)

```
TomForgeShellApp
 └─ MaterialApp
     └─ ForgeShell (controller: ForgeShellController)
         ├─ TitleBar
         │   ├─ NavButtons (◀ ▶)
         │   ├─ SearchTitleField / CommandPalette
         │   └─ ApplicationDropdown
         ├─ MenuBar (actions from registry)
         ├─ Row
         │   ├─ LeftPanelHost (resizable width)
         │   │   ├─ IconTabBar (vertical)
         │   │   │   ├─ [user tabs]
         │   │   │   ├─ ─────── (divider)
         │   │   │   └─ ⚙ ConfigTab (pinned)
         │   │   └─ Accordeon (sections per active tab)
         │   ├─ Column
         │   │   ├─ Row (middle panels, resizable widths)
         │   │   │   ├─ MiddlePanelHost (EditorTabBar + content)
         │   │   │   ├─ ResizableDivider
         │   │   │   └─ MiddlePanelHost
         │   │   ├─ ResizableDivider (vertical)
         │   │   └─ BottomPanelHost (resizable height)
         │   │       ├─ TabBar (horizontal, icon + text)
         │   │       └─ Accordeon (sections per active tab)
         │   └─ RightPanelHost (resizable width)
         │       ├─ Accordeon (sections per active tab)
         │       └─ IconTabBar (vertical)
         ├─ ShortcutPopup (trigger key overlay, when active)
         └─ StatusBar
```

### 17.4 Debug Mode

Per Tom Forge convention, the panel shell implements trail-based debug mode:

- Flag: `kForgeShellDebug`
- Prefix: `[FS]`
- Trail file: `lib/src/shell/shell_trail.dart`
- Events: layout changes, drag operations, application switches, component focus changes, shortcut activations, auto-save events, revision creation

---

## 18. Implementation Phases

### Phase 1 — Shell Skeleton

- **Startup dialog** — workspace + config directory picker with preference persistence
- `ForgeShell` widget with title bar, menu bar, status bar, panel areas
- Resizable dividers between all panels
- Basic `ForgeApplication` and `TomForgeShell` models
- Application dropdown (switch applications, all stay alive)
- Middle panels with tab bar (1–4 panels, split/merge)
- Placeholder components for testing layout
- `.forge/` folder initialization (global or project-local)

### Phase 2 — Accordeon Panels

- Left/right/bottom panels with tab + accordeon structure
- Collapsible sections with mutual exclusion and pinning
- Size hint system (min/preferred/max)
- Bottom panel vertical text for collapsed sections
- "+" button for adding new tabs
- Configuration tab (⚙) pinned at bottom of left panel

### Phase 3 — Component Framework

- `ForgeComponent` contract and `ForgeComponentRegistry`
- Component host wrapper with drag handles
- Multi-render: data state sharing by URI/type, independent UI state per copy
- SHIFT+drag to create UI copies
- Focus tracking service
- `ForgeSystemState` implementation

### Phase 4 — Extension System and Actions

- `ForgeExtension` contract and lifecycle (activate/deactivate)
- `ForgeShellApi` implementation
- Action registry and menu population
- Context menus based on system state
- Extension cross-references

### Phase 5 — Shortcuts and Configuration

- Two-key shortcut system with trigger key popup
- Primary modifier shortcuts (Cmd+P, Cmd+S, etc.)
- Shortcut manager with conflict detection
- Configuration tab with all config views (general, menu, shortcuts, extensions, layout, file types)
- Configuration persistence to `.forge/config.json`

### Phase 6 — Drag and Drop

- Drag components between accordeon sections
- Drag components into middle panel tab bars
- Drag to split middle panels (drop zone overlay)
- Drag entire tabs between left/right/bottom panels
- SHIFT+drag to create UI copies

### Phase 7 — Auto-Save and Revisioning

- `ForgeFileSystem` with routed file access
- Auto-save service (focus loss + idle timer)
- File revision management in `.forge/revisions/`
- Undo stack persistence in `.forge/undo/`
- File History view

### Phase 8 — Built-In Views

- Terminal view (pty integration)
- Output view (channel-based log viewer)
- Problems view (diagnostic aggregator)
- Explorer view (file tree)
- Search view (text search)
- Outline view (active editor structure)
- File History view (revision browser)

### Phase 9 — Persistence and Polish

- Layout persistence per application (JSON save/load in `.forge/state/`)
- Open editor restoration
- Animation for panel transitions
- Accessibility (screen reader support, high contrast)
- Debug trail integration
