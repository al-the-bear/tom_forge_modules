# Summary Scopes & the `tom_dart_editor_bundler`

`tom_dart_editor` does **SDK-free** static analysis inside code-typed fields by
loading pre-built `.sum` bundles at runtime (see
[`package_summary_generation.md`](package_summary_generation.md) for what a
`.sum` is and how one is built). This document describes **summary scopes**: how
an app that embeds **many** small editors — each targeting a **different** code
surface — generates and shares those bundles efficiently, and the
`tom_dart_editor_bundler` CLI that produces them.

The scoped model is the embedding path, and every summary in the workspace is
built by this bundler — the Forge apps' shipped pair included
([`package_summary_generation.md`](package_summary_generation.md)). The
explicit-asset constructors in [`how_to_embed.md`](how_to_embed.md) remain as a
lower-level escape hatch for reading summaries from other paths. The end-to-end reference is the package README's
["Embedding with Summary Scopes"](../README.md) section and the companion CLI at
[`../../tom_dart_editor_bundler`](../../tom_dart_editor_bundler).

---

## 1. The scoping problem

An embedding app rarely has a single "Dart" surface. An editor field may target
any of several **distinct closures**, and they are not the same:

1. **d4rt-flutter layout scripts** — what a d4rt script can reach when built on
   `tom_d4rt_flutter`. This surface is defined by the bridge-generator config in
   `tom_d4rt_flutter/buildkit.yaml` (`d4rtgen`): the bridged libraries
   (`dart:ui`, `package:flutter/{painting,foundation,…,material,cupertino}.dart`,
   `package:vector_math/vector_math_64.dart`) plus the `proxyClasses`. Only this
   surface is reachable from such a script.
2. **document-scripting d4rt** — a second, different bridged API for scripting
   the document/model itself.
3. **plain Dart fields** — `@ContentType('code-dart')` ordinary Dart that may
   want the SDK only, or the SDK plus a small curated closure.

A single editor-wide `packages.sum` serving all of these is both **too broad**
(it exposes packages a d4rt script can never reach, giving misleading
completions) and **too heavy** (tens of MB, loaded once but conceptually wrong
per field type). Each d4rt surface needs its **own, narrower** package closure so
the summary matches the *bridged API*, not the app's transitive dependencies.

---

## 2. The abstraction: a named "summary scope"

A **summary scope** (a.k.a. editor type) is a named bundle of *(sdk-summary
asset, package-summary asset, implicit imports, allowed package prefixes)*
describing one analysis surface:

| Scope / editor type | Bridged surface | Summary source `package_config.json` |
| --- | --- | --- |
| `dart-plain` | SDK (+ optional curated libs) | minimal / sdk-only |
| `d4rt-flutter` | `tom_d4rt_flutter` `d4rtgen` modules + proxy classes | a **dedicated** config covering exactly those packages |
| `d4rt-document` | document-scripting bridged API | a second dedicated config |

Two independent multiplicities are both supported:

- **Multiple *types*** of editor (the scopes above), each bound to a content type
  (`code-dart`, `code-d4rt-flutter`, `code-d4rt-doc`, …). The host's field router
  picks the scope from the content type instead of one hardcoded asset pair.
- **Multiple *instances*** of the same type — a long document can show dozens of
  small code fields. Instantiating many editors does **not** reload or re-hold a
  bundle per instance.

### 2.1 Shared, ref-counted summary stores (the memory model)

The loaded summary data is **shared across instances of the same scope**. A
per-instance `SummaryBackedDartAnalysisAdapter` resolves its summary data from a
**process-wide cache keyed by scope name** — loaded once, parsed once,
ref-counted — instead of each adapter calling `rootBundle.load(...)` and holding
its own copy. Registration **parses the `.sum` bytes into the analyzer element
model and then releases the byte buffers**, so after init only the parsed
(shared) `ParsedSummaryModel` is resident. Each editor builds its own cheap
`AnalysisDriverWithPackages` over that shared model.

Net effect: *N* small editors of one scope cost ≈ **one** parsed store + *N*
lightweight drivers — enabling "many small editors without much memory".

---

## 3. The bundler tool — `tom_dart_editor_bundler`

A standalone `tom_build_base`-based CLI at `tom_forge/tom_dart_editor_bundler`,
beside this package. It reads a per-app config, emits one `.sum` set per scope,
and generates a scope-init helper. The tool name is `dart-editor-bundler`
(`ToolMode.singleCommand`); its entrypoint `bin/dart_editor_bundler.dart` runs a
`tom_build_base` `ToolRunner` over `dartEditorBundlerTool` (arg parsing, version,
help).

### 3.1 Config — `dart-editor-bundler` in the **app's** `buildkit.yaml`

Summary bundles are per-app (the app declares which bridged surfaces its editor
fields target), so the config lives in the **consuming app's** `buildkit.yaml`
under the top-level `dart-editor-bundler` key, mirroring how other buildkit tools
read their own key. Each entry under `bundles` is one summary scope; its
`packages` list covers the **union** of each listed package's resolved
`.dart_tool/package_config.json` closure, so an app can scope a bundle to a
bridged surface without depending on it.

```yaml
dart-editor-bundler:
  out-dir: assets/summaries                       # where .sum assets are written
  generated-helper: lib/generated/summary_scopes.g.dart
  sdk-summary: sdk_summary.sum                     # generated once, shared by all bundles
  bundles:
    - name: dart-plain
      sdk-only: true
      implicit-imports: [dart:async, dart:collection, dart:math]

    - name: d4rt-flutter                           # scoped to the bridged API only
      packages:
        - ../../tom_ai/d4rt/tom_d4rt_flutter        # NOT the whole app closure
      implicit-imports: [package:flutter/material.dart]
      allowed-package-prefixes: [package:flutter/, package:vector_math/]

    - name: d4rt-document
      packages:
        - ../../tom_ai/ai_build/tom_specs_model
      implicit-imports: [package:tom_specs_model/tom_specs_model.dart]
```

| Field | Meaning |
| --- | --- |
| `name` | Scope id — asset sub-dir, registry key, and generated constant name. Must be unique. |
| `packages` | Package dirs whose resolved closures (union) form `packages.sum`. Omitted/empty ⇒ requires `sdk-only: true`. |
| `sdk-only` | When true, no `packages.sum` is built; the scope resolves SDK types only. |
| `implicit-imports` | Imports auto-prepended to the analysed snippet (baseline completions). |
| `allowed-package-prefixes` | Optional completion filter (adapter's `allowedPackagePrefixes`). |
| `include-all-package-completions` | Optional bool (adapter's `includeAllPackageCompletions`). |

The config model and reader are `BundlerConfig` / `SummaryBundleSpec` with
`loadBundlerConfig` (`lib/src/bundler_config.dart`); a `BundlerConfigException` is
raised on schema violations — including duplicate `name`, `packages` empty without
`sdk-only`, `sdk-only` combined with `packages`, and unknown keys.

### 3.2 Base-first: summary building lives in `tom_analyzer_shared`

Per the workspace base-first rule, the bundler **does not reimplement** summary
generation. `tom_ai/basics/tom_analyzer_shared` is the base-first owner of
analyzer-summary infrastructure (SDK-summary build including the Flutter `dart:ui`
embedder, dependency resolution, robust Dart-SDK location, shared tool cache:
`SummaryGenerator`, `DependencyResolver`, `resolveDartSdkPath`, `ToolCacheLocator`,
`runSummaryCacheStage`).

The grouped-bundle capability — building one **grouped** `packages.sum` from the
*union* of several package closures, with the load-bearing
`_PackageMapUriResolver`-before-`ResourceUriResolver` order (so emitted library
URIs are `package:`, never `file:`, and the bundle is portable) — is the
**`GroupedPackageBundleBuilder`** class in `tom_analyzer_shared`, exported from
`package:tom_analyzer_shared/tom_analyzer_shared.dart`. Its entry-point is
`GroupedPackageBundleBuilder(resourceProvider: …).buildFromDirs(dirs, sdkPath: …,
onLog: …)`. It is consumed by **both** the bundler (`bundle_generator.dart`) and
`tom_specs_clitool/bin/summaries.dart`, so the algorithm exists exactly once in
the base library; both consumers take `tom_analyzer_shared` hosted from pub.dev
(the bundler `^0.11.0`, the CLI `^0.10.0`), never through a path override.

**`dart:ui` in a Flutter scope.** A scope over Flutter code (`d4rt-flutter`)
resolves the `dart:ui` types Flutter re-exports (`TextDirection`, `Color`,
`Offset` …) only when **both** halves hold `dart:ui`: the SDK summary built
with Flutter's embedder (`sky_engine/lib/_embedder.yaml`), and the scope's
`packages.sum` linked against that same SDK — linked against the plain SDK,
Flutter's `export 'dart:ui' show ...` lines are dropped from the bundle.
`GroupedPackageBundleBuilder` links against the SDK with the embedder of the
packages' own `sky_engine` (`dartSdkWithEmbedder`) and names it in its result
(`GroupedPackageBundle.embedderYamlPath`); the bundler builds the shared SDK
summary with the embedder of the declared scopes and passes the same one to
every scope, so a Flutter scope resolves them (`tom_specs_editor`
`test/summary_scopes_test.dart`, `tom_dart_editor_test`
`test/shipped_summaries_test.dart`, `tom_analyzer_shared`
`grouped_bundle_dart_ui_test.dart`).

### 3.3 Invocation

Run in the consuming app dir so relative paths resolve against it:

```bash
# All scopes (default config is the project's buildkit.yaml):
dart run ../tom_dart_editor_bundler/bin/dart_editor_bundler.dart \
  --config buildkit.yaml --verbose
# One scope only (the shared SDK summary is still emitted):
dart run ../tom_dart_editor_bundler/bin/dart_editor_bundler.dart \
  --config buildkit.yaml --bundle d4rt-flutter
```

CLI options: `--config`/`-c` (config path; defaults to the project `buildkit.yaml`,
and all relative paths resolve against its directory), `--bundle`/`-b` (build one
named scope), `--verbose`, plus the standard `--help` / `--version`.

This is the **only** generator of a consuming app's scoped summary asset set. A
build orchestrator that wants the assets invokes this command rather than
building them itself — `tom_specs_clitool/bin/build.dart --generate-summaries`
does exactly that. A second generator would have to restate the output layout,
and a layout restated twice is a layout that drifts: the app loads bundles by the
asset keys `summary_scopes.g.dart` names, and a bundle written anywhere else
degrades a code field to plain text with no error raised anywhere.

The executor (`bundler_executor.dart`) sequences the work: `sdk_summary.sum` is
generated **once** into `out-dir` (idempotent — reused while the stamp
beside it, `sdk_summary.sum.stamp`, is the one this run would write: the Dart
SDK, the analyzer data version and the Flutter embedder; a summary another
analyzer wrote, or one without a stamp, is rebuilt),
each non-`sdk-only` bundle's `out-dir/<name>/packages.sum` is built via
`BundleGenerator.generate(...)` (`bundle_generator.dart`), and the generated
helper is written from the **full** config (so every declared scope is registered
even under `--bundle`). Every summary gets its stamp. Before writing anything
the bundler compares its analyzer with the one the consuming app resolves (the
app's `.dart_tool/package_config.json`, by `AnalysisDriver.DATA_VERSION`) and
refuses the run when they differ: the summary format follows the analyzer
version exactly — analyzer 14.5.0 and 14.7.0 on one Dart SDK cannot read each
other's — so the app could not read what it would write. Resolve both with the
same Dart SDK on `PATH`.

### 3.4 Generated scope-init helper

The tool writes the `generated-helper` Dart file
(`generateScopeInitHelper` / `writeScopeInitHelper`, `helper_writer.dart`); the
app imports it and calls it **once** at startup. It registers every declared
bundle with `tom_dart_editor`'s scope registry; registration parses the `.sum`
bytes and releases the buffers (§2.1). Each bundle yields a camelCase `const`
(`d4rt-flutter` → `d4rtFlutter`); `allowed-package-prefixes` /
`include-all-package-completions` are emitted only when declared.

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

## 4. API in `tom_dart_editor`

Shipped in `tom_dart_editor` (`lib/src/summary_scope_registry.dart`):

- **`SummaryScopeAsset`** — the immutable descriptor (`name`, `sdkSummaryAsset`,
  nullable `packageSummaryAsset`, `implicitImports`, `allowedPackagePrefixes`,
  `includeAllPackageCompletions`).
- **`SummaryScope`** — a lightweight handle exposing the asset's properties;
  each editor builds its own cheap `AnalysisDriverWithPackages` over the
  **shared** parsed model via `createDriver()`.
- **`SummaryScopeRegistry`** — a process-wide singleton
  (`SummaryScopeRegistry.instance`) keyed by scope **name**. `register(asset)`
  loads the bytes (via an injectable `bytesLoader`, default `rootBundle`), builds
  the parsed `ParsedSummaryModel` store, retains it, and discards the byte
  buffers; it is idempotent and ref-aware, so repeated calls (and N editor
  instances) share one store. `isRegistered(name)` and `scope(name)` are
  **synchronous** probes the host uses to choose the editor vs. a fallback.
- **`SummaryBackedDartAnalysisAdapter`** — a named `.scope(scopeName, …)`
  constructor resolves the summary data from the registry by name instead of
  holding `_sdkSummaryBytes` / `_packageSummaryBytes` per instance. Per-instance
  `implicitImports` / `includeAllPackageCompletions` / `allowedPackagePrefixes`
  overrides win, otherwise the registered scope's values are inherited. The
  default explicit-asset constructor is retained as the escape hatch.
- **Editor widgets** — `SimpleSummaryBackedDartCodeEditor` /
  `SummaryBackedDartCodeEditor` take a nullable **`String? scope`** parameter
  that, when set, resolves the shared parsed store from the registry instead of
  the hardcoded `sdkSummaryAsset` / `packageSummaryAsset` pair. An absent scope
  yields empty diagnostics with no crash; `didUpdateWidget` recreates the adapter
  on a `scope` change.

```dart
SimpleSummaryBackedDartCodeEditor(
  scope: SummaryScopes.d4rtFlutter,   // resolved from the shared registry
  initialCode: field.value,
  onChanged: field.set,
)
```

### 4.1 Field routing (host side)

In an embedding app, the field router maps each content type to a scope name and
uses the per-scope availability probe to choose the widget. In
`tom_specs_editor`, `spec_document_editor.dart` provides
**`scopeForContentType(String?)`** (`code`/`code-dart` → `dart-plain`,
`code-d4rt-flutter` → `d4rt-flutter`, `code-d4rt-doc` → `d4rt-document`, else
`null`), and `isDartCodeContentType` is defined as `scopeForContentType(ct) !=
null`. A registered scope yields `SimpleSummaryBackedDartCodeEditor(scope: …)`;
an unregistered/absent scope falls back to a plain value field. The synchronous
`SummaryScopeRegistry.instance.isRegistered(scope)` probe replaces a single
hardcoded asset probe (`initialize()` is awaited before `runApp`).

---

## 5. End-to-end embedding

Embedding a scoped editor in a Flutter app:

1. Declare bundles in the app's `buildkit.yaml` (`dart-editor-bundler`, §3.1).
2. Run the bundler (§3.3) to generate the `.sum` assets and the
   `summary_scopes.g.dart` helper.
3. List the generated `.sum` asset dirs (non-recursive) in the app's
   `pubspec.yaml` `flutter: assets:`.
4. Call `await SummaryScopes.initialize()` once in an `async main()` before
   `runApp`.
5. Instantiate editors with `scope: SummaryScopes.<name>`.

**Asset/commit policy.** The generated `summary_scopes.g.dart` helper is
**committed** (committed code may not import a gitignored file), reached via a
`.gitignore` negation; the heavy `.sum` bundles are **gitignored**
(`assets/summaries/**/*.sum`) and regenerated from the committed config. A
committed `.gitkeep` keeps each asset dir present for `pubspec.yaml`.

---

## 6. As-built layout, first consumer, and testing

**Bundler project** (`tom_forge/tom_dart_editor_bundler`):
`bin/dart_editor_bundler.dart` (the `ToolRunner` entrypoint) and `lib/src/`
(`bundler_config.dart`, `bundle_generator.dart`, `helper_writer.dart`,
`bundler_tool.dart`, `bundler_executor.dart`), depending on `tom_build_base`
(CLI scaffold) and `tom_analyzer_shared: ^0.11.0` (summary generation incl.
`GroupedPackageBundleBuilder`, `SummaryStamp`).

**The Forge apps' pair** — `tom_forge/tom_dart_editor_test` declares one scope,
`dart-editor` (its whole closure: Flutter with `dart:ui`, `path`, `dcli`; 93
packages), whose summaries are committed and copied to `tom_forge_app` and
`tom_yaml_editor_test` ([`package_summary_generation.md`](package_summary_generation.md)).

**Scoped code fields** — `tom_forge/tom_specs_editor` wires two scopes:
`dart-plain` (sdk-only) and `d4rt-flutter` (scoped to `tom_d4rt_flutter`; its
`d4rt-flutter/packages.sum` covers 115 packages / 4879 libraries). The third
example scope `d4rt-document` is illustrative and not wired — there is no settled
package closure for `code-d4rt-doc`, so that content type falls back to a plain
field.

**Testing.** Shipped coverage spans: config parsing (valid multi-bundle,
`sdk-only`, optional-field defaults, and each rejection case via
`BundlerConfigException`); bundle generation against fixtures (`sdk_summary.sum`
and `<name>/packages.sum` produced non-empty, SDK summary idempotent, a Flutter
scope's SDK summary holding `dart:ui`, a summary another analyzer wrote or an
unstamped one rebuilt, a run against an app on another analyzer refused); helper
codegen (camelCase constants, asset paths, `register(...)` calls; the emitted
file analyzes clean); the registry in `tom_dart_editor` (`register` idempotent,
two editors of one scope share a single parsed store, byte buffers released after
parse, unregistered scope → graceful fallback); the generated scopes of
`tom_specs_editor` analysing Flutter code with `dart:ui` types and plain Dart
(`test/summary_scopes_test.dart`, skipped until the bundler has run); and editor routing in
`tom_specs_editor` (`scopeForContentType` / `isDartCodeContentType`, and the
summary-backed-vs-plain widget choice).

---

## 7. Relationship to the rest of the editor docs

- This is **editor-internal plumbing** for embedded code fields; it does **not**
  affect the object model or document format.
- [`package_summary_generation.md`](package_summary_generation.md) — what the
  build holds, and how the Forge apps' pair is built and copied.
- [`how_to_embed.md`](how_to_embed.md) /
  [`dart_editor_usage_guide.md`](dart_editor_usage_guide.md) — explicit-asset
  embedding, which remains the escape hatch under the scoped model.
