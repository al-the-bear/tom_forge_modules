# Summary Scopes & the `tom_dart_editor_bundler`

> **Status: specified, not yet implemented.** This document describes the target
> design for *scoped* analyzer-summary bundles and the multi-instance memory
> model. It is the package-level home of the design recorded in the `tom_specs`
> quest:
> [`tom_dart_editor_summary_scoping.md`](../../../_ai/quests/tom_specs/tom_dart_editor_summary_scoping.md)
> (spec, §§6–10 are the target),
> [`…_plan.md`](../../../_ai/quests/tom_specs/tom_dart_editor_summary_scoping_plan.md)
> (numbered implementation plan), and
> [`…_questions.md`](../../../_ai/quests/tom_specs/tom_dart_editor_summary_scoping_questions.md)
> (decisions D1–D8). Until the bundler ships, use the single-pair flow in
> [`package_summary_generation.md`](package_summary_generation.md) and the
> explicit-asset constructors in [`how_to_embed.md`](how_to_embed.md). When the
> bundler lands, the quest spec §§6–10 are revised to describe the actual
> implementation and this doc is updated to drop the "planned" framing.

`tom_dart_editor` does **SDK-free** static analysis inside code-typed fields by
loading pre-built `.sum` bundles at runtime (see
[`package_summary_generation.md`](package_summary_generation.md) for what a
`.sum` is and how one is built today). This document covers the next step: how an
app that embeds **many** small editors — each targeting a **different** code
surface — generates and shares those bundles efficiently.

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

Today all of these would share a **single** editor-wide `packages.sum`, which is
both **too broad** (it exposes packages a d4rt script can never reach, giving
misleading completions) and **too heavy** (~40 MB, loaded once but conceptually
wrong per field type). Each d4rt surface needs its **own, narrower**
`package_config.json` so the summary matches the *bridged API*, not the app's
transitive dependencies.

---

## 2. The abstraction: a named "summary scope" (a.k.a. editor type)

A **summary scope** is a named bundle of *(sdk-summary asset, package-summary
asset, implicit imports, allowed package prefixes)* describing one analysis
surface:

| Scope / editor type | Bridged surface | Summary source `package_config.json` |
| --- | --- | --- |
| `dart-plain` | SDK (+ optional curated libs) | minimal / sdk-only |
| `d4rt-flutter` | `tom_d4rt_flutter` `d4rtgen` modules + proxy classes | a **dedicated** config covering exactly those packages |
| `d4rt-document` | document-scripting bridged API | a second dedicated config |

Two independent multiplicities must both be supported:

- **Multiple *types*** of editor (the scopes above), each bound to a content type
  / file extension (`code-dart`, `code-d4rt-flutter`, `code-d4rt-doc`, …). The
  host's field router picks the scope from the content type instead of one
  hardcoded asset pair.
- **Multiple *instances*** of the same type — a long document can show dozens of
  small code fields. Instantiating many editors **must not** reload or re-hold a
  40 MB bundle per instance.

### 2.1 Shared, ref-counted summary stores (the memory model)

The key refactoring is to **share the loaded summary data across instances of
the same scope**. A per-instance `SummaryBackedDartAnalysisAdapter` resolves its
summary data from a **process-wide cache keyed by scope id** — loaded once,
parsed once, ref-counted — instead of each adapter calling `rootBundle.load(...)`
and holding its own copy. Registration **parses the `.sum` bytes into the
analyzer element model and then releases the byte buffers**, so after init only
the parsed (shared) store is resident.

Net effect: *N* small editors of one scope cost ≈ **one** parsed store + *N*
lightweight controllers — enabling "many small editors without much memory".

---

## 3. The bundler tool — `tom_dart_editor_bundler`

A new standalone `tom_build_base`-based CLI (to live at
`tom_forge/tom_dart_editor_bundler`, beside this package — decision D2/D3) reads
a per-app config, emits one `.sum` set per scope, and generates a scope-init
helper.

### 3.1 Config — `dart-editor-bundler` in the **app's** `buildkit.yaml`

Summary bundles are per-app (the app declares which bridged surfaces its editor
fields target), so the config lives in the **consuming app's** `buildkit.yaml`
under a new top-level `dart-editor-bundler` key (decision D4), mirroring how
other buildkit tools read their own key.

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

### 3.2 Base-first: summary building lives in `tom_analyzer_shared`

Per the workspace base-first rule, the bundler **does not reimplement** summary
generation. `tom_ai/basics/tom_analyzer_shared` is the base-first owner of
analyzer-summary infrastructure (`SummaryGenerator`, `DependencyResolver`,
`resolveDartSdkPath`, `ToolCacheLocator`, `runSummaryCacheStage`) and is reused
as-is for the SDK summary and dependency resolution.

The one capability it does **not** yet expose — building a single **grouped**
`packages.sum` from the *union* of several package closures (with the
load-bearing `_PackageMapUriResolver`-before-`ResourceUriResolver` order; today
in `tom_specs_clitool/bin/summaries.dart` `buildPackageBundle` +
`summary_package_config.dart`) — is **added to `tom_analyzer_shared`** (published,
version-bumped) and then consumed by **both** the bundler and `tom_specs_clitool`,
so the algorithm exists exactly once (decisions D5/D8).

### 3.3 Invocation

```bash
dart run tom_dart_editor_bundler                       # reads ./buildkit.yaml
dart run tom_dart_editor_bundler --config path/to/buildkit.yaml
dart run tom_dart_editor_bundler --bundle d4rt-flutter # one bundle only
```

### 3.4 Generated scope-init helper

The tool writes a generated Dart file the app imports and calls **once** at
startup. It registers every declared bundle with the scope registry; registration
parses the `.sum` bytes and releases the buffers (§2.1).

```dart
// GENERATED — do not edit. Produced by tom_dart_editor_bundler.
import 'package:tom_dart_editor/tom_dart_editor.dart';

abstract final class SummaryScopes {
  static const dartPlain = 'dart-plain';
  static const d4rtFlutter = 'd4rt-flutter';
  static const d4rtDocument = 'd4rt-document';

  /// Loads + parses every bundle once and registers it by name. Idempotent.
  static Future<void> initialize() async {
    await SummaryScopeRegistry.instance.register(
      const SummaryScopeAsset(
        name: d4rtFlutter,
        sdkSummaryAsset: 'assets/summaries/sdk_summary.sum',
        packageSummaryAsset: 'assets/summaries/d4rt-flutter/packages.sum',
        implicitImports: ['package:flutter/material.dart'],
        allowedPackagePrefixes: ['package:flutter/', 'package:vector_math/'],
      ),
    );
    // … dart-plain, d4rt-document …
  }
}
```

---

## 4. New API in `tom_dart_editor`

- **`SummaryScopeAsset`** — immutable descriptor (name + asset paths + defaults).
- **`SummaryScopeRegistry`** — process-wide singleton keyed by scope **name**.
  `register(asset)` loads bytes, builds the parsed `SummaryDataStore` element
  model (the work `createAnalysisDriverWithPackages` does today), retains the
  **parsed** store, and discards the byte buffers; idempotent and ref-aware.
  `scope(name)` returns a lightweight handle from which each editor builds its
  own cheap `AnalysisDriver`/controller over the **shared** model.
- **`SummaryBackedDartAnalysisAdapter`** — refactored to resolve its summary data
  from the registry **by scope name** instead of holding `_sdkSummaryBytes` /
  `_packageSummaryBytes` per instance.
- **Editor widgets** — `SimpleSummaryBackedDartCodeEditor` /
  `SummaryBackedDartCodeEditor` gain a **`scope`** (bundle name) parameter that
  replaces the hardcoded `sdkSummaryAsset` / `packageSummaryAsset` pair; the
  explicit-asset constructor is retained as a lower-level escape hatch.

```dart
SimpleSummaryBackedDartCodeEditor(
  scope: SummaryScopes.d4rtFlutter,   // resolved from the shared registry
  initialCode: field.value,
  onChanged: field.set,
)
```

The host's field router maps each `@ContentType('code-dart' | 'code-d4rt-flutter'
| 'code-d4rt-doc')` to a scope name; a **per-scope availability probe** replaces
today's single hardcoded probe (an unregistered/absent scope falls back to a
plain value field, exactly as the single probe does today).

---

## 5. End-to-end embedding (target)

Once the bundler ships, embedding a scoped editor in a Flutter app is:

1. Declare bundles in the app's `buildkit.yaml` (`dart-editor-bundler`, §3.1).
2. Run `dart run tom_dart_editor_bundler` to generate the `.sum` assets and the
   `summary_scopes.g.dart` helper.
3. List the generated `.sum` assets in the app's `pubspec.yaml` `flutter:
   assets:`.
4. Call `await SummaryScopes.initialize()` once in `main()` before showing
   editors.
5. Instantiate editors with `scope: SummaryScopes.<name>`.

---

## 6. Decisions (from the quest `_questions.md`, D1–D8)

| # | Decision |
| --- | --- |
| D1 | Editor package is **`tom_dart_editor`**; no rename — only doc/tool naming harmonised. |
| D2 | The tool is **`tom_dart_editor_bundler`** (aligned to the package); buildkit key `dart-editor-bundler`. |
| D3 | Bundler location: **`tom_forge/tom_dart_editor_bundler`**, beside this package. |
| D4 | Config lives in the **consuming app's** `buildkit.yaml`, key `dart-editor-bundler`. |
| D5 | Build on **`tom_analyzer_shared`** (base-first owner of summary generation); never reimplement. |
| D6 | The registry **parses once and releases the bytes** — the memory model of §2.1. |
| D7 | The quest turn produced spec + plan only; **no implementation yet** (this doc tracks the target). |
| D8 | The **grouped-bundle** capability is added to `tom_analyzer_shared` and consumed by both the bundler and `tom_specs_clitool` (one algorithm). |

**Deferred (settled at implementation):** whether generated `.sum` assets are
committed in-repo or sourced from the `tom_binaries` L2 layer — decided in
context when the first consumer (`tom_specs_editor`) wires its bundles.

---

## 7. Relationship to the rest of the editor docs

- This is **editor-internal plumbing** for embedded code fields; it does **not**
  affect the object model or document format.
- [`package_summary_generation.md`](package_summary_generation.md) — the
  single-pair `.sum` build that this design generalises into per-scope bundles.
- [`how_to_embed.md`](how_to_embed.md) / [`dart_editor_usage_guide.md`](dart_editor_usage_guide.md)
  — current explicit-asset embedding, which remains the escape hatch under the
  scoped model.
