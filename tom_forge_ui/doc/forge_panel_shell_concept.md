# Tom Forge Panel Shell — Concept Document

**Project:** tom_forge_ui  
**Component:** Panel Shell Framework  
**Date:** 2026-03-24  
**Status:** Concept (v3)

---

## 1. Overview

The Tom Forge Panel Shell is a desktop-optimized, multi-panel application framework for composing visual development tools. It provides a familiar IDE-style window layout with applications, editors, views, and configurable panel arrangements — all within a single Flutter application.

The framework lives in `tom_forge_ui` (library) with a test/demo application in `tom_forge_app`.

### Terminology

| Term | Definition |
|------|-----------|
| **Workspace** | The root folder opened by the user. Contains source files, configuration, and a `.forge/` folder for state and file revisions. |
| **Application** | A named arrangement of panels, components, and shortcuts. Multiple applications can be open simultaneously. Switching between applications keeps the previous one alive in memory. |
| **Component** | An editor or view that plugs into the shell. |
| **Module** | A cohesive group of related components, actions, and shortcuts compiled into the application. No dynamic loading — modules are type-safe Dart code. |
| **Shell** | The top-level framework that manages panels, focus, menus, shortcuts, and state. |

### Design Principles

- **Single window, multi-application** — applications switch via a dropdown; all remain alive in memory simultaneously
- **Component-based** — editors and views are self-contained widgets that plug into the shell
- **Multi-render components** — a component can appear in multiple locations; each UI copy has its own UI state (scroll position, selection), but all copies share the same data state
- **Drag-and-drop layout** — users rearrange components freely between panels
- **Module-driven** — functionality is packaged as modules (groups of components + actions + shortcuts) compiled directly into the application with full, type-safe shell access
- **Integrated, not sandboxed** — modules are normal Dart code in the same isolate as the shell; no marketplace, no dynamic loading, no serialization boundaries
- **Auto-save by default** — files save on focus loss or after 1-second idle
- **File revisioning** — the `.forge/` folder in the workspace tracks file revisions and shell state
- **Code-configured** — initial layout is declarative in Dart; comprehensive runtime configurability; changes persist

---

## 2. Window Structure

```
┌─────────────────────────────────────────────────────────────────────┐
│  ◀ ▶   │        🔍 Application Title              │ [Application ▾]│  Title Bar
├────┬────────────────────────────────────────────────────────┬───────┤
│    │  ┌─ Menu Bar (native) ─────────────────────────────────┐   │       │
│    │  │ File  Edit  View  Modules…  Help                   │   │       │
│    │  └─────────────────────────────────────────────────────┘   │       │
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
| **Editor** | Yes — all copies are equal, all are closable (× button) | Yes (SHIFT+drag creates UI copy) | By URI — all copies share one data model | Each copy has own scroll position, cursor, selection | Middle panels |
| **View** | Main component: not closable. UI copies: closable (× button). | Yes (SHIFT+drag creates UI copy) | By type — all copies share one data model | Each copy has own scroll position, expansion state | Left / right / bottom panels |

### 4.1.1 Close and Pin Button Positioning

Tabs and section headers may show **close** (×) and **pin** (📌) icon buttons:

- The **close button** (×) is always at the **far right** of the tab/header
- The **pin button** is to the **left of the close button** (i.e., second from right)
- If only one button is present (e.g., close without pin), it sits at the far right
- **Editors:** all copies show a close button (all are equal, no "main" distinction)
- **Views:** the main component shows no close button (it cannot be closed); UI copies show a close button

### 4.2 Component Identity and Multi-Render

- **Editors** are identified by a **URI** (`Uri`). The URI can represent a file path, a virtual resource, or any addressable entity. All editor instances with the same URI share the same **data state** (document content, dirty flag, undo history).
- **Views** are identified by their **type** (Dart `Type`). All instances of the same view type share the same **data state**.

**Multi-render model:**

A single logical component can be rendered in multiple locations simultaneously. Each rendered instance is called a **UI copy**. There is always one **main component** (the first instance created) and zero or more UI copies.

- **Data state** (document content, problem list, search results) is shared across all copies and the main component. Changes in one copy are immediately visible in all others.
- **UI state** (scroll position, cursor position, selection highlight, collapsed/expanded sections) is **independent per copy**. Each copy maintains its own UI state.
- **Creating a UI copy:** Hold **SHIFT** while dragging a component tab or section header. The original stays in place; a new UI copy appears at the drop location.
- **Regular drag** (without SHIFT) **moves** the component — the original location is vacated.
- **Closing copies:**
  - **Editors:** All copies are equal — any copy can be closed. There is no "main" editor. Closing the last copy closes the editor entirely.
  - **Views:** The main component (the first/original instance) cannot be closed. Only UI copies can be closed. If the main component is removed from the layout by the user (e.g., cleared from a panel), the oldest UI copy is promoted to main.
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

Components are registered with the shell so it knows what's available. Registration happens through modules (see §8) during their `activate()` call:

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

  /// Global component registry (populated by modules).
  final ForgeComponentRegistry registry;

  /// Application-level status bar items.
  final List<StatusBarItem> globalStatusItems;

  /// Registered modules.
  final List<ForgeModule> modules;

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

Tom Forge uses the **platform-native menu system** on macOS, Windows, and Linux. Flutter's `PlatformMenuBar` (macOS) and `MenuBar` widget (other platforms) render menus using the host OS's native menu infrastructure. This means:

- **macOS:** menus appear in the system menu bar at the top of the screen (standard Mac behavior), not inside the Flutter window
- **Windows / Linux:** menus appear as a native-style menu bar inside the window

The menu bar has a **fixed top-level structure** with menu items automatically populated from components, views, modules, and the shell itself.

**Fixed top-level menus:**

| Menu | Source | Contents |
|------|--------|----------|
| **File** | Shell + editors | New, Open, Save, Save All, Close, Recent, Quit |
| **Edit** | Focused component | Undo, Redo, Cut, Copy, Paste, Find, Replace |
| **View** | Shell | Toggle panels, zoom, appearance, layout |
| **Go** | Shell + focused component | Go-to-file, go-to-line, go-to-symbol, back/forward |
| **Modules** | Modules | Each module can contribute a submenu here |
| **Help** | Shell | About, keyboard shortcuts reference, documentation |

### 7.2 Action-Based Menu Population

Menu items are **actions** (`ForgeAction`). Components, views, and modules register actions with the shell. Each action declares which menu it belongs to:

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

  /// Execute the action with optional parameters.
  /// Returns an undo object (information needed to reverse the action),
  /// or null if the action is not undoable.
  final Future<Object?> Function(Map<String, Object> params) execute;

  /// Whether the action is currently enabled. Evaluated dynamically.
  final bool Function() isEnabled;

  /// Whether the action is currently visible. Evaluated dynamically.
  final bool Function() isVisible;

  /// Shortcut binding (optional — displayed next to the menu item).
  final ForgeShortcutBinding? shortcut;

  /// Undo the action using the undo object returned by execute().
  /// Null if the action is not undoable.
  final Future<void> Function(Object undoInfo)? undo;
}

enum ForgeMenuLocation { file, edit, view, go, modules, help }
```

**Action execution model:**

- `execute(params)` receives a parameter map. For menu invocations, `params` is typically empty. For programmatic calls (e.g., from other modules or keyboard shortcuts), callers can pass structured data.
- The return value is the **undo object** — an opaque value containing whatever information the action needs to reverse itself. If the action returns `null`, it is not added to the undo stack.
- `undo(undoInfo)` reverses the action using the previously returned undo object.
- **User input during execution:** Actions can use `ForgeDialogManager` (via the shell API) to open quick picks, input boxes, or file dialogs before performing the operation. This is the standard pattern for actions that need user choices (e.g., "Rename" opens an input box, "Open File" opens a file picker).
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

## 8. Module System

### 8.1 Concept

A **module** is a cohesive group of related functionality that registers with the shell. Modules are the primary way to add editors, views, actions, and shortcuts to Tom Forge. Unlike VS Code extensions, Tom Forge modules are compiled into the same Flutter application — there is no dynamic loading, no marketplace, and no sandboxing. Modules run in the same Dart isolate as the shell and have full, type-safe access to the shell API. They are best thought of as **shell components** — integrated parts of the application.

### 8.2 Module Contract

```dart
abstract class ForgeModule {
  /// Unique module identifier.
  String get id;

  /// Display name for the module.
  String get displayName;

  /// Called when the module is activated. The shell reference provides
  /// full access to the shell API — registration, state, services, etc.
  void activate(ForgeShellApi shell);

  /// Called when the module is deactivated (shutdown).
  void deactivate();

  /// Actions this module contributes.
  List<ForgeAction> get actions;

  /// Shortcut bindings this module contributes.
  List<ForgeShortcutBinding> get shortcuts;
}
```

### 8.3 Example: Form Editor Module

Visual elements (editors, views) are **direct members** of the module class, not items in a list. This makes them accessible for use in code-based layout configuration (see §16.1).

```dart
class TomFormEditorModule extends ForgeModule {
  late final ForgeShellApi _shell;

  // --- Visual elements as direct members ---

  /// The form editor (opens .form.yaml files).
  late final ForgeEditorDescriptor formEditor;

  /// Properties view showing form field properties.
  late final ForgeViewDescriptor propertiesView;

  @override
  String get id => 'tom.form_editor';

  @override
  String get displayName => 'Tom Form Editor';

  @override
  void activate(ForgeShellApi shell) {
    _shell = shell;

    // Create descriptors as members (accessible for layout config)
    formEditor = shell.registry.registerEditor(
      'tom.form_editor',
      displayName: 'Form Editor',
      icon: Icons.dynamic_form,
      factory: (uri) => TomFormEditor(shell: shell, uri: uri),
    );

    propertiesView = shell.registry.registerView(
      'tom.form_properties',
      displayName: 'Form Properties',
      icon: Icons.settings,
      factory: () => TomFormPropertiesView(shell: shell),
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
  List<ForgeAction> get actions => [
    ForgeAction(
      id: 'tom.form_editor.addField',
      label: 'Add Form Field',
      menu: ForgeMenuLocation.modules,
      group: 'tom.form_editor',
      priority: 0,
      execute: (params) async {
        final field = await _shell.dialogs.showInputBox(
          prompt: 'Field name',
          placeholder: 'Enter field name',
        );
        if (field == null) return null; // user cancelled
        return _addField(field); // returns undo info
      },
      undo: (undoInfo) async => _removeField(undoInfo),
      isEnabled: () => _shell.systemState.focusedComponentTypeId == 'tom.form_editor',
      isVisible: () => _shell.systemState.focusedComponentTypeId == 'tom.form_editor',
    ),
  ];

  @override
  List<ForgeShortcutBinding> get shortcuts => [];
}
```

### 8.4 Module Lifecycle

1. Modules are declared in the `TomForgeShell` configuration
2. `activate()` is called during shell startup, in dependency order
3. Modules can reference each other via `shell.modules.get<T>()`
4. `deactivate()` is called during shell shutdown, in reverse order

### 8.5 Shell API Surface

The `ForgeShellApi` passed to modules provides:

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

  /// Module cross-references (type-safe).
  ForgeModuleRegistry get modules;

  /// Output channel creation.
  ForgeOutputChannelManager get output;

  /// Problem (diagnostic) registration.
  ForgeDiagnosticManager get diagnostics;

  /// Configuration access.
  ForgeConfigManager get config;

  /// Notification toasts and dialogs.
  ForgeNotificationManager get notifications;

  /// Progress indicators (status bar or overlay).
  ForgeProgressManager get progress;

  /// Programmatic dialogs (quick pick, input box, file picker).
  ForgeDialogManager get dialogs;

  /// Terminal instance management.
  ForgeTerminalManager get terminals;

  /// Clipboard access (read/write text).
  ForgeClipboard get clipboard;

  /// Environment utilities (open external URI, app info).
  ForgeEnvironment get environment;

  /// Per-module persistent storage.
  ForgeModuleStorage get storage;
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
| **Modules** | List of loaded modules, enable/disable, module-specific settings |
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
- **Module logic** — modules react to state changes
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

  // --- Layout ---

  /// Which panels are currently visible (open).
  Set<ForgePanelLocation> get visiblePanels;

  /// Number of middle panels currently showing.
  int get middlePanelCount;

  /// Index of the active (focused) middle panel.
  int get activeMiddlePanelIndex;

  // --- Window ---

  /// Whether the application window has OS-level focus.
  bool get isWindowFocused;

  // --- Search ---

  /// The current search query (empty when not searching).
  String get searchQuery;

  /// Whether search is currently active.
  bool get isSearchActive;

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

  /// Fires when the application window gains or loses OS focus.
  Stream<WindowFocusEvent> get onWindowFocusChanged;

  /// Fires when panel visibility or layout changes.
  Stream<LayoutChangeEvent> get onLayoutChanged;
}
```

### 10.3 Action Visibility and Enablement

Actions dynamically evaluate their `isVisible` and `isEnabled` callbacks against the current system state. The shell re-evaluates these whenever the relevant state changes:

```dart
// Example: "Save All" saves all dirty editors and returns an undo object.
ForgeAction(
  id: 'file.saveAll',
  label: 'Save All',
  menu: ForgeMenuLocation.file,
  isEnabled: () => systemState.hasUnsavedChanges,
  isVisible: () => true,
  execute: (params) async {
    final saved = List<Uri>.from(systemState.dirtyEditorUris);
    for (final uri in saved) {
      await shell.fileSystem.save(uri);
    }
    return saved; // undo info: list of URIs that were saved
  },
  undo: null, // save is not undoable at this level
);
```

### 10.4 Service API Details

This section details the APIs for each service on `ForgeShellApi` that are not fully specified in the sections above.

#### ForgeFileSystem

```dart
abstract class ForgeFileSystem {
  /// Read file content at the given URI.
  Future<String> read(Uri uri);

  /// Write content to the given URI (creates or overwrites).
  /// Automatically creates a revision snapshot if revisioning is enabled.
  Future<void> write(Uri uri, String content);

  /// Save (persist) the current content of a file.
  /// Triggers revision snapshot and dirty-state update.
  Future<void> save(Uri uri);

  /// Delete a file.
  Future<void> delete(Uri uri);

  /// Check whether a file exists.
  Future<bool> exists(Uri uri);

  /// Stat a file (size, modification time, type).
  Future<FileStat> stat(Uri uri);

  /// List contents of a directory.
  Future<List<FileSystemEntity>> list(Uri directoryUri, {bool recursive = false});

  /// Watch a file or directory for changes. Returns a stream of events.
  Stream<FileSystemEvent> watch(Uri uri, {bool recursive = false});

  /// Fires when any file changes (create, modify, delete).
  Stream<FileChangeEvent> get onDidChange;

  /// Fires after a file is saved.
  Stream<Uri> get onDidSave;

  /// Fires before a file is saved. Listeners can modify content.
  Stream<WillSaveEvent> get onWillSave;
}
```

#### ForgeLayoutController

```dart
abstract class ForgeLayoutController {
  /// Open a panel (left, right, or bottom).
  void openPanel(ForgePanelLocation location);

  /// Close a panel.
  void closePanel(ForgePanelLocation location);

  /// Toggle a panel's visibility.
  void togglePanel(ForgePanelLocation location);

  /// Focus a specific component by type ID.
  void focusComponent(String componentTypeId);

  /// Open an editor for the given URI. Reuses an existing tab if already open.
  void openEditor(Uri uri, {int? middlePanelIndex});

  /// Split the active middle panel (add a new middle panel column).
  void splitMiddlePanel();

  /// Get the current configuration of a panel.
  PanelConfig? getPanelConfig(ForgePanelLocation location);

  /// Get the index of the active middle panel.
  int get activeMiddlePanelIndex;

  /// Reveal a file in the explorer view.
  void revealInExplorer(Uri uri);
}
```

#### ForgeOutputChannelManager and ForgeOutputChannel

```dart
abstract class ForgeOutputChannelManager {
  /// Create a new output channel.
  ForgeOutputChannel create(String name);

  /// Get an existing channel by name.
  ForgeOutputChannel? get(String name);

  /// List all output channels.
  List<ForgeOutputChannel> get channels;
}

abstract class ForgeOutputChannel {
  /// Channel name.
  String get name;

  /// Append text (no newline).
  void append(String text);

  /// Append text with trailing newline.
  void appendLine(String line);

  /// Clear all content.
  void clear();

  /// Show this channel in the Output view.
  void show({bool preserveFocus = true});

  /// Hide this channel.
  void hide();

  /// Dispose the channel (remove from manager).
  void dispose();
}
```

#### ForgeDiagnosticManager

```dart
abstract class ForgeDiagnosticManager {
  /// Create a named diagnostic collection (e.g., for a linter or build tool).
  ForgeDiagnosticCollection createCollection(String name);

  /// Get all diagnostics across collections.
  List<ForgeDiagnostic> get all;

  /// Get diagnostics for a specific URI.
  List<ForgeDiagnostic> forUri(Uri uri);
}

abstract class ForgeDiagnosticCollection {
  /// Collection name.
  String get name;

  /// Set diagnostics for a URI (replaces previous for that URI).
  void set(Uri uri, List<ForgeDiagnostic> diagnostics);

  /// Remove diagnostics for a URI.
  void delete(Uri uri);

  /// Clear all diagnostics in this collection.
  void clear();

  /// Dispose the collection.
  void dispose();
}
```

#### ForgeActionRegistry

```dart
abstract class ForgeActionRegistry {
  /// Register an action.
  void register(ForgeAction action);

  /// Execute an action by ID with optional parameters.
  /// Returns the undo object (or null if the action is not undoable).
  Future<Object?> execute(String actionId, {Map<String, Object> params = const {}});

  /// Get an action by ID.
  ForgeAction? get(String actionId);

  /// List all registered actions.
  List<ForgeAction> get allActions;

  /// Remove an action by ID.
  void remove(String actionId);

  /// Undo the last undoable action.
  Future<void> undo();

  /// Redo the last undone action.
  Future<void> redo();
}
```

#### ForgeShortcutManager

```dart
abstract class ForgeShortcutManager {
  /// Register a shortcut binding.
  void register(ForgeShortcutBinding binding);

  /// List all registered shortcut bindings.
  List<ForgeShortcutBinding> get allBindings;

  /// Rebind a shortcut to a new key combination.
  void rebind(String actionId, ForgeShortcutKey newKey);

  /// Remove a shortcut binding.
  void remove(String actionId);

  /// Detect conflicts with an existing binding.
  ForgeShortcutBinding? conflictsWith(ForgeShortcutKey key);
}
```

#### ForgeFileAssociationRegistry

```dart
abstract class ForgeFileAssociationRegistry {
  /// Register a file pattern → editor type association.
  void register({required String pattern, required String editorTypeId});

  /// Get the editor type ID for a given URI.
  String? getEditorForUri(Uri uri);

  /// List all associations.
  List<FileAssociation> get allAssociations;

  /// Remove an association by pattern.
  void remove(String pattern);
}
```

#### ForgeModuleRegistry

```dart
abstract class ForgeModuleRegistry {
  /// Get a typed module reference.
  T get<T extends ForgeModule>();

  /// Get a module by ID.
  ForgeModule? getById(String id);

  /// List all registered modules.
  List<ForgeModule> get allModules;

  /// Whether a module is active.
  bool isActive(String id);
}
```

#### ForgeConfigManager

```dart
abstract class ForgeConfigManager {
  /// Get a configuration value by key.
  T? get<T>(String key);

  /// Set a configuration value.
  void set(String key, Object? value);

  /// Get the full configuration object.
  ForgeConfig get current;

  /// Get module-scoped configuration section.
  Map<String, dynamic> getSection(String moduleId);

  /// Fires when any configuration value changes.
  Stream<ConfigChangeEvent> get onDidChange;
}
```

#### ForgeStatusBarController

```dart
abstract class ForgeStatusBarController {
  /// Register a status bar item.
  void register(StatusBarItem item);

  /// Remove a status bar item by ID.
  void remove(String id);

  /// Update a status bar item.
  void update(String id, {String? text, IconData? icon, String? tooltip});
}
```

#### ForgeNotificationManager (new)

```dart
abstract class ForgeNotificationManager {
  /// Show an information notification.
  Future<String?> showInformation(String message, {List<String> actions = const []});

  /// Show a warning notification.
  Future<String?> showWarning(String message, {List<String> actions = const []});

  /// Show an error notification.
  Future<String?> showError(String message, {List<String> actions = const []});
}
```

Returns the label of the selected action button, or null if dismissed.

#### ForgeProgressManager (new)

```dart
abstract class ForgeProgressManager {
  /// Run a task with a progress indicator.
  /// Location can be statusBar or overlay.
  Future<T> withProgress<T>({
    required String title,
    required ForgeProgressLocation location,
    required Future<T> Function(ForgeProgressReporter reporter) task,
    bool cancellable = false,
  });
}

abstract class ForgeProgressReporter {
  /// Report progress increment (0–100) and optional message.
  void report({int? increment, String? message});
}

enum ForgeProgressLocation { statusBar, overlay }
```

#### ForgeDialogManager (new)

```dart
abstract class ForgeDialogManager {
  /// Show a quick pick (selection list).
  Future<T?> showQuickPick<T>(List<ForgeQuickPickItem<T>> items, {
    String? placeholder,
    bool canSelectMany = false,
  });

  /// Show a text input box.
  Future<String?> showInputBox({
    String? prompt,
    String? value,
    String? placeholder,
    String? Function(String)? validateInput,
  });

  /// Show a file open dialog.
  Future<List<Uri>?> showOpenDialog({
    String? title,
    bool canSelectMany = false,
    bool canSelectFolders = false,
    List<FileFilter>? filters,
  });

  /// Show a file save dialog.
  Future<Uri?> showSaveDialog({
    String? title,
    Uri? defaultUri,
    List<FileFilter>? filters,
  });
}
```

#### ForgeTerminalManager (new)

```dart
abstract class ForgeTerminalManager {
  /// Create a new terminal instance.
  ForgeTerminal create({String? name, String? shellPath, String? cwd});

  /// Get all open terminals.
  List<ForgeTerminal> get terminals;

  /// Get the currently active terminal.
  ForgeTerminal? get activeTerminal;

  /// Fires when a terminal is opened.
  Stream<ForgeTerminal> get onDidOpen;

  /// Fires when a terminal is closed.
  Stream<ForgeTerminal> get onDidClose;

  /// Fires when the active terminal changes.
  Stream<ForgeTerminal?> get onDidChangeActive;
}

abstract class ForgeTerminal {
  /// Terminal name.
  String get name;

  /// Send text to the terminal.
  void sendText(String text, {bool addNewLine = true});

  /// Show this terminal.
  void show({bool preserveFocus = true});

  /// Close and dispose the terminal.
  void dispose();
}
```

#### ForgeClipboard (new)

```dart
abstract class ForgeClipboard {
  /// Read text from the system clipboard.
  Future<String> readText();

  /// Write text to the system clipboard.
  Future<void> writeText(String text);
}
```

#### ForgeEnvironment (new)

```dart
abstract class ForgeEnvironment {
  /// Application name.
  String get appName;

  /// Open a URI in the default external application (browser, file manager).
  Future<void> openExternal(Uri uri);
}
```

#### ForgeModuleStorage (new)

```dart
abstract class ForgeModuleStorage {
  /// Get a key-value store scoped to the calling module.
  /// Data is stored in .forge/modules/<moduleId>/.
  ForgeKeyValueStore forModule(String moduleId);
}

abstract class ForgeKeyValueStore {
  /// Get a value.
  T? get<T>(String key);

  /// Set a value.
  Future<void> set(String key, Object? value);

  /// Remove a key.
  Future<void> remove(String key);

  /// List all keys.
  List<String> get keys;
}
```

---

## 11. Keyboard Shortcuts

### 11.1 Shortcut Architecture

Tom Forge uses two complementary shortcut mechanisms:

1. **Standard shortcuts** — Single-modifier shortcuts (CMD on macOS, CTRL on Windows/Linux) for universal operations. These are a **limited, fixed set** of essential operations.
2. **Custom shortcut menus** — Module-defined popup menus opened via **Shift+CMD+\<key\>**. The menu shows available follow-up actions; the user presses a single key (or clicks) to execute.

### 11.2 Design Rationale

- Standard shortcuts intentionally avoid two-modifier combinations (no Cmd+Shift+X, no Ctrl+Alt+F, etc.) — keeping the set small and memorable
- Custom shortcut menus provide **discoverable, context-rich** access to module-specific commands without polluting the global shortcut space
- Multiple shortcut menus can coexist (e.g., Shift+Cmd+E for Explorer commands, Shift+Cmd+G for Git commands)

### 11.3 Standard Shortcuts

These use a single modifier key (CMD on macOS, CTRL on Windows/Linux) and are always active. The list is intentionally small — no two-modifier combinations are used for standard shortcuts:

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
| `Cmd+S` | Save all dirty editors | Global |
| `Cmd+Y` | Delete line | When in text editor |
| `Cmd+X` | Cut | When text is selected |
| `Cmd+C` | Copy | When text is selected |
| `Cmd+V` | Paste | When text input is focused |
| `Cmd+U` | Undo | When editor is focused |
| `Cmd+Z` | Redo | When editor is focused |

### 11.4 Custom Shortcut Menus

In addition to the standard shortcuts, there can be **multiple custom shortcut menus**. Each is opened via **Shift+Cmd+\<key\>** (macOS) or **Shift+Ctrl+\<key\>** (Windows/Linux). Pressing the modifier combination opens a popup menu that shows the available follow-up actions.

**Activation:** `Shift+Cmd+<trigger key>` (e.g., `Shift+Cmd+E` opens the Explorer shortcut menu)

**After the menu opens, the user can:**

1. Press a follow-up key (with or without modifier) to trigger the action
2. Click on an action in the menu
3. Use arrow keys + Enter to select an action
4. Press **ESC** or click outside the popup to cancel

```
User presses Shift+Cmd+E (Explorer shortcut menu trigger)
    ↓
Shortcut popup appears below the search bar:
┌───────────────────────────────────────┐
│ [R] Reveal in Finder                  │
│ [N] New File                          │
│ [D] New Folder                        │
│ [C] Collapse All                      │
│                                       │
│         Press key or ESC to cancel    │
└───────────────────────────────────────┘
    ↓
User presses 'N' (with or without modifier)
    ↓
Action "New File" executes, popup closes
```

**Key behavior:**

- Shortcut menus are **registered by modules** — each module can contribute one or more shortcut menus
- Follow-up keys are **single keys** — no modifier required inside the popup (but the modifiers SHIFT-CMD/CTRL are tolerated, so selection can following without releasing the modifiers)
- The shortcut popup shows categorized actions with their keybindings

### 11.5 Component-Specific Shortcuts

When a shortcut targets a component (e.g., `Cmd+S`), it applies to the **focused UI copy** of that component, not necessarily the main component. The distinction matters for:

- **Save** — saves the document regardless of which UI copy is focused (data state is shared)
- **Find** — opens find in the specific UI copy that has focus (UI state is per-copy)
- **Scroll** — affects only the focused copy's viewport

### 11.6 Shortcut Editor

The Shortcut Editor (in the Configuration tab, see §9.2) provides:

- **Full listing** of all registered shortcuts (from shell, modules, components)
- **Conflict detection** — highlights when two shortcuts use the same key combination
- **Rebinding** — click a shortcut row, then press the desired key combination
- **Reset** — restore individual or all shortcuts to defaults
- **Search/filter** — find shortcuts by action name, key, or module
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

The `.forge/` folder in the **workspace root directory** stores workspace state (layout, open editors, revisions, undo history). It should typically be added to `.gitignore`.

```
<workspace>/.forge/
  config.json           # Runtime configuration overrides (only if project-local config mode)
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
  modules/
    <module-id>/        # Per-module persistent storage
```

When using global configuration mode, configuration lives in `~/.forge/`:

```
~/.forge/
  config.json           # Global configuration overrides
  modules/
    <module-id>/        # Global per-module persistent storage
```

**Important:** Workspace-specific data (revisions, layout state, undo history) is **always** stored in `<workspace>/.forge/` — never in `~/.forge/`. The global `~/.forge/` only holds configuration and module config data.

### 12.3 File Revisioning

The shell **routes all file access** through `ForgeFileSystem`, which transparently manages revisions:

- **On save:** a revision snapshot is created automatically. Sequential identical saves (same content) do not create duplicate revisions.
- **Revision limit:** configurable (default: 50 revisions per file). Oldest revisions are pruned.
- **Viewing history:** the built-in File History view shows all revisions for a file, with diff/restore options.
- **Restore:** any revision can be restored. Restoring creates a new revision (non-destructive).

### 12.4 Undo System

Undo/redo operates at two levels:

1. **Editor-level undo** — standard text/content undo within the editor (Cmd+U / Cmd+Z for redo). This is per-editor and uses the data state's undo stack.
2. **File-level undo** — reverts to a previous file revision. Access via the File History view or command palette.

Both levels are stored in `.forge/` for persistence across sessions.

### 12.5 .forge Folder Location

Tom Forge uses one or two `.forge/` folders depending on the configuration mode chosen at startup (see §13):

| Mode | Config location | State location | Use case |
|------|----------------|----------------|----------|
| **Local** (default) | `<workspace>/.forge/config/` | `<workspace>/.forge/` | Everything in one place; simplest setup; config travels with the project |
| **Split** | `~/.forge/config/` | `<workspace>/.forge/` | Shared configuration across workspaces; workspace state is always local |

In both modes, **workspace state** (revisions, layout, open editors, undo history, module data) is **always** stored in `<workspace>/.forge/`. There is no per-workspace hash directory — state lives directly in the workspace folder.

The `<workspace>/.forge/` folder should typically be added to `.gitignore` (Tom Forge suggests this during initialization). The `~/.forge/` directory, when used, contains only global configuration — never workspace state.

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
│  ● Local (.forge/ in workspace)   ○ Split (~/.forge)    │
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

| Option | Config location | State location | Description |
|--------|----------------|----------------|-------------|
| **Local** | `<workspace>/.forge/config/` | `<workspace>/.forge/` | Default. Config + state live together in the workspace. Good for teams or project-specific setups. |
| **Split** | `~/.forge/config/` | `<workspace>/.forge/` | Config is shared across workspaces. Workspace state (revisions, layout, undo) is always local. |

**Default:** Local (everything in `<workspace>/.forge/`) on first launch. If `~/.forge/config/` already exists, the dialog switches the default to Split.

### 13.4 Remembered Preferences

The shell stores these values in **platform application preferences** (not in `.forge/`, since `.forge/` hasn't been resolved yet at startup time):

```dart
class ForgeStartupPreferences {
  /// Last opened workspace directory.
  String? lastWorkspacePath;

  /// Configuration mode for the last workspace.
  /// 'local' | 'split'
  String? lastConfigMode;

  /// Whether to skip the dialog and use remembered settings.
  bool rememberSettings;

  /// Recent workspace paths (most recent first, max 10).
  /// Shown in the startup dialog for quick re-opening.
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
User confirms or changes workspace + config mode
  ↓
Save updated preferences (add workspace to recentWorkspaces)
  ↓
Initialize ForgeFolderManager with chosen paths
  ↓
┌─ .forge/ folder exists at workspace?
│   YES → Load existing config, state, revisions
│   NO  → Create .forge/ folder structure
│         Suggest adding .forge/ to .gitignore
└─
  ↓
Activate modules, build shell, render
```

### 13.6 Command-Line Override

The startup dialog can be bypassed via command-line arguments:

```
tom_forge --workspace /path/to/project
tom_forge --workspace /path/to/project --config local
tom_forge --workspace /path/to/project --config split
```

When `--workspace` is provided, the dialog is skipped and the shell opens directly. If `--config` is omitted, the remembered preference for that workspace is used (or `local` as fallback).

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
  // Define modules
  final formEditorModule = TomFormEditorModule();
  final flowEditorModule = TomFlowEditorModule();

  final shell = TomForgeShell(
    workspace: Directory.current,
    modules: [formEditorModule, flowEditorModule],
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

### 16.1b Example, user version

```dart
void main() {
  // Define modules
  final shellModule = TomForgeShellModule();
  final formEditorModule = TomFormEditorModule();
  final flowEditorModule = TomFlowEditorModule();
  final dartEditorModule = DartEditorModule();
  final worktrackerModule = WorktrackerModule();

  final shell = TomForgeShell(
    workspace: Directory.current,
    modules: [shellModule, formEditorModule, flowEditorModule,dartEditorModule,worktrackerModule],
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
                  shellModule.explorer,
                  shellModule.outline,
                ],
              ),
              PanelTabConfig(
                title: 'Search',
                icon: Icons.search,
                sections: [
                  shellModule.search,
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
                  shellModule.properties,
                  shellModule.history,
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
                  shellModule.terminal,
                ],
              ),
              PanelTabConfig(
                title: 'Output',
                icon: Icons.output,
                sections: [
                  shellModule.output,
                  shellModule.problems,
                ],
              ),
            ],
          ),
          middlePanels: [
            MiddlePanelConfig(
              flex: 1,
              tabs: [
                MiddleTabConfig(
                  flowEditorModule.queueEditor,
                  uri: Uri.file('example.queue.yaml'),
                ),
              ],
            ),
          ],
        ),
      ),
      dartEditorModule.d4rtScriptingApplication,
      worktrackerModule.worktrackerApplication,
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
      modules/
        forge_module.dart           # Module base class
        module_registry.dart        # Module lifecycle and cross-references
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
        notification_manager.dart   # Toast notifications with action buttons
        progress_manager.dart       # Progress indicators (status bar / overlay)
        dialog_manager.dart         # Quick pick, input box, file dialogs
        terminal_manager.dart       # Terminal instance lifecycle and I/O
        clipboard_service.dart      # System clipboard read/write
        environment_service.dart    # App info, open external URIs
        module_storage.dart         # Per-module key-value persistence
        diagnostic_manager.dart     # Diagnostic collection management
        output_channel_manager.dart # Output channel creation and lifecycle
        file_association_registry.dart # File pattern → editor mapping
        status_bar_controller.dart  # Status bar item registration and updates
      config/
        forge_config.dart           # ForgeConfig, AutoSaveConfig, etc.
        config_views/
          general_config_view.dart
          menu_config_view.dart
          shortcut_config_view.dart
          module_config_view.dart
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
        notifications_view.dart
```

### 17.2 State Management

- **Shell state:** `ForgeShellController` (a `ChangeNotifier`) manages the overall layout, active application, panel sizes, and component placement
- **System state:** `ForgeSystemState` provides reactive access to focus, editors, selection, diagnostics, and more. Used by actions, menus, and modules.
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

### Phase 4 — Module System and Actions

- `ForgeModule` contract and lifecycle (activate/deactivate)
- `ForgeShellApi` implementation
- Action registry and menu population
- Context menus based on system state
- Module cross-references

### Phase 5 — Shortcuts and Configuration

- Two-key shortcut system with trigger key popup
- Primary modifier shortcuts (Cmd+P, Cmd+S, etc.)
- Shortcut manager with conflict detection
- Configuration tab with all config views (general, menu, shortcuts, modules, layout, file types)
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
