# Testing Tom Forge

Where the tests for Forge's component contracts and composed workflows live,
and what a new component or editor adds to them. Each package's own suite
tests its own behaviour; the suites below hold the platform together.
Run them with `testkit :test` from the package root.

## Repo-wide guards (`tom_forge_app/test/`)

They read every package of the repository, so they run with the app's
suite.

| Test | Holds |
| ---- | ----- |
| `platform_layering_test.dart` PL-1–PL-5 | every package has a layer and depends only downwards; the foundation is pure Dart; no Webwork dependency ([platform_architecture.md](platform_architecture.md)) |
| `editor_component_contract_test.dart` EC-1–EC-4 | every `ForgeEditor` is a surface or a registered document editor with an undo conformance run; every editor component has its debug trail, web build test and embedding docs ([editor_component_contract.md](editor_component_contract.md)) |
| `frozen_lock_guard_test.dart` FL-1–FL-4 | no package resolves a `tom_*` version behind one in the pub cache |
| `qim_none1_licence_audit_test.dart` | the app links only permissive (or listed MPL-2.0) packages |

## Component contracts

| Contract | Test |
| -------- | ---- |
| One history per document (six checks) | `runForgeUndoConformance` from `package:tom_forge_ui/testing.dart`, run by every document editor — the register is in [editor_component_contract.md](editor_component_contract.md) §2 |
| Surfaces | `tom_forge_ui/test/components/forge_surface_editor_test.dart` |
| YAML fidelity | `tom_yaml_editor/test/yaml_fidelity_test.dart` ([configuration_compatibility.md](configuration_compatibility.md) §3) |
| `.forge/` state and git | `tom_forge_ui/test/services/keep_forge_state_out_of_git_test.dart`, `forge_state_files_test.dart` |
| Web target | each editor's `test/web_build_test.dart` through `tom_web_build_probe` (its own suite tests when the build runs and why it skips) |

## Composed workflows

| Test | Holds |
| ---- | ----- |
| `tom_forge_app/test/composed_workflows_test.dart` WF-1–WF-3 | on the running shell with Markdown, YAML and text documents open: the shell's Undo undoes the active document only; quitting asks once, naming exactly the unsaved documents; Save writes the active document and leaves the others unsaved |
| `tom_forge_app/test/qim_none5_file_editors_test.dart` | each kind of file opens in the editor of its kind in the composed suite; extensions replace editors |
| `tom_forge_app/test/wonecmpc25_forge_suite_test.dart` | what `composeForgeSuite` registers, in which order, with extensions |
| `tom_forge_ui/test/widgets/ux_patterns_test.dart` and the suites cited in [integrated_ux_patterns.md](integrated_ux_patterns.md) | the integrated UX patterns P1–P13 |

## Adding a component

- A new package: a row in the layer table (PL-1 fails until it has one).
- A new `ForgeEditor`: extend `ForgeSurfaceEditor` if it holds no document;
  else run `runForgeUndoConformance` on it and register it in EC-1's table
  (EC-1 fails until one of the two is done).
- A new editor component (layer 2): a `*_trail.dart` debug switch, a
  `test/web_build_test.dart` and embedding docs (EC-4).
- A new kind of document in the composed app: open it in
  `composed_workflows_test.dart`'s workflows beside the others.
