# Resolving `package:` Imports in the Dart Editor

## Overview

The Dart editor app provides code analysis (diagnostics, completions) for user-written Dart code that may contain `package:xxx` imports (e.g. `import 'package:path/path.dart'`). Since the app runs as a standalone Flutter desktop app without access to a real pub-cache or `.dart_tool/package_config.json` at runtime, packages are provided via **pre-built summary bundles** (`.sum` files).

## How Package Import Resolution Works

### 1. Build Time: Generate `packages.sum`

Run the build tool to create a binary summary of all packages:

```bash
cd tom_editors/tom_dart_editor_test
dart pub get
dart run tool/build_packages_summary.dart
```

This tool:
- Reads `.dart_tool/package_config.json` for the list of installed packages
- **Recursively** lists ALL `.dart` files under each package's `lib/` directory (including `src/` subdirectories — this is critical)
- Uses `AnalysisDriver.buildPackageBundle()` to serialize the element model into `assets/packages.sum`

The output `packages.sum` is bundled as a Flutter asset in the app.

### 2. Runtime: Load and Register the Bundle

At app startup, `createAnalysisDriverWithPackages()` in `analyzer_with_packages.dart`:

1. Loads the SDK summary (`sdk_summary.sum`) and the package summary (`packages.sum`)
2. Creates a `SummaryDataStore` and registers both bundles
3. Manually registers library `package:` URIs in `uriToSummaryPath` (workaround for SDK limitation)
4. Sets up a `SourceFactory` with a custom `PackageSummaryUriResolver` that can resolve ANY `package:X/...` URI for known packages
5. Creates an `AnalysisDriver` with `externalSummaries: dataStore`

### 3. Analysis: User Code with Package Imports

When the user writes code like:

```dart
import 'package:path/path.dart';
final p = join('a', 'b');
```

The analyzer resolves `package:path/path.dart` through the `PackageSummaryUriResolver`, which returns an `InSummarySource` stub. The element model for `path` is then deserialized from the bundle's resolution bytes, enabling full type-checking, completion suggestions, and error reporting.

### 4. Adding New Packages

To support additional `package:xxx` imports:

1. Add the package to `tom_editors/tom_dart_editor_test/pubspec.yaml` dependencies
2. Run `dart pub get`
3. Rebuild `packages.sum`: `dart run tool/build_packages_summary.dart`
4. The build tool automatically includes ALL transitive dependencies

## Key Files

| File | Role |
|------|------|
| `tom_editors/tom_dart_editor/lib/src/analyzer_with_packages.dart` | Consumer-side driver factory, `PackageSummaryUriResolver` |
| `tom_editors/tom_dart_editor_test/tool/build_packages_summary.dart` | Build tool that generates `assets/packages.sum` |
| `tom_editors/tom_dart_editor_test/assets/packages.sum` | Pre-built package summary (~32MB, 3026 files from 73 packages) |
| `tom_editors/tom_dart_editor_test/assets/sdk_summary.sum` | Pre-built SDK summary (~3MB) |
| `tom_editors/tom_dart_editor_test/tool/diagnose_packages_sum.dart` | Diagnostic tool to inspect bundle contents |
| `tom_editors/tom_dart_editor_test/tool/check_sdk_sum.dart` | Diagnostic tool to inspect SDK bundle for comparison |

## Critical Build Tool Requirements

The build tool (`build_packages_summary.dart`) has two requirements that, if violated, break package resolution at runtime:

### Resolver Order Matters

`PackageMapUriResolver` MUST come before `ResourceUriResolver` in the `SourceFactory`. Otherwise, `pathToUri()` returns `file:///` URIs instead of `package:` URIs in the resolution bytes, making the bundle non-portable.

```dart
final sourceFactory = SourceFactory([
  DartUriResolver(sdk),
  _PackageMapUriResolver(resourceProvider, packageMap),  // FIRST
  ResourceUriResolver(resourceProvider),                  // SECOND
]);
```

### Recursive File Listing is Required

The build tool MUST list `.dart` files **recursively** under `lib/` (not just top-level files). The resolution bytes reference all imported/exported URIs including internal `package:X/src/...` files. If those aren't in the bundle as library entries, deserialization fails at runtime.

```dart
for (final entity in libDir.listSync(recursive: true)) {  // NOT recursive: false
```

## Consumer-Side Workarounds (in `analyzer_with_packages.dart`)

Two workarounds compensate for limitations in the SDK's `SummaryDataStore` and `InSummaryUriResolver`:

1. **Manual `uriToSummaryPath` registration**: `SummaryDataStore.addBundle()` only registers unit URIs (which may be `file:///` paths). We explicitly register each library's `package:` URI after calling `addBundle()`.

2. **`PackageSummaryUriResolver`**: A custom `UriResolver` that resolves ANY `package:X/...` URI (including internal `src/` files) when package `X` is known from the bundle. The standard `InSummaryUriResolver` only resolves URIs explicitly in `uriToSummaryPath`, which misses internal files. Without this, `BundleReader._readDirectiveUri` crashes with a null check error at `bundle_reader.dart:427`.

## How the Summary System Works Internally

1. **Build time**: `buildPackageBundle()` in `AnalysisDriver` resolves and analyzes library files, then serializes their element model into resolution bytes via `BundleWriter`. The `PackageBundleBuilder` records library URIs and their unit URIs.

2. **Runtime**: `PackageBundleReader` reads the binary format. `SummaryDataStore` indexes the bundle's unit URIs into `uriToSummaryPath`. Our `PackageSummaryUriResolver` creates `InSummarySource` stubs for URI lookups.

3. **On demand**: When `getLibraryByUri()` is called, the `LinkedElementFactory` reads the resolution bytes via `BundleReader`/`LibraryReader`. During deserialization, import/export directives are resolved by calling `sourceFactory.forUri2(uri)` — which must succeed for ALL URIs referenced in the bytes.

## Upstream Notes

- No SDK source files were modified. All fixes are consumer-side workarounds.
- The SDK's `InSummaryUriResolver` and `SummaryDataStore.addBundle()` are designed for Bazel/build_runner workflows where unit URIs in the bundle match the scheme used at consumer time. This assumption breaks for standalone Flutter app use cases.
- If the SDK ever changes `addBundle()` to also register library URIs, or if `InSummaryUriResolver` gains wildcard/prefix matching, the workarounds can be simplified.
