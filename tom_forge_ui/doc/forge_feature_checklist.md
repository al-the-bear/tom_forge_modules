# Forge Feature Checklist

## 1. Shell Architecture and Lifecycle
This section is intended to cover the top-level Forge shell runtime model: startup, module activation/deactivation, shell service wiring, and lifecycle guarantees. Include checks at Forge level and per integrated module that depends on shell lifecycle hooks.

## 2. Workspace Model and File/Revision Boundaries
This section is intended to cover workspace root handling, file-system scope, `.forge/` state/revision boundaries, and workspace-level assumptions. Include checks for core Forge behavior and module/component behavior when operating on workspace data.

## 3. Application Model and Multi-Application Switching
This section is intended to cover application definitions, switching behavior, in-memory retention of inactive applications, and app-specific layout/action contexts. Include checks for global Forge behavior and module/component behavior across application switches.

## 4. Module Integration and Ownership Boundaries
This section is intended to cover module contracts, registration, module-provided views/editors/actions/shortcuts, and module-to-shell ownership boundaries. Include checks for shell-level module orchestration and per-module conformance.

## 5. Component Model (Views and Editors)
This section is intended to cover component contracts (`title`, `icon`, `buildMain`, `buildCopy`, size hints), view vs editor semantics, and component identity. Include checks at shell level and per component implementation in each module.

## 6. Layout Topology and Panel Composition
This section is intended to cover title bar, menu bar, left/right/middle/bottom panel structure, and status bar composition. Include checks for the Forge shell layout engine and per-module panel content integration.

## 7. Panel Resizing and Splitter Behavior
This section is intended to cover draggable splitters, min/max constraints, hover/drag affordances, and resize persistence expectations. Include checks for shell splitter mechanics and module/component behavior under panel size changes.

## 8. Tab Systems and Editor/View Tab UX
This section is intended to cover tab creation, activation, close behavior, hover feedback, dirty indicators, and tab overflow behavior in middle and auxiliary panels. Include checks for shell tab controls and per-component tab title/state updates.

## 9. Accordeon Section Behavior
This section is intended to cover section expand/collapse rules, pinning, multi-open behavior, section sizing/sharing, and empty/drop placeholder behavior. Include checks for shell accordeon mechanics and per-view section compatibility.

## 10. Drag-and-Drop Layout Operations
This section is intended to cover drag move/copy semantics, drop zones, panel split creation, and UI-copy behavior (including SHIFT-copy flows). Include checks for shell drag/drop infrastructure and per-component/module support.

## 11. Navigation and Command Surfaces
This section is intended to cover menu bar, command palette, title-bar search entry behavior, back/forward navigation hooks, and command parity across entry points. Include checks for shell command routing and per-module command exposure.

## 12. Actions and Shortcut Framework
This section is intended to cover action registration, enable/visible state logic, shortcut binding/effective shortcut display, platform-specific modifier behavior, and conflict handling. Include checks at Forge action/shortcut manager level and per-module/per-component action sets.

## 13. Focus Management and Accessibility
This section is intended to cover keyboard navigation order, focus visibility, focus trapping in modal surfaces, screen-reader semantics, and hit-target usability. Include checks for shell accessibility baseline and per component/module accessibility conformance.

## 14. Theme, Visual Language, and Interaction Feedback
This section is intended to cover shell theming hooks, color/contrast expectations, active/hover/drag visual states, and consistency of feedback patterns. Include checks for global Forge theming and per-module/component visual integration.

## 15. Dialogs, Notifications, and User Prompts
This section is intended to cover quick-pick/input dialogs, open/save dialogs, toast notifications, and user confirmation flows. Include checks for shell service behavior and module/component usage patterns.

## 16. Explorer and Workspace Search
This section is intended to cover file explorer loading behavior, path handling, reveal/open flows, search query execution, search result navigation, and large-workspace responsiveness. Include checks at shell service level and per-module view behavior.

## 17. Diagnostics, Problems, and Output Channels
This section is intended to cover diagnostic collection lifecycle, problem presentation, output channel behavior, and synchronization with editor/system state. Include checks for shell managers and per-module diagnostic/output producers.

## 18. Status Bar and Context Signaling
This section is intended to cover status bar item contribution, placement, update cadence, and context-sensitive values (cursor/language/diagnostics/etc.). Include checks for shell aggregation and per-module/component status item quality.

## 19. Terminal, Process, and Runtime Tooling Integration
This section is intended to cover terminal manager behavior, terminal lifecycle events, process/output integration, and module usage of runtime tooling services. Include checks for shell terminal infrastructure and module-level runtime interactions.

## 20. Editor Base Contracts and Text Editing Core
This section is intended to cover `ForgeEditor`/`ForgeTextEditor`/`ForgeDocument` contracts, text operations, selection/cursor/visible range reporting, and editor integration bridge behavior. Include checks for shared Forge editor base and each integrated editor module.

## 21. Text Settings, Context Discovery, and Configuration Injection
This section is intended to cover `ForgeTextSettings`, context discovery (`ForgeTextContext`), per-editor-type settings, and runtime settings propagation. Include checks for shell persistence/injection and per-editor adaptation behavior.

## 22. Undo/Redo, Dirty State, and Save Lifecycle
This section is intended to cover undo/redo behavior, dirty tracking semantics, save/save-all/will-save/did-save event flow, and consistency across editors. Include checks for shell-level state handling and per-editor implementation consistency.

## 23. File Type Resolution and Fallback Opening
This section is intended to cover `canHandle`/`canHandleContent` resolution, editor selection by URI/content, unknown-type fallback behavior, and file-open error handling. Include checks for shell resolver behavior and per-editor/module resolver contributions.

## 24. Advanced Data Services (Decorations, Outline, Virtual Documents, Workspace Edits)
This section is intended to cover decoration pipelines, outline provider integration, virtual document providers, and multi-file workspace edit application. Include checks for shell service APIs and per-module/component usage coverage.

## 25. State Persistence and Recovery
This section is intended to cover persistence of shell settings, per-editor settings, panel/application state expectations, and recovery behavior after restart. Include checks for shell persistence services and per-module persistence responsibilities.

## 26. Error Handling and Recovery Patterns
This section is intended to cover error classification, user-facing recovery feedback, fallback behavior, and non-fatal degradation patterns. Include checks for shell-level resilience and per-module/component error hygiene.

## 27. Performance and Scalability
This section is intended to cover responsiveness budgets, lazy loading/virtualization strategy, expensive-operation isolation, and large-workspace behavior. Include checks for shell infrastructure and per-module/component performance hotspots.

## 28. Testing and Quality Gates
This section is intended to cover unit/widget/integration/E2E test expectations, analyzer/test gates, regression scope, and promotion criteria from staging to production app. Include checks for framework-level quality gates and per-module/component test coverage.

## 29. Feature Matrix by Scope (Forge vs Module vs Component)
This section is intended to provide a cross-cutting checklist matrix for every feature area, explicitly separating: (a) Forge core responsibility, (b) module-level implementation responsibility, and (c) component-level behavior responsibility.
