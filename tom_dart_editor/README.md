# Tom Dart Editor

A Flutter widget for editing and analyzing Dart code with syntax highlighting, code completion, error display, and comprehensive theming support.

## Features

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

## Embedding Guides

- [doc/how_to_embed.md](doc/how_to_embed.md) — one-liner embedding with
  `SimpleSummaryBackedDartCodeEditor` and advanced controller-based options.

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

// Create analysis driver
final driver = createAnalysisDriverWithPackages(
  resourceProvider: PhysicalResourceProvider.INSTANCE,
  sdkSummaryBytes: sdkBytes.buffer.asUint8List(),
  analysisOptions: AnalysisOptionsImpl(),
  uriResolvers: [...],
  packages: Packages({}),
);

// Use the session for analysis
final session = driver.currentSession;
final errors = await session.getErrors(filePath);
```

**Note:** The analyzer integration uses internal APIs from the `analyzer` package. For desktop-only usage, consider using the public `AnalysisContextCollection` API instead.

## License

BSD-3-Clause — See [LICENSE](LICENSE) for details.
