# Tom Forge Panel Shell — Concept Document

**Project:** tom_forge_ui  
**Component:** Panel Shell Framework  
**Date:** 2026-03-24  
**Status:** Concept (v6 — API completeness: decorations, multi-selection, workspace edit, virtual docs, outline, search, secrets)  
**Companion:** [Implementation Specification](forge_panel_shell_spec.md) — widget details, error handling, performance, accessibility, persistence formats, test strategy

---

## 1. Overview

The Tom Forge Panel Shell is a desktop-optimized, multi-panel application framework for composing visual development tools. It provides a familiar IDE-style window layout with applications, editors, views, and configurable panel arrangements — all within a single Flutter application.

The framework lives in `tom_forge_ui` (library) with a test/demo application in `tom_forge_app`.

### Terminology

| Term | Definition |
|------|-----------|
| **Workspace** | The root folder opened by the user. Contains source files, configuration, and a `.forge/` folder for state and file revisions. |
| **Application** | A named arrangement of panels, components, and shortcuts. References components from modules. Multiple applications can be open simultaneously. Switching between applications keeps the previous one alive in memory. |
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
- **Object-oriented API** — no string IDs, no registries, no indirect lookups. Components are direct typed class members on modules; actions, views, editors are all referenced as Dart objects. The Dart type system (`is`, generics) replaces string-based identity throughout

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

Components in accordeon sections provide size hints as explicit width/height pairs (in logical pixels):

```dart
class ForgeComponentSizeHints {
  /// Minimum size the component needs to be functional.
  final Size minSize;

  /// Preferred size for comfortable display.
  final Size preferredSize;

  /// Maximum useful size (beyond this, extra space is wasted).
  final Size maxSize;

  const ForgeComponentSizeHints({
    this.minSize = const Size(120, 80),
    this.preferredSize = const Size(260, 200),
    this.maxSize = const Size(double.infinity, double.infinity),
  });
}
```

- `minSize` — the accordeon will not shrink a section below this width/height
- `preferredSize` — used for initial/equilibrium sizing when multiple sections share space
- `maxSize` — extra space beyond this is allocated to other sections
- The shell uses the **height** component for left/right panels (vertical accordeon) and the **width** component for the bottom panel (horizontal flow). Both dimensions are available so the layout engine can make informed decisions regardless of orientation.

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

Every component implements `ForgeComponent`. Components are accessed as **direct typed members** on their owning module — there are no string IDs or type registries. The shell interacts with components through this interface:

```dart
abstract class ForgeComponent {
  /// Display title for tabs and headers. Observable — the shell
  /// re-renders the tab/header when this changes.
  ValueListenable<String> get title;

  /// Optional subtitle shown in small font under accordeon titles.
  ValueListenable<String?> get titleExtension;

  /// Icon for tab display.
  IconData get icon;

  /// Whether this is an editor (closable) or a view.
  bool get isEditor;

  /// Size hints for accordeon layout.
  ForgeComponentSizeHints get sizeHints;

  /// Whether this component supports multi-render (UI copies).
  /// Default: true. Set to false for components that cannot be rendered
  /// in parallel (e.g., terminal emulator with exclusive pty).
  bool get supportsMultiRender => true;

  /// Create the Flutter widget for the main component instance.
  /// Called once when the component is first placed in the layout.
  Widget buildMain(BuildContext context);

  /// Create a Flutter widget for a UI copy (multi-render).
  /// Each call returns an independent UI copy that shares data state
  /// with the main widget but has its own scroll position, selection, etc.
  Widget buildCopy(BuildContext context);

  /// Actions this component contributes to the menu and command palette.
  List<ForgeAction> get actions => [];

  /// Shortcut bindings this component contributes when focused.
  List<ForgeShortcutBinding> get shortcuts => [];

  /// The owning module (set by the module during initialization).
  ForgeModule get module;
}
```

#### ForgeEditor (extends ForgeComponent)

Editors are file-bound components identified by URI. The base class provides the minimal contract every editor shares — file association, dirty tracking, and two-phase file resolution. Specialized subclasses add domain-specific APIs (text manipulation, visual canvas, schema delegation):

```dart
abstract class ForgeEditor extends ForgeComponent {
  @override
  bool get isEditor => true;

  /// The URI this editor is associated with.
  Uri get uri;

  /// Phase 1: Whether this editor can handle the given URI based on
  /// extension or path alone. Must be fast — no file I/O.
  /// Return `accept` to claim the file, `reject` to skip,
  /// or `inspect` to request a Phase 2 content inspection.
  FileHandlingResult canHandle(Uri uri);

  /// Phase 2: Called only when `canHandle()` returned `inspect`.
  /// The editor receives the raw file bytes and can make a final
  /// accept/reject decision based on content (e.g., YAML schema
  /// comments, magic bytes, file structure). Default: accept.
  FileHandlingResult canHandleContent(Uri uri, Uint8List bytes) =>
      FileHandlingResult.accept;

  /// Whether this editor has unsaved changes.
  ValueListenable<bool> get isDirty;

  /// The component's history manager for back/forward navigation.
  /// Null if the component does not support history.
  ComponentHistoryManager? get historyManager;
}

/// Result of a file handling check (Phase 1 or Phase 2).
enum FileHandlingResult {
  /// The editor accepts this file.
  accept,

  /// The editor cannot handle this file.
  reject,

  /// The editor needs to inspect the file content before deciding
  /// (Phase 1 only — triggers a Phase 2 call).
  inspect,
}
```

#### ForgeTextEditor (extends ForgeEditor)

Text-based editors that provide document access, text selection, cursor positioning, and text manipulation. Most traditional editors (code, YAML, markdown, JSON) extend this:

```dart
abstract class ForgeTextEditor extends ForgeEditor {
  /// The document model backing this editor.
  ForgeDocument get document;

  /// The current cursor position (line, column).
  ValueListenable<TextPosition> get cursorPosition;

  /// The current text selection range. Null when no selection.
  ValueListenable<TextRange?> get selection;

  /// All current selections (for multi-cursor editing).
  /// Contains at least one entry when the editor is active.
  ValueListenable<List<TextRange>> get selections;

  /// Set multiple selections (multi-cursor).
  void setSelections(List<TextRange> ranges);

  /// The currently selected text content. Empty string when no selection.
  String get selectedText;

  /// Whether there is a non-empty text selection.
  bool get hasSelection;

  /// The currently visible text range (what the user can see).
  /// Changes on scroll. Useful for scroll-aware features like
  /// virtual rendering, minimap sync, and lazy decoration.
  ValueListenable<TextRange> get visibleRange;

  /// Replace the current selection with the given text.
  /// If no selection, inserts at the cursor position.
  void insertText(String text);

  /// Replace text in the given range.
  void replaceRange(TextRange range, String replacement);

  /// Delete text in the given range.
  void deleteRange(TextRange range);

  /// Set the cursor position.
  void setCursorPosition(TextPosition position);

  /// Set the selection range.
  void setSelection(TextRange range);

  /// Select all text.
  void selectAll();

  /// Reveal the given position by scrolling to it.
  void revealPosition(TextPosition position);

  /// Reveal the given range by scrolling to make it visible.
  void revealRange(TextRange range);

  /// Find occurrences of a pattern in the document.
  List<TextRange> findAll(Pattern pattern);

  /// Replace all occurrences of a pattern.
  int replaceAll(Pattern pattern, String replacement);

  /// Per-editor options (tab size, insert spaces, word wrap).
  /// Overrides global defaults for this editor instance.
  ForgeTextEditorOptions get options;

  /// Update per-editor options.
  void updateOptions(ForgeTextEditorOptions options);

  /// Apply decorations to ranges in this editor. Decorations are
  /// visual markers — error underlines, search highlights, git diff
  /// markers, breakpoint icons, etc. Each decoration type is keyed
  /// so modules can update/clear their own decorations independently.
  void setDecorations(ForgeDecorationType type, List<ForgeDecorationRange> ranges);

  /// Remove all decorations of the given type from this editor.
  void clearDecorations(ForgeDecorationType type);
}

/// The document model for a text editor. Represents the file content
/// as a structured text buffer with line-level access.
abstract class ForgeDocument {
  /// The document's URI.
  Uri get uri;

  /// The full text content.
  String get text;

  /// The number of lines.
  int get lineCount;

  /// Get the text of a specific line (0-based).
  String lineAt(int line);

  /// Get the text in a range.
  String textInRange(TextRange range);

  /// The language or file type identifier (e.g., 'dart', 'yaml').
  String get languageId;

  /// The file's encoding.
  Encoding get encoding;

  /// Document version counter. Increments on each edit.
  /// Useful for detecting stale references and concurrent modifications.
  int get version;

  /// Whether this document has never been saved to disk ("untitled").
  bool get isUntitled;

  /// Whether the document has been modified since last save.
  ValueListenable<bool> get isDirty;

  /// Fires when the document content changes.
  Stream<DocumentChangeEvent> get onDidChange;
}

class TextPosition {
  /// 0-based line number.
  final int line;

  /// 0-based column offset.
  final int column;

  const TextPosition({required this.line, required this.column});
}

class TextRange {
  final TextPosition start;
  final TextPosition end;

  const TextRange({required this.start, required this.end});

  bool get isEmpty => start == end;
}

class DocumentChangeEvent {
  /// The ranges that were changed.
  final List<TextRange> changes;

  /// The document after the change.
  final ForgeDocument document;
}

/// Per-editor options that override global defaults.
class ForgeTextEditorOptions {
  /// Number of spaces per tab. Null = use global default.
  final int? tabSize;

  /// Whether to insert spaces instead of tab characters.
  final bool? insertSpaces;

  /// Word wrap mode.
  final ForgeWordWrap? wordWrap;
}

enum ForgeWordWrap { off, on, wordWrapColumn, bounded }

/// A decoration type created by a module for visual markers.
/// Each type defines the visual style; instances are applied to
/// ranges via `ForgeTextEditor.setDecorations()`.
class ForgeDecorationType {
  /// Unique key for this decoration type (used to update/clear).
  final String key;

  /// Background color for decorated ranges.
  final Color? backgroundColor;

  /// Border style for decorated ranges.
  final ForgeBorderStyle? border;

  /// Text style override for decorated ranges.
  final TextStyle? textStyle;

  /// Underline style (e.g., wavy for errors, dotted for warnings).
  final ForgeUnderlineStyle? underlineStyle;

  /// Underline color.
  final Color? underlineColor;

  /// Gutter icon (margin decoration).
  final IconData? gutterIcon;

  /// Gutter icon color.
  final Color? gutterIconColor;

  /// Whether to render in the overview ruler (scrollbar minimap).
  final bool overviewRuler;

  /// Overview ruler color.
  final Color? overviewRulerColor;
}

enum ForgeUnderlineStyle { solid, dotted, dashed, wavy }

class ForgeBorderStyle {
  final Color color;
  final double width;
  final BorderRadius? borderRadius;
}

/// A range with a decoration applied to it.
class ForgeDecorationRange {
  final TextRange range;

  /// Optional hover message shown when the cursor is over this range.
  final String? hoverMessage;
}
```

#### ForgeVisualEditor (extends ForgeEditor)

Canvas-based editors for visual content — flow diagrams, form layouts, node graphs. Provides element selection and viewport control instead of text manipulation:

```dart
abstract class ForgeVisualEditor extends ForgeEditor {
  /// The currently selected elements on the canvas.
  ValueListenable<List<Object>> get selectedElements;

  /// Whether any element is currently selected.
  bool get hasElementSelection;

  /// Select elements programmatically.
  void selectElements(List<Object> elements);

  /// Clear the current selection.
  void clearSelection();

  /// The current viewport (visible area of the canvas).
  ValueListenable<Rect> get viewport;

  /// Pan/zoom to reveal a specific area.
  void revealArea(Rect area);

  /// Zoom to fit all content in the viewport.
  void zoomToFit();

  /// The current zoom level (1.0 = 100%).
  ValueListenable<double> get zoomLevel;

  /// Set the zoom level.
  void setZoom(double level);
}
```

#### ForgeSchemaEditor (extends ForgeEditor)

Schema editors inspect a file's content to determine which schema or editing mode to apply. They always return `inspect` from `canHandle()` because their decision depends on content, not just the URI. In the "Open with" dialog, schema editors appear in an **Additional Options** section because they require content inspection to decide:

```dart
abstract class ForgeSchemaEditor extends ForgeEditor {
  /// Always returns `inspect` — schema editors need file content
  /// to determine whether they can handle the file.
  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.inspect;

  /// Inspect the file content and determine whether this schema
  /// editor can handle it. Typically checks for:
  /// - A schema comment (e.g., `# schema: form-v2` in YAML)
  /// - A specific structure or root key
  /// - Magic bytes or file signature
  @override
  FileHandlingResult canHandleContent(Uri uri, Uint8List bytes);

  /// The schema identifier this editor handles (for display purposes).
  /// Shown in the "Open with" dialog's Additional Options section.
  String get schemaLabel;
}
```

#### ForgeView (extends ForgeComponent)

Views are singleton components identified by their Dart type:

```dart
abstract class ForgeView extends ForgeComponent {
  @override
  bool get isEditor => false;
}
```

#### ComponentHistoryManager

Components that support back/forward navigation (e.g., help browser, documentation viewer) expose a history manager. The shell's title bar back/forward arrows delegate to this:

```dart
abstract class ComponentHistoryManager {
  /// Whether back navigation is available.
  ValueListenable<bool> get canGoBack;

  /// Whether forward navigation is available.
  ValueListenable<bool> get canGoForward;

  /// Navigate back. Updates the component's content and title.
  void goBack();

  /// Navigate forward.
  void goForward();

  /// The current history entry's label (for tooltip on nav buttons).
  String get currentLabel;
}
```

### 4.4 Component Ownership and Access

Components are **owned by modules** and exposed as **direct typed members** on the module class. There is no global component registry and no string-based lookup. The shell discovers components through the modules it is configured with.

**Key rules:**

- Every component belongs to exactly one module
- Modules expose their components as typed `late final` members (see §8.3)
- Layout configuration references these members directly: `shellModule.explorer`, `flowEditorModule.flowEditor`
- The shell itself is a module (`TomForgeShellModule`) that owns the built-in views (Explorer, Output, Problems, Terminal, etc.)
- When the shell needs to open a file, it runs the two-phase file resolution process (see §10.4) — editors claim files via `canHandle(uri)` and optionally `canHandleContent(uri, bytes)`

```dart
// No registry needed — layout config references module members directly:
PanelTabConfig(
  title: 'Explorer',
  icon: Icons.folder,
  sections: [shellModule.explorer, shellModule.outline],
)
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

  /// All modules compiled into this shell. Modules own components
  /// and expose them as typed members.
  final List<ForgeModule> modules;

  /// All applications available in this shell. Applications are
  /// layout configuration structures — they reference components
  /// from modules but do not own or provide components themselves.
  final List<ForgeApplication> applications;

  /// Global configuration defaults.
  final ForgeConfig config;

  /// The .forge folder manager (uses configDirectory).
  final ForgeFolderManager forgeFolder;

  /// System state controller.
  final ForgeSystemState systemState;
}

class ForgeApplication {
  /// Stable identity: per-application state and persistence are keyed by it.
  final String id;

  /// Display title (shown in the switcher); changed through
  /// `ForgeApplicationRegistry.rename`.
  String get title;

  /// Icon for the application dropdown.
  final IconData? icon;

  /// Layout configuration referencing components from modules.
  /// Components are referenced directly as typed objects, not by string ID.
  final ApplicationLayout layout;

  /// The factory kind that recreates this application at the next start,
  /// or null for a static application its module adds on every start.
  final String? kind;

  /// What the factory needs to recreate it (e.g. a quest id).
  final Map<String, Object?> payload;

  /// Hooks as it comes and goes, and what it reports while it runs.
  final ForgeApplicationLifecycle lifecycle;

  /// Actions, shortcuts, status-bar items and context-menu entries bound
  /// while it is the active application.
  final ForgeApplicationContributions contributions;

  /// Whether this application is currently active (visible).
  bool get isActive;
}

/// Called by the registry in this order: created, activated / deactivated as
/// it is switched, closing (null allows; a reason vetoes and the shell asks
/// the user), deactivated if it was active, closed. Defaults do nothing.
class ForgeApplicationLifecycle {
  void created(ForgeApplication application);
  void activated(ForgeApplication application);
  void deactivated(ForgeApplication application);
  Future<String?> closing(ForgeApplication application);
  void closed(ForgeApplication application);
  /// While true its state is never evicted from memory.
  ValueListenable<bool> get hasBackgroundWork;
  /// The switcher's badge for it ("Queue running"), or null.
  ValueListenable<String?> get busy;
}

/// The application a factory is making: id, kind, payload, the application
/// once registered and whether it is active. Views, editors and actions made
/// for an application are bound to it.
class ForgeApplicationContext {
  final String id;
  final String kind;
  final Map<String, Object?> payload;
  ForgeApplication? get application;
  bool get isActive;
  ValueListenable<List<ForgeApplication>> get registry;
}

/// Makes the applications of one kind, at run time and at restore.
abstract class ForgeApplicationFactory {
  String get kind;
  ForgeApplication create(ForgeApplicationContext context, String title);
}

/// `ForgeShellApi.applications`: the open applications and the active one.
abstract class ForgeApplicationRegistry {
  ValueListenable<List<ForgeApplication>> get listenable;
  List<ForgeApplication> get all;
  ForgeApplication? get active;
  void registerFactory(ForgeApplicationFactory factory);
  void add(ForgeApplication application, {bool activate = false});
  ForgeApplication open(String kind, {required String title,
      Map<String, Object?> payload = const {}, bool activate = true});
  void rename(String id, String title);
  ForgeCloseConfirmer? confirmClose;   // set by the shell: asks on a veto
  Future<bool> close(String id);      // the last application cannot be closed
  void activate(String id);
  Map<String, Object?> snapshot();
  void restore(Map<String, Object?> snapshot);
}

/// How an application fills the content area between the title bar (with the
/// application switcher) and the status bar.
sealed class ApplicationLayout {}

/// The panel shell: side, bottom and middle (editor) panels.
class PanelLayout extends ApplicationLayout {
  final PanelConfig leftPanel;
  final PanelConfig rightPanel;
  final PanelConfig bottomPanel;
  final List<MiddlePanelConfig> middlePanels;
}

/// One view filling the content area: no panels and no in-window menu bar.
/// The view runs in its own focus scope; keys it does not handle reach the
/// shell's global shortcuts and command palette.
class FullScreenLayout extends ApplicationLayout {
  final ForgeView view;
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
  /// Each section is a direct reference to a ForgeView from a module.
  final List<ForgeView> sections;
}

class MiddlePanelConfig {
  /// Initial flex factor for horizontal space distribution.
  final double flex;

  /// Editor tabs in this middle panel.
  final List<MiddleTabConfig> tabs;
}

class MiddleTabConfig {
  /// Direct reference to an editor component from a module.
  final ForgeEditor editor;

  /// The URI to open in this editor.
  final Uri? uri;

  MiddleTabConfig(this.editor, {this.uri});
}
```

**Design note:** Applications are purely **structural/layout elements** in the shell configuration. All components come from modules. An application's layout references module members directly — e.g., `shellModule.explorer` for the Explorer view or `flowEditorModule.flowEditor` for the flow editor. Modules can also expose pre-configured `ForgeApplication` instances (e.g., `dartEditorModule.d4rtScriptingApplication`) so the top-level setup stays clean.

### 6.3 Application Switching

- The shell owns the applications: the scaffold shows whichever application `shell.applications` has active and follows the registry as applications are added, renamed, removed and activated — from the switcher or from code. A host builds the scaffold with the shell only.
- Applications come and go at run time. A module registers a `ForgeApplicationFactory` per kind and opens applications of it with `shell.applications.open(kind, title:, payload:)`; several of one kind may be open, told apart by their ids. Closing the active application activates the one active before it; the last application cannot be closed.
- Two applications of one kind show the same views bound to different contexts: the factory gets a `ForgeApplicationContext` per application and makes that application's view, editor and action instances for it (a PROCESS view per quest application, each showing its quest).
- An application's `contributions` (`ForgeApplicationContributions`: actions, shortcuts, status-bar items, context-menu entries) follow the active application: the shell binds the active one's actions and shortcuts and unbinds the previous one's, the status bar shows its items and the context menu its entries. Two applications of one kind contribute the same action ids, so a keystroke or `executeAction` runs the action of the application on show. An application action id a module already registers is not bound, and the collision is reported as a Flutter error.
- Each panel application has its own layout: the middle editor groups with their editors, the active group, the panels' sizes and visibility, and the side panels' active tabs and accordion sections are kept for it while another application is shown and put back when it is shown again. An application shown for the first time gets its `PanelLayout`'s declared middle groups with their editors opened and its declared panel sizes; the first application adopts the layout the shell has and opens its declared editors into it. A full-screen application leaves the panel layout to the panel application shown last.
- An application's `ForgeApplicationLifecycle` hears created, activated, deactivated, closing and closed, in that order. `closing` may veto with a reason; the shell then asks "Close <title>?" with the reason (Keep open / Close anyway), and without an answer the application stays. File > Close Application closes the active one. An application with background work (`hasBackgroundWork`, e.g. a quest's running queue) is never evicted from memory by the application-state limit, and its `busy` label is a badge in the switcher's list and, while another application is shown, beside the switcher. Disposing the shell tells every open application `closed`, so it releases what it holds, without removing it from the file the next start restores.
- At exit the restorable applications (those with a kind) and the active id are in `.forge/state/applications.json`, rewritten on every change and written atomically. At the next start the host adds its static applications, the modules register their factories, and `DefaultShellApi.restoreApplications()` has the factories recreate the rest and re-activates the one that was active. An entry whose kind has no factory this time is kept in the file, not lost. Per-application state (`.forge/state/apps/{hash of id}.json`) is keyed by id and deleted with the application.

- Switching applications does **not** close the previous application. All applications remain alive in memory with their full layout state preserved.
- A full-screen application's view stays in the widget tree offstage while another application is shown, with its tickers off and out of focus traversal; the panel area does the same while a full-screen application is shown. Switching back finds both as they were, and the focus returns to where it was in each.
- The system state keeps each application's open editor instances while another application is active and puts them back on the switch back; a switch neither opens nor closes an editor.
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

Menu items are **actions** (`ForgeAction`). Components and modules expose actions as typed members or lists. Each action declares which menu it belongs to. Actions are identified by their **object identity** — no string IDs:

```dart
class ForgeAction {
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

  /// Execute the action.
  /// Returns an undo object (information needed to reverse the action),
  /// or null if the action is not undoable.
  final Future<Object?> Function( Map<String,Object> parameters ) execute;

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

- `execute()` performs the action. For actions needing user input, the action itself uses `ForgeDialogManager` (via the shell API) to open quick picks, input boxes, or file dialogs.
- The return value is the **undo object** — an opaque value containing whatever information the action needs to reverse itself. If the action returns `null`, it is not added to the undo stack.
- `undo(undoInfo)` reverses the action using the previously returned undo object.
- Actions are referenced as direct objects — `formEditorModule.addFieldAction` — not looked up by string ID.
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
  /// The action to execute when this context menu item is selected.
  final ForgeAction action;

  /// When to show this item. Evaluated against current system state.
  /// Example: show "Copy" only when the focused editor has a text selection.
  final bool Function(ForgeSystemState state) isApplicable;
}
```

---

## 8. Module System

### 8.1 Concept

A **module** is an integration wrapper that brings one or more components (editors, views) into the shell, along with their actions, shortcuts, and context menu contributions. Modules are the primary organizational unit for adding functionality to Tom Forge.

Unlike VS Code extensions, Tom Forge modules are **compiled into the same Flutter application** — there is no dynamic loading, no marketplace, and no sandboxing. Modules run in the same Dart isolate as the shell and have full, type-safe access to the shell API and to each other.

**Key characteristics:**

- Modules expose their components as **direct typed class members** — e.g., `formEditorModule.formEditor`, `shellModule.explorer`
- Layout configuration references these members directly (no string IDs)
- Modules add their static `ForgeApplication`s to the registry (`shell.applications.add`) and register a factory for every kind they open at run time
- The **shell itself is a module** (`TomForgeShellModule`) that provides built-in views (Explorer, Output, Problems, Terminal, Search, Outline, etc.)
- Each module is a Dart class with a well-defined lifecycle (`activate` / `deactivate`)
- Modules for external editors (Dart editor, flow editor, etc.) will be implemented in a separate project (`tom_forge_modules`) that wraps existing editor components into shell-compatible modules

### 8.2 Module Contract

```dart
abstract class ForgeModule {
  /// Display name for the module (shown in configuration UI).
  String get displayName;

  /// Called when the module is activated. The shell reference provides
  /// full access to the shell API for initialization.
  void activate(ForgeShellApi shell);

  /// Called when the module is deactivated (shutdown).
  void deactivate();

  /// All editors this module provides. The shell uses this list to
  /// discover which editors can handle a file (via canHandle).
  List<ForgeEditor> get editors;

  /// All views this module provides.
  List<ForgeView> get views;

  /// Actions this module contributes to menus and command palette.
  /// All actions use the `<source>.<action>` naming convention (see §11.1.1).
  List<ForgeAction> get actions;

  /// Action descriptors for all actions this module provides.
  /// Descriptors are metadata-only (no handlers) — the shell uses them
  /// for shortcut binding, command palette, and the Shortcut Editor.
  /// See [editor_action_externalization.md] for the EditorActionDescriptor class.
  List<EditorActionDescriptor> get actionDescriptors => [];

  /// Shortcut bindings this module contributes.
  List<ForgeShortcutBinding> get shortcuts;

  /// Context menu contributions.
  List<ForgeContextMenuContribution> get contextMenus => [];

  /// Status bar items this module contributes.
  List<StatusBarItem> get statusBarItems => [];
}
```

**The shell itself is a module** (`TomForgeShellModule`). It exposes its own actions (`forge.commandPalette`, `forge.toggleLeftPanel`, `forge.toggleBottomPanel`, etc.) and action descriptors through the same contract as any other module. This ensures all shell shortcuts appear in the Shortcut Editor and command palette (see §11.1.2).

### 8.3 Example: Form Editor Module

Components are **direct typed members** of the module class. This makes them accessible in code-based layout configuration (see §16.1) and by other modules via type-safe cross-references.

```dart
class TomFormEditorModule extends ForgeModule {
  late final ForgeShellApi _shell;

  // --- Components as direct typed members ---

  /// The form editor (opens .form.yaml files).
  late final FormEditor formEditor;

  /// Properties view showing form field properties.
  late final FormPropertiesView propertiesView;

  @override
  String get displayName => 'Tom Form Editor';

  @override
  List<ForgeEditor> get editors => [formEditor];

  @override
  List<ForgeView> get views => [propertiesView];

  @override
  void activate(ForgeShellApi shell) {
    _shell = shell;

    // Create components as direct members
    formEditor = FormEditor(shell: shell);
    propertiesView = FormPropertiesView(shell: shell);

    // React to focus changes — update properties when form editor is focused
    shell.systemState.onFocusChanged.listen((event) {
      if (event.component is FormEditor) {
        propertiesView.showPropertiesFor(event.component as FormEditor);
      }
    });
  }

  @override
  void deactivate() {}

  @override
  List<ForgeAction> get actions => [addFieldAction];

  @override
  List<ForgeShortcutBinding> get shortcuts => [];

  /// Add a form field to the active form.
  late final addFieldAction = ForgeAction(
    label: 'Add Form Field',
    menu: ForgeMenuLocation.modules,
    group: 'Form Editor',
    priority: 0,
    execute: (parameters) async {
      final field = await _shell.dialogs.showInputBox(
        prompt: 'Field name',
        placeholder: 'Enter field name',
      );
      if (field == null) return null; // user cancelled
      return formEditor.addField(field); // returns undo info
    },
    undo: (undoInfo) async => formEditor.removeField(undoInfo),
    isEnabled: () => _shell.systemState.focusedComponent is FormEditor,
    isVisible: () => _shell.systemState.focusedComponent is FormEditor,
  );
}

/// The form editor — handles .form.yaml files.
class FormEditor extends ForgeEditor {
  final ForgeShellApi shell;

  FormEditor({required this.shell});

  @override
  ValueListenable<String> get title => _title;
  final _title = ValueNotifier('Form Editor');

  @override
  IconData get icon => Icons.dynamic_form;

  @override
  FileHandlingResult canHandle(Uri uri) =>
      uri.path.endsWith('.form.yaml')
          ? FileHandlingResult.accept
          : FileHandlingResult.reject;

  @override
  Widget buildMain(BuildContext context) => FormEditorWidget(editor: this);

  @override
  Widget buildCopy(BuildContext context) => FormEditorWidget(editor: this, isCopy: true);

  @override
  ForgeModule get module => shell.modules.get<TomFormEditorModule>();

  Object addField(String name) { /* ... returns undo info */ }
  void removeField(Object undoInfo) { /* ... */ }
}
```

**Key differences from VS Code pattern:**
- No `registerEditor('type.id', factory)` — the editor is a direct class member
- No `shell.fileAssociations.register(pattern: '*.form.yaml', ...)` — the editor implements `canHandle(uri)` directly
- No `componentTypeId` comparisons — use `is FormEditor` (Dart type system)
- The action references `formEditor` directly, not by string lookup
- Other modules can access this module's components: `shell.modules.get<TomFormEditorModule>().formEditor`

### 8.4 Module Lifecycle

1. Modules are declared in the `TomForgeShell` configuration as typed instances
2. `activate()` is called during shell startup, in declaration order
3. Modules can reference each other via `shell.modules.get<T>()` (type-safe)
4. `deactivate()` is called during shell shutdown, in reverse order
5. When the shell needs to open a file, it runs the two-phase resolution process (§10.4): first `canHandle(uri)` on all editors, then `canHandleContent(uri, bytes)` for editors that requested content inspection

### 8.5 Shell API Surface

The `ForgeShellApi` passed to modules provides direct, typed access to all shell services. No string-based lookups — everything is accessed through objects and types:

```dart
abstract class ForgeShellApi {
  /// System state — focus, selection, open editors, problems, etc.
  ForgeSystemState get systemState;

  /// Layout control — open/close panels, focus components, etc.
  ForgeLayoutController get layout;

  /// Status bar control.
  ForgeStatusBarController get statusBar;

  /// File system access (routed through .forge revisioning).
  TomFileSystem get fileSystem;

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

  /// The undo/redo stack for actions.
  ForgeUndoManager get undoManager;

  /// Secure storage for tokens, API keys, and other secrets.
  ForgeSecretStorage get secrets;

  /// File decoration registration (badges, colors in explorer).
  ForgeFileDecorationManager get fileDecorations;

  /// Virtual document content provider registration.
  ForgeVirtualDocumentManager get virtualDocuments;

  /// Outline provider registration (feeds the Outline view).
  ForgeOutlineManager get outline;

  /// Programmatic workspace-wide text search.
  ForgeSearchManager get search;
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
| **File Types** | File-to-editor resolution: view which editors handle which files, adjust priority order, configure "Open with" defaults |

### 9.3 Code-Based Configuration and Startup Sequence

Configuration is defined in code as the **baseline default** and then overlaid with persisted user changes at startup. The code-configured values serve as the reset target:

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

**Startup configuration sequence:**

```
1. Code config
   ├─ TomForgeShell constructor receives ForgeConfig with all defaults
   ├─ Modules are instantiated (but not activated yet)
   └─ Applications are defined with layout referencing module members

2. Startup dialog
   ├─ User selects workspace + config mode (or remembered from prefs)
   └─ .forge/ folder path is resolved

3. Persisted config overlay
   ├─ Load .forge/config.json (or ~/.forge/config.json in split mode)
   ├─ Overlay on top of code config (user changes win)
   ├─ Load .forge/state/layout.json → override code-based PanelLayout
   └─ Load .forge/state/open-editors.json → restore editor tabs

4. Module activation
   ├─ activate() called on each module in declaration order
   ├─ Modules create their component instances
   └─ Modules can read config via shell.config

5. Shell render
   ├─ Build widget tree from merged layout (code + persisted)
   ├─ Open restored editor tabs
   └─ Status bar items from modules become active
```

The **reset** option in the Configuration tab restores the code-configured defaults, discarding persisted overrides.

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

  /// The currently focused component (null if no component is focused).
  /// This is a direct object reference — use `is` to check the type:
  ///   if (state.focusedComponent is FormEditor) { ... }
  ForgeComponent? get focusedComponent;

  /// Whether the focused component is the main instance or a UI copy.
  bool get isFocusedComponentMain;

  /// The panel location of the focused component.
  ForgePanelLocation? get focusedPanelLocation;

  // --- Editors ---

  /// All currently open editors (direct references).
  List<ForgeEditor> get openEditors;

  /// The active editor (the editor with focus, or last focused).
  ForgeEditor? get activeEditor;

  /// Editors with unsaved changes.
  List<ForgeEditor> get dirtyEditors;

  /// Whether any editor has unsaved changes.
  bool get hasUnsavedChanges;

  // --- Component Context ---

  /// The current text selection in the focused component, if any.
  /// Delegates to `ForgeTextEditor.selection` when the focused
  /// component is a ForgeTextEditor. Returns null for non-text editors.
  TextSelection? get focusedTextSelection;

  /// The selected text content in the focused component, if any.
  /// Delegates to `ForgeTextEditor.selectedText` when the focused
  /// component is a ForgeTextEditor. Returns null for non-text editors.
  String? get focusedSelectedText;

  /// Whether the focused component currently has a non-empty text selection.
  /// True when the focused component is a ForgeTextEditor with a selection,
  /// or a ForgeVisualEditor with selected elements.
  bool get hasTextSelection;

  /// The selected elements in the focused component, if any.
  /// Delegates to `ForgeVisualEditor.selectedElements` when the focused
  /// component is a ForgeVisualEditor. Returns null for non-visual editors.
  List<Object>? get focusedSelectedElements;

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

  /// Fires when focus changes. Provides the old and new component references.
  Stream<FocusChangeEvent> get onFocusChanged;

  /// Fires when an editor's dirty state changes.
  Stream<DirtyStateEvent> get onDirtyStateChanged;

  /// Fires when explorer selection changes.
  Stream<SelectionChangeEvent> get onSelectionChanged;

  /// Fires when the focused component's text selection changes.
  Stream<TextSelectionChangeEvent> get onTextSelectionChanged;

  /// Fires when diagnostics change.
  Stream<DiagnosticChangeEvent> get onDiagnosticsChanged;

  /// Fires when any open editor list changes.
  Stream<EditorListChangeEvent> get onEditorsChanged;

  /// Fires when the application window gains or loses OS focus.
  Stream<WindowFocusEvent> get onWindowFocusChanged;

  /// Fires when panel visibility or layout changes.
  Stream<LayoutChangeEvent> get onLayoutChanged;
}

class FocusChangeEvent {
  /// The previously focused component (null if none was focused).
  final ForgeComponent? previous;

  /// The newly focused component (null if focus was lost).
  final ForgeComponent? current;
}

class DirtyStateEvent {
  /// The editor whose dirty state changed.
  final ForgeEditor editor;

  /// The new dirty state.
  final bool isDirty;
}

class SelectionChangeEvent {
  /// The component whose selection changed.
  final ForgeComponent component;

  /// The new selection (type depends on component — TextRange, List<Object>, etc.).
  final Object? selection;
}

class TextSelectionChangeEvent {
  /// The text editor whose selection changed.
  final ForgeTextEditor editor;

  /// The new text selection.
  final TextRange? selection;
}

class DiagnosticChangeEvent {
  /// URIs with changed diagnostics.
  final List<Uri> uris;
}

class EditorListChangeEvent {
  /// Editors that were opened.
  final List<ForgeEditor> opened;

  /// Editors that were closed.
  final List<ForgeEditor> closed;
}

class WindowFocusEvent {
  /// Whether the window is now focused.
  final bool focused;
}

class LayoutChangeEvent {
  /// The type of layout change.
  final LayoutChangeType type;

  /// The affected panel (if applicable).
  final ForgePanelLocation? panel;
}

enum LayoutChangeType { panelOpened, panelClosed, panelResized, middlePanelSplit, middlePanelMerged }
```

**Design note on URIs:** Files are identified by `Uri` because URIs are universal resource identifiers that can represent local files (`file://`), virtual documents, or remote resources. Editors expose `Uri get uri` and `FileHandlingResult canHandle(Uri uri)` — the URI is the file handle, while the editor object itself is the component handle. There is no need for a separate component ID system: use the Dart type system (`is FormEditor`, `is FlowEditor`, `is ForgeTextEditor`) for type checks and object identity for instance checks.

### 10.3 Action Visibility and Enablement

Actions dynamically evaluate their `isVisible` and `isEnabled` callbacks against the current system state. The shell re-evaluates these whenever the relevant state changes:

```dart
// Example: "Save All" saves all dirty editors.
ForgeAction(
  label: 'Save All',
  menu: ForgeMenuLocation.file,
  isEnabled: () => systemState.hasUnsavedChanges,
  isVisible: () => true,
  execute: () async {
    final saved = List<ForgeEditor>.from(systemState.dirtyEditors);
    for (final editor in saved) {
      await shell.fileSystem.save(editor.uri);
    }
    return saved; // undo info: list of editors that were saved
  },
  undo: null, // save is not undoable at this level
);

// Example: "Copy" action — visible only when text is selected.
ForgeAction(
  label: 'Copy',
  menu: ForgeMenuLocation.edit,
  isEnabled: () => systemState.hasTextSelection,
  isVisible: () => systemState.hasTextSelection,
  execute: () async {
    final text = systemState.focusedSelectedText;
    if (text != null) await shell.clipboard.writeText(text);
    return null; // not undoable
  },
);
```

### 10.4 Service API Details

This section details the APIs for each service on `ForgeShellApi` that are not fully specified in the sections above.

#### TomFileSystem

The contract lives in `tom_file_system` (`package:tom_file_system/tom_file_system.dart`),
with two implementations: `TomMemoryFileSystem` and, in `io.dart`,
`TomLocalFileSystem` over a folder on disk. It is addressed by `Uri`; a file
system has a `root`, and `uriOf` / `pathOf` map root-relative paths to URIs and
back.

```dart
abstract interface class TomFileSystem {
  Uri get root;
  Uri uriOf(String path);
  String? pathOf(Uri uri);

  /// The entries directly in a folder.
  Future<List<TomFileEntry>> list(Uri directory);

  /// One entry, or null when nothing is there.
  Future<TomFileEntry?> stat(Uri uri);

  /// The bytes with the revision they were read at — the input of the
  /// two-phase file resolution flow (canHandleContent receives the bytes).
  Future<TomFileContent> read(Uri uri);
  Future<String> readText(Uri uri);

  /// At most maxBytes, from the start or the end (a log read where it grows).
  Future<String?> readSlice(Uri uri, {required int maxBytes, required bool fromEnd});

  /// Atomic writes; with [expected], refused with a TomFileConflict when
  /// the file is no longer that revision.
  Future<TomFileRevision> write(Uri uri, Uint8List bytes, {TomFileRevision? expected});
  Future<TomFileRevision> writeText(Uri uri, String text, {TomFileRevision? expected});

  Future<void> create(Uri uri, {bool directory = false});
  Future<void> rename(Uri from, Uri to);

  /// Moves to the platform's trash; false where there is none.
  Future<bool> trash(Uri uri);
  Future<void> delete(Uri uri);
  Future<bool> exists(Uri uri);

  /// Changes below the root, or null where the platform does not watch;
  /// [descend] names the folders not to watch into.
  Stream<TomFileChange>? watch({bool Function(String path)? descend});

  /// Save (persist) the current content of a file.
  /// Triggers revision snapshot and dirty-state update.
  Future<void> save(Uri uri);

  /// Apply a workspace edit atomically — multiple file creates, deletes,
  /// renames, and text edits as a single undo step. Used for refactoring
  /// operations that span multiple files.
  Future<bool> applyWorkspaceEdit(ForgeWorkspaceEdit edit);

  /// Fires when any file changes (create, modify, delete).
  Stream<TomFileChangeEvent> get onDidChange;

  /// Fires after a file is saved.
  Stream<Uri> get onDidSave;

  /// Fires before a file is saved. Listeners can modify content.
  Stream<TomWillSaveEvent> get onWillSave;
}

/// An atomic multi-file edit operation. All changes are applied as a
/// single undo step and either all succeed or all are rolled back.
class ForgeWorkspaceEdit {
  /// Text edits grouped by URI.
  final Map<Uri, List<ForgeTextEdit>> textEdits;

  /// File operations (create, delete, rename).
  final List<ForgeFileOperation> fileOperations;
}

class ForgeTextEdit {
  final TextRange range;
  final String newText;
}

abstract class ForgeFileOperation {}

class ForgeCreateFileOperation extends ForgeFileOperation {
  final Uri uri;
  final String? content;
  final bool overwrite;
}

class ForgeDeleteFileOperation extends ForgeFileOperation {
  final Uri uri;
  final bool recursive;
}

class ForgeRenameFileOperation extends ForgeFileOperation {
  final Uri oldUri;
  final Uri newUri;
  final bool overwrite;
}

/// A file system change event.
class TomFileChangeEvent {
  /// The URI that changed.
  final Uri uri;

  /// The type of change.
  final TomFileChangeType type;
}

enum TomFileChangeType { created, modified, deleted }

/// Event fired before a file is saved. Listeners can modify content.
class TomWillSaveEvent {
  /// The URI being saved.
  final Uri uri;

  /// The content to be saved. Listeners can modify this.
  String content;

  /// Reason for the save.
  final TomSaveReason reason;
}

enum TomSaveReason { manual, autoSave, focusLoss }
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

  /// Focus a specific component (direct reference, no ID).
  void focusComponent(ForgeComponent component);

  /// Open a file. The shell runs two-phase file resolution (§10.4):
  /// Phase 1 checks canHandle(uri), Phase 2 inspects content for
  /// editors that requested it. If multiple editors accept, the
  /// first by module priority wins. Reuses an existing tab if an
  /// editor for this URI is already open.
  void openFile(Uri uri, {int? middlePanelIndex});

  /// Open a specific editor for the given URI (bypasses resolution).
  void openEditor(ForgeEditor editor, Uri uri, {int? middlePanelIndex});

  /// Show the "Open with" dialog for the given URI. Lists all
  /// accepting editors (Phase 1) and additional options (Phase 2).
  Future<void> openFileWith(Uri uri, {int? middlePanelIndex});

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

/// A single diagnostic issue (error, warning, info, hint).
class ForgeDiagnostic {
  /// The file this diagnostic applies to.
  final Uri uri;

  /// The range in the document.
  final TextRange range;

  /// The diagnostic message.
  final String message;

  /// Severity level.
  final ForgeSeverity severity;

  /// Source identifier (e.g., 'dart', 'yaml-lint', 'form-validator').
  final String source;

  /// Optional error code.
  final String? code;
}

enum ForgeSeverity { error, warning, info, hint }

/// Aggregated diagnostic counts by severity.
class DiagnosticSummary {
  final int errors;
  final int warnings;
  final int infos;
  final int hints;

  int get total => errors + warnings + infos + hints;
}
```

#### ForgeUndoManager

Actions register with the undo manager automatically when their `execute()` returns a non-null undo object:

```dart
abstract class ForgeUndoManager {
  /// Undo the last undoable action.
  Future<void> undo();

  /// Redo the last undone action.
  Future<void> redo();

  /// Whether undo is available.
  ValueListenable<bool> get canUndo;

  /// Whether redo is available.
  ValueListenable<bool> get canRedo;
}
```

#### ForgeShortcutManager

Shortcuts are collected from modules and components automatically. The manager resolves conflicts and allows runtime rebinding:

```dart
abstract class ForgeShortcutManager {
  /// All registered shortcut bindings (from all modules and components).
  List<ForgeShortcutBinding> get allBindings;

  /// Rebind a shortcut to a new key combination.
  void rebind(ForgeAction action, ForgeShortcutKey newKey);

  /// Reset a shortcut to its default binding.
  void resetToDefault(ForgeAction action);

  /// Detect conflicts with an existing binding.
  ForgeShortcutBinding? conflictsWith(ForgeShortcutKey key);
}
```

#### ForgeShortcutBinding and ForgeShortcutKey

Shortcut bindings connect actions to key combinations. Used throughout the module system (§8.2), component contracts (§4.3), and the menu system (§7.2):

```dart
class ForgeShortcutBinding {
  /// The action this shortcut triggers.
  final ForgeAction action;

  /// The key combination that activates this shortcut.
  final ForgeShortcutKey key;

  /// When this shortcut is active. Null = always active.
  /// Examples: 'editorFocus', 'textEditorFocus', 'explorerFocus'.
  final String? context;
}

class ForgeShortcutKey {
  /// The primary key (e.g., LogicalKeyboardKey.keyS).
  final LogicalKeyboardKey key;

  /// Whether the primary modifier is required (CMD on macOS, CTRL on others).
  final bool primaryModifier;

  /// Whether SHIFT is required.
  final bool shift;

  /// Whether ALT/OPT is required.
  final bool alt;
}

/// Panel locations in the shell layout.
enum ForgePanelLocation { left, right, bottom, middle }
```

#### File-to-Editor Resolution (Two-Phase)

File-to-editor resolution uses a **two-phase process** to determine which editor opens a file. Phase 1 is fast (URI-only), Phase 2 gives editors a chance to inspect file content:

**Phase 1 — URI-Based Matching:**

```dart
// Phase 1: Ask all editors based on URI alone (fast, no I/O).
FileResolutionResult resolveEditorForFile(Uri uri) {
  final accepted = <ForgeEditor>[];
  final needsInspection = <ForgeEditor>[];

  for (final module in modules) {
    for (final editor in module.editors) {
      final result = editor.canHandle(uri);
      if (result == FileHandlingResult.accept) {
        accepted.add(editor);
      } else if (result == FileHandlingResult.inspect) {
        needsInspection.add(editor);
      }
    }
  }

  return FileResolutionResult(
    accepted: accepted,
    needsInspection: needsInspection,
  );
}
```

**Phase 2 — Content Inspection:**

```dart
// Phase 2: For editors that returned `inspect`, read the file
// and let them decide based on content.
Future<ForgeEditor?> findEditorForFile(Uri uri) async {
  final phase1 = resolveEditorForFile(uri);

  // Run Phase 2 for editors that need content inspection.
  if (phase1.needsInspection.isNotEmpty) {
    final bytes = (await fileSystem.read(uri)).bytes;
    for (final editor in phase1.needsInspection) {
      final result = editor.canHandleContent(uri, bytes);
      if (result == FileHandlingResult.accept) {
        phase1.accepted.add(editor);
      }
      // `reject` or `inspect` in Phase 2 → skip
    }
  }

  if (phase1.accepted.isEmpty) return null;

  // Module declaration order determines priority — first accepted editor wins.
  return phase1.accepted.first;
}
```

**"Open with" Dialog:**

When the user explicitly requests "Open with" (via context menu or command palette), the shell presents a dialog with all editors that can handle the file:

```dart
Future<ForgeEditor?> showOpenWithDialog(Uri uri) async {
  final phase1 = resolveEditorForFile(uri);

  // Phase 2 for content-inspecting editors
  final additionalOptions = <ForgeEditor>[];
  if (phase1.needsInspection.isNotEmpty) {
    final bytes = (await fileSystem.read(uri)).bytes;
    for (final editor in phase1.needsInspection) {
      final result = editor.canHandleContent(uri, bytes);
      if (result == FileHandlingResult.accept) {
        additionalOptions.add(editor);
      }
    }
  }

  // Show dialog with two sections:
  // 1. "Editors" — editors that accepted based on URI (phase 1)
  // 2. "Additional Options" — schema editors and others that
  //    accepted after content inspection (phase 2)
  return shell.dialogs.showOpenWithPicker(
    uri: uri,
    editors: phase1.accepted,
    additionalOptions: additionalOptions,
  );
}
```

The "Open with" dialog displays:

| Section | Source | Example |
|---------|--------|---------|
| **Editors** | Phase 1 accepts (URI-based) | YAML Editor, Text Editor |
| **Additional Options** | Phase 2 accepts (content-based) | Form Schema Editor, Flow Schema Editor |

Schema editors (see §4.3 `ForgeSchemaEditor`) always return `inspect` from `canHandle()`, so they always appear in the Additional Options section. This makes them discoverable without polluting the primary editor list.

Module declaration order determines priority within each section. Users can override this in the Configuration tab (File Types section, see §9.2) to set a preferred default editor per file extension and to pin schema editors as default for specific content patterns.

#### ForgeModuleRegistry

```dart
abstract class ForgeModuleRegistry {
  /// Get a typed module reference. Type-safe, no string IDs.
  T get<T extends ForgeModule>();

  /// List all registered modules.
  List<ForgeModule> get allModules;
}
```

#### ForgeConfigManager

```dart
abstract class ForgeConfigManager {
  /// Get the full configuration object (code defaults + persisted overrides).
  ForgeConfig get current;

  /// Update a configuration property. Persists the change.
  void update(void Function(ForgeConfig config) updater);

  /// Get module-specific configuration (typed).
  T getModuleConfig<T extends ForgeModule, C>(T module);

  /// Fires when any configuration value changes.
  Stream<ConfigChangeEvent> get onDidChange;

  /// Reset all configuration to code-configured defaults.
  void resetToDefaults();
}

/// Event fired when a configuration value changes.
class ConfigChangeEvent {
  /// Key path of the changed configuration.
  final String key;

  /// The new value (null if deleted).
  final Object? newValue;

  /// The previous value (null if newly added).
  final Object? oldValue;
}
```

#### ForgeStatusBarController

```dart
abstract class ForgeStatusBarController {
  /// All currently visible status bar items.
  List<StatusBarItem> get items;
}
```

Status bar items are contributed by modules via `ForgeModule.statusBarItems`. The shell automatically collects them. Items activate/deactivate based on their `isActive` callback (see §15.2).

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

/// An item in a quick pick list.
class ForgeQuickPickItem<T> {
  /// The label shown in the list.
  final String label;

  /// Optional description shown below the label.
  final String? description;

  /// Optional detail text.
  final String? detail;

  /// The value returned when this item is selected.
  final T value;

  /// Whether this item is pre-selected.
  final bool picked;
}

/// A file filter for open/save dialogs.
class FileFilter {
  /// Display name (e.g., 'YAML Files').
  final String name;

  /// File extensions without dots (e.g., ['yaml', 'yml']).
  final List<String> extensions;
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
  /// Data is stored in .forge/modules/<module-type-name>/.
  /// The module type is used as the directory name (no string IDs).
  ForgeKeyValueStore forModule(ForgeModule module);
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

#### ForgeSecretStorage (new)

Secure, encrypted storage for tokens, API keys, passwords, and other sensitive data. Uses the platform's secure storage (Keychain on macOS, Credential Manager on Windows, libsecret on Linux):

```dart
abstract class ForgeSecretStorage {
  /// Store a secret value.
  Future<void> store(String key, String value);

  /// Retrieve a secret value. Returns null if not found.
  Future<String?> get(String key);

  /// Delete a secret.
  Future<void> delete(String key);

  /// Fires when a secret is stored or deleted.
  Stream<SecretChangeEvent> get onDidChange;
}

/// Event fired when a secret is stored or deleted.
class SecretChangeEvent {
  /// The secret key.
  final String key;

  /// True if the secret was deleted, false if stored/updated.
  final bool deleted;
}
```

#### ForgeFileDecorationManager (new)

File decorations add visual markers (badges, color tints) to files and folders in the Explorer view. Modules register decoration providers to show SCM status, build errors, ignored files, etc.:

```dart
abstract class ForgeFileDecorationManager {
  /// Register a file decoration provider. Returns a disposable.
  ForgeDisposable registerProvider(ForgeFileDecorationProvider provider);
}

abstract class ForgeFileDecorationProvider {
  /// Provide decorations for the given URI. Return null for no decoration.
  ForgeFileDecoration? provideDecoration(Uri uri);

  /// Fires when decorations should be re-evaluated.
  Stream<Uri?> get onDidChange;
}

class ForgeFileDecoration {
  /// Badge text (short, 1-2 characters, e.g., "M", "!", "2").
  final String? badge;

  /// Badge tooltip.
  final String? tooltip;

  /// Tint color for the file label.
  final Color? color;

  /// Whether to propagate this decoration to parent folders.
  final bool propagate;
}
```

#### ForgeVirtualDocumentManager (new)

Virtual document providers supply content for custom URI schemes. This enables computed documents (diffs, previews, generated content) without writing files to disk:

```dart
abstract class ForgeVirtualDocumentManager {
  /// Register a virtual document provider for the given URI scheme.
  /// Returns a disposable.
  ForgeDisposable registerProvider(String scheme, ForgeVirtualDocumentProvider provider);
}

abstract class ForgeVirtualDocumentProvider {
  /// Provide text content for the given URI.
  Future<String> provideContent(Uri uri);

  /// Fires when the content for a URI has changed and should be refreshed.
  Stream<Uri> get onDidChange;
}
```

#### ForgeOutlineManager (new)

Outline providers feed structured symbol/section data to the built-in Outline view. Without this registration, the Outline view cannot show content from module editors:

```dart
abstract class ForgeOutlineManager {
  /// Register an outline provider for a specific editor type.
  /// Returns a disposable.
  ForgeDisposable registerProvider(ForgeOutlineProvider provider);
}

abstract class ForgeOutlineProvider {
  /// Whether this provider can supply outline data for the given editor.
  bool canProvide(ForgeEditor editor);

  /// Provide outline items for the given editor.
  Future<List<ForgeOutlineItem>> provideOutline(ForgeEditor editor);

  /// Fires when the outline for the current editor has changed.
  Stream<void> get onDidChange;
}

class ForgeOutlineItem {
  /// Display label.
  final String label;

  /// Item kind (class, function, property, section, etc.).
  final ForgeSymbolKind kind;

  /// Detail text (e.g., return type, parameter signature).
  final String? detail;

  /// The range in the document this item represents.
  final TextRange range;

  /// The range to select when clicking this item.
  final TextRange selectionRange;

  /// Children (nested outline — methods inside a class, etc.).
  final List<ForgeOutlineItem> children;
}

enum ForgeSymbolKind {
  file, module, namespace, package, classKind, method, property,
  field, constructor, enumKind, interface, function, variable,
  constant, string, number, boolean, array, object, key, nullKind,
  enumMember, struct, event, operator, typeParameter, section,
}
```

#### ForgeSearchManager (new)

Programmatic workspace-wide text search. Modules can trigger searches and receive results without using the Search view UI:

```dart
abstract class ForgeSearchManager {
  /// Search for a pattern across workspace files.
  Future<List<ForgeSearchResult>> search(
    String query, {
    bool isRegExp = false,
    bool isCaseSensitive = false,
    bool isWordMatch = false,
    String? includePattern,
    String? excludePattern,
    int? maxResults,
  });

  /// Search and stream results as they arrive.
  Stream<ForgeSearchResult> searchStream(
    String query, {
    bool isRegExp = false,
    bool isCaseSensitive = false,
    bool isWordMatch = false,
    String? includePattern,
    String? excludePattern,
  });
}

class ForgeSearchResult {
  /// The file URI containing the match.
  final Uri uri;

  /// The matched ranges within the file.
  final List<ForgeSearchMatch> matches;
}

class ForgeSearchMatch {
  /// The range of the match.
  final TextRange range;

  /// The line text containing the match (for preview).
  final String lineText;
}
```

#### ForgeDisposable

Common disposable interface used by registration methods:

```dart
abstract class ForgeDisposable {
  /// Unregister / clean up the resource.
  void dispose();
}
```

---

## 11. Keyboard Shortcuts

### 11.1 Shortcut Architecture

Tom Forge uses two complementary shortcut mechanisms:

1. **Standard shortcuts** — Single-modifier shortcuts (CMD on macOS, CTRL on Windows/Linux) for universal operations. These are a **limited, fixed set** of essential operations.
2. **Custom shortcut menus** — Module-defined popup menus opened via **Shift+CMD+\<key\>**. The menu shows available follow-up actions; the user presses a single key (or clicks) to execute.

**All shortcuts and actions are discoverable.** There are no hidden, hardcoded shortcuts. Every shortcut — whether from the shell, a module, or an editor — is registered through the action/descriptor system, appears in the Shortcut Editor (§11.6), and can be rebound by the user.

#### 11.1.1 Action Naming Convention

All actions use the naming pattern `<source>.<action>`:

| Prefix | Source | Examples |
|--------|--------|----------|
| `forge.` | Shell (global operations) | `forge.toggleLeftPanel`, `forge.commandPalette`, `forge.saveAll` |
| `forge.edit.` | Standard editing (all editors) | `forge.edit.cut`, `forge.edit.undo`, `forge.edit.moveLineUp` |
| `dart.` | Dart editor | `dart.triggerCompletion`, `dart.toggleComment` |
| `md.` | Markdown editor | `md.toggleBold`, `md.insertLink` |
| `yaml.` | YAML editor | `yaml.addKey`, `yaml.toggleTextMode` |
| `flow.` | Flow editor | `flow.addNode`, `flow.autoLayout` |

The **prefix acts as a category** for routing: when the shell dispatches an action, the prefix identifies which module/editor handles it. The Shortcut Editor and command palette group actions by prefix.

#### 11.1.2 Shell as Action Source

The shell itself is a module (`TomForgeShellModule`, see §8) and exposes its actions and shortcuts through the same `EditorActionDescriptor` / `ForgeAction` system as any other module. Shell actions use the `forge.` prefix. This means:

- Shell shortcuts (Cmd+L, Cmd+R, Cmd+B, Cmd+P, etc.) appear in the Shortcut Editor and can be rebound
- Shell actions appear in the command palette
- There is **no distinction** between shell-owned and module-owned shortcuts in the binding system

#### 11.1.3 Standard Text Editing Actions

Every text-based editor must implement a common set of editing actions using the `forge.edit.` prefix. These are not optional — they are required for any editor that handles text content. The shell assigns default shortcuts to these actions:

| Action ID | Label | Default Shortcut | Context |
|-----------|-------|------------------|---------|
| `forge.edit.cut` | Cut | `Cmd+X` | When text is selected |
| `forge.edit.copy` | Copy | `Cmd+C` | When text is selected |
| `forge.edit.paste` | Paste | `Cmd+V` | When text input is focused |
| `forge.edit.selectAll` | Select All | `Cmd+A` | When editor is focused |
| `forge.edit.undo` | Undo | `Cmd+Z` | When editor is focused |
| `forge.edit.redo` | Redo | `Shift+Cmd+Z`; also `Ctrl+Y` on Windows and Linux | When editor is focused |
| `forge.edit.deleteLine` | Delete Line | `Shift+Cmd+K` | When in text editor |
| `forge.edit.duplicateLine` | Duplicate Line | `Cmd+D` | When in text editor |
| `forge.edit.moveLineUp` | Move Line Up | `Alt+↑` | When in text editor |
| `forge.edit.moveLineDown` | Move Line Down | `Alt+↓` | When in text editor |
| `forge.edit.toggleComment` | Toggle Comment | `Cmd+/` | When in text editor |

Tree-based editors (like the YAML tree editor) implement the subset that applies to their editing model — at minimum `undo`, `redo`, and any operations that have a meaningful tree equivalent.

These actions are defined as `EditorActionDescriptor` instances in `StandardEditingActions` (see [editor_action_externalization.md](editor_action_externalization.md) §2.7). The shell registers all of them and binds their default keys when it starts, so the **binding table owns every editing key**, including the undo keys, before any editor opens. A key the user rebinds stays rebound; an editor registering the action later does not restore the default.

**Routing.** The shell's key handler looks a key up in the table (and in `StandardEditingActions.alternateShortcuts`, which holds `Ctrl+Y` for redo on Windows and Linux) and runs the action through `executeAction`, which sends a `forge.edit.*` action to the active editor. Two rules keep a key from doing the wrong thing:

- A `forge.edit.*` key typed into a **text field outside the editors** (find, quick open, chat, settings) is left to that field: the shell neither runs the action nor takes the key, so `Cmd+Z` there undoes the field's own typing and never touches the document.
- A key whose action did nothing (`executeAction` returned false) is **not consumed**, so whatever is below the shell gets it.

A bound key never opens a shortcut menu (§11.4): `Shift+Cmd+Z` redoes and `Shift+Cmd+K` deletes a line even if a menu were registered on Z or K.

**Editors' own key maps.** An editor that puts a `Shortcuts` widget above its text field builds the map with `buildEditorShortcutMap(integration)` and nowhere else: each supported action's key from `getShortcutForAction` (the shell's table when hosted), the platform alternates, and the editor's own extra keys, a key taken once. It rebuilds the map when `ForgeEditorIntegration.shortcutBindings` notifies, so a key rebound in the Shortcut Editor reaches a focused editor at once.

**History.** Each editor keeps its own history. The shell's `ForgeUndoManager` holds shell actions only; no editor pushes into it. `Edit > Undo` and `Edit > Redo` run `forge.edit.undo` / `forge.edit.redo`, so they reach the active editor and are disabled when no editor is active. On macOS the native menu's accelerators are read from the binding table, and a menu selection that echoes a keystroke the shell already routed (same key, within half a second) is not run a second time.

### 11.2 Design Rationale

- Standard shortcuts avoid two-modifier combinations (no Ctrl+Alt+F, etc.) — keeping the set small and memorable. The exceptions are the platform conventions `Shift+Cmd+Z` (redo) and `Shift+Cmd+K` (delete line)
- Custom shortcut menus provide **discoverable, context-rich** access to module-specific commands without polluting the global shortcut space
- Multiple shortcut menus can coexist (e.g., Shift+Cmd+E for Explorer commands, Shift+Cmd+G for Git commands)

### 11.3 Shell Shortcuts

These are **global shell shortcuts** using a single modifier key (CMD on macOS, CTRL on Windows/Linux). They control shell-level layout and navigation — not text editing. The shell registers these as `forge.` actions:

| Shortcut | Action ID | Action | Context |
|----------|-----------|--------|---------|
| `Cmd+P` | `forge.commandPalette` | Open command palette (search bar) | Global |
| `Cmd+L` | `forge.toggleLeftPanel` | Toggle left panel | Global |
| `Cmd+R` | `forge.toggleRightPanel` | Toggle right panel | Global |
| `Cmd+B` | `forge.toggleBottomPanel` | Toggle bottom panel | Global |
| `Cmd+F` | `forge.find` | Find in focused component | When component is focused |
| `Cmd+1` | `forge.focusPanel1` | Focus middle panel 1 | Global |
| `Cmd+2` | `forge.focusPanel2` | Focus middle panel 2 | Global |
| `Cmd+3` | `forge.focusPanel3` | Focus middle panel 3 | Global |
| `Cmd+4` | `forge.focusPanel4` | Focus middle panel 4 | Global |
| `Cmd+S` | `forge.saveAll` | Save all dirty editors | Global |
| `F1` | `forge.commandPaletteFull` | Open command palette (full list) | Global |
| `Cmd+]` | `forge.focusNextPanel` | Focus next panel | Global |
| `Cmd+[` | `forge.focusPrevPanel` | Focus previous panel | Global |

Text editing shortcuts (`Cmd+X`, `Cmd+C`, `Cmd+V`, `Cmd+A`, `Cmd+Z`, `Shift+Cmd+Z`, `Shift+Cmd+K`, `Cmd+D`, `Cmd+/`, `Alt+↑`, `Alt+↓`) are listed in §11.1.3 above. They are bound to `forge.edit.*` actions, not shell actions.

### 11.4 Custom Shortcut Menus

In addition to the standard shortcuts, there can be **multiple custom shortcut menus**. Each is opened via **Shift+Cmd+\<key\>** (macOS) or **Shift+Ctrl+\<key\>** (Windows/Linux). Pressing the modifier combination opens a popup menu that shows the available follow-up actions. A key bound to an action (`Shift+Cmd+Z`, `Shift+Cmd+K`) runs that action and opens no menu.

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

- **Full listing** of all registered shortcuts — from the shell module, editor modules, and any other module. Because the shell exposes its actions through the same system as editors (§11.1.2), all shortcuts appear in a single, unified list.
- **Scope selection** — when rebinding a shortcut, the user chooses the scope:
  - **Global** — shortcut is active regardless of which editor is focused
  - **Editor-specific** — shortcut is active only when a specific editor type is focused (e.g., only in the Dart editor). This allows the same key combination to trigger different actions in different editors without conflict.
- **Conflict detection** — highlights when two shortcuts use the same key combination in overlapping scopes
- **Rebinding** — click a shortcut row, then press the desired key combination, then select the scope
- **Reset** — restore individual or all shortcuts to defaults
- **Search/filter** — find shortcuts by action name, key, module, or scope
- **Source column** — shows which module/editor provides the action (e.g., "Shell", "Dart Editor", "Markdown")
- **Context column** — shows when each shortcut is active (`global`, `editorFocused`, `textEditorFocused`, `hasSelection`, `editable`)

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
    <module-type>/      # Per-module persistent storage (directory named by Dart type)
```

When using global configuration mode, configuration lives in `~/.forge/`:

```
~/.forge/
  config.json           # Global configuration overrides
  modules/
    <module-type>/      # Global per-module persistent storage
```

**Important:** Workspace-specific data (revisions, layout state, undo history) is **always** stored in `<workspace>/.forge/` — never in `~/.forge/`. The global `~/.forge/` only holds configuration and module config data.

### 12.3 File Revisioning

The shell **routes all file access** through `TomFileSystem`, which transparently manages revisions:

- **On save:** a revision snapshot is created automatically. Sequential identical saves (same content) do not create duplicate revisions.
- **Revision limit:** configurable (default: 50 revisions per file). Oldest revisions are pruned.
- **Viewing history:** the built-in File History view shows all revisions for a file, with diff/restore options.
- **Restore:** any revision can be restored. Restoring creates a new revision (non-destructive).

### 12.4 Undo System

Undo/redo operates at two levels:

1. **Editor-level undo** — standard text/content undo within the editor (`Cmd+Z`, and `Shift+Cmd+Z` or on Windows and Linux `Ctrl+Y` to redo). This is per-editor and uses the data state's undo stack; the shell's undo manager holds shell actions only.
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

These views ship with the panel shell framework as members of `TomForgeShellModule`:

| View | Module Member | Description | Default Panel |
|------|--------------|-------------|---------------|
| **Terminal** | `shellModule.terminal` | Embedded terminal emulator (pty-based on desktop). Multiple terminal instances managed as tabs within the view. | Bottom |
| **Output** | `shellModule.output` | Read-only text output channel. Components can write to named output channels (dropdown to select channel). Shows timestamped, scrollable log output. | Bottom |
| **Problems** | `shellModule.problems` | Aggregated diagnostics list (errors, warnings, info). Components register problem providers via `ForgeDiagnosticManager`. Click-to-navigate to source location. Filterable by severity and source. | Bottom |
| **Explorer** | `shellModule.explorer` | File/resource tree browser. Shows workspace files, supports open/rename/delete. Double-click opens in editor. Supports file decorations (badges, colors) via `ForgeFileDecorationManager`. | Left |
| **Search** | `shellModule.search` | Full-text search across workspace files. Shows results grouped by file with match highlighting. Click navigates to match. Modules can trigger searches programmatically via `ForgeSearchManager`. | Left |
| **Outline** | `shellModule.outline` | Structural outline of the active editor's content (sections, classes, functions). Modules register outline providers via `ForgeOutlineManager`. Follows focus. Click navigates within the editor. | Left |
| **File History** | `shellModule.history` | Revision history for the active file. Shows timestamps, diffs, restore options. Reads from `.forge/revisions/`. | Right |

### 14.2 Suggested for Later

| View | Module Member | Description | Rationale |
|------|--------------|-------------|-----------|
| **Debug Console** | `shellModule.debug` | Interactive debug output and evaluation | Needed once D4rt integration lands |
| **Git / Source Control** | `shellModule.scm` | Git status, staging, commit, diff | Common development need |
| **Notifications** | `shellModule.notifications` | System and component notifications with history | Better than toast-only |
| **Minimap** | `shellModule.minimap` | Thumbnail overview of the active editor | Useful for large files |
| **Properties** | `shellModule.properties` | Context-sensitive property editor for the selected item | Useful for visual editors (flow editor, form editor) |
| **Preview** | `shellModule.preview` | Live preview of the active editor's content (markdown, flow diagram) | Already exists in tom_md_editor |
| **Help** | `shellModule.help` | Contextual documentation browser | Supports back/forward history |
| **Execution Monitor** | `shellModule.execution` | Real-time flow execution display (node states, timing, logs) | Core for the flow editor |

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
  /// Display text. Observable — the shell re-renders when this changes.
  final ValueListenable<String> text;

  /// Optional icon.
  final IconData? icon;

  final StatusBarAlignment alignment; // left, center, right

  /// Higher priority = closer to the edge of its alignment zone.
  final int priority;

  /// Tap handler (e.g., click language mode to change it).
  final VoidCallback? onTap;

  /// Tooltip on hover.
  final String? tooltip;

  /// Whether this status bar item is currently active (visible).
  /// Evaluated dynamically against the system state. Items that return
  /// false are hidden. This enables context-sensitive status lines:
  /// e.g., "Ln 42, Col 17" only shows when a text editor is focused.
  final bool Function(ForgeSystemState state) isActive;
}

enum StatusBarAlignment { left, center, right }
```

- **Global items:** contributed by the shell module (connection status, application info, problem count) — typically always active
- **Component items:** contributed by modules, active only when the relevant component is focused (cursor position, file encoding, language mode)
- Items with `ValueListenable<String> text` update reactively — no manual refresh calls needed
- The `isActive` callback is re-evaluated whenever `ForgeSystemState` changes, so items appear/disappear based on context (e.g., cursor position item becomes active when a text editor gains focus, and deactivates when a non-text view gains focus)

---

## 16. Application Setup (Code-Configured)

### 16.1 Example

The shell setup references module members directly — no string IDs, no registries:

```dart
void main() {
  // Instantiate modules. Each module owns its components as typed members.
  final shellModule = TomForgeShellModule();
  final formEditorModule = TomFormEditorModule();
  final flowEditorModule = TomFlowEditorModule();
  final dartEditorModule = DartEditorModule();
  final worktrackerModule = WorktrackerModule();

  final shell = TomForgeShell(
    workspace: Directory.current,
    modules: [
      shellModule,
      formEditorModule,
      flowEditorModule,
      dartEditorModule,
      worktrackerModule,
    ],
    config: ForgeConfig(
      autoSave: AutoSaveConfig(enabled: true, idleDelay: Duration(seconds: 1)),
      revisioning: RevisioningConfig(maxRevisionsPerFile: 50),
    ),
    applications: [
      // Application with explicit layout — references module members directly
      ForgeApplication(
        id: 'tom-flow',
        title: 'Tom Flow',
        layout: PanelLayout(
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

      // Modules can provide pre-configured applications
      dartEditorModule.d4rtScriptingApplication,
      worktrackerModule.worktrackerApplication,
    ],
  );

  runApp(TomForgeShellApp(shell: shell));
}
```

**Key patterns demonstrated:**
- **Direct member access:** `shellModule.explorer`, `flowEditorModule.queueEditor` — typed, IDE-navigable, refactor-safe
- **Module-provided applications:** `dartEditorModule.d4rtScriptingApplication` — modules can expose entire application layouts
- **No string IDs anywhere** — components, views, editors are all direct Dart object references
- **Shell as a module:** `TomForgeShellModule` provides built-in views (Explorer, Output, Problems, Terminal, Search, Outline, File History, Properties)

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
        forge_component.dart        # ForgeComponent base class
        forge_editor.dart           # ForgeEditor, FileHandlingResult
        forge_text_editor.dart      # ForgeTextEditor, ForgeDocument, TextPosition, TextRange, decorations
        forge_visual_editor.dart    # ForgeVisualEditor (canvas/node editors)
        forge_schema_editor.dart    # ForgeSchemaEditor (content-based schema detection)
        forge_view.dart             # ForgeView base class
        component_host.dart         # Wraps a component in a panel section
        component_history.dart      # ComponentHistoryManager
        component_state.dart        # Shared data state + per-copy UI state
        multi_render_manager.dart   # Track main component vs UI copies
        file_resolution.dart        # Two-phase file-to-editor resolution + "Open with"
      modules/
        forge_module.dart           # ForgeModule base class
        module_registry.dart        # Module lifecycle and type-safe cross-references
        shell_module.dart           # TomForgeShellModule — built-in views
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
        action_collector.dart       # Collect actions from modules and components
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
        undo_manager.dart           # ForgeUndoManager — action undo/redo stack
        status_bar_controller.dart  # Status bar item collection and visibility
        secret_storage.dart         # ForgeSecretStorage — secure credential storage
        file_decoration_manager.dart # ForgeFileDecorationManager — explorer file badges/colors
        virtual_document_manager.dart # ForgeVirtualDocumentManager — custom URI scheme content
        outline_manager.dart        # ForgeOutlineManager — structured outline provider registration
        search_manager.dart         # ForgeSearchManager — programmatic workspace text search
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

- `ForgeComponent`, `ForgeEditor`, `ForgeView` base contracts
- `ForgeTextEditor` with `ForgeDocument`, text selection, cursor, modification API, multi-selection (`selections`, `setSelections`), visible range, per-editor options (`ForgeTextEditorOptions`), and decoration system (`ForgeDecorationType`, `setDecorations`, `clearDecorations`)
- `ForgeVisualEditor` with element selection, viewport, zoom
- `ForgeSchemaEditor` with content-based schema detection
- Component host wrapper with drag handles
- Multi-render: data state sharing by URI/type, independent UI state per copy
- SHIFT+drag to create UI copies
- Focus tracking service
- `ForgeSystemState` implementation
- Two-phase file-to-editor resolution (`canHandle` + `canHandleContent`)
- "Open with" dialog with primary editors and additional options

### Phase 4 — Module System and Actions

- `ForgeModule` contract and lifecycle (activate/deactivate)
- `ForgeShellApi` implementation with all services: systemState, layout, statusBar, fileSystem, modules, output, diagnostics, config, notifications, progress, dialogs, terminals, clipboard, environment, storage, undoManager, secrets (`ForgeSecretStorage`), fileDecorations (`ForgeFileDecorationManager`), virtualDocuments (`ForgeVirtualDocumentManager`), outline (`ForgeOutlineManager`), search (`ForgeSearchManager`)
- `TomForgeShellModule` with built-in views
- Action collection from modules and components
- Menu population from actions
- Context menus based on system state
- Module cross-references via `get<T>()`

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

- `TomFileSystem` with routed file access (`read`, `write`, `save`, `create`, `rename`, `trash`, `delete`, `exists`, `stat`, `list`, `watch`, `applyWorkspaceEdit`)
- Auto-save service (focus loss + idle timer)
- File revision management in `.forge/revisions/`
- Undo stack persistence in `.forge/undo/`
- File History view

### Phase 8 — Built-In Views

- Terminal view (pty integration)
- Output view (channel-based log viewer)
- Problems view (diagnostic aggregator, backed by `ForgeDiagnosticManager`)
- Explorer view (file tree with file decorations via `ForgeFileDecorationManager`)
- Search view (text search, backed by `ForgeSearchManager` for programmatic access)
- Outline view (active editor structure, backed by `ForgeOutlineManager` for provider registration)
- File History view (revision browser)

### Phase 9 — Persistence and Polish

- Layout persistence per application (JSON save/load in `.forge/state/`)
- Open editor restoration
- Animation for panel transitions
- Accessibility (screen reader support, high contrast)
- Debug trail integration

---

## 19. Implementation Details Cross-Reference

For implementation-level details not covered in this concept document, see the companion [Implementation Specification](forge_panel_shell_spec.md):

| Topic | Spec Section |
|-------|-------------|
| Animation timing & curves | §2.1 |
| Dimension constants | §2.2 |
| Theme extension (`ForgeShellTheme`) | §2.3 |
| Focus management | §2.4 |
| Scroll behaviors | §2.5 |
| Drag/drop visual feedback | §2.6 |
| Error categories & UI | §3 |
| Memory budgets & caching | §4.1, §4.4 |
| Virtualization requirements | §4.2 |
| Lazy loading patterns | §4.3 |
| Debouncing/throttling | §4.5 |
| Keyboard navigation | §5.1 |
| Screen reader support | §5.2 |
| High contrast mode | §5.3 |
| Reduced motion | §5.4 |
| JSON schemas for state files | §6 |
| Shell lifecycle sequence | §7.1 |
| Editor lifecycle sequence | §7.2 |
| Event ordering guarantees | §7.3 |
| Test strategy & patterns | §8 |
| Cross-reference matrix | §9 |
| Test modules implementation | §10 |
| Editor integration (tom_md_editor) | §11.2 |
| Editor integration (tom_dart_editor) | §11.3 |
| Editor integration (tom_yaml_editor) | §11.4 |
| Shared library requirements | §11.5 |
| Integration test scenarios | §11.6 |
| Implementation checklist | §11.7 |
