# Tom Dart Editor

A Flutter widget for editing Dart code with syntax highlighting, code completion, error display, and comprehensive theming support. The editor has **no analyzer**: it highlights with a light, lexical highlighter of its own and takes diagnostics and completions from its host. Its analysis plugin, [`tom_dart_analysis`](../tom_dart_analysis/README.md), brings the summary-backed analysis (diagnostics and completions **without a Dart SDK on the target device**) and the semantic highlighter.

## Features

- **Syntax Highlighting** — a light, lexical highlighter built in (`DartLightHighlighter`: keywords, strings with interpolation, numbers, comments, annotations, brackets); any `tom_text_highlight` highlighter plugs in (`highlighter:`), e.g. `tom_dart_analysis`'s semantic `DartSyntaxHighlighter`
- **Rainbow Brackets** — Color-coded bracket pairs for visual depth tracking
- **Code Completion** — Context-aware completions with customizable providers
- **Error Display** — Real-time error/warning markers and tooltips
- **Undo/Redo** — one history per document, word by word, with the caret
  restored, shared by split views; or the host's history in the external
  history mode (`DartCodeHistoryHost`)
- **Auto-indentation** — Smart indent on Enter, auto-close brackets
- **Theming** — Dark and light themes with full customization
- **SDK-Free Analysis** — with `tom_dart_analysis`: full diagnostics and completions via pre-built summary bundles

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

## Highlighting

The editor highlights with the highlighter it is given (`highlighter:`, a
`tom_text_highlight` `SyntaxHighlighter`), else with its own light, lexical
`DartLightHighlighter`. A highlighter's token classes are highlight.js class
names with dotted refinements (`keyword.control`, `title.function`,
`punctuation.bracket.2`); the editor styles each with the colour its theme gives
the matching kind (`HighlightType`, `dartHighlightClass`), so a highlighter
decides *what* a token is and the theme how it looks. Pass the same highlighter
instance on every build.

```dart
DartCodeEditor(
  controller: _controller,
  highlighter: _highlighter, // e.g. a DartSyntaxHighlighter from tom_dart_analysis
)
```

`registerDartCodeBlockHighlighting()` makes `tom_text_highlight`'s
`highlighterForLanguage('dart')` answer the light highlighter (Markdown code
blocks and other source views); nothing is registered by default.

## Adding analysis

Diagnostics and completions come through two seams: `errors:` (a
`List<CodeError>`) and `onCompletionRequest:`. `tom_dart_analysis` fills both
from pre-built analyzer summaries, gives the semantic highlighter, and has the
editors with all of it built in (`SummaryBackedDartCodeEditor`,
`SimpleSummaryBackedDartCodeEditor`) and the summary scopes; see its
[README](../tom_dart_analysis/README.md) and
[`doc/how_to_embed.md`](doc/how_to_embed.md).

## Documentation

- **[Usage Guide](doc/dart_editor_usage_guide.md)** — Complete guide with embedding patterns, theming, and settings
- **[How to embed](doc/how_to_embed.md)** — The editor alone, and with its analysis
- **[`tom_dart_analysis`](../tom_dart_analysis/README.md)** — The summary-backed analysis, the summary scopes and the semantic highlighter
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

Pass errors from your analyzer (`tom_dart_analysis`'s
`SummaryBackedDartAnalysisAdapter.analyzeCode`, or your own):

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

## Platform support

The editor is built for Flutter's desktop, mobile **and web** targets, with its
analysis (`tom_dart_analysis`) too. Web support is not an inference from the
in-memory design — it is measured, by `test/web_build_test.dart`, which runs a
real `flutter build web` over the companion app in `../tom_dart_editor_test`
(the editor with its analysis). That test runs as part of the normal
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

There is a separate grep in `tom_dart_analysis`'s
`test/summary_analysis_adapter_test.dart` that does look for `dart:io` in that
package's own sources. It enforces a different rule —
that *analysed source* stays in memory — and it says so.

### Why `dart:io` compiles for the web and `dart:ffi` does not

The paragraph above says a `dart:io` mention predicts nothing. Here is *why*,
because "we observe it" is a thin foundation for a supported platform, and the
usual guess — that the unused surface is tree-shaken away before the platform
check — is wrong.

**`dart:io` is a declared dart2js library.** In `dart-sdk/lib/libraries.json`
the `dart2js` target's own `libraries` map holds only eight entries and `io` is
not among them; that is what makes it look absent. But the target is defined as
`"include": [{"target": "_dart2js_common"}]`, and `_dart2js_common` declares:

```json
"io": {
  "uri": "io/io.dart",
  "patches": "_internal/js_runtime/lib/io_patch.dart",
  "support_conditional_import": false
}
```

`flutter_web_sdk/libraries.json` adds six web-only libraries and includes the
same dart-sdk `dart2js` target, so a Flutter web build inherits it. `dart:ffi`
appears in **no** dart2js target at all, which is why it is refused with
*"Dart library 'dart:ffi' is not available on this platform"* — the asymmetry is
in the SDK's own manifest, not in the compiler's cleverness.

**It is not tree-shaking**, and the shortest way to see that is to use the
library rather than merely import it. `dart compile js` compiles this:

```dart
import 'dart:io';
void main() {
  print(File('nope.txt').existsSync());
  print(Directory.current.path);
  print(Platform.operatingSystem);
}
```

**The boundary is at run time.** `io_patch.dart` is ~825 lines of `@patch`
methods that throw, so the program above compiles and then dies on its first
real call with `UnsupportedError: _Namespace`. Compilable and unusable are
different properties, and only the second is about `dart:io` being unavailable.

**`dart.library.io` is `false` regardless**, which is the point of
`support_conditional_import: false`: a conditional import routes away from
`dart:io` on the web even though a direct `import 'dart:io'` would have
compiled. Availability and the environment flag are two different questions, and
a library can answer them differently.

The practical consequence for this package: a web build cannot break because
something in the closure *names* `dart:io`, and it will not start breaking if a
future SDK tightens a check that does not exist. What it *can* break on is a
library that actually calls into `dart:io` on a web code path — which fails at
run time, not at build time, and which no build gate can catch.

`test/web_build_test.dart` pins both halves of this with `dart compile js`
probes that take about two seconds: a `dart:io`-using program must still
compile, and a `dart:ffi` one must still fail. If a toolchain change ever
reverses either, those go red with the reason attached instead of the real build
failing somewhere unhelpful.

## License

BSD-3-Clause — See [LICENSE](LICENSE) for details.
