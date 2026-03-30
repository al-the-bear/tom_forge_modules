# Forge Feature Checklist

## 1. Shell Architecture and Lifecycle
This section is intended to cover the top-level Forge shell runtime model: startup, module activation/deactivation, shell service wiring, and lifecycle guarantees. Include checks at Forge level and per integrated module that depends on shell lifecycle hooks.

- [x] Section completed (finished on 2026-03-30T05:53:06+02:00)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| Shell startup sequence (`constructor` -> `initState` -> `ready`) | no | no | no | yes | documented in `forge_panel_shell_spec.md` (section 7.1) |
| Module registration into shell registry during startup | yes | no | yes (module instantiation/registration) | yes | documented in `forge_panel_shell_spec.md` (section 7.1) and `tom_forge_ui_testapp.md` (section 3.2) |
| Sequential module activation in dependency order (`module.activate(api)`) | yes | no | yes (each module implements activation) | yes | documented in `forge_panel_shell_spec.md` (section 7.1) and `forge_panel_shell_concept.md` (module lifecycle) |
| Shell collects module contributions (actions/views/editors/shortcuts) | yes | yes | yes (modules/components contribute) | yes | documented in `forge_panel_shell_spec.md` (section 7.1) and `tom_forge_full_integration.md` (section 4.2, Phase B) |
| Boot flow wiring (file system + shell module + app module + application layout + scaffold) | yes | no | yes (app modules) | yes | completed 2026-03-26 in `tom_forge_full_integration.md` (section 4.1, Phase A/E) |
| Shell service single-source wiring (`ForgeActionRegistry`, `ForgeShortcutManager`, `ForgeSystemState`, settings) | yes | yes | yes (module actions/shortcuts) | yes | completed 2026-03-26 in `tom_forge_full_integration.md` (section 4.2, Phase B/C) |
| Startup hydration and runtime preference synchronization | yes | yes | yes (module/editor settings consumers) | yes | completed 2026-03-26 in `tom_forge_full_integration.md` (Phase C) |
| Layout/editor state restoration before running | yes | yes | yes (editor state adapters) | yes | documented in `forge_panel_shell_spec.md` (section 7.1) |
| Graceful shutdown flow (dirty prompts, cancellable shutdown, save state) | yes | yes | yes (module/editor dirty + save handlers) | yes | documented in `forge_panel_shell_spec.md` (section 7.1) |
| Reverse-order module deactivation during shutdown (`module.deactivate()`) | yes | no | yes (each module implements deactivation) | yes | documented in `forge_panel_shell_spec.md` (section 7.1) and `forge_panel_shell_concept.md` |
| Startup boundary: modules registered at startup (no hot-load/unload flow in test app) | yes | no | no | yes (current scope) | documented in `tom_forge_ui_testapp.md` (non-goals + module structure) |

## 2. Workspace Model and File/Revision Boundaries
This section is intended to cover workspace root handling, file-system scope, `.forge/` state/revision boundaries, and workspace-level assumptions. Include checks for core Forge behavior and module/component behavior when operating on workspace data.

- [x] Section completed (finished on 2026-03-30T06:00:30+02:00)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| Workspace root is the primary runtime boundary (`workspaceRoot`/`workspaceRootUri`) | no | no | no | yes | documented in `forge_panel_shell_concept.md` and `forge_panel_shell_spec.md` (test harness `workspaceUri`) |
| `.forge` workspace folder stores state and revisions in workspace scope | no | no | no | yes | documented in `forge_panel_shell_concept.md` section 12.2 |
| Workspace state stays local in both config modes (never in `~/.forge`) | no | no | no | yes | documented in `forge_panel_shell_concept.md` (local vs split mode matrix) |
| Config mode split (`local` vs `split`) separates config location from workspace state | no | no | no | yes | documented in `forge_panel_shell_concept.md` sections 12.5 and 13 |
| Startup workspace detection and selection (remembered path, walk-up `.forge`, CWD fallback) | no | no | no | yes | documented in `forge_panel_shell_concept.md` section 13 |
| Standard workspace state files (`state/layout.json`, `state/open-editors.json`, `state/editors/{uri-hash}.json`) | no | yes | yes (editor state adapters) | yes | documented in `forge_panel_shell_concept.md` and `forge_panel_shell_spec.md` state schema sections |
| Revision snapshots under `.forge/revisions/{uri-hash}/` with content snapshots | no | yes | yes (components triggering saves) | yes | documented in `forge_panel_shell_spec.md` revision schema and `forge_panel_shell_concept.md` |
| Undo history persisted under `.forge/undo/{uri-hash}/` boundary | no | yes | yes (editor undo producers) | yes | documented in `forge_panel_shell_concept.md` section 12.2 and related schema references |
| All file operations are routed through `ForgeFileSystem` (read/write/save/list/watch/edit) | yes | yes | yes (module/component file workflows) | yes | documented in `forge_panel_shell_concept.md` and `forge_vs_code_api_comparison.md` |
| Revisioning behavior on save (dedupe identical saves, prune old revisions) | no | yes | yes (save semantics in components) | yes | documented in `forge_panel_shell_concept.md` revisioning notes |
| Workspace `.forge` should be suggested for `.gitignore` | no | no | no | yes | documented in `forge_panel_shell_concept.md` initialization flow |
| Test app workspace boundary uses seeded `MemoryFileSystem` virtual root | yes | yes | yes (module views/editors in test app) | yes (test app scope) | documented in `tom_forge_ui_testapp.md` sections 3, 5, and 11 |

## 3. Application Model and Multi-Application Switching
This section is intended to cover application definitions, switching behavior, in-memory retention of inactive applications, and app-specific layout/action contexts. Include checks for global Forge behavior and module/component behavior across application switches.

- [x] Section completed (finished on 2026-03-30T06:02:09+02:00)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| ForgeApplication model defines named app-level layout and metadata | no | no | no | yes | documented in `forge_panel_shell_concept.md` (`ForgeApplication` model) |
| Multiple applications exist in one shell instance | no | no | no | yes | documented in `forge_panel_shell_concept.md` (single window, multi-application) |
| Application switcher dropdown selects active application | no | no | no | yes | documented in `forge_panel_shell_concept.md` (title bar/application dropdown) |
| Switching keeps previous applications alive in memory | no | no | no | yes | documented in `forge_panel_shell_concept.md` (switch behavior) |
| Inactive app layout state is preserved in memory | no | no | no | yes | documented in `forge_panel_shell_concept.md` (`preserveLayoutInMemory`, switch behavior) |
| Default behavior is no save-on-switch; optional save-on-deactivate support | no | yes | yes (per app policy) | yes | documented in `forge_panel_shell_concept.md` (application switching notes) |
| Active application tracked in system state/controller | no | no | no | yes | documented in `forge_panel_shell_concept.md` (`activeApplication`, `ForgeShellController`) |
| Per-application layout persistence in `.forge/state/layout.json` | no | yes | yes (app layout contributions) | yes | documented in `forge_panel_shell_concept.md` (persistence sections) |
| Per-application open editor restoration via `.forge/state/open-editors.json` | no | yes | yes (editor components participate) | yes | documented in `forge_panel_shell_concept.md` startup flow |
| Modules can expose pre-configured applications | yes | no | yes (module-provided applications) | yes | documented in `forge_panel_shell_concept.md` (module-provided application layouts) |
| Application layouts reference module-owned components | yes | yes | yes (module components wired into app layout) | yes | documented in `forge_panel_shell_concept.md` design note on application structure |
| App switch lifecycle is represented in shell event stream and architecture | no | yes | yes (components react to app switch/focus) | yes | documented in `forge_panel_shell_concept.md` (events and focus/app switch behaviors) |

## 4. Module Integration and Ownership Boundaries
This section is intended to cover module contracts, registration, module-provided views/editors/actions/shortcuts, and module-to-shell ownership boundaries. Include checks for shell-level module orchestration and per-module conformance.

- [x] Section completed (finished on 2026-03-30T06:03:41+02:00)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| Module contract defines lifecycle and contributions (`activate/deactivate`, editors, views, actions, shortcuts) | yes | no | yes | yes | documented in `forge_panel_shell_concept.md` (`ForgeModule` contract) |
| Components are owned by exactly one module | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` ownership rules |
| Shell discovers components through configured modules (no global component registry) | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` design notes |
| Shell module ownership boundary: built-in views belong to `TomForgeShellModule` | yes | yes | yes (for custom module boundaries) | yes | documented in `forge_panel_shell_concept.md` module notes |
| Module integration is compile-time and type-safe (no dynamic loading/marketplace sandbox) | yes | no | yes | yes | documented in `forge_panel_shell_concept.md` architecture principles |
| Module cross-references are type-safe (`modules.get<T>()`) | yes | no | yes | yes | documented in `forge_panel_shell_concept.md` shell API section |
| Module activation order uses declaration order during startup | yes | no | yes (module dependency-safe design) | yes | documented in `forge_panel_shell_concept.md` lifecycle and `forge_panel_shell_spec.md` event ordering |
| Module deactivation order is reverse declaration order at shutdown | yes | no | yes | yes | documented in `forge_panel_shell_concept.md` lifecycle and `forge_panel_shell_spec.md` event ordering |
| Module contributions are published to shell registries (actions/shortcuts/views/editors) | yes | yes | yes | yes | implemented evidence in `tom_forge_full_integration.md` Phase B and shell lifecycle docs |
| Module failure isolation boundary (one failing module must not crash shell) | yes | no | yes (defensive module code) | yes | documented in `forge_panel_shell_spec.md` module error handling |
| Module declaration order influences editor resolution priority | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` file resolution notes |
| Module integration acceptance includes required actions/shortcuts/views/status items | yes | yes | yes | yes | documented in `tom_forge_full_integration.md` Phase E acceptance evidence |

## 5. Component Model (Views and Editors)
This section is intended to cover component contracts (`title`, `icon`, `buildMain`, `buildCopy`, size hints), view vs editor semantics, and component identity. Include checks at shell level and per component implementation in each module.

- [x] Section completed (finished on 2026-03-30T06:05:16+02:00)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| Core `ForgeComponent` contract: observable `title`, optional `titleExtension`, `icon`, `isEditor`, `sizeHints`, `supportsMultiRender` | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` component interface |
| Rendering contract split: `buildMain(context)` vs `buildCopy(context)` | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` (`ForgeComponent`) |
| Component size hints contract (`minSize`, `preferredSize`, `maxSize`) guides layout behavior | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` size hints section |
| View vs editor closability semantics are different by design | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` editor/view comparison table |
| Component identity model: editors by `Uri`, views by Dart `Type` | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` identity rules |
| Multi-render model: shared data state with per-copy UI state | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` multi-render section |
| UI copy lifecycle: main component + additional UI copies, shift-drag copy behavior | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` copy semantics |
| File-opening editor resolution uses `canHandle(uri)` then `canHandleContent(uri, bytes)` | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` and `forge_panel_shell_spec.md` editor lifecycle |
| Schema editor specialization: `canHandle` returns `inspect`, decision in `canHandleContent` | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` schema editor contract and `forge_panel_shell_spec.md` examples |
| Concrete component contract evidence in test module (`ForgeTestTextEditor` title/icon/uri/canHandle) | yes | yes | yes | yes | documented in `forge_panel_shell_spec.md` section 10.3 |
| Module contribution surfaces expose typed `List<ForgeEditor>` and `List<ForgeView>` | yes | no | yes | yes | documented in `forge_panel_shell_concept.md` (`ForgeModule`) and `forge_panel_shell_spec.md` test module |
| Integration scenario evidence validates editor/view component behavior by file type | yes | yes | yes | yes | documented in `forge_panel_shell_spec.md` section 11 integration scenarios and `tom_forge_ui_testapp.md` |

## 6. Layout Topology and Panel Composition
This section is intended to cover title bar, menu bar, left/right/middle/bottom panel structure, and status bar composition. Include checks for the Forge shell layout engine and per-module panel content integration.

- [x] Section completed (finished on 2026-03-30T06:06:58+02:00)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| Top-level shell frame includes title bar, menu bar, panel areas, and status bar | no | no | no | yes | documented in `forge_panel_shell_concept.md` shell structure |
| Left panel topology: full-height side panel with vertical icon-strip tabs and accordeon content | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` left panel section |
| Right panel mirrors left panel topology (icon strip + accordeon tabs) | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` right panel section |
| Middle topology supports 1-4 editor panels with per-panel editor tab bars | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` middle panel section and architecture map |
| Bottom topology spans between side panels and uses tab bar + accordeon sections | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` bottom panel section |
| Configuration tab topology is fixed/pinned at bottom of left icon strip | no | no | no | yes | documented in `forge_panel_shell_concept.md` configuration tab rules |
| Side/bottom panels share accordeon section-hosting composition model | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` accordeon layout description |
| Panel composition supports drag flows: accordeon reordering, tab moves between side/bottom, middle drop zones for split/add tab | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` drag behavior sections |
| Menu bar composition is fixed top-level structure populated from shell/modules/components | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` menu bar section |
| Status bar composition aggregates dynamic items and progress indicators | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` status/progress sections |
| Platform composition rule: menu bar native placement differs on macOS vs Windows/Linux | no | no | no | yes | documented in `forge_panel_shell_concept.md` platform menu behavior |
| Implementation evidence: test app shell scaffold and panel/status widgets provide open/close/resize composition behavior | yes | yes | yes | yes | documented in `tom_forge_ui_testapp.md` deliverables/files and `tom_forge_full_integration.md` Phase E evidence |

## 7. Panel Resizing and Splitter Behavior
This section is intended to cover draggable splitters, min/max constraints, hover/drag affordances, and resize persistence expectations. Include checks for shell splitter mechanics and module/component behavior under panel size changes.

- [x] Section completed (finished on 2026-03-30T06:08:30+02:00)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| Left panel width is user-adjustable via dedicated drag handle | no | no | no | yes | documented in `forge_panel_shell_concept.md` left panel behavior |
| Right panel width is user-adjustable via dedicated drag handle | no | no | no | yes | documented in `forge_panel_shell_concept.md` right panel behavior |
| Bottom panel height is user-adjustable via top-edge drag handle | no | no | no | yes | documented in `forge_panel_shell_concept.md` bottom panel behavior |
| Middle area supports multiple panels separated by draggable dividers | no | no | no | yes | documented in `forge_panel_shell_concept.md` middle panel structure |
| Resizing is real-time during drag (no animation), with reset animation on double-click | no | no | no | yes | documented in `forge_panel_shell_spec.md` animation timing table |
| Minimum size constraints exist (for example middle panel minimum width) | no | yes | yes (component/module layouts must respect bounds) | yes | documented in `forge_panel_shell_spec.md` dimensions/constraints |
| Splitter hit target and visual thickness are explicitly defined | no | no | no | yes | documented in `forge_panel_shell_spec.md` divider constants |
| Accordeon section splitters support manual separator drag when sections are pinned open | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` accordeon behavior table |
| Layout controller is responsible for resize bounds and restore behavior | yes | no | yes (module interactions via layout API) | yes | documented in `forge_panel_shell_spec.md` service test matrix |
| Panel size and layout changes persist through layout persistence in core shell architecture | no | no | no | yes | documented in `forge_panel_shell_concept.md` layout persistence and architecture sections |
| Implementation evidence in test app uses explicit drag-handle dividers and resizable/collapsible panels | yes | yes | yes | yes | documented in `tom_forge_ui_testapp.md` layout map and deliverables |
| Test-app scope notes that restart persistence is intentionally not implemented there (while core concept specifies persistence) | no | no | no | yes (scope-specific) | documented in `tom_forge_ui_testapp.md` non-goals and `forge_panel_shell_concept.md` persistence model |

## 8. Tab Systems and Editor/View Tab UX
This section is intended to cover tab creation, activation, close behavior, hover feedback, dirty indicators, and tab overflow behavior in middle and auxiliary panels. Include checks for shell tab controls and per-component tab title/state updates.

- [x] Section completed (finished on 2026-03-30T06:10:02+02:00)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| Distinct tab systems exist: middle editor tab bar and side/bottom panel tab bars | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` and `forge_panel_shell_spec.md` |
| Tab creation on file open adds editor tab in active middle panel | yes | yes | yes | yes | documented in `forge_panel_shell_spec.md` editor lifecycle and `tom_forge_ui_testapp.md` layout controller flow |
| Tab activation selects one active component per panel | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` middle panel behavior |
| Tab close behavior differs by type (all editors closable; view main vs copy rules) | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` editor/view semantics |
| Close-dirty workflow prompts save/discard/cancel on tab close | yes | yes | yes | yes | documented in `forge_panel_shell_spec.md` flows and `tom_forge_ui_testapp.md` behavior table |
| Dirty state is reflected in tab UX and tracked in system state (`dirtyEditors`) | yes | yes | yes | yes | documented in `forge_panel_shell_spec.md` `DirtyStateEvent` and `tom_forge_ui_testapp.md` |
| Tab keyboard UX is defined (`Left/Right`, `Enter`, `Delete`) | no | no | no | yes | documented in `forge_panel_shell_spec.md` keyboard table |
| Accessibility semantics for tab system are defined (`tablist`, `tab`, `tabpanel`) | no | no | no | yes | documented in `forge_panel_shell_spec.md` accessibility roles |
| Tab overflow behavior: horizontal scrolling with wheel and overflow arrows | no | no | no | yes | documented in `forge_panel_shell_spec.md` scrolling behavior |
| Tab visual UX includes active/inactive/hover/indicator theme tokens | no | no | no | yes | documented in `forge_panel_shell_spec.md` theme tokens |
| Drag-tab UX supports moving tabs across panels and split-editor scenarios | no | yes | yes | yes | documented in `forge_panel_shell_spec.md` widget tests and `tom_forge_ui_testapp.md` notes |
| Implementation evidence includes dedicated tab widgets and tab-management controller logic | yes | yes | yes | yes | documented in `tom_forge_ui_testapp.md` file inventory and `forge_panel_shell_spec.md` tests |

## 9. Accordeon Section Behavior
This section is intended to cover section expand/collapse rules, pinning, multi-open behavior, section sizing/sharing, and empty/drop placeholder behavior. Include checks for shell accordeon mechanics and per-view section compatibility.

- [x] Section completed (finished on 2026-03-30T06:11:30+02:00)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| Accordeon is the section container model for left/right/bottom panel tabs | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` panel topology |
| Section open/closed presentation is defined (triangle direction and title orientation) | no | no | no | yes | documented in `forge_panel_shell_concept.md` accordeon section rules |
| Default mutual exclusivity: opening one section collapses others in same tab | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` behavior table |
| Pinning enables multi-open behavior in a tab | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` behavior table |
| Pinned-open sections share available space with size-hint awareness | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` space distribution + size-hints |
| Manual separator dragging between pinned-open sections is supported | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` separator-drag behavior |
| Single-section tabs are always open and non-collapsible | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` single-section rule |
| Empty sections must render placeholders for drag/drop targets | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` empty-sections rule |
| Empty accordeon tabs persist as placeholders when sections are moved away | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` drag/reorder behavior |
| Section-header controls (pin and close placement) are standardized | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` tab/header controls |
| Accordeon keyboard controls are specified (`Up/Down`, `Enter/Space`) | no | no | no | yes | documented in `forge_panel_shell_spec.md` keyboard table |
| Implementation/test evidence exists for expand/collapse and pinned state behavior | yes | yes | yes | yes | documented in `forge_panel_shell_spec.md` `accordeon_section_test.dart` and `tom_forge_ui_testapp.md` panel widget docs |

## 10. Drag-and-Drop Layout Operations
This section is intended to cover drag move/copy semantics, drop zones, panel split creation, and UI-copy behavior (including SHIFT-copy flows). Include checks for shell drag/drop infrastructure and per-component/module support.

- [x] Section completed (finished on 2026-03-30T06:16:42+02:00)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| Core layout supports drag-and-drop rearrangement of components between panels | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` drag-and-drop layout section |
| Regular drag performs move semantics (original location vacated) | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` move behavior |
| `SHIFT+drag` performs UI-copy semantics (original stays, copy created) | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` and `forge_panel_shell_spec.md` |
| Middle-panel drop zones support add-to-tabbar and split-left/right/top/bottom operations | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` middle drop-zone rules |
| Split creation is bounded by middle panel count limits | no | no | no | yes | documented in `forge_panel_shell_concept.md` middle panel constraints and test app split behavior |
| Section-header drag supports reorder within tab and moves between tabs/panels | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` move/reorder rules |
| Entire side/bottom tabs can be moved between left/right/bottom panels | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` tab move rules |
| Middle panels intentionally use component tabs (side/bottom whole-tab drag not allowed into middle) | no | no | no | yes | documented in `forge_panel_shell_concept.md` restriction notes |
| Empty accordeon/tab placeholders persist to keep valid future drop targets | no | yes | yes | yes | documented in `forge_panel_shell_concept.md` empty placeholder behavior |
| Drag feedback includes proxy visuals, grabbing cursor, delayed zone reveal, valid/invalid flash states | no | no | no | yes | documented in `forge_panel_shell_spec.md` drag/drop interaction specs |
| Drop-zone color semantics are explicitly themed (`highlight`, `valid`, `invalid`) | no | no | no | yes | documented in `forge_panel_shell_spec.md` color tokens |
| Implementation/test evidence covers move and copy (`moveComponent`, `copyComponent`) and split flows | yes | yes | yes | yes | documented in `forge_panel_shell_spec.md` `drag_drop_test.dart` and split tests, plus `tom_forge_ui_testapp.md` split controller behavior |

## 11. Navigation and Command Surfaces
This section is intended to cover menu bar, command palette, title-bar search entry behavior, back/forward navigation hooks, and command parity across entry points. Include checks for shell command routing and per-module command exposure.

- [x] Section completed (finished on 2026-03-30T06:17:54+02:00)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| Title-bar search field doubles as quick command/search entry surface | no | no | no | yes | documented in `forge_panel_shell_concept.md` title bar/search field behavior |
| Command palette is a first-class global entry point (`F1`, `Cmd+P`) | no | no | no | yes | documented in `forge_panel_shell_concept.md` and `forge_panel_shell_spec.md` |
| Menu bar is fixed top-level structure with module/component-populated entries | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` menu structure section |
| Cross-platform menu surface behavior is defined (macOS system menu, Windows/Linux in-window) | no | no | no | yes | documented in `forge_panel_shell_concept.md` platform behavior |
| `Go` surface includes navigation actions (go-to targets and back/forward) | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` menu table |
| Back/forward navigation hooks are delegated through focused component history manager | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` history manager section |
| Command execution routes through action objects with dynamic visibility/enabled state | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` action execution/state evaluation |
| Dialog-driven command UX supports quick pick/input/file picker flows | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` `ForgeDialogManager` usage |
| Explicit "Open with" command surface available from context menu and command palette | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` Open With flow |
| Command parity objective across menu, palette, and shortcuts is required | yes | yes | yes | yes | documented in `tom_forge_full_integration.md` acceptance and manual matrix |
| Implementation evidence: menu handlers switched from placeholders to real action dispatch | yes | no | yes | yes | documented in `tom_forge_full_integration.md` Phase B implementation evidence |
| Implementation evidence: command palette source unified to action registry with fallback dedupe | yes | no | yes | yes | documented in `tom_forge_full_integration.md` command-source unification notes |

## 12. Actions and Shortcut Framework
This section is intended to cover action registration, enable/visible state logic, shortcut binding/effective shortcut display, platform-specific modifier behavior, and conflict handling. Include checks at Forge action/shortcut manager level and per-module/per-component action sets.

- [x] Section completed (finished on 2026-03-30T06:19:17+02:00)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| Action model is object-based (no string-ID routing) with explicit menu location and optional shortcut | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` action model section |
| Action execution pipeline supports undo object return and undo callback integration | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` action + undo manager sections |
| Dynamic action state evaluation (`isEnabled`, `isVisible`) is re-evaluated against system state | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` state-evaluated actions |
| Actions from modules/components are collected into shell command/menu surfaces | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` and architecture modules |
| Shortcut bindings are collected centrally from modules/components | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` shortcut manager section |
| Shortcut conflict detection is supported and explicitly surfaced | no | no | no | yes | documented in `forge_panel_shell_concept.md` (`conflictsWith`) and `forge_panel_shell_spec.md` (`SH001`) |
| Runtime shortcut rebinding and reset-to-default are supported | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` (`rebind`, `resetToDefault`) |
| Effective shortcut display source comes from `ForgeShortcutManager` bindings | no | no | no | yes | documented in `tom_forge_full_integration.md` Phase B evidence |
| Platform-specific primary-modifier shortcut behavior is required (Cmd vs Ctrl) | no | no | no | yes | documented in `forge_panel_shell_concept.md` shortcut model and `tom_forge_full_integration.md` |
| Two-key trigger-menu shortcut system is defined (Shift+Cmd/Ctrl+key popup) | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` section 11.5 |
| Duplicate action ID policy/conflict logging is part of framework hardening | yes | no | yes | yes | documented in `tom_forge_full_integration.md` Phase B objectives |
| Implementation/test evidence includes `ForgeShortcutManager` tests, platform shortcut tests, and parity matrix requirements | yes | no | yes | yes | documented in `forge_panel_shell_spec.md` service tests and `tom_forge_full_integration.md` |

## 13. Focus Management and Accessibility
This section is intended to cover keyboard navigation order, focus visibility, focus trapping in modal surfaces, screen-reader semantics, and hit-target usability. Include checks for shell accessibility baseline and per component/module accessibility conformance.

- [x] Section completed (finished on 2026-03-30T06:21:41+02:00)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| System state exposes focused component, panel location, and focus-derived editor/selection context | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` (`ForgeSystemState` focus fields) |
| Focus lifecycle emits explicit events (`onFocusChanged`, selection-change + window-focus signals) | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` focus event API |
| Keyboard focus navigation APIs are defined (`focusNextPanel`, `focusPreviousPanel`, `focusActiveComponent`, `focusComponent`) | yes | yes | yes | yes | documented in `forge_panel_shell_spec.md` `ForgeFocusManager` contract |
| Focus ring accessibility baseline is defined (visible on keyboard focus, theme-driven color/width) | no | yes | yes | yes | documented in `forge_panel_shell_spec.md` accessibility implementation + theme tokens |
| Mouse-only focus indicator suppression (`focus-visible` equivalent behavior) is required | no | yes | yes | yes | documented in `forge_panel_shell_spec.md` focus-ring behavior rules |
| Modal surfaces trap focus (dialogs, shortcut popup, quick pick) until dismissed | no | yes | yes | yes | documented in `forge_panel_shell_spec.md` focus-trap requirements |
| Screen-reader semantics roles are defined for tab infrastructure (`tablist`, `tabpanel`) | no | yes | yes | yes | documented in `forge_panel_shell_spec.md` accessibility constants |
| Accessibility announcement pipeline is defined with polite/assertive modes via `SemanticsService` | yes | yes | yes | yes | documented in `forge_panel_shell_spec.md` (`announce`, `announceUrgent`) |
| Hit-target usability baseline is specified for splitters (8px interaction zone) | no | yes | yes | yes | documented in `forge_panel_shell_spec.md` design token table |
| High-contrast theme support is required as shell-level accessibility baseline | yes | yes | yes | yes | documented in `forge_panel_shell_spec.md` high-contrast section and test reference |
| Accessibility baseline includes keyboard navigation + screen-reader support in shell requirements | yes | yes | yes | yes | documented in `forge_panel_shell_spec.md` non-functional requirements and `forge_panel_shell_concept.md` scope notes |
| Integration/test evidence includes high-contrast widget tests and parity validation checkpoints | yes | no | yes | yes | documented in `forge_panel_shell_spec.md` (`high contrast` test) and `tom_forge_full_integration.md` validation cadence |

## 14. Theme, Visual Language, and Interaction Feedback
This section is intended to cover shell theming hooks, color/contrast expectations, active/hover/drag visual states, and consistency of feedback patterns. Include checks for global Forge theming and per-module/component visual integration.

- [x] Section completed (finished on 2026-03-30T06:23:31+02:00)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| Shell theme is exposed as a dedicated extension (`ForgeShellTheme`) with shell-level visual tokens | yes | no | yes | yes | documented in `forge_panel_shell_spec.md` theme extension section and `forge_panel_shell_concept.md` parity matrix |
| Theme configuration is part of persisted shell/application settings (`ThemeConfig theme`) | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` settings model (`ThemeConfig`) |
| Appearance controls are part of command/navigation surface (`View` menu includes appearance) | no | no | no | yes | documented in `forge_panel_shell_concept.md` command surfaces (`View` row) |
| Light/dark/high-contrast theme variants are explicitly defined and expected | no | yes | yes | yes | documented in `forge_panel_shell_spec.md` (`ForgeShellTheme.light/dark/highContrast`) |
| High-contrast mode changes visual behavior and reduces motion (0ms animations, static progress) | no | yes | yes | yes | documented in `forge_panel_shell_spec.md` high-contrast behavior rules |
| Animation timing/curve system is standardized for panel, tab, popup, toast, and feedback transitions | yes | yes | yes | yes | documented in `forge_panel_shell_spec.md` animation table and constants |
| Drag feedback is explicitly styled (semi-transparent proxy, cursor change to grabbing, drop-zone timing) | no | yes | yes | yes | documented in `forge_panel_shell_spec.md` drag-and-drop visual behavior |
| Drop-zone highlight style is theme-bound (`dropZoneHighlight` token and opacity rules) | no | yes | yes | yes | documented in `forge_panel_shell_spec.md` theme tokens + drag highlight behavior |
| Severity-driven visual feedback for diagnostics is standardized (background tint, border, icon) | yes | yes | yes | yes | documented in `forge_panel_shell_spec.md` diagnostic visual treatment |
| Highlight feedback patterns are defined for search/selection/decorations in editor and explorer contexts | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` decorations/search highlighting and `tom_forge_ui_testapp.md` selection highlighting |
| Status bar visual feedback supports context-sensitive active/inactive item visibility (`isActive`) | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` status bar item model and integration notes |
| Theme and visual-language implementation evidence includes golden tests for default/dark/high-contrast shells | no | no | no | yes | documented in `forge_panel_shell_spec.md` golden tests (`shell_default`, `shell_dark`, `shell_high_contrast`) |

## 15. Dialogs, Notifications, and User Prompts
This section is intended to cover quick-pick/input dialogs, open/save dialogs, toast notifications, and user confirmation flows. Include checks for shell service behavior and module/component usage patterns.

- [x] Section completed (finished on 2026-03-30T06:25:19+02:00)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| Dialog, notification, and progress services are first-class shell APIs (`dialogs`, `notifications`, `progress`) | yes | no | yes | yes | documented in `forge_panel_shell_concept.md` `ForgeShellApi` service surface |
| Action flow supports user-driven dialogs for input/selection/file operations via dialog manager | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` action execution notes (`ForgeDialogManager`) |
| Quick pick interaction is defined (`showQuickPick`) for selection prompts | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` dialog API and `tom_forge_ui_testapp.md` test dialog behavior |
| Input prompt interaction is defined (`showInputBox`) for text-based user input | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` dialog API and usage example |
| Open/save file dialog flows are defined (`showOpenDialog`, `showSaveDialog`) | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` dialog API and `tom_forge_ui_testapp.md` simplified picker implementation |
| "Open with" resolver prompt is defined with primary + additional editor options | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` open-with workflow and shell dialog behavior |
| Startup dialog flow is specified (workspace/config selection, remembered defaults, CLI bypass) | no | no | no | yes | documented in `forge_panel_shell_concept.md` startup dialog section |
| Notification API supports info/warning/error message channels and optional user actions | yes | yes | yes | yes | documented in `forge_panel_shell_concept.md` notification API and `tom_forge_ui_testapp.md` action button behavior |
| Toast lifecycle/visual behavior is specified (appear/dismiss timing, overlay pattern, auto-dismiss) | no | yes | yes | yes | documented in `forge_panel_shell_spec.md` notification timing and `tom_forge_ui_testapp.md` `NotificationOverlay` behavior |
| Error and recovery prompts are defined for file and save conflicts (modal, retry/cancel, merge options) | yes | yes | yes | yes | documented in `forge_panel_shell_spec.md` error scenario table and save conflict flow |
| Dirty-close confirmation prompts (save / don't save / cancel) are explicitly required | yes | yes | yes | yes | documented in `forge_panel_shell_spec.md` close flow and `tom_forge_ui_testapp.md` close-dirty behavior |
| Test coverage expectations exist for dialog/notification/progress managers | yes | no | yes | yes | documented in `forge_panel_shell_spec.md` test matrix and `tom_forge_ui_testapp.md` service list |

## 16. Explorer and Workspace Search
This section is intended to cover file explorer loading behavior, path handling, reveal/open flows, search query execution, search result navigation, and large-workspace responsiveness. Include checks at shell service level and per-module view behavior.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

## 17. Diagnostics, Problems, and Output Channels
This section is intended to cover diagnostic collection lifecycle, problem presentation, output channel behavior, and synchronization with editor/system state. Include checks for shell managers and per-module diagnostic/output producers.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

## 18. Status Bar and Context Signaling
This section is intended to cover status bar item contribution, placement, update cadence, and context-sensitive values (cursor/language/diagnostics/etc.). Include checks for shell aggregation and per-module/component status item quality.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

## 19. Terminal, Process, and Runtime Tooling Integration
This section is intended to cover terminal manager behavior, terminal lifecycle events, process/output integration, and module usage of runtime tooling services. Include checks for shell terminal infrastructure and module-level runtime interactions.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

## 20. Editor Base Contracts and Text Editing Core
This section is intended to cover `ForgeEditor`/`ForgeTextEditor`/`ForgeDocument` contracts, text operations, selection/cursor/visible range reporting, and editor integration bridge behavior. Include checks for shared Forge editor base and each integrated editor module.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

## 21. Text Settings, Context Discovery, and Configuration Injection
This section is intended to cover `ForgeTextSettings`, context discovery (`ForgeTextContext`), per-editor-type settings, and runtime settings propagation. Include checks for shell persistence/injection and per-editor adaptation behavior.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

## 22. Undo/Redo, Dirty State, and Save Lifecycle
This section is intended to cover undo/redo behavior, dirty tracking semantics, save/save-all/will-save/did-save event flow, and consistency across editors. Include checks for shell-level state handling and per-editor implementation consistency.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

## 23. File Type Resolution and Fallback Opening
This section is intended to cover `canHandle`/`canHandleContent` resolution, editor selection by URI/content, unknown-type fallback behavior, and file-open error handling. Include checks for shell resolver behavior and per-editor/module resolver contributions.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

## 24. Advanced Data Services (Decorations, Outline, Virtual Documents, Workspace Edits)
This section is intended to cover decoration pipelines, outline provider integration, virtual document providers, and multi-file workspace edit application. Include checks for shell service APIs and per-module/component usage coverage.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

## 25. State Persistence and Recovery
This section is intended to cover persistence of shell settings, per-editor settings, panel/application state expectations, and recovery behavior after restart. Include checks for shell persistence services and per-module persistence responsibilities.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

## 26. Error Handling and Recovery Patterns
This section is intended to cover error classification, user-facing recovery feedback, fallback behavior, and non-fatal degradation patterns. Include checks for shell-level resilience and per-module/component error hygiene.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

## 27. Performance and Scalability
This section is intended to cover responsiveness budgets, lazy loading/virtualization strategy, expensive-operation isolation, and large-workspace behavior. Include checks for shell infrastructure and per-module/component performance hotspots.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

## 28. Testing and Quality Gates
This section is intended to cover unit/widget/integration/E2E test expectations, analyzer/test gates, regression scope, and promotion criteria from staging to production app. Include checks for framework-level quality gates and per-module/component test coverage.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

## 29. Feature Matrix by Scope (Forge vs Module vs Component)
This section is intended to provide a cross-cutting checklist matrix for every feature area, explicitly separating: (a) Forge core responsibility, (b) module-level implementation responsibility, and (c) component-level behavior responsibility.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |
