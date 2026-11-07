# Generating Summary Files for Dart Analysis

This document explains how to generate the `.sum` summary files required by `tom_dart_editor` for SDK-free Dart analysis.

---

## Overview

The Dart editor provides full code analysis (diagnostics, completions) without requiring a Dart SDK installed on the target device. This is achieved through **pre-built summary bundles** (`.sum` files) that contain serialized element models.

Two summary files are required:

| File | Contents | Size (typical) |
|------|----------|----------------|
| `sdk_summary.sum` | Dart SDK libraries and Flutter's `dart:ui` | ~4 MB |
| `packages.sum` | Package libraries (e.g., `path`, `dcli`) | ~30+ MB |

---

## Build Time: Generate Summary Files

### 1. SDK Summary

The SDK summary is generated from the Dart SDK the build runs on with the
libraries of Flutter's embedder added (`<sky_engine>/lib/_embedder.yaml`:
`dart:ui`, `dart:ui_web` and the private libraries they need), so code using
`TextDirection`, `Color`, `Offset` and the rest of `dart:ui` resolves, and
plain Dart code (`dart:io`, `dart:convert` …) resolves as before. Run it with
the `dart` of the Flutter whose `dart:ui` is wanted, after `flutter pub get`
(the embedder is found through the package config's `sky_engine`):

```bash
cd tom_forge/tom_dart_editor_test
flutter pub get
dart run tool/build_sdk_summary.dart assets/sdk_summary.sum
```

`tool/flutter_sdk.dart` finds the SDK and the embedder for both build tools.
In your own tool, the analyzer's built-in function takes the embedder:

```dart
import 'package:analyzer/dart/sdk/build_sdk_summary.dart';
import 'package:analyzer/file_system/physical_file_system.dart';

final bytes = await buildSdkSummary(
  resourceProvider: PhysicalResourceProvider.INSTANCE,
  sdkPath: sdkPath,                // the running dart's SDK
  embedderYamlPath: embedderYaml,  // <sky_engine>/lib/_embedder.yaml
);
File('assets/sdk_summary.sum').writeAsBytesSync(bytes);
```

### 2. Package Summary

Generate a summary for all packages you want available for imports:

```bash
cd your_app
dart pub get
dart run tool/build_packages_summary.dart assets/packages.sum
```

The build tool:
1. Reads `.dart_tool/package_config.json` for installed packages
2. **Recursively** lists ALL `.dart` files under each package's `lib/` directory (including `src/` — this is critical)
3. Uses `AnalysisDriver.buildPackageBundle()` to serialize the element model

### Critical Requirements

**The same SDK for both summaries**: the package summary is linked against
the SDK its driver resolves `dart:` URIs with, and it must be the SDK the SDK
summary holds — the plain SDK with the embedder's libraries added
(`sdkWithEmbedder` in `tool/flutter_sdk.dart`). Linked against the plain SDK,
Flutter's `export 'dart:ui' show ...` lines are dropped from the bundle and
every `dart:ui` type Flutter re-exports is undefined in the editor, even
with an SDK summary that holds `dart:ui`.

**Resolver Order**: `PackageMapUriResolver` MUST come before `ResourceUriResolver` in the `SourceFactory`:

```dart
final sourceFactory = SourceFactory([
  DartUriResolver(sdk),
  _PackageMapUriResolver(resourceProvider, packageMap),  // FIRST
  ResourceUriResolver(resourceProvider),                  // SECOND
]);
```

If reversed, `pathToUri()` returns `file:///` URIs instead of `package:` URIs, making the bundle non-portable.

**Recursive File Listing**: The build tool MUST list `.dart` files **recursively** under `lib/`:

```dart
for (final entity in libDir.listSync(recursive: true)) {  // NOT recursive: false
```

Resolution bytes reference all imported/exported URIs, including internal `src/` files.

### When to rebuild, and where the copies go

A summary is written in the analyzer's own binary format, so both files are
rebuilt whenever the analyzer the editor runs on changes major version (the
current pair is built with analyzer 14 on Dart 3.13.7), and the package
summary also when an app's dependencies change. Build both in
`tom_dart_editor_test` and copy the pair to every app that ships them:
`tom_forge_app/assets/` and `tom_yaml_editor_test/assets/`.
`tom_dart_editor_test/test/shipped_summaries_test.dart` checks that the pair
analyses real code with the editor's analyzer — Flutter with its `dart:ui`
types, and plain Dart — and that the copies match.

---

## Adding New Packages

To support additional `package:xxx` imports:

1. Add the package to your app's `pubspec.yaml` dependencies
2. Run `dart pub get`
3. Rebuild `packages.sum`: `dart run tool/build_packages_summary.dart`
4. The build tool automatically includes ALL transitive dependencies

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
| `tom_dart_editor/lib/src/analyzer_with_packages.dart` | Consumer-side driver factory, `PackageSummaryUriResolver` |
| `tom_dart_editor_test/tool/build_sdk_summary.dart` | Build tool for `sdk_summary.sum` |
| `tom_dart_editor_test/tool/build_packages_summary.dart` | Build tool for `packages.sum` |
| `tom_dart_editor_test/tool/flutter_sdk.dart` | The SDK both tools build against: the running SDK plus Flutter's embedder libraries |
| `tom_dart_editor_test/tool/diagnose_packages_sum.dart` | Diagnostic tool to inspect bundle contents |
| `tom_dart_editor_test/tool/check_sdk_sum.dart` | Diagnostic tool to inspect SDK bundle |

---

## Named summary scopes

The build described above produces a single `(sdk_summary.sum, packages.sum)`
pair tied to one fixed dependency closure. **Named summary scopes** generalise
it: one bundle per bridged surface (plain Dart, d4rt-flutter, …), sharing a
single `sdk_summary.sum`, and selected at editor-construction time by `scope:`
name.

That is the shipped mechanism. `tom_forge/tom_dart_editor_bundler` is a
`tom_build_base` CLI that reads a `dart-editor-bundler:` block from the
consuming app's `buildkit.yaml` and emits the shared SDK bundle, a
`<scope>/packages.sum` per bundle, and a generated registration helper. The
first consumer is `tom_forge/tom_specs_editor`, which registers two scopes
(`dart-plain`, `d4rt-flutter`) from `lib/generated/summary_scopes.g.dart` before
`runApp`.

See **[Summary Scopes](summary_scopes.md)** for the configuration block, the
`BundlerConfig` / `SummaryBundleSpec` model and the registry API.
