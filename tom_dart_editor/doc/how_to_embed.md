# How to Embed `tom_dart_editor`

This package now provides a one-liner embed widget for the common case:

- `SimpleSummaryBackedDartCodeEditor` (internal controller)
- `SummaryBackedDartCodeEditor` (external controller)

## Minimal embed (one-liner)

```dart
import 'package:tom_dart_editor/tom_dart_editor.dart';

SimpleSummaryBackedDartCodeEditor(
  initialCode: 'void main() { print("Hello"); }',
  sdkSummaryAsset: 'assets/sdk_summary.sum',
  packageSummaryAsset: 'assets/packages.sum',
)
```

## Minimal with imports from bundled summaries

```dart
SimpleSummaryBackedDartCodeEditor(
  initialCode: 'void main() { print(join("a", "b")); }',
  implicitImports: const [
    'dart:async',
    'dart:collection',
    'dart:math',
    'package:path/path.dart',
  ],
  sdkSummaryAsset: 'assets/sdk_summary.sum',
  packageSummaryAsset: 'assets/packages.sum',
)
```

## Capture code and errors

```dart
SimpleSummaryBackedDartCodeEditor(
  initialCode: code,
  sdkSummaryAsset: 'assets/sdk_summary.sum',
  packageSummaryAsset: 'assets/packages.sum',
  onChanged: (updatedCode) {
    // Persist code
  },
  onErrorsChanged: (errors) {
    // Update diagnostics panel
  },
)
```

## When to use which widget

- Use `SimpleSummaryBackedDartCodeEditor` for easiest embedding.
- Use `SummaryBackedDartCodeEditor` if you need to manage your own `DartCodeController`.

## Summaries by scope

The summaries are built by `tom_dart_editor_bundler` from a
`dart-editor-bundler:` block in the app's `buildkit.yaml`
([Generating Summary Files](package_summary_generation.md)). It writes the
shared `assets/summaries/sdk_summary.sum`, one
`assets/summaries/<scope>/packages.sum` per scope, and
`lib/generated/summary_scopes.g.dart`, which registers every scope in a
shared, ref-counted `SummaryScopeRegistry`:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SummaryScopes.initialize();
  runApp(const MyApp());
}

SimpleSummaryBackedDartCodeEditor(
  initialCode: code,
  scope: SummaryScopes.dartEditor,
)
```

Editors of one scope share one parsed bundle. See
**[Summary Scopes](summary_scopes.md)**.

## Required assets

The scope folders are asset directories in the app's `pubspec.yaml`
(directory entries are not recursive):

```yaml
flutter:
  assets:
    - assets/summaries/
    - assets/summaries/dart-editor/
```

The explicit-asset form above (`sdkSummaryAsset:` / `packageSummaryAsset:`)
reads two summary files from any asset paths — for summaries not registered as
a scope; the paths in the examples are the parameters' defaults.
