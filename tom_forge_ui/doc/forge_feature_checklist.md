# Forge Feature Checklist

## Column Legend

| Column | Description |
|--------|-------------|
| **category** | Feature or behavior being tracked |
| **per module?** | Whether this applies to each module individually |
| **per component?** | Whether this applies to each component individually |
| **to be implemented in modules?** | Whether modules are responsible for implementing this |
| **documented?** | Whether the feature is documented/specified in design docs |
| **demo implemented?** | Whether a working demo exists in `tom_forge_ui_test` — **requires manual verification** |
| **wired to editors?** | Whether the feature is connected to actual editor implementations (MD/Dart/YAML) — **requires manual verification** |
| **implemented on** | Reference to documentation or implementation evidence |

### Status Key
- `yes` = Confirmed working/present
- `no` = Not implemented or not verified
- `partial` = Partially implemented

---

## 1. Shell Architecture and Lifecycle
This section is intended to cover the top-level Forge shell runtime model: startup, module activation/deactivation, shell service wiring, and lifecycle guarantees. Include checks at Forge level and per integrated module that depends on shell lifecycle hooks.

- [x] Section completed (finished on 2026-03-30T09:15:00+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Shell startup sequence (`constructor` -> `initState` -> `ready`) | no | no | no | yes | yes | n/a | documented in `forge_panel_shell_spec.md` (section 7.1) |
| Module registration into shell registry during startup | yes | no | yes (module instantiation/registration) | yes | yes | n/a | documented in `forge_panel_shell_spec.md` (section 7.1) and `tom_forge_ui_testapp.md` (section 3.2) |
| Sequential module activation in dependency order (`module.activate(api)`) | yes | no | yes (each module implements activation) | yes | yes | yes | documented in `forge_panel_shell_spec.md` (section 7.1) and `forge_panel_shell_concept.md` (module lifecycle) |
| Shell collects module contributions (actions/views/editors/shortcuts) | yes | yes | yes (modules/components contribute) | yes | yes | yes | documented in `forge_panel_shell_spec.md` (section 7.1) and `tom_forge_full_integration.md` (section 4.2, Phase B) |
| Boot flow wiring (file system + shell module + app module + application layout + scaffold) | yes | no | yes (app modules) | yes | yes | yes | completed 2026-03-26 in `tom_forge_full_integration.md` (section 4.1, Phase A/E) |
| Shell service single-source wiring (`ForgeActionRegistry`, `ForgeShortcutManager`, `ForgeSystemState`, settings) | yes | yes | yes (module actions/shortcuts) | yes | yes | yes | completed 2026-03-26 in `tom_forge_full_integration.md` (section 4.2, Phase B/C) |
| Startup hydration and runtime preference synchronization | yes | yes | yes (module/editor settings consumers) | yes | partial | partial | completed 2026-03-26 in `tom_forge_full_integration.md` (Phase C) |
| Layout/editor state restoration before running | yes | yes | yes (editor state adapters) | yes | no | no | documented in `forge_panel_shell_spec.md` (section 7.1) |
| Graceful shutdown flow (dirty prompts, cancellable shutdown, save state) | yes | yes | yes (module/editor dirty + save handlers) | yes | no | no | documented in `forge_panel_shell_spec.md` (section 7.1) |
| Reverse-order module deactivation during shutdown (`module.deactivate()`) | yes | no | yes (each module implements deactivation) | yes | no | no | documented in `forge_panel_shell_spec.md` (section 7.1) and `forge_panel_shell_concept.md` |
| Startup boundary: modules registered at startup (no hot-load/unload flow in test app) | yes | no | no | yes (current scope) | yes | yes | documented in `tom_forge_ui_testapp.md` (non-goals + module structure) |

## 2. Workspace Model and File/Revision Boundaries
This section is intended to cover workspace root handling, file-system scope, `.forge/` state/revision boundaries, and workspace-level assumptions. Include checks for core Forge behavior and module/component behavior when operating on workspace data.

- [x] Section completed (finished on 2025-07-18T09:45:00+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Workspace root is the primary runtime boundary (`workspaceRoot`/`workspaceRootUri`) | no | no | no | yes | yes | yes | `DefaultSystemState.workspaceRootPath`, `TestAppModule`/`ForgeAppModule` receive `workspaceRootUri`, file explorer uses root |
| `.forge` workspace folder stores state and revisions in workspace scope | no | no | no | yes | no | no | documented only; `.forge` folder not created at runtime |
| Workspace state stays local in both config modes (never in `~/.forge`) | no | no | no | yes | partial | n/a | `ForgePreferencesService.getConfigDirectory()` returns `.forge` path but not exercised |
| Config mode split (`local` vs `split`) separates config location from workspace state | no | no | no | yes | yes | n/a | `ForgeConfigMode` enum and `ForgeConfigurationDialog` implemented |
| Startup workspace detection and selection (remembered path, walk-up `.forge`, CWD fallback) | no | no | no | yes | partial | n/a | `lastWorkspacePath` remembered; walk-up `.forge` detection not implemented |
| Standard workspace state files (`state/layout.json`, `state/open-editors.json`, `state/editors/{uri-hash}.json`) | no | yes | yes (editor state adapters) | yes | no | no | not implemented; layout state in memory only |
| Revision snapshots under `.forge/revisions/{uri-hash}/` with content snapshots | no | yes | yes (components triggering saves) | yes | no | no | not implemented |
| Undo history persisted under `.forge/undo/{uri-hash}/` boundary | no | yes | yes (editor undo producers) | yes | no | no | in-memory `UndoHistory` only; no persistence |
| All file operations are routed through `ForgeFileSystem` (read/write/save/list/watch/edit) | yes | yes | yes (module/component file workflows) | yes | yes | partial | `ForgeFileSystem` interface with `RealFileSystem`/`MemoryFileSystem`; file explorer uses it |
| Revisioning behavior on save (dedupe identical saves, prune old revisions) | no | yes | yes (save semantics in components) | yes | no | no | not implemented |
| Workspace `.forge` should be suggested for `.gitignore` | no | no | no | yes | no | n/a | not implemented |
| Test app workspace boundary uses seeded `MemoryFileSystem` virtual root | yes | yes | yes (module views/editors in test app) | yes (test app scope) | yes | yes | `DefaultShellApi.withDefaults(fileSystemSeed:...)` creates `MemoryFileSystem` |

## 3. Application Model and Multi-Application Switching
This section is intended to cover application definitions, switching behavior, in-memory retention of inactive applications, and app-specific layout/action contexts. Include checks for global Forge behavior and module/component behavior across application switches.

- [x] Section completed (finished on 2025-07-18T10:02:00+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| ForgeApplication model defines named app-level layout and metadata | no | no | no | yes | yes | n/a | `ForgeApplication` in `forge_application.dart` with title, icon, layout, isActive |
| Multiple applications exist in one shell instance | no | no | no | yes | partial | n/a | `_applications` list in `DefaultSystemState`; no multi-app demo in test app |
| Application switcher dropdown selects active application | no | no | no | yes | yes | n/a | `PopupMenuButton` in `forge_shell_scaffold.dart` title bar center cluster |
| Switching keeps previous applications alive in memory | no | no | no | yes | no | n/a | `setActiveApplication` exists but no lifecycle management implemented |
| Inactive app layout state is preserved in memory | no | no | no | yes | no | n/a | not implemented |
| Default behavior is no save-on-switch; optional save-on-deactivate support | no | yes | yes (per app policy) | yes | n/a | n/a | not implemented; no switch lifecycle |
| Active application tracked in system state/controller | no | no | no | yes | yes | n/a | `activeApplication` getter in `DefaultSystemState` |
| Per-application layout persistence in `.forge/state/layout.json` | no | yes | yes (app layout contributions) | yes | no | no | not implemented |
| Per-application open editor restoration via `.forge/state/open-editors.json` | no | yes | yes (editor components participate) | yes | no | no | not implemented |
| Modules can expose pre-configured applications | yes | no | yes (module-provided applications) | yes | no | n/a | `ForgeModule` interface lacks `applications` getter |
| Application layouts reference module-owned components | yes | yes | yes (module components wired into app layout) | yes | yes | yes | `ApplicationLayout.leftPanel/rightPanel/bottomPanel` contain `ForgeView` sections from modules |
| App switch lifecycle is represented in shell event stream and architecture | no | yes | yes (components react to app switch/focus) | yes | no | no | not implemented; no shell events for app switching |

## 4. Module Integration and Ownership Boundaries
This section is intended to cover module contracts, registration, module-provided views/editors/actions/shortcuts, and module-to-shell ownership boundaries. Include checks for shell-level module orchestration and per-module conformance.

- [x] Section completed (finished on 2025-07-18T10:15:00+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Module contract defines lifecycle and contributions (`activate/deactivate`, editors, views, actions, shortcuts) | yes | no | yes | yes | yes | yes | `ForgeModule` abstract class with all contract methods; `TomForgeShellModule` and `TestAppModule` implement it |
| Components are owned by exactly one module | yes | yes | yes | yes | yes | yes | modules maintain their own `_editors`, `_views` lists; editors registered via `TomForgeShellModule.registerMdEditor()` etc |
| Shell discovers components through configured modules (no global component registry) | yes | yes | yes | yes | yes | yes | `DefaultModuleRegistry.allModules` iterates modules; `DefaultLayoutController` finds editors via `_moduleRegistry.allModules` |
| Shell module ownership boundary: built-in views belong to `TomForgeShellModule` | yes | yes | yes (for custom module boundaries) | yes | yes | yes | `TomForgeShellModule` owns MD/Dart/YAML editor adapters; `TestAppModule` owns views/actions/shortcuts |
| Module integration is compile-time and type-safe (no dynamic loading/marketplace sandbox) | yes | no | yes | yes | yes | n/a | modules are instantiated in `main.dart` and registered statically |
| Module cross-references are type-safe (`modules.get<T>()`) | yes | no | yes | yes | yes | partial | `DefaultModuleRegistry.get<T>()` implemented; used in `forge_yaml_editor.dart` for `TomForgeShellModule` access |
| Module activation order uses declaration order during startup | yes | no | yes (module dependency-safe design) | yes | yes | n/a | `main.dart` shows `TomForgeShellModule.activate()` then `TestAppModule.activate()` in sequence |
| Module deactivation order is reverse declaration order at shutdown | yes | no | yes | yes | no | n/a | `ForgeModule.deactivate()` defined but no reverse-order shutdown logic implemented |
| Module contributions are published to shell registries (actions/shortcuts/views/editors) | yes | yes | yes | yes | yes | yes | `DefaultModuleRegistry.register()` calls `actionRegistry.registerAction()` and `shortcutManager.rebind()` |
| Module failure isolation boundary (one failing module must not crash shell) | yes | no | yes (defensive module code) | yes | no | n/a | `DefaultModuleRegistry.register()` rethrows errors; no isolation boundary |
| Module declaration order influences editor resolution priority | yes | yes | yes | yes | yes | yes | `DefaultLayoutController` iterates `_moduleRegistry.allModules` to find matching editor |
| Module integration acceptance includes required actions/shortcuts/views/status items | yes | yes | yes | yes | yes | yes | `TestAppModule` demonstrates all: views, actions, shortcuts, statusBarItems contributions |

## 5. Component Model (Views and Editors)
This section is intended to cover component contracts (`title`, `icon`, `buildMain`, `buildCopy`, size hints), view vs editor semantics, and component identity. Include checks at shell level and per component implementation in each module.

- [x] Section completed (finished on 2025-07-18T10:25:00+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Core `ForgeComponent` contract: observable `title`, optional `titleExtension`, `icon`, `isEditor`, `sizeHints`, `supportsMultiRender` | no | yes | yes | yes | yes | yes | `ForgeComponent` abstract class in `forge_component.dart` with all properties; all editors/views implement them |
| Rendering contract split: `buildMain(context)` vs `buildCopy(context)` | no | yes | yes | yes | yes | yes | Both methods defined in `ForgeComponent`; all adapters implement both |
| Component size hints contract (`minSize`, `preferredSize`, `maxSize`) guides layout behavior | no | yes | yes | yes | yes | yes | `ForgeComponentSizeHints` class; views use custom sizes (e.g., `ForgeProblemsView.sizeHints`) |
| View vs editor closability semantics are different by design | no | yes | yes | yes | yes | n/a | `isEditor` returns true for editors (closable), false for views; `forge_view.dart`, `forge_editor.dart` |
| Component identity model: editors by `Uri`, views by Dart `Type` | no | yes | yes | yes | yes | yes | Editors have `Uri get uri`; views are singletons by type (one Explorer, one Outline, etc.) |
| Multi-render model: shared data state with per-copy UI state | no | yes | yes | yes | partial | partial | `supportsMultiRender` exists; `buildCopy` delegates to `buildMain`; no per-copy state separation |
| UI copy lifecycle: main component + additional UI copies, shift-drag copy behavior | no | yes | yes | yes | no | no | not implemented; no shift-drag copy logic |
| File-opening editor resolution uses `canHandle(uri)` then `canHandleContent(uri, bytes)` | yes | yes | yes | yes | yes | yes | Both methods in `ForgeEditor`; `DefaultLayoutController` iterates modules calling `canHandle` |
| Schema editor specialization: `canHandle` returns `inspect`, decision in `canHandleContent` | yes | yes | yes | yes | partial | partial | `canHandleContent` exists but yaml/dart editors don't use `inspect` flow; always accept by extension |
| Concrete component contract evidence in test module (`ForgeTestTextEditor` title/icon/uri/canHandle) | yes | yes | yes | yes | yes | yes | `ForgeMdEditor`, `ForgeDartEditor`, `ForgeYamlEditor` all implement full contract |
| Module contribution surfaces expose typed `List<ForgeEditor>` and `List<ForgeView>` | yes | no | yes | yes | yes | yes | `ForgeModule` interface has `editors` and `views` getters returning typed lists |
| Integration scenario evidence validates editor/view component behavior by file type | yes | yes | yes | yes | yes | yes | File explorer opens .dart/.md/.yaml in appropriate editors via `canHandle` resolution |

## 6. Layout Topology and Panel Composition
This section is intended to cover title bar, menu bar, left/right/middle/bottom panel structure, and status bar composition. Include checks for the Forge shell layout engine and per-module panel content integration.

- [x] Section completed (finished on 2025-07-18T10:35:00+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Top-level shell frame includes title bar, menu bar, panel areas, and status bar | no | no | no | yes | yes | yes | `ForgeShellScaffold` implements Column with TitleBar, MenuBar, panels, StatusBar per concept §2 |
| Left panel topology: full-height side panel with vertical icon-strip tabs and accordeon content | no | yes | yes | yes | yes | yes | `ForgeSidePanelWidget` with `_buildVerticalIconStrip`, `_AccordeonLayout` |
| Right panel mirrors left panel topology (icon strip + accordeon tabs) | no | yes | yes | yes | yes | yes | Same `ForgeSidePanelWidget` with `IconStripPosition.right` |
| Middle topology supports 1-4 editor panels with per-panel editor tab bars | no | yes | yes | yes | yes | yes | `_buildMiddleArea` creates panels with `ForgeEditorTabBar` per panel |
| Bottom topology spans between side panels and uses tab bar + accordeon sections | no | yes | yes | yes | yes | yes | `_buildBottomPanel` uses `ForgePanelWidget` between side panels |
| Configuration tab topology is fixed/pinned at bottom of left icon strip | no | no | no | yes | yes | n/a | `ForgeSidePanelWidget.showConfigTab` and `_buildConfigTab` implement pinned config tab |
| Side/bottom panels share accordeon section-hosting composition model | no | yes | yes | yes | yes | yes | `_AccordeonLayout` and `_AccordeonSection` used by all side/bottom panels |
| Panel composition supports drag flows: accordeon reordering, tab moves between side/bottom, middle drop zones for split/add tab | no | yes | yes | yes | no | no | not implemented; no drag/drop between panels |
| Menu bar composition is fixed top-level structure populated from shell/modules/components | yes | yes | yes | yes | yes | yes | `ForgeMenuBar` with File/Edit/View/Help menus, actions from `ForgeActionRegistry` |
| Status bar composition aggregates dynamic items and progress indicators | yes | yes | yes | yes | yes | yes | `ForgeStatusBarWidget` + `DefaultStatusBarController`; modules contribute `StatusBarItem`s |
| Platform composition rule: menu bar native placement differs on macOS vs Windows/Linux | no | no | no | yes | no | n/a | not implemented; menu bar always in-app widget (not native) |
| Implementation evidence: test app shell scaffold and panel/status widgets provide open/close/resize composition behavior | yes | yes | yes | yes | yes | yes | `ForgeShellScaffold` in test app with panel toggles, resize handles, status bar |

## 7. Panel Resizing and Splitter Behavior
This section is intended to cover draggable splitters, min/max constraints, hover/drag affordances, and resize persistence expectations. Include checks for shell splitter mechanics and module/component behavior under panel size changes.

- [x] Section completed (finished on 2026-03-30T13:45:00+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Left panel width is user-adjustable via dedicated drag handle | no | no | no | yes | yes | n/a | `_ResizeHandle` in `forge_shell_scaffold.dart` with `_resizeLeftPanel` |
| Right panel width is user-adjustable via dedicated drag handle | no | no | no | yes | yes | n/a | `_ResizeHandle` in `forge_shell_scaffold.dart` with `_resizeRightPanel` |
| Bottom panel height is user-adjustable via top-edge drag handle | no | no | no | yes | yes | n/a | `_ResizeHandle` in `forge_shell_scaffold.dart` with `_resizeBottomPanel` |
| Middle area supports multiple panels separated by draggable dividers | no | no | no | yes | partial | n/a | multiple panels via `middlePanels` but `VerticalDivider(width: 1)` is static, not draggable |
| Resizing is real-time during drag (no animation), with reset animation on double-click | no | no | no | yes | partial | n/a | real-time drag works via `onDragUpdate`; double-click reset not implemented |
| Minimum size constraints exist (for example middle panel minimum width) | no | yes | yes (component/module layouts must respect bounds) | yes | yes | n/a | `ForgeDimensions` defines min/max for left/right/bottom panels; `.clamp()` in resize methods |
| Splitter hit target and visual thickness are explicitly defined | no | no | no | yes | yes | n/a | `ForgeDimensions.dividerHitTarget=14`, `dividerVisual=2`; `_ResizeHandle` uses these constants |
| Accordeon section splitters support manual separator drag when sections are pinned open | no | yes | yes | yes | no | no | accordeon sections have fixed `height: 200`; no drag resize between sections |
| Layout controller is responsible for resize bounds and restore behavior | yes | no | yes (module interactions via layout API) | yes | yes | n/a | `DefaultLayoutController.setPanelSize` with `.clamp()` to enforce bounds |
| Panel size and layout changes persist through layout persistence in core shell architecture | no | no | no | yes | no | n/a | no persistence; sizes reset on app restart |
| Implementation evidence in test app uses explicit drag-handle dividers and resizable/collapsible panels | yes | yes | yes | yes | yes | n/a | test app has left/right/bottom panels with `_ResizeHandle` dividers and toggleable visibility |
| Test-app scope notes that restart persistence is intentionally not implemented there (while core concept specifies persistence) | no | no | no | yes (scope-specific) | yes | n/a | persistence not implemented (matches test-app non-goals documentation) |

## 8. Tab Systems and Editor/View Tab UX
This section is intended to cover tab creation, activation, close behavior, hover feedback, dirty indicators, and tab overflow behavior in middle and auxiliary panels. Include checks for shell tab controls and per-component tab title/state updates.

- [x] Section completed (finished on 2026-03-30T13:50:00+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Distinct tab systems exist: middle editor tab bar and side/bottom panel tab bars | no | yes | yes | yes | yes | n/a | `ForgeEditorTabBar` for middle; `ForgeSidePanelWidget` icon strip + `ForgePanelWidget` horizontal tabs for side/bottom |
| Tab creation on file open adds editor tab in active middle panel | yes | yes | yes | yes | yes | yes | `DefaultLayoutController.openFile` creates editor, adds to `_middlePanels`, sets active |
| Tab activation selects one active component per panel | no | yes | yes | yes | yes | yes | `DefaultSystemState.activeEditor` + `setActiveEditor`; shell passes to `ForgeEditorTabBar.activeEditor` |
| Tab close behavior differs by type (all editors closable; view main vs copy rules) | no | yes | yes | yes | partial | n/a | editors closable via `onClose`; view main/copy rules not implemented |
| Close-dirty workflow prompts save/discard/cancel on tab close | yes | yes | yes | yes | no | no | not implemented; `closeEditor` does not check dirty state |
| Dirty state is reflected in tab UX and tracked in system state (`dirtyEditors`) | yes | yes | yes | yes | yes | yes | `isDirty ? '$title *' : title` in tab; `DefaultSystemState.dirtyEditors` updated on close |
| Tab keyboard UX is defined (`Left/Right`, `Enter`, `Delete`) | no | no | no | yes | no | no | not implemented; no keyboard shortcuts for tab navigation |
| Accessibility semantics for tab system are defined (`tablist`, `tab`, `tabpanel`) | no | no | no | yes | no | no | not implemented; no `Semantics` widgets in tab bar |
| Tab overflow behavior: horizontal scrolling with wheel and overflow arrows | no | no | no | yes | partial | n/a | `ListView(scrollDirection: Axis.horizontal)` provides scroll; no overflow arrows |
| Tab visual UX includes active/inactive/hover/indicator theme tokens | no | no | no | yes | yes | n/a | `tabBackground` uses `surfaceContainerHighest`/`surfaceContainer`; active has primary top border |
| Drag-tab UX supports moving tabs across panels and split-editor scenarios | no | yes | yes | yes | no | no | not implemented; no `Draggable`/`DragTarget` in tab bar |
| Implementation evidence includes dedicated tab widgets and tab-management controller logic | yes | yes | yes | yes | yes | yes | `ForgeEditorTabBar` widget; `DefaultLayoutController` with `closeEditor`, `openFile`, `splitMiddlePanel` |

## 9. Accordeon Section Behavior
This section is intended to cover section expand/collapse rules, pinning, multi-open behavior, section sizing/sharing, and empty/drop placeholder behavior. Include checks for shell accordeon mechanics and per-view section compatibility.

- [x] Section completed (finished on 2026-03-30T13:55:00+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Accordeon is the section container model for left/right/bottom panel tabs | no | yes | yes | yes | yes | n/a | `_AccordeonLayout` and `_AccordeonSection` in `forge_panel_widget.dart` |
| Section open/closed presentation is defined (triangle direction and title orientation) | no | no | no | yes | yes | n/a | `Icons.arrow_drop_down`/`arrow_right` based on `isExpanded`; title in UPPERCASE |
| Default mutual exclusivity: opening one section collapses others in same tab | no | yes | yes | yes | yes | n/a | `_toggleSection` removes unpinned sections when opening: `_expandedSections.removeWhere((i) => !_pinnedSections.contains(i))` |
| Pinning enables multi-open behavior in a tab | no | yes | yes | yes | yes | n/a | `_pinnedSections` set + `_togglePin` method; pinned sections preserved when others open |
| Pinned-open sections share available space with size-hint awareness | no | yes | yes | yes | no | no | fixed `height: 200` for all sections; no dynamic size-hint distribution |
| Manual separator dragging between pinned-open sections is supported | no | yes | yes | yes | no | no | not implemented; no divider drag handles between sections |
| Single-section tabs are always open and non-collapsible | no | yes | yes | yes | yes | n/a | `if (widget.sections.length == 1) return widget.sections.first.buildMain(context)` |
| Empty sections must render placeholders for drag/drop targets | no | yes | yes | yes | no | no | no placeholder logic for empty sections |
| Empty accordeon tabs persist as placeholders when sections are moved away | no | yes | yes | yes | no | no | no drag/move implemented; no placeholder persistence |
| Section-header controls (pin and close placement) are standardized | no | yes | yes | yes | partial | n/a | pin button in header; no close button on sections |
| Accordeon keyboard controls are specified (`Up/Down`, `Enter/Space`) | no | no | no | yes | no | no | no keyboard navigation for accordeon (only for command palette) |
| Implementation/test evidence exists for expand/collapse and pinned state behavior | yes | yes | yes | yes | yes | n/a | `_AccordeonLayout`, `_AccordeonSection` widgets with expand/pin state management |

## 10. Drag-and-Drop Layout Operations
This section is intended to cover drag move/copy semantics, drop zones, panel split creation, and UI-copy behavior (including SHIFT-copy flows). Include checks for shell drag/drop infrastructure and per-component/module support.

- [x] Section completed (finished on 2026-03-30T14:00:00+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Core layout supports drag-and-drop rearrangement of components between panels | no | yes | yes | yes | no | no | no `Draggable`/`DragTarget` widgets in panel code |
| Regular drag performs move semantics (original location vacated) | no | yes | yes | yes | no | no | not implemented |
| `SHIFT+drag` performs UI-copy semantics (original stays, copy created) | no | yes | yes | yes | no | no | not implemented |
| Middle-panel drop zones support add-to-tabbar and split-left/right/top/bottom operations | no | yes | yes | yes | no | no | no drop zones implemented (only `ForgeAnimations.dropZoneFade` constant exists) |
| Split creation is bounded by middle panel count limits | no | no | no | yes | partial | n/a | `splitMiddlePanel` adds panels; no max limit enforcement found |
| Section-header drag supports reorder within tab and moves between tabs/panels | no | yes | yes | yes | no | no | not implemented |
| Entire side/bottom tabs can be moved between left/right/bottom panels | no | yes | yes | yes | no | no | not implemented |
| Middle panels intentionally use component tabs (side/bottom whole-tab drag not allowed into middle) | no | no | no | yes | n/a | n/a | no drag implemented; restriction documented only |
| Empty accordeon/tab placeholders persist to keep valid future drop targets | no | yes | yes | yes | no | no | no placeholder persistence for drag targets |
| Drag feedback includes proxy visuals, grabbing cursor, delayed zone reveal, valid/invalid flash states | no | no | no | yes | no | no | not implemented |
| Drop-zone color semantics are explicitly themed (`highlight`, `valid`, `invalid`) | no | no | no | yes | no | no | not implemented (constants may exist but no widgets use them) |
| Implementation/test evidence covers move and copy (`moveComponent`, `copyComponent`) and split flows | yes | yes | yes | yes | partial | n/a | `splitMiddlePanel` exists; no `moveComponent`/`copyComponent` found in lib |

## 11. Navigation and Command Surfaces
This section is intended to cover menu bar, command palette, title-bar search entry behavior, back/forward navigation hooks, and command parity across entry points. Include checks for shell command routing and per-module command exposure.

- [x] Section completed (finished on 2026-03-30T16:45:00+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Title-bar search field doubles as quick command/search entry surface | no | no | no | yes | partial | n/a | `_buildTitleBar` has search icon + text container but displays app title only; not functional search field |
| Command palette is a first-class global entry point (`F1`, `Cmd+P`) | no | no | no | yes | yes | n/a | `ForgeCommandPalette` fully implemented with search/filter/keyboard nav; `Cmd+P`/`Ctrl+P` bound; F1 not bound |
| Menu bar is fixed top-level structure with module/component-populated entries | yes | yes | yes | yes | partial | n/a | `ForgeMenuBar` implemented with File/Edit/View/Help; modules do not dynamically populate menu entries |
| Cross-platform menu surface behavior is defined (macOS system menu, Windows/Linux in-window) | no | no | no | yes | partial | n/a | In-window menu only; no macOS system menu integration |
| `Go` surface includes navigation actions (go-to targets and back/forward) | yes | yes | yes | yes | no | no | No "Go" menu exists; back/forward only in title bar (disabled buttons) |
| Back/forward navigation hooks are delegated through focused component history manager | yes | yes | yes | yes | partial | n/a | `ComponentHistoryManager` interface exists; title bar has disabled back/forward buttons; not wired to components |
| Command execution routes through action objects with dynamic visibility/enabled state | yes | yes | yes | yes | yes | n/a | `ForgeAction` model with `ForgeActionRegistry`, `executeAction` pipeline works |
| Dialog-driven command UX supports quick pick/input/file picker flows | yes | yes | yes | yes | yes | n/a | `DefaultDialogManager` with `showQuickPick`, `showInputBox`, `onOpenDialog`, `onSaveDialog` callbacks |
| Explicit "Open with" command surface available from context menu and command palette | yes | yes | yes | yes | partial | n/a | `openFileWith()` API exists in layout controller; no explicit "Open With" entry in context menu or palette |
| Command parity objective across menu, palette, and shortcuts is required | yes | yes | yes | yes | partial | n/a | Actions shared via registry; menu has hardcoded entries; palette dynamically populated from registry |
| Implementation evidence: menu handlers switched from placeholders to real action dispatch | yes | no | yes | yes | yes | n/a | `_executeActionOrInform` calls `shellApi.executeAction` with real action IDs |
| Implementation evidence: command palette source unified to action registry with fallback dedupe | yes | no | yes | yes | yes | n/a | `ForgeCommandPalette._buildCommandList` iterates `actionRegistry.allActions` and module actions |

## 12. Actions and Shortcut Framework
This section is intended to cover action registration, enable/visible state logic, shortcut binding/effective shortcut display, platform-specific modifier behavior, and conflict handling. Include checks at Forge action/shortcut manager level and per-module/per-component action sets.

- [x] Section completed (finished on 2026-03-30T16:50:00+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Action model is object-based (no string-ID routing) with explicit menu location and optional shortcut | yes | yes | yes | yes | yes | yes | `ForgeAction` class with `id`, `label`, `menu`, `defaultShortcut` fields; editors register via `_integration.registerAction()` |
| Action execution pipeline supports undo object return and undo callback integration | yes | yes | yes | yes | yes | yes | `ForgeAction.execute` returns `Object?`; `undo` callback field; `DefaultUndoManager` with `UndoEntry`; editors have `_undoStack/_redoStack` |
| Dynamic action state evaluation (`isEnabled`, `isVisible`) is re-evaluated against system state | yes | yes | yes | yes | yes | yes | `ForgeAction` has `isEnabled()` and `isVisible()` callbacks; editors use e.g., `isEnabled: () => _undoStack.isNotEmpty` |
| Actions from modules/components are collected into shell command/menu surfaces | yes | yes | yes | yes | yes | n/a | `ForgeModule.actions` getter; `ForgeCommandPalette._buildCommandList` iterates `actionRegistry.allActions` and `module.actions` |
| Shortcut bindings are collected centrally from modules/components | yes | yes | yes | yes | yes | n/a | `StubShortcutManager.loadBindings`; `DefaultModuleRegistry` calls `shortcutManager.rebind` for module shortcuts |
| Shortcut conflict detection is supported and explicitly surfaced | no | no | no | yes | yes | n/a | `ForgeShortcutManager.conflictsWith(key)` returns conflicting binding if exists; `StubShortcutManager` implements it |
| Runtime shortcut rebinding and reset-to-default are supported | yes | yes | yes | yes | yes | n/a | `ForgeShortcutManager.rebind()` and `resetToDefault()` implemented in `StubShortcutManager` |
| Effective shortcut display source comes from `ForgeShortcutManager` bindings | no | no | no | yes | yes | n/a | `ForgeCommandPalette` calls `shellApi.shortcuts.getBinding(action.id)?.key` for effective shortcut display |
| Platform-specific primary-modifier shortcut behavior is required (Cmd vs Ctrl) | no | no | no | yes | yes | yes | `ForgeShortcutKey.usePrimaryModifier`; shell uses `defaultTargetPlatform == TargetPlatform.macOS` for `useMetaPrimary` |
| Two-key trigger-menu shortcut system is defined (Shift+Cmd/Ctrl+key popup) | yes | yes | yes | yes | no | no | Not implemented; documented only |
| Duplicate action ID policy/conflict logging is part of framework hardening | yes | no | yes | yes | no | no | `DefaultActionRegistry` silently overwrites on duplicate ID; no logging or warning |
| Implementation/test evidence includes `ForgeShortcutManager` tests, platform shortcut tests, and parity matrix requirements | yes | no | yes | yes | partial | n/a | `forge_shortcut_key_test.dart` exists; `forge_action_test.dart` covers shortcuts; no dedicated ShortcutManager test file |

## 13. Focus Management and Accessibility
This section is intended to cover keyboard navigation order, focus visibility, focus trapping in modal surfaces, screen-reader semantics, and hit-target usability. Include checks for shell accessibility baseline and per component/module accessibility conformance.

- [x] Section completed (finished on 2026-03-30T17:00:00+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| System state exposes focused component, panel location, and focus-derived editor/selection context | yes | yes | yes | yes | yes | yes | `DefaultSystemState` exposes `focusedComponent`, `focusedPanelLocation`, `focusedSelectedText`; editors set via `setFocusedComponent` |
| Focus lifecycle emits explicit events (`onFocusChanged`, selection-change + window-focus signals) | yes | yes | yes | yes | yes | yes | `onFocusChanged` stream (FocusChangeEvent), `onWindowFocusChanged` stream, `onSelectionChanged` stream all implemented |
| Keyboard focus navigation APIs are defined (`focusNextPanel`, `focusPreviousPanel`, `focusActiveComponent`, `focusComponent`) | yes | yes | yes | yes | partial | n/a | Panel focus via Cmd+1/2/3/4 shortcuts (`setFocusedPanelLocation`); no `focusNextPanel`/`focusPreviousPanel` API |
| Focus ring accessibility baseline is defined (visible on keyboard focus, theme-driven color/width) | no | yes | yes | yes | no | no | No custom focus ring implementation; relies on Flutter defaults |
| Mouse-only focus indicator suppression (`focus-visible` equivalent behavior) is required | no | yes | yes | yes | no | no | Not implemented |
| Modal surfaces trap focus (dialogs, shortcut popup, quick pick) until dismissed | no | yes | yes | yes | partial | n/a | Command palette uses `FocusNode.requestFocus()` + Escape dismiss; no explicit `FocusTrap` widget |
| Screen-reader semantics roles are defined for tab infrastructure (`tablist`, `tabpanel`) | no | yes | yes | yes | partial | n/a | `Semantics` used in `ValidationBadge`, `ActionButton`, `CollapseToggle`; no `tablist`/`tabpanel` roles on tabs |
| Accessibility announcement pipeline is defined with polite/assertive modes via `SemanticsService` | yes | yes | yes | yes | no | no | Not implemented; no `SemanticsService.announce` calls found |
| Hit-target usability baseline is specified for splitters (8px interaction zone) | no | yes | yes | yes | yes | n/a | `ForgeDimensions.dividerHitTarget = 14` px with `HitTestBehavior.opaque` (exceeds 8px baseline) |
| High-contrast theme support is required as shell-level accessibility baseline | yes | yes | yes | yes | no | no | No high-contrast theme variant implemented |
| Accessibility baseline includes keyboard navigation + screen-reader support in shell requirements | yes | yes | yes | yes | partial | partial | Keyboard shortcuts for panels/palette work; editors have FocusNode; no screen-reader roles for shell chrome |
| Integration/test evidence includes high-contrast widget tests and parity validation checkpoints | yes | no | yes | yes | no | no | No high-contrast or accessibility tests found |

## 14. Theme, Visual Language, and Interaction Feedback
This section is intended to cover shell theming hooks, color/contrast expectations, active/hover/drag visual states, and consistency of feedback patterns. Include checks for global Forge theming and per-module/component visual integration.

- [x] Section completed (finished on 2026-03-30T17:20:00+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Shell theme is exposed as a dedicated extension (`ForgeShellTheme`) with shell-level visual tokens | yes | no | yes | yes | no | no | documented in `forge_panel_shell_spec.md` theme extension section and `forge_panel_shell_concept.md` parity matrix |
| Theme configuration is part of persisted shell/application settings (`ThemeConfig theme`) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` settings model (`ThemeConfig`) |
| Appearance controls are part of command/navigation surface (`View` menu includes appearance) | no | no | no | yes | no | no | documented in `forge_panel_shell_concept.md` command surfaces (`View` row) |
| Light/dark/high-contrast theme variants are explicitly defined and expected | no | yes | yes | yes | partial | partial | `DartEditorTheme.dark()`/`.light()` with full color sets; `MdBasicTheme` light variant; `YamlEditorTheme` dark/light; no shell-level `ForgeShellTheme` variants; no high-contrast variant |
| High-contrast mode changes visual behavior and reduces motion (0ms animations, static progress) | no | yes | yes | yes | no | no | documented in `forge_panel_shell_spec.md` high-contrast behavior rules |
| Animation timing/curve system is standardized for panel, tab, popup, toast, and feedback transitions | yes | yes | yes | yes | yes | partial | `ForgeAnimations` class in `forge_shell_scaffold.dart` with `panelTransition`/`tabTransition`/`dropZoneFade`/`shortcutPopupIn`/`notificationIn` and curves `panelCurve`/`tabCurve`/`popupCurve`; used in shell panels; editors use own inline `Curves.easeOut`/`easeInOut` instead of shared constants |
| Drag feedback is explicitly styled (semi-transparent proxy, cursor change to grabbing, drop-zone timing) | no | yes | yes | yes | partial | partial | md_editor `_DraggableListBlock`: `Material(elevation:4)` drag proxy, `Opacity(0.35)` ghost, accent-colored drop borders; md_tree_view uses `Draggable`/`DragTarget`; md_table_overlay has column/row drag; no `SystemMouseCursors.grabbing`; no shell-level drag feedback |
| Drop-zone highlight style is theme-bound (`dropZoneHighlight` token and opacity rules) | no | yes | yes | yes | partial | partial | `ForgeAnimations.dropZoneFade` constant exists (100ms); md_editor drop targets use `theme.accent` border; no dedicated `dropZoneHighlight` shell-level token; editor-level only |
| Severity-driven visual feedback for diagnostics is standardized (background tint, border, icon) | yes | yes | yes | yes | yes | yes | `DiagnosticColors` class with `.dark()`/`.light()` (error/warning/info/hint colors); `severityColor` + squiggly underline painter in `dart_code_editor.dart`; `_severityColor` tint in `md_quick_fix_menu.dart` |
| Highlight feedback patterns are defined for search/selection/decorations in editor and explorer contexts | yes | yes | yes | yes | yes | yes | `EditorColors.selection` in dart editor (dark `#264F78`, light `#ADD6FF`); `MdBasicTheme.selection` in md_search_panel and tree_view; `YamlEditorThemeColors.selectionColor` in yaml tree nodes; `TreeTheme.selectionColor` in shared tree_view |
| Status bar visual feedback supports context-sensitive active/inactive item visibility (`isActive`) | yes | yes | yes | yes | yes | partial | `StatusBarItem.isActive(ForgeSystemState)` function; `ForgeStatusBarWidget` renders left/center/right items; `ForgeStatusBarController` aggregates from modules; test app creates sample items; md_editor has own `MdEditorStatusBar`; shell `isActive` filtering not visually applied in widget build |
| Theme and visual-language implementation evidence includes golden tests for default/dark/high-contrast shells | no | no | no | yes | no | no | documented in `forge_panel_shell_spec.md` golden tests (`shell_default`, `shell_dark`, `shell_high_contrast`) |

## 15. Dialogs, Notifications, and User Prompts
This section is intended to cover quick-pick/input dialogs, open/save dialogs, toast notifications, and user confirmation flows. Include checks for shell service behavior and module/component usage patterns.

- [x] Section completed (finished on 2026-03-30T17:35:00+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Dialog, notification, and progress services are first-class shell APIs (`dialogs`, `notifications`, `progress`) | yes | no | yes | yes | yes | partial | `ForgeShellApi` exposes `dialogs`/`notifications`/`progress`; `DefaultShellApi.create` wires `DefaultDialogManager`, `DefaultNotificationManager`, and `DefaultProgressManager` |
| Action flow supports user-driven dialogs for input/selection/file operations via dialog manager | yes | yes | yes | yes | no | no | `ForgeAction` execution exists but no actions call `shell.dialogs.*`; dialog manager callback hooks are unassigned |
| Quick pick interaction is defined (`showQuickPick`) for selection prompts | yes | yes | yes | yes | partial | no | `DefaultDialogManager.showQuickPick` implemented with callback hook and fallback return (`items.first.value`) |
| Input prompt interaction is defined (`showInputBox`) for text-based user input | yes | yes | yes | yes | partial | no | `DefaultDialogManager.showInputBox` implemented with callback hook and fallback return (`value`) |
| Open/save file dialog flows are defined (`showOpenDialog`, `showSaveDialog`) | yes | yes | yes | yes | partial | no | `DefaultDialogManager.showOpenDialog`/`showSaveDialog` implemented with callback hooks; no widget-layer binding found |
| "Open with" resolver prompt is defined with primary + additional editor options | yes | yes | yes | yes | no | no | only `ForgeSchemaEditor.schemaLabel` mentions "Open with"; no resolver prompt flow implementation found |
| Startup dialog flow is specified (workspace/config selection, remembered defaults, CLI bypass) | no | no | no | yes | partial | no | `WorkspaceWelcomePage` + `WorkspaceFolderSelector` implemented; persisted recent workspaces via `ForgePreferencesService`; no CLI bypass flow |
| Notification API supports info/warning/error message channels and optional user actions | yes | yes | yes | yes | yes | partial | `DefaultNotificationManager.showInformation/showWarning/showError` with optional actions; test app `help.about` triggers `showInformation` |
| Toast lifecycle/visual behavior is specified (appear/dismiss timing, overlay pattern, auto-dismiss) | no | yes | yes | yes | yes | partial | `ForgeNotificationOverlay` rendered by `ForgeShellScaffold`; manager auto-dismisses after `autoDismissDuration` (4s) |
| Error and recovery prompts are defined for file and save conflicts (modal, retry/cancel, merge options) | yes | yes | yes | yes | no | no | no implemented conflict/recovery prompt flow found |
| Dirty-close confirmation prompts (save / don't save / cancel) are explicitly required | yes | yes | yes | yes | no | no | `DefaultLayoutController.closeEditor/closeAllEditors` closes directly; no save/don't-save/cancel confirmation path |
| Test coverage expectations exist for dialog/notification/progress managers | yes | no | yes | yes | partial | no | widget tests instantiate scaffold with `DefaultNotificationManager`; no dedicated dialog/progress manager behavior tests in scanned packages |

## 16. Explorer and Workspace Search
This section is intended to cover file explorer loading behavior, path handling, reveal/open flows, search query execution, search result navigation, and large-workspace responsiveness. Include checks at shell service level and per-module view behavior.

- [x] Section completed (finished on 2026-03-30T17:48:00+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Explorer and Search are defined as shell module views with explicit responsibilities | yes | yes | yes | yes | yes | yes | `TestAppModule` registers `ForgeFileExplorerView` and `ForgeSearchView`; views are surfaced in shell panels via module view list |
| Explorer supports workspace file tree operations (open/rename/delete) and double-click open behavior | yes | yes | yes | yes | partial | partial | `ForgeFileExplorerView` loads tree and opens files on tap through `layoutController.openFile`; no rename/delete actions and no double-click handler |
| Explorer selection/hover state is exposed in system state for context-driven behaviors | yes | yes | yes | yes | partial | no | `DefaultSystemState` exposes `selectedExplorerItems` and `hoveredExplorerItem` with setters; explorer view does not set hover/selection state on interaction |
| Layout API includes explicit reveal flow (`revealInExplorer`) for navigation synchronization | yes | yes | yes | yes | yes | no | `DefaultLayoutController.revealInExplorer` implemented and sets selected explorer items; no usage sites found |
| File opening/resolution uses two-phase URI + content inspection (`canHandle`, `canHandleContent`) | yes | yes | yes | yes | partial | partial | `openFile` reads file content and resolves editor by extension/`canHandle`; `ForgeYamlEditor.canHandleContent` exists but layout resolver does not call `canHandleContent` |
| "Open with" flow is part of resolver behavior for ambiguous matches | yes | yes | yes | yes | no | no | `openFileWith` currently delegates directly to `openFile`; no resolver prompt/selection flow implemented |
| Search service API supports programmatic workspace queries and streaming (`search`, `searchStream`) | yes | yes | yes | yes | yes | partial | `ForgeSearchManager` + `DefaultSearchManager`/`RealSearchManager` implement `search` and `searchStream`; UI currently uses `search` path only |
| Search UI behavior includes grouped-by-file results, match highlighting, click-to-navigate, and result count | yes | yes | yes | yes | partial | partial | `ForgeSearchView` groups by file and opens files on match click; no explicit match-highlighting rendering and no result-count display |
| Search context is tracked in system state (`searchQuery`, search active state) | yes | yes | yes | yes | partial | no | `DefaultSystemState` has `searchQuery`/`isSearchActive` fields and setters; search view does not synchronize query/active state into system state |
| Explorer visual feedback supports file decorations via `ForgeFileDecorationManager` | yes | yes | yes | yes | no | no | `ForgeFileDecorationManager` and `DefaultFileDecorationManager` exist, but `ForgeFileExplorerView` does not consume decoration providers |
| Large-workspace responsiveness strategies exist for search (debounce, indexing, result cache with LRU eviction) | no | no | no | yes | no | no | documented in `forge_panel_shell_spec.md` performance strategies (`searchDebounce`, search index, search results cache) |
| Test coverage expectations include `ForgeSearchManager` service tests and explorer/open-file E2E flows | yes | yes | yes | yes | partial | partial | `tom_forge_core_test.dart` includes `DefaultSearchManager` unit tests (`search`, `searchStream`, filters); UI tests cover open-file flows, but no dedicated explorer E2E flow found |

## 17. Diagnostics, Problems, and Output Channels
This section is intended to cover diagnostic collection lifecycle, problem presentation, output channel behavior, and synchronization with editor/system state. Include checks for shell managers and per-module diagnostic/output producers.

- [x] Section completed (finished on 2026-03-30T17:58:00+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Shell API exposes dedicated diagnostics and output managers (`diagnostics`, `output`) | yes | no | yes | yes | yes | no | `ForgeShellApi` exposes `diagnostics` and `output`; `DefaultShellApi.withDefaultsAndFileSystem` wires `DefaultDiagnosticManager` and `DefaultOutputChannelManager` |
| Problems and Output are first-class shell views (aggregated diagnostics + channel logs) | yes | yes | yes | yes | yes | partial | `TestAppModule` registers `ForgeProblemsView` and `ForgeOutputView`; views are mounted in bottom panel tabs (`Problems`, `Output`) |
| Diagnostic lifecycle supports named collections via `createCollection` for producer isolation | yes | yes | yes | yes | partial | no | `DefaultDiagnosticManager.createCollection` and `DefaultDiagnosticCollection` exist; no module usage of `createCollection` found in scanned UI/editor packages |
| Diagnostic CRUD and URI-scoped queries are defined (`all`, `forUri`, `set`, `delete`, `clear`) | yes | yes | yes | yes | yes | no | `ForgeDiagnosticManager`/`ForgeDiagnosticCollection` APIs plus `DefaultDiagnosticManager` + collection implement `all`, `forUri`, `set`, `delete`, `clear` |
| System state synchronization includes aggregated diagnostic summary and diagnostics-changed events | yes | yes | yes | yes | partial | no | `DefaultSystemState` maintains `diagnosticSummary`, `diagnostics`, `onDiagnosticsChanged`, and `setDiagnostics`; no automatic bridge from `DefaultDiagnosticManager` into `DefaultSystemState` |
| Problems presentation supports severity-rich entries and click-to-navigate to source | no | yes | yes | yes | partial | partial | `ForgeProblemsView` shows severity icons/colors and click opens file via `layoutController.openFile(diag.uri)`; no line/column jump into editor location |
| Output channel manager supports channel lifecycle and write operations (`create/get/list`, `append`, `appendLine`, `clear`) | yes | yes | yes | yes | yes | no | `DefaultOutputChannelManager` and `DefaultOutputChannel` implement lifecycle and write/clear operations |
| Output view supports channel selection, scrollable logs, and timestamped/readable channel output | yes | yes | yes | yes | partial | no | `ForgeOutputView` supports channel dropdown + scrollable monospace logs; no timestamp rendering in channel output |
| Output UX behavior defines auto-scroll strategy and preserves user position when not at bottom | no | yes | yes | yes | no | no | `ForgeOutputView` has `ScrollController` but no auto-scroll/preserve-position logic implemented |
| Throughput and retention constraints are defined for output channels (ring buffer with line limits) | no | no | no | yes | no | no | documented in `forge_panel_shell_spec.md` output channel limits/performance table |
| Error/reporting flows integrate output logging with diagnostic emission for the same failure path | yes | yes | yes | yes | no | no | no code path found that emits diagnostics and output log entries together for the same failure scenario |
| Test coverage expectations include diagnostic manager, output channel manager, and Problems-view integration tests | yes | no | yes | yes | partial | no | `tom_forge_core_test.dart` covers `DefaultDiagnosticManager` and `DefaultOutputChannelManager`; no dedicated `ForgeProblemsView` integration tests found |

## 18. Status Bar and Context Signaling
This section is intended to cover status bar item contribution, placement, update cadence, and context-sensitive values (cursor/language/diagnostics/etc.). Include checks for shell aggregation and per-module/component status item quality.

- [x] Section completed (finished on 2026-03-30T18:08:00+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Shell API exposes a dedicated status-bar controller (`ForgeStatusBarController`) | yes | no | yes | yes | yes | no | `ForgeShellApi` exposes `statusBar`; `DefaultShellApi.withDefaultsAndFileSystem` wires `DefaultStatusBarController` |
| Status items are module-contributed (`ForgeModule.statusBarItems`) and shell-aggregated | yes | yes | yes | yes | yes | partial | `ForgeModule.statusBarItems` contribution point + `DefaultStatusBarController` aggregates module items; test module contributes multiple items |
| Status item visibility is context-driven via `isActive(ForgeSystemState)` callbacks | yes | yes | yes | yes | partial | no | `StatusBarItem` requires `isActive` callback and test module defines it, but `ForgeStatusBarWidget` does not filter on `isActive` |
| Reactive text updates use `ValueListenable<String>` (no manual refresh cycle) | yes | yes | yes | yes | yes | partial | `StatusBarItem.text` uses `ValueListenable<String>` and widget renders with `ValueListenableBuilder`; language/diagnostic values update from shell events |
| Placement model is explicit by alignment zones (`left`, `center`, `right`) | yes | yes | yes | yes | yes | no | `StatusBarAlignment` enum + `ForgeStatusBarWidget` segments left/center/right zones |
| Ordering within each alignment zone is controlled by item priority | yes | yes | yes | yes | yes | no | `DefaultStatusBarController` and `ForgeStatusBarWidget` sort by `priority` |
| Status items can be interactive (tap handler for context actions such as language switch) | yes | yes | yes | yes | partial | no | `StatusBarItem.onTap` exists and widget wraps items in `GestureDetector`; test module items do not provide tap actions |
| Context-signaling data sources include active editor cursor, language mode, encoding, and diagnostic summary | yes | yes | yes | yes | partial | partial | test module contributes cursor/language/encoding/diagnostic items; language + diagnostics update from shell state, cursor/encoding remain static placeholders |
| Dynamic visibility and content updates track focus/editor changes and system-state transitions | yes | yes | yes | yes | partial | partial | test module listens to `onEditorsChanged` and `onDiagnosticsChanged`; no focus/selection-driven cursor updates and no widget-level `isActive` filtering |
| Progress can signal in status bar region (or overlay), including high-contrast static-update mode | yes | no | yes | yes | partial | no | `ForgeProgressLocation` includes `statusBar`/`overlay` and progress manager accepts location; no status-bar progress rendering or high-contrast static mode implementation |
| Integration evidence requires module status items for cursor/language indicators | yes | yes | yes | yes | yes | partial | `TestAppModule` registers cursor + language status items and shell renders them; language is editor-driven, cursor currently not synchronized from editor context |
| Test coverage expectations include dedicated status bar controller tests and widget segments | yes | no | yes | yes | no | no | no `status_bar_test.dart` or dedicated status bar widget/controller tests found in repository test folders |

## 19. Terminal, Process, and Runtime Tooling Integration
This section is intended to cover terminal manager behavior, terminal lifecycle events, process/output integration, and module usage of runtime tooling services. Include checks for shell terminal infrastructure and module-level runtime interactions.

- [ ] Section completed (finished on 2026-03-30T06:31:54+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Shell API exposes runtime tooling services (`terminals`, `clipboard`, `environment`) | yes | no | yes | yes | no | no | documented in `forge_panel_shell_concept.md` `ForgeShellApi` services |
| Terminal view is a first-class shell module surface with bottom-panel integration | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` shell module table (`shellModule.terminal`) |
| Terminal backend model is PTY-based on desktop with support for multiple terminal tabs | no | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` terminal view description |
| Terminal manager supports creation with runtime options (`name`, `shellPath`, `cwd`) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` `ForgeTerminalManager.create` |
| Terminal lifecycle collection is defined (`terminals`, `activeTerminal`) for runtime state tracking | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` terminal manager contract |
| Terminal lifecycle events are defined (`onDidOpen`, `onDidClose`, `onDidChangeActive`) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` terminal event streams |
| Terminal interaction API supports command/input dispatch (`sendText`) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` `ForgeTerminal.sendText` |
| Terminal visibility/lifecycle operations are explicit (`show`, `close`, dispose semantics) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` `ForgeTerminal` interface |
| Runtime process and output integration is expected through terminal + output channel tooling | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` service locator/runtime stack and `forge_panel_shell_spec.md` terminal scenario |
| Environment service includes external runtime handoff (`openExternal(Uri)`) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` environment interface and `tom_forge_ui_testapp.md` environment behavior |
| Execution-monitor runtime surface is defined for live process/execution signaling | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` `shellModule.execution` notes |
| Test coverage expectations include terminal manager service tests and long-running-command scenarios | yes | no | yes | yes | no | no | documented in `forge_panel_shell_spec.md` test matrix (`terminal_manager_test.dart`) |

## 20. Editor Base Contracts and Text Editing Core
This section is intended to cover `ForgeEditor`/`ForgeTextEditor`/`ForgeDocument` contracts, text operations, selection/cursor/visible range reporting, and editor integration bridge behavior. Include checks for shared Forge editor base and each integrated editor module.

- [ ] Section completed (finished on 2026-03-30T06:33:43+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Base editor contract (`ForgeEditor`) defines URI identity and file-resolution hooks | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` `ForgeEditor` contract |
| Two-phase file resolution (`canHandle` + `canHandleContent`) is part of core editor opening model | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` resolution flow and `forge_panel_shell_spec.md` open flow |
| Text editor base (`ForgeTextEditor`) requires document + cursor/selection observables | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` `ForgeTextEditor` API |
| Multi-selection contract is explicit (`selections`, `setSelections`) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` text editor API and `forge_panel_shell_spec.md` test editor implementation |
| Visible-range reporting is a required text-core primitive (`visibleRange`) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` and `forge_panel_shell_spec.md` |
| Core text mutation operations are defined (`insertText`, `replaceRange`, `deleteRange`) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` text operations and `forge_panel_shell_spec.md` test implementation |
| Cursor/selection control and navigation operations are defined (`setCursorPosition`, `setSelection`, `revealPosition`, `revealRange`) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` text editor API |
| In-editor query/search primitives are part of text core (`findAll`) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` and `forge_panel_shell_spec.md` |
| Document contract (`ForgeDocument`) includes text extraction, language id, encoding, and change model | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` `ForgeDocument`/`TextRange`/`TextPosition` |
| Text editor options pipeline is standardized (`ForgeTextEditorOptions`, `updateOptions`) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` and `forge_panel_shell_spec.md` adapter mapping notes |
| Bridge/integration path includes shared `ForgeDocumentAdapter` for existing editors | yes | yes | yes | yes | no | no | documented in `tom_forge_ui_testapp.md` package layout and `forge_panel_shell_spec.md` integration section |
| System-state integration ties editor base contracts to `activeEditor`, `dirtyEditors`, and selection-change events | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` system state/events and `tom_forge_ui_testapp.md` state behavior |

## 21. Text Settings, Context Discovery, and Configuration Injection
This section is intended to cover `ForgeTextSettings`, context discovery (`ForgeTextContext`), per-editor-type settings, and runtime settings propagation. Include checks for shell persistence/injection and per-editor adaptation behavior.

- [ ] Section completed (finished on 2026-03-30T06:35:12+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Text editor option contract is standardized through `ForgeTextEditorOptions` in base API | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` `ForgeTextEditor` options API |
| Per-editor runtime option mutation is defined (`updateOptions`) for live settings propagation | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` and `forge_panel_shell_spec.md` |
| Editor adaptation requires mapping existing editor settings to `ForgeTextEditorOptions` | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_spec.md` integration gaps (`MdEditorSettings`, `DartEditorTheme`) |
| Configuration service is part of shell runtime (`ForgeConfigManager`) and accessible to modules | yes | no | yes | yes | no | no | documented in `forge_panel_shell_concept.md` shell API services |
| Config manager supports structured updates and typed module config lookup (`update`, `getModuleConfig`) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` `ForgeConfigManager` contract |
| Config change propagation is event-driven (`ConfigChangeEvent`, `onDidChange`) after persistence | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` and `forge_panel_shell_spec.md` event ordering |
| Shell startup configuration flow includes async config load and restoration of persisted config | no | no | no | yes | no | no | documented in `forge_panel_shell_spec.md` startup sequence |
| Editor text settings persistence is defined per editor type via preferences key `forge.editor.textSettings` | no | yes | yes | yes | no | no | documented in `tom_forge_full_integration.md` settings persistence notes |
| Runtime injection path applies persisted per-editor text settings into active shell at startup and on preference changes | no | yes | yes | yes | no | no | documented in `tom_forge_full_integration.md` startup hydration/runtime sync evidence |
| Settings source layering is defined (shell config + text settings APIs) | yes | yes | yes | yes | no | no | documented in `tom_forge_full_integration.md` phase objective notes |
| Test/runtime config implementations include config update notifications (`TestConfigManager.update` + `onDidChange`) | yes | no | yes | yes | no | no | documented in `tom_forge_ui_testapp.md` config manager behavior |
| Configuration tab/file-types views provide operator-facing context for per-editor defaults and resolver settings | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` configuration sections |

## 22. Undo/Redo, Dirty State, and Save Lifecycle
This section is intended to cover undo/redo behavior, dirty tracking semantics, save/save-all/will-save/did-save event flow, and consistency across editors. Include checks for shell-level state handling and per-editor implementation consistency.

- [ ] Section completed (finished on 2026-03-30T06:37:03+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Editor base contract includes dirty-state observables (`isDirty`) shared across editor types | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` editor contracts and `forge_panel_shell_spec.md` implementations |
| System state tracks dirty editors and publishes dirty-state change events | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` (`dirtyEditors`, `onDirtyStateChanged`) |
| Save lifecycle streams are defined (`onWillSave`, `onDidSave`) for pre/post-save integration | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` file system events and `tom_forge_ui_testapp.md` save behavior |
| Save reasons are classified (`manual`, `autoSave`, `focusLoss`) for lifecycle semantics | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` `SaveReason` |
| Auto-save and revisioning settings are configurable at shell-level defaults | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` configuration model |
| Save-all workflow is defined against current dirty editor set | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` save-all example and `tom_forge_ui_testapp.md` command mapping |
| Dirty-close flow requires explicit user decision (save / discard / cancel) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_spec.md` close flow and `tom_forge_ui_testapp.md` close behavior |
| Undo manager is a first-class shell service (`ForgeUndoManager`) with availability semantics | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` undo manager API |
| Undo/redo operations are exposed and validated (`undo`, `redo`, can-undo/can-redo) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` undo API and `tom_forge_ui_testapp.md` command map |
| Undo/redo persistence and revision artifacts are defined under `.forge/undo` and `.forge/revisions` | no | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` storage structure and `forge_panel_shell_spec.md` schemas |
| Save path creates revision snapshots and clears dirty state when persisted content changes | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_spec.md` save sequence/tests |
| Test coverage expectations include undo manager tests plus dirty/save regression checks | yes | no | yes | yes | no | no | documented in `forge_panel_shell_spec.md` (`undo_manager_test.dart`, dirty/save tests) and `tom_forge_ui_testapp.md` |

## 23. File Type Resolution and Fallback Opening
This section is intended to cover `canHandle`/`canHandleContent` resolution, editor selection by URI/content, unknown-type fallback behavior, and file-open error handling. Include checks for shell resolver behavior and per-editor/module resolver contributions.

- [ ] Section completed (finished on 2026-03-30T06:38:44+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| File-type resolution is contract-driven at editor level (`canHandle`, `canHandleContent`) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` `ForgeEditor`/`ForgeSchemaEditor` contracts |
| Resolver is explicitly two-phase (URI-first, content-inspection second) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` resolution process and helper functions |
| Decision result model is standardized (`accept`, `reject`, `inspect`) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` `FileHandlingResult` enum |
| Schema/content-sensitive editors use `inspect` and Phase-2 acceptance rules | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` schema editor behavior |
| Resolver priority defaults to module declaration order for accepted editors | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` resolution priority notes |
| User-facing override path exists in File Types configuration and Open-with defaults | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` configuration/File Types references |
| Explicit Open-with operation is supported via layout API (`openFileWith`) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` layout API |
| Open-with UI separates URI-accepted editors and content-inspected additional options | no | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` Open-with section |
| No-match/error path is defined (`ED002: No editor available for {uri}`) | no | no | no | yes | no | no | documented in `forge_panel_shell_spec.md` error code table |
| Unknown/unsupported file fallback is defined in runtime test app (read-only text fallback) | no | yes | yes | yes | no | no | documented in `tom_forge_ui_testapp.md` file-open fallback behavior |
| Integration expectations include implementing missing `canHandle/canHandleContent` gaps in editor adapters | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_spec.md` integration checklist tables |
| Test expectations include Open-with behavior verification and resolver path checks | yes | no | yes | yes | no | no | documented in `forge_panel_shell_spec.md` TODO/tests and `tom_forge_ui_testapp.md` resolver workflow |

## 24. Advanced Data Services (Decorations, Outline, Virtual Documents, Workspace Edits)
This section is intended to cover decoration pipelines, outline provider integration, virtual document providers, and multi-file workspace edit application. Include checks for shell service APIs and per-module/component usage coverage.

- [ ] Section completed (finished on 2026-03-30T06:40:36+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Text-decoration pipeline is part of editor contract (`setDecorations`, `clearDecorations`) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` `ForgeTextEditor` decoration API |
| Decoration model is typed and extensible (`ForgeDecorationType`, keyed ranges, gutter/icon/overview support) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` decoration type/range model |
| Explorer file decoration service exists with provider registration and URI-scoped evaluation | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` `ForgeFileDecorationManager` |
| File-decoration invalidation/event flow is supported (`onDidChange`) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` file decoration provider events |
| Virtual document service exists with scheme-based provider registration | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` `ForgeVirtualDocumentManager` |
| Virtual-document invalidation/event flow is supported (`onDidChange`) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` virtual document manager contract |
| Outline service exists with provider registry and editor-targeted outline resolution (`provideOutline`) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` `ForgeOutlineManager` |
| Outline update/event signaling is part of service contract (`onDidChange`) and active-editor sync model | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` outline manager and `tom_forge_ui_testapp.md` outline behavior |
| Workspace-edit API supports atomic multi-file edits (`applyWorkspaceEdit(ForgeWorkspaceEdit)`) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` file system/workspace edit API |
| Workspace-edit model explicitly defines all-or-nothing semantics for multi-file operations | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` `ForgeWorkspaceEdit` description |
| Integration expectations include adapting existing editors to generalized decoration APIs | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_spec.md` integration gaps for md/dart editors |
| Test coverage expectations include dedicated tests for file decorations, virtual documents, and outline managers | yes | no | yes | yes | no | no | documented in `forge_panel_shell_spec.md` service test matrix |

## 25. State Persistence and Recovery
This section is intended to cover persistence of shell settings, per-editor settings, panel/application state expectations, and recovery behavior after restart. Include checks for shell persistence services and per-module persistence responsibilities.

- [ ] Section completed (finished on 2026-03-30T06:43:16+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Workspace state storage model is defined under `<workspace>/.forge/` (layout, open editors, revisions, undo history) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` `.forge/` workspace state model |
| Startup recovery sequence restores config and state (`.forge/config.json`, `.forge/state/layout.json`, `.forge/state/open-editors.json`) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` startup sequence |
| Configuration is merged from code defaults plus persisted overrides at startup | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` baseline + persisted overlay model |
| Configuration changes persist to `.forge/config.json` and support reset to code defaults | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` config persistence and reset behavior |
| Layout persistence is per application with save/load flow in `.forge/state/layout.json` | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` and `forge_panel_shell_spec.md` layout persistence format/tests |
| Open editor restoration is explicitly modeled through `.forge/state/open-editors.json` | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` editor restore flow |
| Last-opened applications are restored on next launch | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` launch restoration behavior |
| Per-module persistent key-value storage is exposed via `ForgeModuleStorage` | yes | no | yes | yes | no | no | documented in `forge_panel_shell_concept.md` and `forge_panel_shell_spec.md` module storage contracts/tests |
| Split/local persistence mode is defined with workspace state always local to workspace `.forge/` | yes | no | yes | yes | no | no | documented in `forge_panel_shell_concept.md` local vs split configuration directories |
| File revision persistence and non-destructive restore workflow are part of recovery model | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` revisions and restore behavior |
| Undo history persistence format is specified (`.forge/undo/{uri-hash}.json`) | no | yes | yes | yes | no | no | documented in `forge_panel_shell_spec.md` state persistence formats |
| Current test app baseline still declares restart persistence as not yet implemented (gap for integration completion) | yes | yes | yes | no | no | no | documented in `tom_forge_ui_testapp.md` current-state notes and `tom_forge_full_integration.md` persistence TODOs |

## 26. Error Handling and Recovery Patterns
This section is intended to cover error classification, user-facing recovery feedback, fallback behavior, and non-fatal degradation patterns. Include checks for shell-level resilience and per-module/component error hygiene.

- [ ] Section completed (finished on 2026-03-30T06:44:56+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Error scenarios are explicitly classified with severity and user-facing recovery guidance (error/warning + retry/fallback/edit/manual actions) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_spec.md` error handling patterns table |
| File I/O failures define explicit UX patterns (modal/toast) and recovery actions (retry/cancel) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_spec.md` read/write/delete error rows |
| Network timeout path specifies non-fatal behavior with status indication and auto-retry policy | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_spec.md` timeout handling (`Auto-retry 3x`) |
| Module activation failures are isolated so one failing module does not crash the shell | yes | no | yes | yes | no | no | documented in `forge_panel_shell_spec.md` module isolation and activation failure flow |
| Module failure recovery includes diagnostics emission, module error-state marking, and user notification | yes | no | yes | yes | no | no | documented in `forge_panel_shell_spec.md` `ForgeDiagnostic`, `ModuleState.error`, and notification calls |
| Retry utility contract exists with retryable-error typing and custom retry predicate hooks | yes | no | yes | yes | no | no | documented in `forge_panel_shell_spec.md` `executeWithRetry`, `retryableErrors`, `shouldRetry` |
| Configuration parse failures define fallback-to-defaults behavior with user guidance | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_spec.md` config parse error recovery |
| Standardized diagnostic code taxonomy exists for module/config/editor/UI failures (`MD*`, `CF*`, `ED*`, `UI*`) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_spec.md` diagnostic code table |
| Problems view aggregates diagnostics from providers and supports click-to-navigate/filtering | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` `ForgeDiagnosticManager` + Problems view contract |
| Notification service exposes info/warning/error channels with action-capable APIs for recovery prompts | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` `ForgeNotificationManager` API |
| Non-fatal fallback rendering for unsupported editor cases is defined (read-only text fallback) | yes | yes | yes | yes | no | no | documented in `tom_forge_ui_testapp.md` editor fallback behavior |
| Test expectations include explicit module error scenario validation (toast + Problems entry while other modules keep working) | yes | no | yes | yes | no | no | documented in `forge_panel_shell_spec.md` scenario matrix |

## 27. Performance and Scalability
This section is intended to cover responsiveness budgets, lazy loading/virtualization strategy, expensive-operation isolation, and large-workspace behavior. Include checks for shell infrastructure and per-module/component performance hotspots.

- [ ] Section completed (finished on 2026-03-30T06:46:24+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Performance strategy section defines explicit contracts for memory, lazy loading, and virtualization | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_spec.md` Performance Strategies overview |
| Open-editor scalability target is defined with LRU closure policy for least-recently-focused editors | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_spec.md` capacity table |
| File-watcher scalability target is defined (1000 paths) with consolidation to parent directories | yes | no | yes | yes | no | no | documented in `forge_panel_shell_spec.md` capacity table |
| Search cache memory budget is defined (50MB) with LRU eviction strategy | yes | no | yes | yes | no | no | documented in `forge_panel_shell_spec.md` cache limits and implementation notes |
| Image preview cache memory budget is defined (100MB) with LRU eviction strategy | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_spec.md` capacity table |
| Runtime budget monitoring contract exists (`usage`, `budget`, high-usage signaling, forced eviction) | yes | no | yes | yes | no | no | documented in `forge_panel_shell_spec.md` memory budget interfaces |
| Expensive computations (outline/diagnostics/symbols) are isolated behind generation-based caching | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_spec.md` generation cache pattern |
| Autosave responsiveness is controlled via debounce (default 1000ms, configurable) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_spec.md` debounce policy |
| File watcher responsiveness uses batch + throttle with explicit 50ms window | yes | no | yes | yes | no | no | documented in `forge_panel_shell_spec.md` throttle configuration |
| Diagnostic subsystem includes explicit scalability expectation for large sets (10K diagnostics) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_spec.md` service matrix |
| File-system service acknowledges concurrent-access and multi-file-operation performance constraints | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_spec.md` `ForgeFileSystem` service matrix |
| Multi-application shell model keeps apps alive in memory; this is an intentional performance tradeoff requiring resource management | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` multi-application memory behavior |

## 28. Testing and Quality Gates
This section is intended to cover unit/widget/integration/E2E test expectations, analyzer/test gates, regression scope, and promotion criteria from staging to production app. Include checks for framework-level quality gates and per-module/component test coverage.

- [ ] Section completed (finished on 2026-03-30T06:47:47+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Test strategy explicitly spans unit, widget, integration, E2E, and golden layers | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_spec.md` Test Strategy matrix |
| Coverage targets are defined per test layer (unit 90%+, widget 80%+, integration 70%+) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_spec.md` coverage target table |
| Golden regression testing is part of quality gates (`matchesGoldenFile` for key screens/themes) | no | yes | yes | yes | no | no | documented in `forge_panel_shell_spec.md` golden examples |
| Service-level unit tests are specified for persistence, diagnostics, notifications, undo, config, and module storage | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_spec.md` service test mapping |
| Widget-level interaction tests are specified for accordeon behavior and drag-drop workflows | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_spec.md` widget test examples |
| Integration tests are specified for end-to-end file-save and shell-path scenarios | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_spec.md` integration examples and `tom_forge_full_integration.md` phase tests |
| Staging quality gate requires analyzer and test passes in framework and staging runtime packages | yes | no | yes | yes | no | no | documented in `tom_forge_full_integration.md` strict pass verification results |
| Expansion-cycle merge gate requires no analyzer errors and no command/editor regressions | yes | yes | yes | yes | no | no | documented in `tom_forge_full_integration.md` Phase D acceptance criteria |
| Promotion gate checklist is explicitly defined before staging-to-production port | yes | no | yes | yes | no | no | documented in `tom_forge_full_integration.md` promotion gate checklist |
| Promotion criteria include repeated staging regression stability and integration-matrix readiness | yes | yes | yes | yes | no | no | documented in `tom_forge_full_integration.md` checklist and risk controls |
| Milestone command gates define mandatory `dart analyze`/`flutter test` runs for integration and promotion | yes | no | yes | yes | no | no | documented in `tom_forge_full_integration.md` runbook commands |
| Test app acts as near-production staging runtime used to validate shell interfaces and integrated behavior before promotion | yes | yes | yes | yes | no | no | documented in `tom_forge_ui_testapp.md` goals and `tom_forge_full_integration.md` staging architecture |

## 29. Feature Matrix by Scope (Forge vs Module vs Component)
This section is intended to provide a cross-cutting checklist matrix for every feature area, explicitly separating: (a) Forge core responsibility, (b) module-level implementation responsibility, and (c) component-level behavior responsibility.

- [ ] Section completed (finished on 2026-03-30T06:49:18+02:00)

| category | per module? | per component? | to be implemented in modules? | documented? | demo implemented? | wired to editors? | implemented on |
|---|---|---|---|---|---|---|---|
| Shell framework owns panel/layout/focus/menu/shortcut orchestration as core runtime responsibility | no | no | no | yes | no | no | documented in `forge_panel_shell_concept.md` shell definition and architecture |
| Modules are the primary packaging unit for functionality (components + actions + shortcuts + context menus) | yes | no | yes | yes | no | no | documented in `forge_panel_shell_concept.md` module model |
| Components are owned by modules and exposed as direct typed members (no string IDs/registries) | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` ownership and typed-member model |
| Shell module (`TomForgeShellModule`) provides built-in views as framework-level baseline | no | yes | no | yes | no | no | documented in `forge_panel_shell_concept.md` built-in views ownership |
| Application layout config is structural and references module members directly | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` application/layout design notes |
| Module lifecycle (`activate`/`deactivate`) controls registration and teardown of module-provided capabilities | yes | no | yes | yes | no | no | documented in `forge_panel_shell_concept.md` module lifecycle and `forge_panel_shell_spec.md` startup sequence |
| Actions and shortcuts are contributed by modules/components while shell aggregates and resolves execution context | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` menu/shortcut system |
| Provider-based extension points (outline, file decorations, virtual documents) are registered by modules against shell services | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` provider registration APIs |
| Status bar model separates shell-global items from active-component/module-contributed items | yes | yes | yes | yes | no | no | documented in `forge_panel_shell_concept.md` status bar item model |
| Module-scoped persistence is provided through shell storage service (`forModule`) with typed module identity | yes | no | yes | yes | no | no | documented in `forge_panel_shell_concept.md` `ForgeModuleStorage` contract |
| Cross-module access uses typed module registry lookups (`shell.modules.get<T>()`) instead of string identifiers | yes | no | yes | yes | no | no | documented in `forge_panel_shell_concept.md` module registry API notes |
| Staging-to-production integration workflow preserves module composition, actions, shortcuts, views, and status bar responsibilities | yes | yes | yes | yes | no | no | documented in `tom_forge_full_integration.md` Phase E port and verification checklist |
