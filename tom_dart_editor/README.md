# Tom Dart Editor

A Flutter widget for editing and analyzing Dart code with syntax highlighting, code completion, error display, and comprehensive theming support — **without requiring a Dart SDK on the target device**.  

## Features

- **SDK-Free Analysis** — Full diagnostics and completions via pre-built summary bundles
- **Syntax Highlighting** — AST-based semantic highlighting with support for all Dart constructs
- **Rainbow Brackets** — Color-coded bracket pairs for visual depth tracking
- **Code Completion** — Context-aware completions with customizable providers
- **Error Display** — Real-time error/warning markers and tooltips
- **Undo/Redo** — Full edit history with Cmd/Ctrl+Z and Cmd/Ctrl+Shift+Z
- **Auto-indentation** — Smart indent on Enter, auto-close brackets
- **Theming** — Dark and light themes with full customization

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  tom_dart_editor:
    path: ../tom_editors/tom_dart_editor
```

Or from pub.dev (when published):

```yaml
dependencies:
  tom_dart_editor: ^0.1.0
```

## Quick Start

```dart
import 'package:tom_dart_editor/tom_dart_editor.dart';

class MyCodeEditor extends StatefulWidget {
  @override
  State<MyCodeEditor> createState() => _MyCodeEditorState();
}

class _MyCodeEditorState extends State<MyCodeEditor> {
  late final DartCodeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DartCodeController(
      initialCode: 'void main() {\n  print("Hello, Dart!");\n}',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DartCodeEditor(
      controller: _controller,
      theme: DartEditorTheme.dark(),
      onChanged: (code) {
        // Handle code changes
      },
    );
  }
}
```

## Embedding with Summary Scopes

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
        - ../../tom_ai/d4rt/tom_d4rt_flutter   # the bridged surface, not the app closure
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

## Documentation

- **[Usage Guide](doc/dart_editor_usage_guide.md)** — Complete guide with embedding patterns, theming, and settings
- **[Package Summary Generation](doc/package_summary_generation.md)** — How to build `.sum` files for SDK-free analysis
- **[Summary Scopes](doc/summary_scopes.md)** — Named, per-surface summary scopes and the shared-store memory model
- **[`tom_dart_editor_bundler`](../tom_dart_editor_bundler/README.md)** — The CLI that builds the `.sum` bundles and the `SummaryScopes` helper

## Theming

The editor supports full theme customization:

```dart
// Use built-in themes
DartCodeEditor(
  controller: _controller,
  theme: DartEditorTheme.dark(),  // or .light()
)

// Custom theme
DartCodeEditor(
  controller: _controller,
  theme: DartEditorTheme.dark().copyWith(
    editor: const EditorColors.dark().copyWith(
      border: Colors.pinkAccent,
      borderWidth: 2.0,
    ),
    syntax: const SyntaxColors.dark().copyWith(
      keyword: Colors.purple,
    ),
  ),
)
```

## Editor Settings

Configure editor behavior via `DartEditorSettings`:

```dart
DartCodeEditor(
  controller: _controller,
  settings: const DartEditorSettings(
    autoCompleteEnabled: true,
    showLineNumbers: true,
    showToolbar: true,
    maxCompletionItems: 10,
    popupPreferBelow: true,
    showErrorMarkers: true,
    showWarningMarkers: true,
    showInfoMarkers: false,
  ),
  onSettingsChanged: (settings) {
    // Settings changed via toolbar
  },
)
```

## Code Completion

Provide custom completions via the `onCompletionRequest` callback:

```dart
DartCodeEditor(
  controller: _controller,
  onCompletionRequest: (code, offset, prefix) async {
    // Return completion items based on context
    return [
      CompletionItem(
        label: 'myFunction',
        kind: CompletionKind.function,
        detail: '() → void',
      ),
    ];
  },
)
```

## Error Display

Pass errors from your analyzer:

```dart
DartCodeEditor(
  controller: _controller,
  errors: [
    CodeError(
      message: 'Undefined name',
      line: 3,
      column: 5,
      offset: 42,
      length: 4,
      severity: 'ERROR',
      code: 'undefined_identifier',
    ),
  ],
  onErrorTap: (error) {
    // Handle error tap
  },
)
```

## Implicit Imports

Support code snippets that assume certain imports:

```dart
_controller = DartCodeController(
  initialCode: 'final file = File("test.txt");',
  implicitImports: [
    'dart:io',
    'dart:async',
  ],
);
```

The controller provides `fullCode` (with imports) for analysis while displaying only `userCode` to the user.

## Analyzer Integration

For full Dart analysis (requires analyzer package with internal APIs):

```dart
import 'package:tom_dart_editor/tom_dart_editor.dart';

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

The editor is built for Flutter's desktop, mobile **and web** targets. Web
support is not an inference from the in-memory design — it is measured, by
`test/web_build_test.dart`, which runs a real `flutter build web` over the
companion app in `../tom_dart_editor_test`. That test runs as part of the normal
suite (about a minute; `TOM_SKIP_WEB_BUILD=1` opts out).

**Do not try to replace that build with a search for `dart:io`.** It is a
tempting shortcut and it does not work — not because it would miss transitive
dependencies, but because it measures a property that has nothing to do with the
outcome. The import closure of `package:tom_dart_editor/tom_dart_editor.dart` is
around 1900 libraries, and 45 of them name `dart:io` unconditionally. The list is
led by Flutter itself: `package:flutter/services.dart` exports
`src/services/text_input.dart`, whose second line is
`import 'dart:io' show Platform;`. That library is in the closure of every
Flutter web app ever built, all of which compile. A web build fails for a
different reason than a `dart:io` mention — when it fails, the compiler names the
offending library and the exact import chain that reached it, which is worth far
more than any grep.

There is a separate grep in `test/summary_analysis_adapter_test.dart` that does
look for `dart:io` in this package's own sources. It enforces a different rule —
that *analysed source* stays in memory — and it says so.

## License

BSD-3-Clause — See [LICENSE](LICENSE) for details.
