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

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

## 4. Module Integration and Ownership Boundaries
This section is intended to cover module contracts, registration, module-provided views/editors/actions/shortcuts, and module-to-shell ownership boundaries. Include checks for shell-level module orchestration and per-module conformance.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

## 5. Component Model (Views and Editors)
This section is intended to cover component contracts (`title`, `icon`, `buildMain`, `buildCopy`, size hints), view vs editor semantics, and component identity. Include checks at shell level and per component implementation in each module.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

## 6. Layout Topology and Panel Composition
This section is intended to cover title bar, menu bar, left/right/middle/bottom panel structure, and status bar composition. Include checks for the Forge shell layout engine and per-module panel content integration.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

## 7. Panel Resizing and Splitter Behavior
This section is intended to cover draggable splitters, min/max constraints, hover/drag affordances, and resize persistence expectations. Include checks for shell splitter mechanics and module/component behavior under panel size changes.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

## 8. Tab Systems and Editor/View Tab UX
This section is intended to cover tab creation, activation, close behavior, hover feedback, dirty indicators, and tab overflow behavior in middle and auxiliary panels. Include checks for shell tab controls and per-component tab title/state updates.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

## 9. Accordeon Section Behavior
This section is intended to cover section expand/collapse rules, pinning, multi-open behavior, section sizing/sharing, and empty/drop placeholder behavior. Include checks for shell accordeon mechanics and per-view section compatibility.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

## 10. Drag-and-Drop Layout Operations
This section is intended to cover drag move/copy semantics, drop zones, panel split creation, and UI-copy behavior (including SHIFT-copy flows). Include checks for shell drag/drop infrastructure and per-component/module support.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

## 11. Navigation and Command Surfaces
This section is intended to cover menu bar, command palette, title-bar search entry behavior, back/forward navigation hooks, and command parity across entry points. Include checks for shell command routing and per-module command exposure.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

## 12. Actions and Shortcut Framework
This section is intended to cover action registration, enable/visible state logic, shortcut binding/effective shortcut display, platform-specific modifier behavior, and conflict handling. Include checks at Forge action/shortcut manager level and per-module/per-component action sets.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

## 13. Focus Management and Accessibility
This section is intended to cover keyboard navigation order, focus visibility, focus trapping in modal surfaces, screen-reader semantics, and hit-target usability. Include checks for shell accessibility baseline and per component/module accessibility conformance.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

## 14. Theme, Visual Language, and Interaction Feedback
This section is intended to cover shell theming hooks, color/contrast expectations, active/hover/drag visual states, and consistency of feedback patterns. Include checks for global Forge theming and per-module/component visual integration.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

## 15. Dialogs, Notifications, and User Prompts
This section is intended to cover quick-pick/input dialogs, open/save dialogs, toast notifications, and user confirmation flows. Include checks for shell service behavior and module/component usage patterns.

- [ ] Section completed (finished on ...)

| category | per module? | per component? | to be implemented in modules? | shell implementation done? | implemented on |
|---|---|---|---|---|---|
| | | | | | |

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
