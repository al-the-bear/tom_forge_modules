/// A Flutter widget for editing Dart code.
///
/// Provides syntax highlighting, code completion, error display, and
/// comprehensive theming support. Can be embedded in any Flutter application.
/// The editor has no analyzer of its own: it highlights with the light,
/// lexical [DartLightHighlighter], and takes diagnostics ([DartCodeEditor.errors])
/// and completions ([DartCodeEditor.onCompletionRequest]) from its host.
/// `tom_dart_analysis` brings the summary-backed analysis and the semantic
/// highlighter.
///
/// ## Basic Usage
///
/// ```dart
/// import 'package:tom_dart_editor/tom_dart_editor.dart';
///
/// // Create a controller
/// final controller = DartCodeController(
///   initialCode: 'void main() { print("Hello"); }',
/// );
///
/// // Use the editor widget
/// DartCodeEditor(
///   controller: controller,
///   theme: DartEditorTheme.dark(),
/// )
/// ```
///
/// ## Features
///
/// - Lexical syntax highlighting; a pluggable highlighter
///   ([DartCodeEditor.highlighter])
/// - Rainbow bracket matching
/// - Code completion with customizable providers
/// - Error/warning display with tooltips
/// - Undo/redo support
/// - Auto-indentation
/// - Dark and light themes
/// - Fully customizable theming
library tom_dart_editor;

// Core editor widget and controller
export 'src/dart_code_editor.dart'
    show
        DartCodeEditor,
        DartCodeController,
        DartCodeHistoryHost,
        DartEditorSettings,
        CodeError;

// Forge editor integration
export 'src/dart_text_context.dart' show DartTextContext;
export 'src/editor_trail.dart' show kDartEditorDebug, trailEvent;

// Theme system
export 'src/editor_theme.dart'
    show
        DartEditorTheme,
        EditorColors,
        SyntaxColors,
        DiagnosticColors,
        BracketColors,
        TooltipStyle,
        FontSettings;

// Completion types
export 'src/completion_provider.dart'
    show CompletionItem, CompletionKind, MemberInfo;

// Highlighting: the light highlighter, the kinds and their token classes.
export 'src/dart_light_highlighter.dart'
    show
        DartLightHighlighter,
        dartCodeBlockHighlighter,
        registerDartCodeBlockHighlighting,
        unregisterDartCodeBlockHighlighting;
export 'src/highlight_types.dart'
    show
        DartHighlightTheme,
        DartHighlightToken,
        HighlightType,
        BracketPair,
        HighlightedTextBuilder,
        dartHighlightClass,
        dartBracketClassPrefix,
        dartBracketDepthOfClass,
        bracketPairsOf;

// The highlighter interface the editor takes (`DartCodeEditor.highlighter`).
export 'package:tom_text_highlight/tom_text_highlight.dart'
    show
        SyntaxHighlighter,
        HighlightSpan,
        TokenHighlighter,
        HighlightToken,
        HighlightTheme;
