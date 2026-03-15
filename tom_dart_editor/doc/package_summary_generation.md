# Generating Summary Files for Dart Analysis

This document explains how to generate the `.sum` summary files required by `tom_dart_editor` for SDK-free Dart analysis.

---

## Overview

The Dart editor provides full code analysis (diagnostics, completions) without requiring a Dart SDK installed on the target device. This is achieved through **pre-built summary bundles** (`.sum` files) that contain serialized element models.

Two summary files are required:

| File | Contents | Size (typical) |
|------|----------|----------------|
| `sdk_summary.sum` | Dart SDK core libraries | ~3 MB |
| `packages.sum` | Package libraries (e.g., `path`, `dcli`) | ~30+ MB |

---

## Build Time: Generate Summary Files

### 1. SDK Summary

The SDK summary is generated from your installed Dart SDK:

```bash
dart run tool/build_sdk_summary.dart assets/sdk_summary.sum
```

Or use the analyzer's built-in function in your own tool:

```dart
import 'package:analyzer/dart/sdk/build_sdk_summary.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/src/util/sdk.dart';

final bytes = await buildSdkSummary(
  resourceProvider: PhysicalResourceProvider.INSTANCE,
  sdkPath: getSdkPath(),
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
| `tom_dart_editor_test/tool/build_packages_summary.dart` | Build tool for `packages.sum` |
| `tom_dart_editor_test/tool/diagnose_packages_sum.dart` | Diagnostic tool to inspect bundle contents |
| `tom_dart_editor_test/tool/check_sdk_sum.dart` | Diagnostic tool to inspect SDK bundle |
