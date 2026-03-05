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

## Required assets

Make sure both summary files are available in the embedding app's assets:

- `assets/sdk_summary.sum`
- `assets/packages.sum`

And included in app `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/sdk_summary.sum
    - assets/packages.sum
```
