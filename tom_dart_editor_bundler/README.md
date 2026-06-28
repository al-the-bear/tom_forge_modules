# tom_dart_editor_bundler

CLI tool that builds the summary `.sum` bundles and the generated scope-init
helper consumed by the [`tom_dart_editor`](../tom_dart_editor) embedded code
editor.

> **Status: scaffold.** The CLI surface (`--help`, `--version`, `--config`,
> `--bundle`) is in place. Config parsing and bundle generation are implemented
> incrementally — see
> [`tom_dart_editor_summary_scoping_plan.md`](../../_ai/quests/tom_specs/tom_dart_editor_summary_scoping_plan.md)
> items 2–6. The full configuration/usage documentation lands with plan item 12.

## What it will do

Read a `dart-editor-bundler` block from a consuming app's `buildkit.yaml` and
emit:

- one SDK summary (`<out-dir>/<sdk-summary>`),
- one grouped package bundle per non-`sdk-only` scope
  (`<out-dir>/<name>/packages.sum`), and
- a generated `SummaryScopes` helper that registers each scope at app startup.

## Run

```bash
dart run bin/dart_editor_bundler.dart --help
```

## Design

The bundler is base-first: it never calls `package:analyzer` summary APIs
directly. CLI plumbing comes from `tom_build_base`; summary generation comes from
`tom_analyzer_shared`. See the
[summary-scoping spec](../../_ai/quests/tom_specs/tom_dart_editor_summary_scoping.md)
and the editor's [summary scopes doc](../tom_dart_editor/doc/summary_scopes.md).
