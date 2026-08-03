# Tom Dart Editor — Usage Guide

A full-featured Dart code editor for Flutter with syntax highlighting, real-time code analysis, intelligent completions, and error display — **without requiring a Dart SDK on the target device**.

---

## Key Features

- **SDK-Free Analysis**: No Dart SDK required at runtime — analysis powered by pre-built summary bundles
- **Real-time Diagnostics**: Errors, warnings, and hints displayed inline and in gutter
- **Intelligent Completions**: Context-aware code completions with documentation
- **Package Support**: Import and analyze any Dart package included in bundles
- **Customizable Themes**: Full control over syntax colors, editor chrome, and diagnostics
- **Flexible Embedding**: Three embedding patterns for different control requirements

---

## No Dart SDK Required — How It Works

Traditional Dart analysis requires a complete Dart SDK installation. `tom_dart_editor` eliminates this dependency through **pre-built summary bundles** (`.sum` files):

| Bundle | Contents | Purpose |
|--------|----------|---------|
| `sdk_summary.sum` | Dart SDK core libraries | Enables `dart:core`, `dart:async`, etc. |
| `packages.sum` | Your app's package dependencies | Enables `package:xxx` imports |

These bundles contain serialized element models built at compile time. At runtime, the analyzer deserializes these models to provide full analysis without SDK access.

See [package_summary_generation.md](package_summary_generation.md) for build instructions.

---

## Embedding Forms

### Simple: One-Liner Embed (SimpleSummaryBackedDartCodeEditor)

The easiest way to add a Dart editor. Creates and manages its own controller internally.

```dart
SimpleSummaryBackedDartCodeEditor(
  initialCode: 'void main() {\n  print("Hello");\n}',
  sdkSummaryAsset: 'assets/sdk_summary.sum',
  packageSummaryAsset: 'assets/packages.sum',
  onChanged: (code) => print('Code changed: $code'),
  onErrorsChanged: (errors) => print('Errors: ${errors.length}'),
)
```

**When to use**: Quick embeds, prototypes, single-editor screens.

---

### Medium: External Controller (SummaryBackedDartCodeEditor)

Provides your own `DartCodeController` for external code access and manipulation.

```dart
class _MyState extends State<MyWidget> {
  late final DartCodeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DartCodeController(
      userCode: 'void main() {}',
      implicitImports: ['dart:async', 'package:path/path.dart'],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SummaryBackedDartCodeEditor(
      controller: _controller,
      sdkSummaryAsset: 'assets/sdk_summary.sum',
      packageSummaryAsset: 'assets/packages.sum',
      onChanged: (code) => _handleCodeChange(code),
    );
  }

  void _saveCode() {
    final code = _controller.userCode;  // Access code externally
    // ...
  }
}
```

**When to use**: Multi-editor screens, external code access, undo/redo integration.

---

### Long: Manual Analysis (DartCodeEditor)

Full control — you provide completions and errors from your own analysis pipeline.

```dart
DartCodeEditor(
  controller: _controller,
  completions: _currentCompletions,
  errors: _currentErrors,
  onChanged: (code) => _runAnalysis(code),
  onCompletionRequest: _handleCompletionRequest,
)
```

**When to use**: Custom analysis backends, LSP integration, non-Dart languages.

---

## Asset Configuration

### pubspec.yaml

Add summary bundles as assets:

```yaml
flutter:
  assets:
    - assets/sdk_summary.sum
    - assets/packages.sum
```

### Platform-Specific Notes

| Platform | Notes |
|----------|-------|
| **iOS** | Assets bundled in app; no special config |
| **Android** | Assets bundled in app; no special config |
| **macOS** | Assets in `Frameworks/App.framework/Resources/flutter_assets/` |
| **Windows** | Assets in `data/flutter_assets/` |
| **Linux** | Assets in `data/flutter_assets/` |
| **Web** | Assets served from `assets/` — consider lazy loading for large bundles |

### Web Optimization

For web builds, summary bundles can be large (~30MB for packages). Consider:

```dart
// Load on demand
SummaryBackedDartCodeEditor(
  sdkSummaryAsset: 'assets/sdk_summary.sum',
  packageSummaryAsset: 'assets/packages.sum',
  loadingBuilder: (context) => Center(child: CircularProgressIndicator()),
)
```

---

## DartCodeController

Manages code state with support for implicit imports (code prepended but hidden from the user).

### Constructor

```dart
DartCodeController({
  String userCode = '',
  List<String> implicitImports = const [],
})
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `userCode` | `String` | The visible user code |
| `implicitImports` | `List<String>` | Import statements prepended to code |
| `fullCode` | `String` | Complete code including implicit imports |
| `lineOffset` | `int` | Number of lines added by implicit imports |

### Methods

| Method | Description |
|--------|-------------|
| `updateUserCode(String code)` | Update visible code |
| `adjustLineNumber(int line)` | Convert analysis line to editor line |
| `addListener(VoidCallback)` | Listen for code changes |
| `dispose()` | Clean up resources |

### Implicit Imports

Implicit imports let you provide context without cluttering the editor:

```dart
final controller = DartCodeController(
  userCode: 'final p = join("a", "b");',  // User sees only this
  implicitImports: [
    'dart:async',
    'package:path/path.dart',  // 'join' available without visible import
  ],
);
```

The `fullCode` sent to analysis includes:
```dart
import 'dart:async';
import 'package:path/path.dart';
final p = join("a", "b");
```

Line numbers are automatically adjusted in diagnostics.

---

## Theming

### DartEditorTheme

Full control over editor appearance:

```dart
SimpleSummaryBackedDartCodeEditor(
  // ...
  theme: DartEditorTheme.dark().copyWith(
    editorColors: EditorColors(
      background: Color(0xFF1E1E1E),
      lineNumbers: Color(0xFF858585),
      currentLine: Color(0xFF282828),
      selection: Color(0xFF264F78),
      cursor: Color(0xFFAEAFAD),
      gutter: Color(0xFF252526),
    ),
    syntaxColors: SyntaxColors(
      keyword: Color(0xFF569CD6),
      string: Color(0xFFCE9178),
      number: Color(0xFFB5CEA8),
      comment: Color(0xFF6A9955),
      type: Color(0xFF4EC9B0),
      function: Color(0xFFDCDCAA),
      variable: Color(0xFF9CDCFE),
      parameter: Color(0xFF9CDCFE),
      operator: Color(0xFFD4D4D4),
      punctuation: Color(0xFFD4D4D4),
    ),
  ),
)
```

### Built-in Themes

```dart
DartEditorTheme.dark()   // VS Code dark-inspired
DartEditorTheme.light()  // VS Code light-inspired
```

### Theme Components

| Component | Purpose |
|-----------|---------|
| `EditorColors` | Background, gutter, selection, cursor |
| `SyntaxColors` | Keywords, strings, types, comments, etc. |
| `DiagnosticColors` | Error, warning, hint, info underlines |
| `BracketColors` | Rainbow bracket matching colors |
| `TooltipStyle` | Completion and hover tooltip styling |
| `FontSettings` | Font family, size, line height |

---

## Settings

### DartEditorSettings

Configure editor behavior:

```dart
SimpleSummaryBackedDartCodeEditor(
  // ...
  settings: DartEditorSettings(
    showToolbar: true,
    showLineNumbers: true,
    showGutter: true,
    enableCompletion: true,
    enableDiagnostics: true,
    showDiagnosticsInline: true,
    showDiagnosticsPanel: false,
    enableBracketMatching: true,
    enableRainbowBrackets: true,
    autoIndent: true,
    tabSize: 2,
    insertSpacesForTab: true,
    wrapLines: false,
    enableUndo: true,
    maxUndoHistory: 100,
    analysisDebounceMs: 300,
  ),
)
```

### Settings Reference

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `showToolbar` | `bool` | `true` | Show formatting toolbar |
| `showLineNumbers` | `bool` | `true` | Show line number column |
| `showGutter` | `bool` | `true` | Show error/warning icons in gutter |
| `enableCompletion` | `bool` | `true` | Enable code completions |
| `enableDiagnostics` | `bool` | `true` | Enable error analysis |
| `showDiagnosticsInline` | `bool` | `true` | Show error underlines in code |
| `showDiagnosticsPanel` | `bool` | `false` | Show error list panel |
| `enableBracketMatching` | `bool` | `true` | Highlight matching brackets |
| `enableRainbowBrackets` | `bool` | `true` | Color brackets by nesting level |
| `autoIndent` | `bool` | `true` | Auto-indent on newline |
| `tabSize` | `int` | `2` | Spaces per tab |
| `insertSpacesForTab` | `bool` | `true` | Insert spaces instead of tabs |
| `wrapLines` | `bool` | `false` | Soft wrap long lines |
| `enableUndo` | `bool` | `true` | Enable undo/redo |
| `maxUndoHistory` | `int` | `100` | Max undo steps |
| `analysisDebounceMs` | `int` | `300` | Debounce analysis after typing |

---

## Filtering Completions

Control which packages appear in completions:

```dart
SimpleSummaryBackedDartCodeEditor(
  // ...
  includeAllPackageCompletions: false,  // Don't show all packages
  allowedPackagePrefixes: ['path', 'collection'],  // Only these packages
)
```

Use `includeAllPackageCompletions: true` to show completions from all bundled packages.

---

## Error Handling

### CodeError

Represents a diagnostic from analysis:

```dart
class CodeError {
  final int line;        // 1-indexed line number (editor-relative)
  final int column;      // 1-indexed column
  final int length;      // Length of error span
  final String message;  // Human-readable message
  final ErrorSeverity severity;  // error, warning, hint, info
}

enum ErrorSeverity { error, warning, hint, info }
```

### Listening for Errors

```dart
SimpleSummaryBackedDartCodeEditor(
  // ...
  onErrorsChanged: (List<CodeError> errors) {
    final errorCount = errors.where((e) => e.severity == ErrorSeverity.error).length;
    print('Code has $errorCount errors');
  },
)
```

---

## Read-Only Mode

For code display without editing:

```dart
SimpleSummaryBackedDartCodeEditor(
  initialCode: sampleCode,
  readOnly: true,
  // ...
)
```

---

## Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart';

class DartEditorScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dart Editor')),
      body: SimpleSummaryBackedDartCodeEditor(
        initialCode: '''
void main() {
  final greeting = 'Hello, World!';
  print(greeting);
}
''',
        implicitImports: ['dart:async'],
        sdkSummaryAsset: 'assets/sdk_summary.sum',
        packageSummaryAsset: 'assets/packages.sum',
        includeAllPackageCompletions: true,
        theme: DartEditorTheme.dark(),
        settings: DartEditorSettings(
          showToolbar: true,
          enableRainbowBrackets: true,
          analysisDebounceMs: 500,
        ),
        onChanged: (code) {
          debugPrint('Code length: ${code.length}');
        },
        onErrorsChanged: (errors) {
          debugPrint('Diagnostics: ${errors.length}');
        },
      ),
    );
  }
}
```

---

## Related Documentation

- [Package Summary Generation](package_summary_generation.md) — Building `.sum` files
- [Summary Scopes](summary_scopes.md) — Named per-surface summary scopes and the `tom_dart_editor_bundler` tool that produces them
