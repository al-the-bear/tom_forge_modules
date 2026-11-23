/// Core types, contracts, service interfaces, and default implementations
/// for the Tom Forge Panel Shell.
///
/// Provides platform-independent types used across forge packages:
///
/// - **Types**: [ForgeTextPosition], [ForgeTextRange], [ForgeSeverity],
///   [ForgeDiagnostic], [FileHandlingResult], [ForgeTextEditorOptions],
///   [ForgeValueListenable], [ForgeValueNotifier]
/// - **Document**: [ForgeDocument], [DocumentChangeEvent]
/// - **Decorations**: [ForgeDecorationType], [ForgeDecorationRange]
/// - **Events**: Focus, selection, diagnostic, layout, and file events
/// - **Workspace Edit**: [ForgeWorkspaceEdit], [ForgeTextEdit]
/// - **Context menus**: [ForgeContextTarget], [ForgeContextMenuItem],
///   [ForgeContextMenuContribution]
/// - **Model**: [ForgeConfig], [AutoSaveConfig]
/// - **Services**: [TomFileSystem], [ForgeClipboard], [ForgeConfigManager],
///   [ForgeDiagnosticManager], [ForgeNotificationManager],
///   [ForgeUndoManager], and more
/// - **Defaults**: [DefaultConfigManager], [DefaultDiagnosticManager],
///   [DefaultNotificationManager], [DefaultOutputChannelManager],
///   [DefaultProgressManager], [DefaultSearchManager],
///   [DefaultUndoManager], [TomMemoryFileSystem]
library;

import 'package:tom_file_system/tom_file_system.dart';

// Core types
export 'src/types/text_position.dart';
export 'src/types/text_range.dart';
export 'src/types/forge_severity.dart';
export 'src/types/forge_diagnostic.dart';
export 'src/types/file_handling_result.dart';
export 'src/types/forge_context_menu_entry.dart';
export 'src/types/forge_quick_pick_item.dart';
export 'src/types/status_bar_alignment.dart';
export 'src/types/text_editor_options.dart';
export 'src/types/decoration_types.dart';
export 'src/types/forge_enums.dart';
export 'src/types/forge_error_codes.dart';
export 'src/types/forge_events.dart';
export 'src/types/workspace_edit.dart';
export 'src/types/forge_listenable.dart';
export 'src/types/forge_context_menu.dart';

// Document
export 'src/document/forge_document.dart';

// Model
export 'src/model/forge_config.dart';
export 'src/model/forge_search_config.dart';

// Utils
export 'src/utils/gitignore_loader.dart';
export 'src/utils/workspace_edit_apply.dart';

// Services (pure-Dart interfaces)
export 'src/services/forge_clipboard.dart';
export 'src/services/forge_config_manager.dart';
export 'src/services/forge_diagnostic_manager.dart';
export 'src/services/forge_disposable.dart';
export 'src/services/forge_environment.dart';
export 'src/services/forge_execution_monitor.dart';
export 'src/services/forge_notification_manager.dart';
export 'src/services/forge_output_channel_manager.dart';
export 'src/services/forge_progress_manager.dart';
export 'src/services/forge_search_manager.dart';
export 'src/services/forge_secret_storage.dart';
export 'src/services/forge_terminal_manager.dart';
export 'src/services/forge_undo_manager.dart';
export 'src/services/forge_virtual_document_manager.dart';
export 'src/services/forge_performance_contract.dart';
export 'src/services/forge_quality_gate.dart';

// Default implementations (pure-Dart)
export 'src/defaults/default_config_manager.dart';
export 'src/defaults/forge_retry_policy.dart';
export 'src/defaults/default_diagnostic_manager.dart';
export 'src/defaults/default_execution_monitor.dart';
export 'src/defaults/default_notification_manager.dart';
export 'src/defaults/default_output_manager.dart';
export 'src/defaults/default_progress_manager.dart';
export 'src/defaults/default_search_manager.dart';
export 'src/defaults/default_undo_manager.dart';
export 'src/defaults/test_config_manager.dart';
export 'src/defaults/lru_cache.dart';
export 'src/defaults/generation_cache.dart';
export 'src/defaults/image_preview_cache.dart';
