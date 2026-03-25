/// Core types, contracts, and service interfaces for the Tom Forge Panel Shell.
///
/// Provides platform-independent types used across forge packages:
///
/// - **Types**: [ForgeTextPosition], [ForgeTextRange], [ForgeSeverity],
///   [ForgeDiagnostic], [FileHandlingResult], [ForgeTextEditorOptions]
/// - **Document**: [ForgeDocument], [DocumentChangeEvent]
/// - **Decorations**: [ForgeDecorationType], [ForgeDecorationRange]
/// - **Events**: Focus, selection, diagnostic, layout, and file events
/// - **Workspace Edit**: [ForgeWorkspaceEdit], [ForgeTextEdit]
/// - **Model**: [ForgeConfig], [AutoSaveConfig]
/// - **Services**: [ForgeFileSystem], [ForgeClipboard], [ForgeConfigManager],
///   [ForgeDiagnosticManager], [ForgeNotificationManager], and more
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

// Model
export 'src/model/forge_config.dart';

// Services (pure-Dart interfaces)
export 'src/services/forge_clipboard.dart';
export 'src/services/forge_config_manager.dart';
export 'src/services/forge_diagnostic_manager.dart';
export 'src/services/forge_disposable.dart';
export 'src/services/forge_environment.dart';
export 'src/services/forge_file_system.dart';
export 'src/services/forge_notification_manager.dart';
export 'src/services/forge_output_channel_manager.dart';
export 'src/services/forge_progress_manager.dart';
export 'src/services/forge_search_manager.dart';
export 'src/services/forge_secret_storage.dart';
export 'src/services/forge_terminal_manager.dart';
export 'src/services/forge_virtual_document_manager.dart';
