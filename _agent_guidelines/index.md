# Tom Forge Modules — Agent Guidelines

Guidelines of the **tom_forge_modules** repository: the libraries of the Tom
construction kit — Tom Forge's side for building IDEs and Webwork's side for
building business applications — and the components that follow the kit's
contracts. Read these before modifying any package here.

---

## Placement rule: where a component belongs

Three layers, each depending only on itself and the layers below:

| Layer | Repository | Holds | May depend on |
| --- | --- | --- | --- |
| 1 Framework | `tom_ai` (basics, core, core extensions) and `tom_modules` | services, storage, sync, the business models (items, calendar, formula), file sessions and editors, highlighters, the PDF and office widgets: models and widgets any Flutter or Dart program can use; **free of Forge** | layer 1 |
| 2 Libraries of the kit | **`tom_forge_modules`** (this repository) | the kit itself (`tom_forge_core`, `tom_editors_shared`, `tom_forge_kit`, `tom_forge_shared_ui`, the panel shell `tom_forge_shell`), the editors and their plugins, the adapters, the views, the terminal, the quest workbench, the agentic views, the hosts, the full-desktop umbrella `tom_forge_ui`, the kit's examples, and Webwork's libraries beside Forge's: **every component that follows the kit's contracts** | layers 1 and 2 |
| 3 Applications | `tom_forge` (the Tom Forge application), `app_webwork`, `app_secrets_manager`, new projects | the composition of an application, its runners and its application-level suites | layers 1 and 2 |

- A package here never depends on an application (layer 3); an application
  depends only on libraries, never on another top-level project.
- A component with no Forge dependency in itself (a model, a plain widget)
  belongs in layer 1 (`tom_modules`); its Forge adapter sits here.
- Within this repository the kit never names a component, and the layer table
  of [platform_architecture.md](platform_architecture.md) decides what may
  depend on what; the guard is the Tom Forge application's
  `tom_forge/tom_forge_app/test/platform_layering_test.dart`, which scans this
  repository and `tom_forge`.

---

## Documents

| Document | Purpose |
|----------|---------|
| [platform_architecture.md](platform_architecture.md) | The platform's layers (foundation, editor kit, editors, shell, shell services, modules, apps), the contracts at each boundary, how a file reaches an editor, the dependency and licence rules; the Tom Forge application's `tom_forge/tom_forge_app/test/platform_layering_test.dart` checks the layering |
| [editor_component_contract.md](editor_component_contract.md) | What an editor component and a shell editor must provide to be assembled into a tool: the standalone component rules, document editors (and the undo conformance run each has), surfaces (`ForgeSurfaceEditor`), how tools assemble editors; `tom_forge/tom_forge_app/test/editor_component_contract_test.dart` checks the register |
| [integrated_ux_patterns.md](integrated_ux_patterns.md) | How combined editors, views and applications behave as one tool: P1–P13 (active-editor actions, one key table, context-menu contributions, one editor per document, split copies, nothing unsaved lost, disk changes, per-application state, focus, feedback, no dead controls, readable chrome, Back and Forward), each with the code and the tests that pin it |
| [configuration_compatibility.md](configuration_compatibility.md) | Every workspace file Forge reads or writes, whose format it is and the test that holds compatibility; `.forge/` state (kept out of git through the clone's exclude file, no migrations); YAML fidelity of the YAML editor; rules for new code |
| [testing.md](testing.md) | Where the tests for Forge's component contracts and composed workflows live (repo-wide guards, conformance runs, composed workflows WF-1–WF-3) and what a new component adds to them |
| [debug_mode.md](debug_mode.md) | **MANDATORY** — Debug mode pattern: static switch, event trail, heartbeat, error intercept |
| [context_menu_contributions.md](context_menu_contributions.md) | How a module's actions reach the shell's context menus: the `tom_forge_core` model, the controller, `ForgeContextTargetProvider`, the rendering rules |
| [i18n.md](i18n.md) | Internationalisation in this repository: the workspace guideline `i18n.md` applies (texts in `lib/resources/<package-name>_<language>.json`, ids relative to the package, resolved under the mount scope); here only Forge's own part — `ForgeText` as the text reference outside widgets, `ForgeTextScope`, modules and their text scope, the shared test support, which packages are migrated by which todo |
| [../tom_forge_ui/_agent_guidelines/editor_history_contract.md](../tom_forge_ui/_agent_guidelines/editor_history_contract.md) | **Every editor** — the undo/history contract: one history per document, dirty against the saved state, `replaceContent`, Flutter's text undo off, grouped typing, one depth setting, the conformance harness |

---

## Key Rules (Quick Reference)

- **Dependencies point down the layer table** of [platform_architecture.md](platform_architecture.md).
  A new package gets a layer there and in `tom_forge/tom_forge_app/test/platform_layering_test.dart`.
- **A new editor is a document editor or a surface** — see [editor_component_contract.md](editor_component_contract.md):
  a document editor runs the undo conformance harness, a surface extends `ForgeSurfaceEditor`.
- **Debug mode is permanent.** Every editor component MUST have an `*_trail.dart`
  file with a `const bool kXxxEditorDebug` switch. See [debug_mode.md](debug_mode.md).
- **Never remove trail infrastructure** — flip the flag to `false` if the output
  is unwanted, but keep the code.
- **Adding a new editor component?** Copy the pattern from `tom_yaml_editor/lib/src/tree/editor_trail.dart`
  and add a row to the table in [debug_mode.md](debug_mode.md).
- **Adding a right-click menu?** Never a hard-coded `showMenu`: contribute through
  `ForgeModule.contextMenus` and `shell.contextMenus`. See
  [context_menu_contributions.md](context_menu_contributions.md).
