/// Core types and contracts for the Tom Forge Panel Shell.
///
/// Provides platform-independent types used across forge packages:
///
/// - **Types**: [ForgeTextPosition], [ForgeTextRange], [ForgeSeverity],
///   [ForgeDiagnostic], [FileHandlingResult], [ForgeTextEditorOptions]
/// - **Document**: [ForgeDocument], [DocumentChangeEvent]
/// - **Decorations**: [ForgeDecorationType], [ForgeDecorationRange]
/// - **Events**: Focus, selection, diagnostic, layout, and file events
/// - **Workspace Edit**: [ForgeWorkspaceEdit], [ForgeTextEdit]
library;

// Core types
export 'src/types/text_position.dart';
export 'src/types/text_range.dart';
export 'src/types/forge_severity.dart';
export 'src/types/forge_diagnostic.dart';
export 'src/types/file_handling_result.dart';
export 'src/types/text_editor_options.dart';
export 'src/types/decoration_types.dart';
export 'src/types/forge_enums.dart';
export 'src/types/forge_events.dart';
export 'src/types/workspace_edit.dart';

// Document
export 'src/document/forge_document.dart';
