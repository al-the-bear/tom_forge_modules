# tom_dart_editor_bundler

CLI tool that builds the analyzer summary (`.sum`) bundles and the generated
scope-init helper consumed by the [`tom_dart_editor`](../tom_dart_editor)
embedded code editor.

A consuming Flutter app declares its **summary scopes** in a
`dart-editor-bundler` block inside its `buildkit.yaml`. The bundler reads that
block and emits, into the app's `assets/`:

- **one shared SDK summary** (`<out-dir>/<sdk-summary>`),
- **one grouped package bundle per non-`sdk-only` scope**
  (`<out-dir>/<name>/packages.sum`), and
- **a generated `SummaryScopes` helper** (`<generated-helper>`) that registers
  every scope with `tom_dart_editor`'s `SummaryScopeRegistry` at app startup.

A *summary scope* is a named, analyzable surface — the SDK plus an optional set
of packages — that a code field is analysed against. Authoring a snippet of
`code-d4rt-flutter` should offer Flutter completions; a plain `code` snippet
should only see `dart:` libraries. Scopes make that distinction declarative.

The bundler is **base-first**: it never calls `package:analyzer` summary APIs
directly. CLI plumbing (arg parsing, `--help`/`--version`, process execution)
comes from `tom_build_base`; summary generation comes from `tom_analyzer_shared`
(`GroupedPackageBundleBuilder`, `resolveDartSdkPath`).

---

## Configuration

The bundler is driven entirely by the `dart-editor-bundler:` block of the
consuming project's `buildkit.yaml`. Unknown keys are rejected so typos fail
loudly.

### Top-level keys

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `out-dir` | string | `assets/summaries` | Directory (relative to the config file) where the SDK summary and per-scope bundles are written. |
| `generated-helper` | string | `lib/generated/summary_scopes.g.dart` | Path (relative to the config file) of the generated `SummaryScopes` Dart helper. |
| `sdk-summary` | string | `sdk_summary.sum` | File name of the shared SDK summary inside `out-dir`. One SDK summary is shared by every scope. |
| `bundles` | list | *(required, non-empty)* | The summary scopes to build. See below. |

### Per-bundle keys

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | string | *(required, unique)* | Scope identifier. Used as the bundle sub-directory name, the generated constant name (camel-cased), and the `scope:` value passed to editor widgets. |
| `packages` | list of paths | `[]` | Package directories (relative to the config file) whose transitive closure forms the scope's analyzable surface. **Must be empty iff `sdk-only: true`.** |
| `sdk-only` | bool | `false` | When `true`, the scope is the Dart SDK alone — no package bundle is emitted. Mutually exclusive with a non-empty `packages`. |
| `implicit-imports` | list | `[]` | Imports made available to every snippet in the scope without an explicit `import` line (e.g. `package:flutter/material.dart`). |
| `allowed-package-prefixes` | list | `[]` | Restricts which package import prefixes the scope exposes for completion. Empty means no prefix restriction. |
| `include-all-package-completions` | bool | `false` | When `true`, surfaces completions from the entire bundled package closure rather than just the directly-depended packages. |

### Validation rules

The config is rejected (with a clear message) when:

- `bundles` is missing or empty;
- two bundles share a `name`;
- a bundle sets `sdk-only: true` **and** lists `packages`;
- a non-`sdk-only` bundle has an empty `packages` list;
- any unknown key appears at the top level or inside a bundle.

### Worked example

From `tom_specs_editor/buildkit.yaml` — two scopes, one SDK-only and one
package-backed:

```yaml
dart-editor-bundler:
  out-dir: assets/summaries
  generated-helper: lib/generated/summary_scopes.g.dart
  sdk-summary: sdk_summary.sum
  bundles:
    # Plain Dart snippets (`@ContentType('code' | 'code-dart')`): SDK only, no
    # third-party package surface.
    - name: dart-plain
      sdk-only: true
      implicit-imports: [dart:async, dart:collection, dart:math]

    # Live Flutter-layout snippets (`@ContentType('code-d4rt-flutter')`): the
    # closure of `tom_d4rt_flutter` (Flutter + the d4rt-flutter runtime).
    - name: d4rt-flutter
      packages:
        - ../../tom_ai/d4rt/tom_d4rt_flutter
      implicit-imports: [package:flutter/material.dart]
```

---

## Running it

Run from the consuming project's directory (so relative `out-dir`,
`generated-helper`, and `packages` paths resolve against it):

```bash
# From the consuming app (e.g. tom_specs_editor/), regenerate all scopes:
dart run ../tom_dart_editor_bundler/bin/dart_editor_bundler.dart \
  --config buildkit.yaml --verbose
```

### CLI options

| Option | Alias | Description |
| --- | --- | --- |
| `--config <path>` | `-c` | Path to the `buildkit.yaml` holding the `dart-editor-bundler` block. Defaults to the consuming project's `buildkit.yaml`. All other relative paths resolve against this file's directory. |
| `--bundle <name>` | `-b` | Build only the named scope. The shared SDK summary is still emitted (every scope needs it). Useful for fast iteration on one scope. |
| `--verbose` | | Log each step (SDK summary, per-scope bundle, helper write) and a summary of bytes produced. |
| `--help` | `-h` | Show usage, the config schema, and an example. |
| `--version` | | Print the tool version. |

Examples:

```bash
# Rebuild just the d4rt-flutter scope (plus the shared SDK summary):
dart run ../tom_dart_editor_bundler/bin/dart_editor_bundler.dart \
  --config buildkit.yaml --bundle d4rt-flutter --verbose

# Point at a config in a non-default location:
dart run ../tom_dart_editor_bundler/bin/dart_editor_bundler.dart \
  --config tool/editor_bundles.yaml
```

The SDK summary is **idempotent**: if `<out-dir>/<sdk-summary>` already exists it
is reused rather than rebuilt, so repeated runs only regenerate the package
bundles and the helper.

---

## What gets generated

### Asset layout

Given the worked example above, the bundler writes:

```
assets/summaries/
  sdk_summary.sum            # shared SDK summary (one per app)
  d4rt-flutter/
    packages.sum             # grouped closure of tom_d4rt_flutter
lib/generated/
  summary_scopes.g.dart      # the SummaryScopes helper
```

An `sdk-only` scope (`dart-plain`) emits **no** `packages.sum` — it points
straight at the shared SDK summary.

### Generated helper

`<generated-helper>` is an `abstract final class SummaryScopes` with one
camel-cased `const` per scope (`d4rt-flutter` → `d4rtFlutter`) and an async,
idempotent `initialize()` that registers every scope:

```dart
// GENERATED — do not edit. Produced by tom_dart_editor_bundler.
import 'package:tom_dart_editor/tom_dart_editor.dart';

abstract final class SummaryScopes {
  static const dartPlain = 'dart-plain';
  static const d4rtFlutter = 'd4rt-flutter';

  static Future<void> initialize() async {
    await SummaryScopeRegistry.instance.register(const SummaryScopeAsset(
      name: dartPlain,
      sdkSummaryAsset: 'assets/summaries/sdk_summary.sum',
      packageSummaryAsset: null,
      implicitImports: ['dart:async', 'dart:collection', 'dart:math'],
    ));
    await SummaryScopeRegistry.instance.register(const SummaryScopeAsset(
      name: d4rtFlutter,
      sdkSummaryAsset: 'assets/summaries/sdk_summary.sum',
      packageSummaryAsset: 'assets/summaries/d4rt-flutter/packages.sum',
      implicitImports: ['package:flutter/material.dart'],
    ));
  }
}
```

---

## Using the generated code

### 1. Initialize at startup

Call `SummaryScopes.initialize()` once, **before** `runApp`, so the registry is
populated before the first frame. Guard it so a dev checkout missing the `.sum`
assets degrades gracefully (those fields fall back to plain text):

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SummaryScopes.initialize();
  } catch (error, stack) {
    debugPrint('Summary scope init skipped: $error');
    debugPrintStack(stackTrace: stack);
  }
  runApp(const SpecsEditorApp());
}
```

### 2. Instantiate editors by scope

Pass a scope constant (or the same string the field's content type maps to) to
the editor widget. Probe the registry synchronously to decide between the
summary-backed editor and a plain-text fallback:

```dart
if (SummaryScopeRegistry.instance.isRegistered(SummaryScopes.d4rtFlutter)) {
  return SimpleSummaryBackedDartCodeEditor(
    initialCode: value,
    scope: SummaryScopes.d4rtFlutter,
    onChanged: onChanged,
  );
}
return PlainTextField(value: value, onChanged: onChanged); // fallback
```

### 3. Declare the assets

Flutter asset directories are **non-recursive**, so list each scope
sub-directory explicitly in the consuming app's `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/summaries/
    - assets/summaries/d4rt-flutter/
```

### 4. Version-control policy

- **Commit** the generated `summary_scopes.g.dart` — committed code imports it,
  so a fresh checkout must build without first running the bundler. (Re-include
  it past any repo-wide `*.g.dart` ignore with a `!` negation in `.gitignore`.)
- **Do not commit** the heavy `.sum` bundles — regenerate them from
  `buildkit.yaml`. Keep `<out-dir>/**/*.sum` gitignored (with a `.gitkeep` so
  the asset paths stay valid).

---

## Why d4rt-flutter

Live Flutter-layout snippets (`@ContentType('code-d4rt-flutter')`) are rendered
through the d4rt-flutter runtime (`SourceFlutterD4rt`). To give the author
correct analysis and completions, the editor must analyse the snippet against
the **same surface the runtime executes** — Flutter plus the d4rt-flutter
runtime. That surface is exactly the transitive closure of the
`tom_d4rt_flutter` package, which is why the `d4rt-flutter` scope bundles that
one package directory. `package:flutter/material.dart` is the default implicit
import because that is what layout authors write against.

Plain `code`/`code-dart` snippets carry no such runtime, so the `dart-plain`
scope is SDK-only — smaller bundle, no spurious Flutter completions.

---

## Multi-instance memory model

Scopes exist to keep memory flat as editors multiply (spec §3.1). The `.sum`
bytes for a scope are parsed **once** into a shared `ParsedSummaryModel` held by
the `SummaryScopeRegistry`; `register()` is idempotent and ref-counted. Every
editor created with the same `scope:` shares that one parsed store and only adds
a lightweight per-instance analysis driver:

> **N editors of one scope ≈ one parsed store + N light drivers.**

This is why scopes are coarse (one per analyzable surface) rather than per-field:
ten `d4rt-flutter` code fields cost one Flutter summary parse, not ten.

---

## Design references

- Summary-scopes specification:
  [`tom_dart_editor/doc/summary_scopes.md`](../tom_dart_editor/doc/summary_scopes.md)
