/// A Flutter widget for editing and analyzing Dart code.
///
/// Provides syntax highlighting, code completion, error display, and
/// comprehensive theming support. Can be embedded in any Flutter application.
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
/// - Syntax highlighting with AST-based semantic analysis
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
    show DartCodeEditor, DartCodeController, DartEditorSettings, CodeError;

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

// Syntax highlighting (for advanced use)
export 'src/syntax_highlighter.dart'
    show
        DartSyntaxHighlighter,
        DartHighlightTheme,
        HighlightToken,
        HighlightType,
        BracketPair,
        HighlightedTextBuilder;

// Analyzer integration (uses internal analyzer APIs)
export 'src/analyzer_with_packages.dart'
    show AnalysisDriverWithPackages, createAnalysisDriverWithPackages;
