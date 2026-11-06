# Tom Forge — Copilot Guidelines

Guidelines specific to the **Tom Forge** repository and its editor components.
Read these before modifying any component in `tom_forge/`.

---

## Documents

| Document | Purpose |
|----------|---------|
| [platform_architecture.md](platform_architecture.md) | The platform's layers (foundation, editor kit, editors, shell, shell services, modules, apps), the contracts at each boundary, how a file reaches an editor, the dependency and licence rules; `tom_forge_app/test/platform_layering_test.dart` checks the layering |
| [editor_component_contract.md](editor_component_contract.md) | What an editor component and a shell editor must provide to be assembled into a tool: the standalone component rules, document editors (and the undo conformance run each has), surfaces (`ForgeSurfaceEditor`), how tools assemble editors; `tom_forge_app/test/editor_component_contract_test.dart` checks the register |
| [debug_mode.md](debug_mode.md) | **MANDATORY** — Debug mode pattern: static switch, event trail, heartbeat, error intercept |
| [context_menu_contributions.md](context_menu_contributions.md) | How a module's actions reach the shell's context menus: the `tom_forge_core` model, the controller, `ForgeContextTargetProvider`, the rendering rules |
| [../tom_forge_ui/_copilot_guidelines/editor_history_contract.md](../tom_forge_ui/_copilot_guidelines/editor_history_contract.md) | **Every editor** — the undo/history contract: one history per document, dirty against the saved state, `replaceContent`, Flutter's text undo off, grouped typing, one depth setting, the conformance harness |

---

## Key Rules (Quick Reference)

- **Dependencies point down the layer table** of [platform_architecture.md](platform_architecture.md).
  A new package gets a layer there and in `tom_forge_app/test/platform_layering_test.dart`.
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
