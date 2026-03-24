# Tom Forge Panel Shell — Concept Document

**Project:** tom_forge_ui  
**Component:** Panel Shell Framework  
**Date:** 2026-03-24  
**Status:** Concept

---

## 1. Overview

The Tom Forge Panel Shell is a desktop-optimized, multi-panel application framework for composing visual development tools. It provides a VS Code-inspired window layout with workspaces, editors, views, and configurable panel arrangements — all within a single Flutter window.

The framework lives in `tom_forge_ui` (library) with a test/demo application in `tom_forge_app`.

### Design Principles

- **Single window, multi-workspace** — workspaces switch via a dropdown, not separate windows
- **Component-based** — editors and views are self-contained widgets that plug into the shell
- **Drag-and-drop layout** — users rearrange components freely between panels
- **State sharing** — two instances of the same view share state; two editors with the same URI share state
- **Code-configured** — initial layout is declarative in Dart; runtime changes persist

---

## 2. Window Structure

```
┌─────────────────────────────────────────────────────────────────────┐
│  ◀ ▶   │          🔍 Workspace Title                │ [Workspace ▾]│  Title Bar
├────┬────────────────────────────────────────────────────────┬───────┤
│    │                                                        │       │
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
│    │   └────────────────────────────────────────────────────┘       │
├────┴────────────────────────────────────────────────────────┴───────┤
│  Status Line: context-sensitive information                         │  Status Bar
└─────────────────────────────────────────────────────────────────────┘
```

### 2.1 Title Bar

| Element | Position | Behavior |
|---------|----------|----------|
| **Back / Forward arrows** | Left | Navigate history for components that support it (e.g., browser views, help panels). Disabled when the focused component has no history. |
| **Search field** | Center | Displays the workspace title centered with a search-lens icon prefix. Tapping activates search mode (command palette style). The field serves dual purpose: workspace title display and quick search/command entry. |
| **Workspace dropdown** | Right of search | Dropdown selector to switch between configured workspaces. Shows the current workspace name. |

### 2.2 Left Panel (Multipanel)

- **Position:** Left edge, full height between title bar and status bar
- **Width:** User-adjustable via drag handle on the right edge
- **Tabs:** Vertical icon strip on the left edge; clicking an icon activates that tab
- **Tab content:** Accordeon structure with collapsible sections (see §3)
- **Tab management:** "+" button at the bottom of the icon strip to add tabs (user picks icon + title)

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

| Type | Closable | Duplicable | State Sharing | Primary Location |
|------|----------|------------|---------------|------------------|
| **Editor** | Yes (× button) | Yes (same URI = shared state) | By URI | Middle panels |
| **View** | No | Yes (same type = shared state) | By type | Left / right / bottom panels |

### 4.2 Component Identity

- **Editors** are identified by a **URI** (`Uri`). The URI can represent a file path, a virtual resource, or any addressable entity. Two editor instances with the same URI share the same controller/state.
- **Views** are identified by their **type** (Dart `Type`). Only one logical instance exists per view type. If displayed in multiple locations, all instances reflect the same state.

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
}
```

### 4.4 Component Registration

Components are registered with the application so the shell knows what's available:

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

## 6. Workspace Model

### 6.1 Structure

```dart
class TomForgeApplication {
  /// All workspaces available in this application.
  final List<TomWorkspace> workspaces;

  /// Global component registry.
  final ForgeComponentRegistry registry;

  /// Application-level status bar items.
  final List<StatusBarItem> globalStatusItems;
}

class TomWorkspace {
  /// Display title (shown in search bar and workspace dropdown).
  final String title;

  /// Icon for the workspace dropdown.
  final IconData? icon;

  /// Components available in this workspace.
  final List<ForgeComponentDescriptor> components;

  /// Initial layout configuration.
  final WorkspaceLayout layout;
}

class WorkspaceLayout {
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

### 6.2 Workspace Switching

- Switching workspaces replaces the entire panel layout
- Each workspace maintains its own layout state independently
- Editors with unsaved changes prompt before workspace switch
- Workspace state is preserved when switching away and restored when switching back

---

## 7. Built-In Views

### 7.1 Initial Implementation (v1)

These views ship with the panel shell framework:

| View | Type ID | Description | Default Panel |
|------|---------|-------------|---------------|
| **Terminal** | `forge.terminal` | Embedded terminal emulator (pty-based on desktop). Multiple terminal instances managed as tabs within the view. | Bottom |
| **Output** | `forge.output` | Read-only text output channel. Components can write to named output channels (dropdown to select channel). Shows timestamped, scrollable log output. | Bottom |
| **Problems** | `forge.problems` | Aggregated diagnostics list (errors, warnings, info). Components register problem providers. Click-to-navigate to source location. Filterable by severity and source. | Bottom |
| **Explorer** | `forge.explorer` | File/resource tree browser. Shows workspace files, supports open/rename/delete. Double-click opens in editor. | Left |
| **Search** | `forge.search` | Full-text search across workspace files. Shows results grouped by file with match highlighting. Click navigates to match. | Left |
| **Outline** | `forge.outline` | Structural outline of the active editor's content (sections, classes, functions — editor-dependent). Follows focus. Click navigates within the editor. | Left |

### 7.2 Suggested for Later

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

### 7.3 View Responsibilities

Each built-in view is a self-contained package-level widget. The panel shell provides:

- **View host:** wraps the view widget, provides the accordeon section header, handles drag
- **Service locator:** views access shared services (file system, diagnostics, terminal manager) via the `ForgeServices` provider
- **Focus tracking:** the shell notifies views when the active editor changes (for outline, properties, etc.)

---

## 8. Status Bar

### 8.1 Structure

```
┌──────────────────────────────────────────────────────────────────────┐
│ ⚡ Ready  │  main ↗  │  Ln 42, Col 17  │  UTF-8  │  Dart  │  2 ⚠  │
└──────────────────────────────────────────────────────────────────────┘
 ← global items →       ← active component items →        ← global →
```

### 8.2 Status Bar Items

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

- **Global items:** contributed by the application (connection status, workspace info, problem count)
- **Component items:** contributed by the focused component (cursor position, file encoding, language)
- Items are reactive — they update via `ValueNotifier` or stream

---

## 9. Configuration API

### 9.1 Application Setup (Code-Configured)

```dart
void main() {
  final app = TomForgeApplication(
    workspaces: [
      TomWorkspace(
        title: 'Tom Flow',
        layout: WorkspaceLayout(
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
          rightPanel: PanelConfig(initialSize: 0, tabs: []),
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
                  componentTypeId: 'forge.flow_editor',
                  uri: Uri.file('example.queue.yaml'),
                ),
              ],
            ),
          ],
        ),
      ),
      TomWorkspace(title: 'Tom D4rt Scripting'),
      TomWorkspace(title: 'Tom Worktracker'),
    ],
  );

  runApp(TomForgeShellApp(application: app));
}
```

### 9.2 Layout Persistence

- Layout changes (panel sizes, component positions, tab order) are persisted per workspace
- Storage: JSON file in the application's data directory
- On startup: load persisted layout; fall back to code-configured defaults
- Reset option: restore to code-configured defaults

---

## 10. Implementation Architecture

### 10.1 Package Structure

```
tom_forge_ui/
  lib/
    tom_forge_ui.dart               # Barrel export
    src/
      shell/
        forge_shell.dart            # Top-level shell widget
        title_bar.dart              # Title bar with nav, search, workspace dropdown
        status_bar.dart             # Status bar
        workspace_switcher.dart     # Workspace dropdown + switch logic
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
        component_state.dart        # Shared state management (by URI / by type)
      models/
        application_model.dart      # TomForgeApplication, TomWorkspace
        layout_model.dart           # PanelConfig, TabConfig, etc.
        status_bar_model.dart       # StatusBarItem
      services/
        layout_persistence.dart     # Save/load layout state
        focus_service.dart          # Track active component, notify listeners
        history_service.dart        # Back/forward navigation per component
      views/                        # Built-in views
        terminal_view.dart
        output_view.dart
        problems_view.dart
        explorer_view.dart
        search_view.dart
        outline_view.dart
```

### 10.2 State Management

- **Shell state:** `ForgeShellController` (a `ChangeNotifier`) manages the overall layout, active workspace, panel sizes, and component placement
- **Component state:** Each component type manages its own state internally. The shell provides a `ForgeComponentStateManager` that maps URIs/types to shared state objects.
- **Reactive updates:** `ValueListenable` pattern consistent with other Tom Forge components

### 10.3 Widget Tree (Simplified)

```
TomForgeShellApp
 └─ MaterialApp
     └─ ForgeShell (controller: ForgeShellController)
         ├─ TitleBar
         │   ├─ NavButtons (◀ ▶)
         │   ├─ SearchTitleField
         │   └─ WorkspaceDropdown
         ├─ Row
         │   ├─ LeftPanelHost (resizable width)
         │   │   ├─ IconTabBar (vertical)
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
         └─ StatusBar
```

### 10.4 Debug Mode

Per Tom Forge convention, the panel shell implements trail-based debug mode:

- Flag: `kForgeShellDebug`
- Prefix: `[FS]`
- Trail file: `lib/src/shell/shell_trail.dart`
- Events: layout changes, drag operations, workspace switches, component focus changes

---

## 11. Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+Shift+P` | Open command palette (search field) |
| `Cmd+B` | Toggle left panel visibility |
| `Cmd+J` | Toggle bottom panel visibility |
| `Cmd+Shift+B` | Toggle right panel visibility |
| `Cmd+1/2/3/4` | Focus middle panel 1/2/3/4 |
| `Cmd+W` | Close active editor tab |
| `Cmd+Shift+T` | Reopen last closed editor |
| `Cmd+[` / `Cmd+]` | Navigate back / forward |
| `Cmd+Tab` | Cycle through open editors |
| `` Ctrl+` `` | Focus terminal view |

---

## 12. Implementation Phases

### Phase 1 — Shell Skeleton

- `ForgeShell` widget with title bar, status bar, panel areas
- Resizable dividers between all panels
- Basic `TomWorkspace` and `TomForgeApplication` models
- Workspace dropdown (switch workspaces, layout resets)
- Middle panels with tab bar (1–4 panels, split/merge)
- Placeholder components for testing layout

### Phase 2 — Accordeon Panels

- Left/right/bottom panels with tab + accordeon structure
- Collapsible sections with mutual exclusion and pinning
- Size hint system (min/preferred/max)
- Bottom panel vertical text for collapsed sections
- "+" button for adding new tabs

### Phase 3 — Component Framework

- `ForgeComponent` contract and `ForgeComponentRegistry`
- Component host wrapper with drag handles
- State sharing by URI (editors) and by type (views)
- Focus tracking service

### Phase 4 — Drag and Drop

- Drag components between accordeon sections
- Drag components into middle panel tab bars
- Drag to split middle panels (drop zone overlay)
- Drag entire tabs between left/right/bottom panels

### Phase 5 — Built-In Views

- Terminal view (pty integration)
- Output view (channel-based log viewer)
- Problems view (diagnostic aggregator)
- Explorer view (file tree)
- Search view (text search)
- Outline view (active editor structure)

### Phase 6 — Persistence and Polish

- Layout persistence (JSON save/load per workspace)
- Keyboard shortcuts
- Animation for panel transitions
- Accessibility (screen reader support, high contrast)
- Debug trail integration
