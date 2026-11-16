# Changelog

## 0.1.1

- Runs again: on tom_build_base 2.30.0–2.39.1 a run reached no executor and
  did nothing (exit 0, no bundles); tom_build_base 2.39.2 runs the executor on
  the current directory.
- The section's `defines:` / `<MODE>-defines:` are not taken for the bundler's
  keys.
- `-n` names the SDK summary, the bundles and the scope-init helper a run would
  build, and writes nothing. The outcome line is printed (kept with the
  project's output).

## 0.1.0

- Initial scaffold of the `dart-editor-bundler` CLI tool built on
  `tom_build_base` (ToolRunner / ToolDefinition), depending on
  `tom_analyzer_shared` for summary generation.
- CLI surface in place: `--help`, `--version`, and the `--config` / `--bundle`
  options. Bundle generation is not yet implemented (see plan items 2–6).
