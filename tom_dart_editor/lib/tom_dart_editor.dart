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

// Reusable summary-backed analyzer/completion adapter
export 'src/summary_analysis_adapter.dart'
    show SummaryBackedDartAnalysisAdapter;

// High-level editor wrapper with built-in summary-backed analysis
export 'src/summary_backed_dart_editor.dart' show SummaryBackedDartCodeEditor;

// Easy one-liner embed widget (internal controller)
export 'src/simple_summary_backed_dart_editor.dart'
    show SimpleSummaryBackedDartCodeEditor;
