# Tom Forge Full Integration Plan

## 1. Goal

This document defines the steps required to run the full Tom Forge editor stack
as an integrated shell application, not only as package-level components and
tests.

Success means:

1. The real app entrypoint starts the Forge shell.
2. The shell registers the editor module set and app module set.
3. Menus, command palette, shortcuts, editor actions, and settings work through
   shared shell services.
4. The system behaves consistently on Linux/macOS/Windows.

## 2. Current Status Snapshot

The editor integration foundation is implemented and validated in
`tom_forge_ui` and related editor packages. The main missing piece is full
runtime wiring in the production app path.

Implemented:

1. `ShellEditorIntegration` and editor adapter wiring.
2. Shared shell action/shortcut APIs in `ForgeShellApi` + defaults.
3. Integration tests proving editor-shell bridge behavior.

Still missing for full runtime integration:

1. `tom_forge_app/lib/main.dart` still uses Flutter template flow, not shell
   bootstrap flow.
2. Production app module composition equivalent to the test app module is not
   yet wired in the real app path.
3. `ForgeMenuBar` still contains placeholder actions and a non-executing
   `_executeAction` path.
4. Command sources are split (module action lists vs shell action registry).
5. Top-level shell shortcuts are hard-coded for Meta key usage.

## 3. Target Architecture

## 3.1 Runtime Boot Sequence

1. Create shell API with real file system backing.
2. Create and activate modules:
   1. `TomForgeShellModule`
   2. Application module (views/actions/status bar)
3. Register modules in module registry.
4. Build `ForgeApplication` layout from module-provided views.
5. Start `ForgeShellScaffold` with the created shell and application layout.

## 3.2 Single Source of Truth

All shell interactions should converge to these services:

1. `ForgeActionRegistry` for available commands/actions.
2. `ForgeShortcutManager` for active key bindings.
3. `ForgeSystemState` for active editor and editor context.
4. `ForgeConfigManager` + text settings API for editor display settings.

## 4. Implementation Steps

## Phase 0: Bootstrap Production App (Highest Priority)

Objective: Make the real app start with `ForgeShellScaffold` and registered
modules.

Primary files:

1. `tom_forge_app/lib/main.dart`
2. New app bootstrap file(s) under `tom_forge_app/lib/src/`

Tasks:

1. Replace Flutter demo entrypoint with shell bootstrap flow.
2. Instantiate `DefaultShellApi.withDefaultsAndFileSystem(...)` with real
   workspace root.
3. Activate and register `TomForgeShellModule`.
4. Activate and register an application module for shell views/actions.
5. Render `ForgeShellScaffold` as app home.

Acceptance criteria:

1. App launches directly into shell layout.
2. Opening a markdown/dart/yaml file creates the correct adapter editor.
3. No demo counter/home page remains in runtime path.

## Phase 1: Production App Module Extraction

Objective: Move test-harness shell app behavior into production module code.

Primary files:

1. New module file in `tom_forge_app/lib/src/` (for example
   `tom_forge_app_module.dart`).
2. Optionally reuse or port logic from
   `tom_forge_ui_test/lib/src/test_app_module.dart`.

Tasks:

1. Define views: Explorer, Search, Outline, Problems, Output.
2. Define core actions: file save/save-all, close/close-all, undo/redo,
   panel toggles.
3. Define default shortcut bindings.
4. Define status bar items and state listeners.

Acceptance criteria:

1. Command palette contains production module actions.
2. Status bar updates when active editor/diagnostics change.
3. Actions can be executed from both command palette and menu.

## Phase 2: Menu Wiring to Real Actions

Objective: Remove menu placeholders and execute real shell actions.

Primary files:

1. `tom_forge_ui/lib/src/widgets/forge_menu_bar.dart`

Tasks:

1. Replace `_showNotImplemented(...)` action entries with real action dispatch.
2. Implement `_executeAction(String actionId)` via shell API action execution.
3. Route editor commands (undo/redo/cut/copy/paste/find) through either:
   1. focused editor integration action IDs, or
   2. shell action registry entries with context checks.
4. Keep user feedback for unavailable actions (disabled menu entries or
   informative toast).

Acceptance criteria:

1. File/Edit/View menu operations execute where supported.
2. Menu labels and enabled state reflect actual command availability.
3. Placeholder-only menu items are removed or explicitly marked as deferred.

## Phase 3: Command Palette and Registry Unification

Objective: Use shell action registry as command source.

Primary files:

1. `tom_forge_ui/lib/src/widgets/forge_command_palette.dart`
2. `tom_forge_ui/lib/src/defaults/default_shell_api.dart`
3. `tom_forge_ui/lib/src/defaults/default_module_registry.dart`

Tasks:

1. Build palette list from `shellApi.actionRegistry` (plus optional built-ins).
2. Use shortcut manager bindings to display effective shortcuts (not only
   default shortcuts).
3. Ensure module activation/registration publishes actions and shortcuts to
   registries consistently.
4. Prevent duplicate action IDs and define deterministic precedence.

Acceptance criteria:

1. Palette shows editor and shell actions consistently.
2. Rebound shortcuts are reflected in palette labels.
3. Executing a palette entry follows same execution path as menu shortcuts.

## Phase 4: Platform-Accurate Shortcut Handling

Objective: Make shell shortcuts correct on all desktop platforms.

Primary files:

1. `tom_forge_ui/lib/src/widgets/forge_shell_scaffold.dart`
2. Shortcut utility/helper file(s) if needed.

Tasks:

1. Replace hard-coded `meta: true` activators with platform-aware primary
   modifier handling.
2. Align shell-level shortcut display and behavior with `ForgeShortcutKey`.
3. Validate Linux Ctrl-based behavior, macOS Cmd-based behavior, and Windows
   Ctrl-based behavior.

Acceptance criteria:

1. Same command IDs trigger correctly using expected platform modifiers.
2. No Linux regression from Meta-only bindings.
3. Shortcut docs and visible labels match runtime behavior.

## Phase 5: Settings and Persistence Integration

Objective: Make editor settings persist and round-trip through shell config.

Primary files:

1. `tom_forge_ui/lib/src/widgets/forge_configuration_dialog.dart`
2. `tom_forge_ui/lib/src/services/forge_preferences_service.dart`
3. Any app-level persistence bridge in `tom_forge_app`.

Tasks:

1. Ensure settings save path writes and reloads editor text settings.
2. Ensure per-editor-type settings (`md`, `dart`, `yaml`) persist across app
   restart.
3. Ensure runtime updates propagate to active editor widgets.

Acceptance criteria:

1. Changing settings updates open editors immediately or on documented reload.
2. Restarting app preserves settings.
3. Settings dialog values always match effective shell values.

## Phase 6: End-to-End Validation

Objective: Verify full integrated behavior in runtime, not only unit tests.

Required checks:

1. `dart analyze` for affected packages:
   1. `tom_forge_ui`
   2. `tom_forge_app`
2. Relevant test runs:
   1. `tom_forge_ui` integration tests
   2. app/widget smoke tests for `tom_forge_app`
3. Manual integration matrix:
   1. Open files by extension (`.md`, `.dart`, `.yaml`, `.yml`)
   2. Save/save-all flows
   3. Menu and palette command parity
   4. Shortcut behavior per platform
   5. Settings persistence across restart

Recommended command sequence:

```bash
cd tom_forge/tom_forge_ui
dart analyze
flutter test

cd ../tom_forge_app
dart analyze
flutter test
flutter run
```

## 5. Detailed Work Breakdown (Task Board)

## Sprint A (Bootstrap + module wiring)

1. Replace production main entrypoint with shell bootstrap.
2. Introduce production app module and register it.
3. Verify shell opens files and renders all panels.

## Sprint B (menu/palette/shortcuts)

1. Wire menu actions to real execution paths.
2. Unify palette source with action registry.
3. Implement platform-aware shortcut handling.

## Sprint C (settings + polish + E2E)

1. Complete settings persistence round-trip.
2. Add regression tests for menu and palette command execution.
3. Perform final analyzer/tests/manual validation.

## 6. Risks and Mitigations

1. Risk: duplicate action IDs from shell + editor modules.
   Mitigation: enforce ID namespace and collision logging.
2. Risk: inconsistent shortcut display vs runtime behavior.
   Mitigation: format labels from effective binding source only.
3. Risk: editor-specific commands unavailable when no active editor.
   Mitigation: strict enabled/visible guards and focus-aware dispatch.
4. Risk: platform shortcut regressions.
   Mitigation: add platform-specific shortcut tests and manual checklist.

## 7. Definition of Done

Full integration is complete when all conditions are true:

1. Production app boots into `ForgeShellScaffold` with registered modules.
2. Menu, palette, and keyboard shortcuts execute through unified shell action
   infrastructure.
3. Markdown, Dart, and YAML editors work in shell mode with context/action
   integration.
4. Settings persist and reapply correctly.
5. Analyzer and tests pass in both `tom_forge_ui` and `tom_forge_app`.
6. Manual integration matrix has no open blockers.

## 8. Suggested Implementation Order

Do the work in this exact sequence to reduce rework:

1. Phase 0
2. Phase 1
3. Phase 2
4. Phase 3
5. Phase 4
6. Phase 5
7. Phase 6

This order ensures runtime wiring is stable before command and UX refinement.
