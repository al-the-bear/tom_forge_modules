# Generating Summary Files for Dart Analysis

This document explains how the `.sum` summary files `tom_dart_analysis` (the
analysis of the Dart editor, `tom_dart_editor`) needs
for SDK-free Dart analysis are built, and where the Forge apps get theirs.

---

## Overview

The Dart editor provides full code analysis (diagnostics, completions) without
requiring a Dart SDK installed on the target device. This is achieved through
**pre-built summary bundles** (`.sum` files) that contain serialized element
models, grouped into named **summary scopes** ([Summary Scopes](summary_scopes.md)).

An app ships one shared SDK summary and one package summary per scope:

| File | Contents | Size (typical) |
|------|----------|----------------|
| `assets/summaries/sdk_summary.sum` | Dart SDK libraries and Flutter's `dart:ui` | ~4 MB |
| `assets/summaries/<scope>/packages.sum` | The libraries of the scope's packages (e.g. Flutter, `path`, `dcli`) | ~45 MB |
| `<summary>.stamp` beside each | What wrote it: Dart SDK, analyzer data version, whether `dart:ui` is in | a few lines |

---

## Build Time: tom_dart_editor_bundler

Both summaries are built by `tom_forge/tom_dart_editor_bundler` from the
`dart-editor-bundler:` block of the consuming app's `buildkit.yaml`. It also
writes `lib/generated/summary_scopes.g.dart`, which registers every scope
before the app's first frame (`await SummaryScopes.initialize()`).

```bash
cd your_app
flutter pub get
dart run ../tom_dart_editor_bundler/bin/dart_editor_bundler.dart \
  --config buildkit.yaml --verbose
```

Run it with the `dart` of the Flutter the app builds with on `PATH`: the
bundler refuses a run whose analyzer differs from the one the app resolves
(by `AnalysisDriver.DATA_VERSION`), because the app could not read what it
would write.

What the build holds, whatever the app:

- **`dart:ui` on both sides.** The SDK summary is built with the libraries of
  Flutter's embedder (`<sky_engine>/lib/_embedder.yaml`: `dart:ui`,
  `dart:ui_web` and what they need) when a scope holds Flutter packages, and
  every `packages.sum` is linked against that same SDK. Linked against the
  plain SDK, Flutter's `export 'dart:ui' show ...` lines are dropped and
  `TextDirection`, `Color`, `Offset` … are undefined in the editor, even with
  an SDK summary that holds `dart:ui`. Plain Dart (`dart:io`, `dart:convert`
  …) resolves either way.
- **Every library of every package**: `.dart` files are listed recursively
  under each package's `lib/`, `src/` included — the resolution bytes reference
  internal URIs, and one missing from the bundle fails deserialization.
- **Portable URIs**: the package resolver comes before `ResourceUriResolver`,
  so the bundle records `package:` URIs, never `file:` ones.
- **Stamps**: the shared SDK summary is kept between runs only while its
  stamp is the one the run would write; one another analyzer wrote, or one
  without a stamp, is rebuilt.

The grouped bundle and the `dart:ui` linking live in `tom_analyzer_shared`
(`GroupedPackageBundleBuilder`, `dartSdkWithEmbedder`, `SummaryStamp`); the
bundler drives them.

---

## The Forge apps' pair

`tom_forge_app`, `tom_yaml_editor_test` and `tom_dart_editor_test` ship one
pair, the `dart-editor` scope: `tom_dart_editor_test`'s whole resolved
closure (Flutter with `dart:ui`, `path`, `dcli` and what they pull in),
declared in `tom_dart_editor_test/buildkit.yaml`.

1. Build it in `tom_dart_editor_test` (the command above). It writes
   `assets/summaries/sdk_summary.sum`,
   `assets/summaries/dart-editor/packages.sum`, their stamps and
   `lib/generated/summary_scopes.g.dart`.
2. Copy `assets/summaries/` to `tom_forge_app/assets/summaries/` and
   `tom_yaml_editor_test/assets/summaries/`.
3. Run `tom_dart_editor_test/test/shipped_summaries_test.dart`: SUM-1
   analyses Flutter code with `dart:ui` types and plain Dart against the pair
   through the generated helper, SUM-2 checks the copies (stamps included),
   SUM-3 the stamps.

The pair is committed: a fresh clone analyses without a generation step. The
apps read it at `ForgeDartSummaryAssets.root` (Forge's own app,
`tom_dart_editor_test` through `SummaryScopes`, `tom_yaml_editor_test`), or
under `tom_forge_app`'s package prefix (`ForgeDartSummaryAssets.ofPackage`,
`forgeSuiteDartSummaries`) in an app built on Forge.

### When to rebuild

A summary is written in the analyzer's own binary format, which changes
between analyzer versions — minors included (14.5.0 and 14.7.0 on one Dart SDK
cannot read each other's). Rebuild the pair whenever the analyzer the editor
runs on changes (the stamp's `toolchain` then no longer matches), and when
`tom_dart_editor_test`'s dependencies change.

### Adding packages to the pair

1. Add the package to `tom_dart_editor_test/pubspec.yaml`.
2. `flutter pub get`.
3. Rebuild and copy the pair (above). All transitive dependencies are
   included.

---

## Runtime: How Resolution Works

At runtime, `createAnalysisDriverWithPackages()`:

1. Loads both summary bundles as Flutter assets
2. Creates a `SummaryDataStore` and registers both bundles
3. Registers library `package:` URIs in `uriToSummaryPath`
4. Sets up a `SourceFactory` with `PackageSummaryUriResolver`
5. Creates an `AnalysisDriver` with `externalSummaries: dataStore`

When user code imports `package:path/path.dart`, the analyzer resolves it through `PackageSummaryUriResolver`, which returns an `InSummarySource` stub. The element model is deserialized from the bundle.

---

## Consumer-Side Workarounds

Two workarounds in `analyzer_with_packages.dart` compensate for SDK limitations:

1. **Manual `uriToSummaryPath` registration**: `SummaryDataStore.addBundle()` only registers unit URIs. We explicitly register each library's `package:` URI after calling `addBundle()`.

2. **`PackageSummaryUriResolver`**: Resolves ANY `package:X/...` URI when package `X` is known from the bundle. Without this, internal `src/` files can't be resolved.

---

## Key Files

| File | Role |
|------|------|
| `tom_dart_analysis/lib/src/analyzer_with_packages.dart` | Consumer-side driver factory, `PackageSummaryUriResolver` |
| `tom_dart_editor_bundler/` | The build: config, SDK summary, grouped bundles, stamps, scope helper |
| `tom_dart_editor_test/buildkit.yaml` | The Forge apps' pair, the `dart-editor` scope |
| `tom_dart_editor_test/test/shipped_summaries_test.dart` | What the shipped pair resolves, and that the copies match |
| `tom_dart_editor_test/tool/diagnose_packages_sum.dart` | Diagnostic tool to inspect bundle contents |
| `tom_dart_editor_test/tool/check_sdk_sum.dart` | Diagnostic tool to inspect SDK bundle |

See **[Summary Scopes](summary_scopes.md)** for the configuration block, the
`BundlerConfig` / `SummaryBundleSpec` model and the registry API.
