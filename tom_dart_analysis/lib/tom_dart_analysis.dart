/// The Dart analysis of the Dart editor (`tom_dart_editor`).
///
/// - [SummaryBackedDartAnalysisAdapter]: diagnostics and completions over
///   pre-built SDK and package summaries, in memory (desktop, mobile, web).
/// - [SummaryScopeRegistry]: the named summary scopes an application
///   registers once (the scope-init helper `tom_dart_editor_bundler`
///   generates).
/// - [SummaryBackedDartCodeEditor], [SimpleSummaryBackedDartCodeEditor]: the
///   editor with that analysis built in.
/// - [DartSyntaxHighlighter]: the analyzer-based highlighter with its
///   semantic pass, plugged into a `DartCodeEditor` through its
///   `highlighter` (the two editors above do so by default).
///
/// ```dart
/// DartCodeEditor(
///   controller: controller,
///   highlighter: highlighter, // a DartSyntaxHighlighter, kept by the host
///   errors: await adapter.analyzeCode(controller.userCode),
///   onCompletionRequest: adapter.completions,
/// )
/// ```
library;

// Analyzer integration (uses internal analyzer APIs)
export 'src/analyzer_with_packages.dart'
    show
        AnalysisDriverWithPackages,
        createAnalysisDriverWithPackages,
        ParsedSummaryModel,
        buildAnalysisDriver;

// Shared, name-keyed summary-scope registry
export 'src/summary_scope_registry.dart'
    show
        SummaryScopeAsset,
        SummaryScope,
        SummaryScopeRegistry,
        SummaryAssetBytesLoader;

// Reusable summary-backed analyzer/completion adapter
export 'src/summary_analysis_adapter.dart'
    show SummaryBackedDartAnalysisAdapter;

// High-level editor wrapper with built-in summary-backed analysis
export 'src/summary_backed_dart_editor.dart' show SummaryBackedDartCodeEditor;

// Easy one-liner embed widget (internal controller)
export 'src/simple_summary_backed_dart_editor.dart'
    show SimpleSummaryBackedDartCodeEditor;

// The analyzer-based highlighter with its semantic pass
export 'src/syntax_highlighter.dart' show DartSyntaxHighlighter;
