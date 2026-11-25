# Configuration Compatibility

Tom Forge works in a workspace whose files belong to other tools and other
people: build configuration, todo files, spec documents, a `.gitignore` the
team commits. This document lists every workspace file Forge reads or
writes, whose format it is, how Forge stays compatible with it, and the test
that holds it. The rule behind every row: **Forge reads and writes a shared
format through its owner's code, writes only what the user changed, and
never edits a file the workspace tracks that the user did not open.**

## 1. Workspace files

| File | Format owned by | Forge reads / writes through | Held by |
| ---- | --------------- | ---------------------------- | ------- |
| Any `*.yaml` / `*.yml` opened in the YAML editor (`buildkit.yaml`, `buildkit_master.yaml`, …) | the file's own conventions | `tom_yaml_editor` (`YamlDocumentModel` on `yaml_edit`): an edit writes the value it changes and nothing else (§3) | `tom_yaml_editor/test/yaml_fidelity_test.dart` YF-1–YF-8 |
| `tom.website-editor.yaml` | `tom_website_editor_core` (`websiteEditorConfigSpec`) | the core's loader and validator; the JSON Schema in the Tom root's `.tom/json-schema/website-editor/tom.website-editor.schema.json` (the root found by `.tom/tom_root.yaml`) is generated from the same spec (`tool/write_schema.dart`) | `tom_website_editor_core/test/json_schema_test.dart` ("committed schema file is in sync") |
| `*.todo.yaml` | `tom_todo_model` (shared with the VS Code extension and the agents); schema `_ai/schemas/yaml/todo.schema.json` | the todo-file editor (`tom_forge_file_editors`) over `tom_todo_ui`'s todo views, which use the `tom_todo_model` codec | `tom_forge_file_editors/test/file_editors_module_test.dart` FE-6 |
| `*.docspecs.yaml`, `*.tomspecs.yaml`, SOM Markdown | the SOM runtime (`tom_som_dart_runtime`), shared with the `tom_specs` tools | `tom_specs_editor` (`DocSpecsFile` on the runtime's `SpecDocumentYaml`) | `tom_specs_editor/test/docspecs_file_test.dart` |
| Markdown | the file | the Markdown file editor over a `ForgeFileSession`: a save keeps the byte-order mark and the line endings | `tom_forge_file_editors/test/file_editors_module_test.dart` FE-2 |
| `.env` | the file | the `.env` editor over its file session | FE-4 |
| Any file opened in an editor, changed on disk meanwhile | — | not written over until the user keeps theirs | FE-3 |
| `.gitignore` (every one under the workspace) | git | read only, with `tom_basics`' `TomGitignoreSet` (`forgeLoadGitignores`), which applies git's rules | `tom_forge_core/test/gitignore_loader_test.dart` |
| `buildkit.yaml` (`dart-editor-bundler:` block) | `tom_build_base` | `tom_dart_editor_bundler`, a `tom_build_base` tool whose name is its config key | `tom_dart_editor_bundler/test/bundler_config_test.dart` |

## 2. Forge's own state: `.forge/`

`.forge/` in the workspace root holds Forge's state as JSON: open
applications and their layouts (`state/apps`), editor view state
(`state/editors`), revisions, module storage, `config.json`. It is **per
machine**:

- **Kept out of git without touching a tracked file.** At startup
  (`keepForgeStateOutOfGit`) git answers whether `.forge/` is ignored —
  every `.gitignore` up to the repository root, `.git/info/exclude` and the
  global excludes count. When it is not, `.forge/` (anchored at the
  workspace) is added to the clone's own `.git/info/exclude`. A folder
  outside git is left alone. Held by
  `tom_forge_ui/test/services/keep_forge_state_out_of_git_test.dart` GI-1–GI-4.
- **No migrations.** A state file Forge cannot read — damaged, or of another
  shape — counts as absent, and the workspace opens with fresh state. Held
  by `tom_forge_ui/test/services/forge_state_files_test.dart` FS-1–FS-3.

## 3. YAML fidelity

Editing a YAML file through the tree changes what the edit targets and
nothing else (`YamlDocumentModel`):

- Loading changes nothing; the text is the file's until an edit.
- Comments, blank lines, key order and flow collections (`{a: 1}`, `[a, b]`)
  of the rest of the file stay as written.
- A string replacing a quoted scalar keeps its quotes, so `"1.2"` set to
  `1.3` stays the string `"1.3"`.
- A new map or list takes the style of the collection it goes into (block in
  block, flow in flow); a new multiline string in block context is a literal
  block (`|`).
- A new key goes where `yaml_edit` puts it: in key order when the map's keys
  are sorted, else at the end.
- Removing a key removes exactly its lines; the lines around it stay.
- The source view and the fragment editor show the text as the file has it.

## 4. Rules for new code

- Read and write a shared format through the code that owns it; do not write
  a second parser.
- A new YAML configuration format gets a JSON Schema under
  `.tom/json-schema/<tool>/`, generated from the same description the code
  validates with, and a test that fails when the committed schema drifts.
- Never write to a file the workspace tracks unless the user opened it and
  saved: settings and state go under `.forge/`, git exclusions to the
  clone's `.git/info/exclude`.
