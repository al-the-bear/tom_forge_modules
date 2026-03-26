# Tom Forge Full Integration Plan

## 1. Goal

Build and validate an almost-production integrated shell runtime in
`tom_forge_ui_test`, then promote it into `tom_forge_app` after additional
modules/editors and review cycles.

This document intentionally treats `tom_forge_ui_test` as the staging runtime.

Success means:

1. `tom_forge_ui_test` behaves like a production shell for core flows.
2. New modules/editors can be integrated there with low risk.
3. Promotion to `tom_forge_app` is a controlled copy/move, not a redesign.

## 1.1 Implementation Status

| Phase | Status | Notes |
| --- | --- | --- |
| Phase A | Completed (2026-03-26) | Implemented and re-verified in both `tom_forge_ui` and `tom_forge_ui_test` with analyzer/tests passing (latest strict pass included integration-path test coverage) |
| Phase B | Completed (2026-03-26) | Implemented and verified in `tom_forge_ui` and `tom_forge_ui_test`; command source unification, effective shortcut display, and platform-aware shell shortcuts are active |
| Phase C | Completed (2026-03-26, strict re-verified) | Implemented and strictly re-verified; per-editor text settings persistence, startup hydration, and runtime synchronization validated across shell and staging app |
| Phase D | Not Started | Planned |
| Phase E | Not Started | Planned |

## 2. Strategy: Staged Promotion Model

## 2.1 Runtime Roles

1. `tom_forge_ui`: shell framework and reusable integration infrastructure.
2. `tom_forge_ui_test`: near-production staging app and integration proving
   ground.
3. `tom_forge_app`: final consumer app, promoted only after staging gates pass.

## 2.2 Why This Model

1. Faster iteration while APIs and module set are still evolving.
2. Safer integration of additional editors/modules before locking app runtime.
3. Clear quality gates before promotion.

## 3. Current Baseline

Already in place:

1. `ShellEditorIntegration` wiring in editor adapters.
2. Shared shell APIs for actions, shortcuts, settings, and editor context.
3. Working shell bootstrap pattern in `tom_forge_ui_test`.

Current gaps for near-production readiness:

1. Expansion-cycle validation for additional modules/editors (Phase D) is not
   started yet.
2. Promotion package (`tom_forge_app`) remains template-level until staged
   promotion work (Phase E).

## 4. Target Staging Architecture (tom_forge_ui_test)

## 4.1 Boot Flow

1. Create shell with real file system backing.
2. Activate/register `TomForgeShellModule`.
3. Activate/register app module(s) for views/actions/status bar.
4. Build `ForgeApplication` layout from modules.
5. Start `ForgeShellScaffold`.

## 4.2 Command and State Single Sources

1. Action source: `ForgeActionRegistry`.
2. Shortcut source: `ForgeShortcutManager` effective bindings.
3. Editor state source: `ForgeSystemState` active context.
4. Settings source: shell config plus text settings APIs.

## 5. Implementation Plan

## Phase A: Harden Staging Runtime in tom_forge_ui_test

Objective: make `tom_forge_ui_test` almost production for current scope.

Status timeline: In-Progress -> Completed (2026-03-26, re-verified)

Primary files:

1. `tom_forge_ui_test/lib/main.dart`
2. `tom_forge_ui_test/lib/src/app.dart`
3. `tom_forge_ui_test/lib/src/test_app_module.dart`

Tasks:

1. Keep bootstrap path as canonical staging startup.
2. Ensure all shell views are wired with stable layout defaults.
3. Ensure save/save-all/close/undo/redo/panel actions are complete and usable.
4. Extend module with new editors/modules as they are added.

Acceptance criteria:

1. App boots to shell without placeholder-only critical paths.
2. Core actions work from menu, command palette, and shortcuts.
3. Opening `.md`, `.dart`, `.yaml`, `.yml` consistently selects correct editor.

Implementation evidence:

1. Added test-first coverage for menu command execution in
   `tom_forge_ui/test/widgets/forge_menu_bar_test.dart`.
2. Implemented real action dispatch for menu commands (`file.save`,
   `file.saveAll`, `file.close`, `edit.undo`, `edit.redo`) in
   `tom_forge_ui/lib/src/widgets/forge_menu_bar.dart`.
3. Confirmed tests pass in `tom_forge_ui` after implementation.
4. Verified `tom_forge_ui_test` end-to-end package validation with
   `flutter analyze` and `flutter test` passing after staging SDK alignment.
5. Added and passed strict integration-path tests in
   `tom_forge_ui/test/widgets/phase_a_shell_paths_test.dart` covering:
   1. command palette command execution (`file.save`)
   2. shell shortcut command execution (`file.save`)

## Phase B: Shell UX and Command Reliability (tom_forge_ui)

Objective: remove framework-level blockers for near-production operation.

Status timeline: In-Progress -> Completed (2026-03-26, strict re-verification)

Primary files:

1. `tom_forge_ui/lib/src/widgets/forge_menu_bar.dart`
2. `tom_forge_ui/lib/src/widgets/forge_command_palette.dart`
3. `tom_forge_ui/lib/src/widgets/forge_shell_scaffold.dart`
4. `tom_forge_ui/lib/src/defaults/default_shell_api.dart`
5. `tom_forge_ui/lib/src/defaults/default_module_registry.dart`

Tasks:

1. Replace placeholder menu handlers with real action dispatch.
2. Unify palette command source to action registry.
3. Display shortcuts using effective runtime bindings.
4. Make shell shortcut handling platform-accurate.
5. Define duplicate action ID policy and conflict logging.

Acceptance criteria:

1. No critical File/Edit/View action is placeholder-only.
2. Menu and palette execute identical command IDs.
3. Shortcut labels match actual active bindings.
4. Linux/macOS/Windows modifier behavior is correct.

Implementation evidence:

1. Replaced critical File/Edit placeholder menu paths with real action
   dispatch in `tom_forge_ui/lib/src/widgets/forge_menu_bar.dart`.
2. Unified command palette action source to shell action registry, with
   deduped module-action fallback coverage in
   `tom_forge_ui/lib/src/widgets/forge_command_palette.dart`.
3. Command palette now shows effective shortcut bindings from shortcut manager
   (runtime binding first, default shortcut second).
4. Updated shell scaffold shortcuts to platform-aware primary modifier mapping
   in `tom_forge_ui/lib/src/widgets/forge_shell_scaffold.dart`.
5. Updated module registration wiring so module actions/shortcuts are published
   into shell registries in `tom_forge_ui/lib/src/defaults/default_module_registry.dart`
   and `tom_forge_ui/lib/src/defaults/default_shell_api.dart`.
6. Added and passed new Phase B tests:
   1. `tom_forge_ui/test/widgets/phase_b_command_palette_test.dart`
   2. `tom_forge_ui/test/widgets/phase_b_shortcut_platform_test.dart`

Verification results (latest strict pass):

1. `tom_forge_ui`: `dart analyze` clean, `flutter test` 51 passed.
2. `tom_forge_ui_test`: `flutter analyze` clean, `flutter test` 1 passed.

## Phase C: Settings and Persistence Hardening

Objective: make staging behavior durable across runs.

Status timeline: In-Progress -> Completed (2026-03-26)

Primary files:

1. `tom_forge_ui/lib/src/widgets/forge_configuration_dialog.dart`
2. `tom_forge_ui/lib/src/services/forge_preferences_service.dart`
3. `tom_forge_ui_test` persistence entrypoint code as needed

Tasks:

1. Persist editor text settings by editor type.
2. Ensure values round-trip after restart.
3. Ensure active editors refresh from updated settings consistently.

Acceptance criteria:

1. Settings changes survive restart.
2. Staging UI shows effective values after reload.
3. Editor visuals and behavior are consistent with configured values.

Implementation evidence:

1. Added persistent editor text settings storage in
   `tom_forge_ui/lib/src/services/forge_preferences_service.dart` using
   shared preferences key `forge.editor.textSettings` with per-editor-type
   serialization and round-trip loading.
2. Added shell startup hydration and runtime synchronization from preferences in
   `tom_forge_ui/lib/src/widgets/forge_shell_scaffold.dart` so persisted
   settings are applied to shell APIs during initialization and on preference
   updates.
3. Updated settings dialog save flow in
   `tom_forge_ui/lib/src/widgets/forge_configuration_dialog.dart` to persist
   per-editor text settings via preferences and apply them to the active shell.
4. Added and passed Phase C tests:
   1. `tom_forge_ui/test/services/forge_preferences_service_test.dart`
   2. `tom_forge_ui/test/widgets/phase_c_settings_persistence_test.dart`
   3. Additional runtime-sync coverage in
      `tom_forge_ui/test/widgets/phase_c_settings_persistence_test.dart`
      verifies shell updates when preferences change after startup.
5. Enabled `uses-material-design: true` in `tom_forge_ui/pubspec.yaml`
   to align package configuration with Material icon usage in the IDE shell.

Verification results (latest strict pass):

1. `tom_forge_ui`: `dart analyze` clean, `flutter test` 54 passed.
2. `tom_forge_ui_test`: `flutter analyze` clean, `flutter test` 1 passed.

## Phase D: Expansion Cycles (More Modules/Editors)

Objective: integrate additional modules/editors while staying near-production.

For each new module/editor:

1. Add module to staging bootstrap.
2. Register actions and shortcuts in shell registries.
3. Add panel/view integration in application layout.
4. Add integration tests and smoke scenarios.
5. Run analyzer + test suite before merging.

Gate per cycle:

1. No analyzer errors in affected packages.
2. No command regression in menu/palette/shortcut matrix.
3. No editor opening regression by file type.

## Phase E: Promotion to tom_forge_app

Objective: promote proven staging runtime into production app package.

Promotion approach:

1. Copy bootstrap/module composition from `tom_forge_ui_test` to
   `tom_forge_app` with minimal delta.
2. Keep same command IDs, shortcut IDs, and layout model.
3. Avoid introducing new behavior during promotion.

Primary files:

1. `tom_forge_app/lib/main.dart`
2. New `tom_forge_app/lib/src/` runtime files derived from staging app/module

Promotion gate checklist:

1. At least two review cycles completed in staging after latest major module
   additions.
2. Manual integration matrix fully green.
3. Staging regression tests stable across repeated runs.
4. `tom_forge_app` analyze/tests green after port.

## 6. Validation Plan

## 6.1 Automated

Run on every integration milestone:

```bash
cd tom_forge/tom_forge_ui
dart analyze
flutter test

cd ../tom_forge_ui_test
dart analyze
flutter test
```

Run on promotion milestones:

```bash
cd tom_forge/tom_forge_app
dart analyze
flutter test
flutter run
```

## 6.2 Manual Matrix

1. Open each supported file type and verify correct adapter.
2. Execute save/save-all/close/undo/redo through:
   1. menu
   2. command palette
   3. keyboard shortcut
3. Verify panel toggles and focus routing.
4. Verify settings persistence across restart.
5. Verify platform shortcut behavior.

## 7. Risks and Controls

1. Risk: drift between staging and production runtime.
   Control: promotion by copy/port with minimal behavioral delta.
2. Risk: action duplication and command ambiguity.
   Control: explicit action ID conventions and conflict checks.
3. Risk: platform-specific shortcut regressions.
   Control: platform test matrix and primary-modifier abstraction.
4. Risk: frequent module expansion destabilizes shell UX.
   Control: per-cycle gates and mandatory smoke checklist.

## 8. Definition of Done for This Stage

This stage is done when:

1. `tom_forge_ui_test` is accepted as almost production for integrated shell
   behavior.
2. Core shell UX paths are real (not placeholders) for required commands.
3. Additional modules/editors can be integrated repeatedly without regressions.
4. Promotion packet for `tom_forge_app` is ready and low risk.

## 9. Immediate Next Steps

1. Start Phase D by integrating the next module/editor set in staging only.
2. Add Phase D integration tests for menu/palette/shortcut parity and
   file-type opening behavior for the new module/editor set.
3. Execute a full manual matrix pass including persistence and platform
   shortcut validation after the new module/editor integration.
4. Prepare a promotion packet for `tom_forge_app` only after Phase D gates are
   green.
