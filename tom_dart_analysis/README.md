# Tom Dart Analysis

The analysis of the Dart editor ([`tom_dart_editor`](../tom_dart_editor/README.md)),
as a plugin package: the editor itself has no analyzer, and an application that
wants Dart analysis takes this package beside it.

- **SDK-free analysis** — `SummaryBackedDartAnalysisAdapter`: diagnostics
  (`analyzeCode`) and completions (`completions`) over pre-built SDK and package
  summaries, in memory, on desktop, mobile and web.
- **Summary scopes** — `SummaryScopeRegistry`: named analysis surfaces an
  application registers once (with the helper `tom_dart_editor_bundler`
  generates) and every editor of a scope shares.
- **Editors with the analysis built in** — `SummaryBackedDartCodeEditor`
  (your `DartCodeController`) and `SimpleSummaryBackedDartCodeEditor` (its own).
- **Semantic highlighting** — `DartSyntaxHighlighter`: the analyzer's scanner
  for the lexical kinds, then a pass over the AST for class, function, method
  call, parameter, property and type names. The editors above use it by default.

It brings the analyzer (`analyzer`, with some of its internal APIs) and the
summaries.

## How it plugs in

The Dart editor has three seams: `highlighter:`, `errors:` and
`onCompletionRequest:`. This package fills them:

```dart
import 'package:tom_dart_analysis/tom_dart_analysis.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart';

final adapter = SummaryBackedDartAnalysisAdapter.scope(SummaryScopes.dartEditor);
final highlighter = DartSyntaxHighlighter(); // one per editor, kept

DartCodeEditor(
  controller: controller,
  highlighter: highlighter,
  errors: errors, // from await adapter.analyzeCode(controller.userCode)
  onCompletionRequest: adapter.completions,
)
```

or, with all of it wired:

```dart
SimpleSummaryBackedDartCodeEditor(
  initialCode: code,
  scope: SummaryScopes.dartEditor,
)
```

## Installation

```yaml
dependencies:
  tom_dart_editor:
    path: ../tom_dart_editor
  tom_dart_analysis:
    path: ../tom_dart_analysis
```

## Summary scopes

When an app embeds **many** code editors — possibly targeting **different** code
surfaces (plain Dart, a d4rt-Flutter bridged API, a document-scripting API) —
wire them through **summary scopes** rather than hand-loading `.sum` assets per
field. A *summary scope* is a named analysis surface: the SDK plus an optional
package closure, with default implicit imports and completion filters. Each
content type maps to a scope; every editor created with the same `scope:` shares
one parsed summary store (see [Memory model](#memory-model-many-editors-one-store)).

Scopes are produced by the companion CLI
[`tom_dart_editor_bundler`](../tom_dart_editor_bundler) — see its
[README](../tom_dart_editor_bundler/README.md) for the full config schema. The
end-to-end flow is five steps:

### 1. Declare bundles in the app's `buildkit.yaml`

```yaml
dart-editor-bundler:
  out-dir: assets/summaries
  generated-helper: lib/generated/summary_scopes.g.dart
  sdk-summary: sdk_summary.sum
  bundles:
    - name: dart-plain
      sdk-only: true
      implicit-imports: [dart:async, dart:collection, dart:math]

    - name: d4rt-flutter
      packages:
        - ../../d4rt/tom_d4rt_flutter   # the bridged surface, not the app closure
      implicit-imports: [package:flutter/material.dart]
```

### 2. Run the bundler

From the app directory (so relative paths resolve against it):

```bash
dart run ../tom_dart_editor_bundler/bin/dart_editor_bundler.dart \
  --config buildkit.yaml --verbose
```

This writes the shared SDK summary (`assets/summaries/sdk_summary.sum`), one
`assets/summaries/<name>/packages.sum` per non-`sdk-only` scope, and the
generated `SummaryScopes` helper (`lib/generated/summary_scopes.g.dart`).

### 3. List the `.sum` assets in `pubspec.yaml`

Flutter asset directories are **non-recursive**, so list each scope sub-directory
explicitly:

```yaml
flutter:
  assets:
    - assets/summaries/
    - assets/summaries/d4rt-flutter/
```

Commit the generated `summary_scopes.g.dart` (committed code imports it); keep
the heavy `.sum` bundles gitignored and regenerate them from `buildkit.yaml`.

### 4. Register the scopes once in `main()`

Call the generated `initialize()` before `runApp` so the registry is populated
before the first frame. Guard it so a checkout missing the `.sum` assets degrades
to plain-text fields instead of crashing:

```dart
import 'generated/summary_scopes.g.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SummaryScopes.initialize();
  } catch (error, stack) {
    debugPrint('Summary scope init skipped: $error');
    debugPrintStack(stackTrace: stack);
  }
  runApp(const MyApp());
}
```

### 5. Instantiate editors by scope

Pass a generated scope constant. Probe the registry synchronously (it is already
populated by step 4) to choose between the summary-backed editor and a plain-text
fallback for an unregistered scope:

```dart
if (SummaryScopeRegistry.instance.isRegistered(SummaryScopes.d4rtFlutter)) {
  return SimpleSummaryBackedDartCodeEditor(
    scope: SummaryScopes.d4rtFlutter,   // resolved from the shared registry
    initialCode: field.value,
    onChanged: field.set,
  );
}
return PlainTextField(value: field.value, onChanged: field.set); // fallback
```

The host's field router maps each `@ContentType('code-dart' | 'code-d4rt-flutter'
| …)` to a scope name; an absent scope falls back to a plain value field.

> The explicit-asset constructor (`sdkSummaryAsset` / `packageSummaryAsset`)
> remains as a lower-level escape hatch — use `scope:` for multi-editor apps so
> the shared store kicks in.

### Memory model (many editors, one store)

`SummaryScopeRegistry.register()` parses each scope's `.sum` bytes **once** into
the analyzer element model and releases the byte buffers; the parsed store is
held shared and ref-counted. Every editor created with the same `scope:` builds a
lightweight per-instance analysis driver over that **one** shared store:

> **N editors of one scope ≈ one parsed store + N light drivers.**

That is what makes "dozens of small code fields in one document" cheap — ten
`d4rt-flutter` fields cost one Flutter summary parse, not ten.

## The analysis driver

For full Dart analysis (requires analyzer package with internal APIs):

```dart
import 'package:tom_dart_analysis/tom_dart_analysis.dart';

// Load pre-built SDK summary
final sdkBytes = await rootBundle.load('assets/sdk_summary.sum');

// Analysed source stays in memory — never a physical provider.
final resourceProvider = OverlayResourceProvider(MemoryResourceProvider());

// Create analysis driver
final driver = createAnalysisDriverWithPackages(
  resourceProvider: resourceProvider,
  sdkSummaryBytes: sdkBytes.buffer.asUint8List(),
  analysisOptions: AnalysisOptionsImpl(),
  uriResolvers: [...],
  packages: Packages({}),
);

// Use the session for analysis
final session = driver.currentSession;
final errors = await session.getErrors(filePath);
```

**Note:** The analyzer integration uses internal APIs from the `analyzer` package.

The resource provider is required and must be in-memory. The code being edited
is the user's code, and it must never be written to a disk to be analysed — on
web there is no disk to write to anyway. `PhysicalResourceProvider` is not a
supported configuration.

## Platform support

The analysis runs on Flutter's desktop, mobile and web targets: analysed source
stays in memory (`test/summary_analysis_adapter_test.dart` checks that no library
source reaches for a filesystem). The web build is measured by
`tom_dart_editor`'s `test/web_build_test.dart`, a real `flutter build web` of the
companion app `../tom_dart_editor_test`, which runs the editor with this
analysis; its README explains why that build, and not a search for `dart:io`,
decides.

## Documentation

- **[Package Summary Generation](doc/package_summary_generation.md)** — How to build `.sum` files for SDK-free analysis
- **[Summary Scopes](doc/summary_scopes.md)** — Named, per-surface summary scopes and the shared-store memory model
- **[`tom_dart_editor_bundler`](../tom_dart_editor_bundler/README.md)** — The CLI that builds the `.sum` bundles and the `SummaryScopes` helper

## License

BSD-3-Clause; see [LICENSE](LICENSE).
