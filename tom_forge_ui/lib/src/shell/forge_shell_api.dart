import '../services/forge_clipboard.dart';
import '../services/forge_config_manager.dart';
import '../services/forge_dialog_manager.dart';
import '../services/forge_diagnostic_manager.dart';
import '../services/forge_environment.dart';
import '../services/forge_file_decoration_manager.dart';
import '../services/forge_file_system.dart';
import '../services/forge_module_storage.dart';
import '../services/forge_notification_manager.dart';
import '../services/forge_outline_manager.dart';
import '../services/forge_output_channel_manager.dart';
import '../services/forge_progress_manager.dart';
import '../services/forge_search_manager.dart';
import '../services/forge_secret_storage.dart';
import '../services/forge_terminal_manager.dart';
import '../services/forge_undo_manager.dart';
import '../services/forge_virtual_document_manager.dart';
import 'forge_layout_controller.dart';
import 'forge_module_registry.dart';
import 'forge_status_bar_controller.dart';
import 'forge_system_state.dart';

/// The main API surface provided to modules by the forge shell.
///
/// Modules receive this via [ForgeModule.activate] and use it to
/// access system state, layout, services, and cross-module references.
abstract class ForgeShellApi {
  /// Observable system state.
  ForgeSystemState get systemState;

  /// Layout control.
  ForgeLayoutController get layout;

  /// Status bar control.
  ForgeStatusBarController get statusBar;

  /// File system access.
  ForgeFileSystem get fileSystem;

  /// Module cross-references.
  ForgeModuleRegistry get modules;

  /// Output channel creation.
  ForgeOutputChannelManager get output;

  /// Diagnostic registration.
  ForgeDiagnosticManager get diagnostics;

  /// Configuration access.
  ForgeConfigManager get config;

  /// Notification toasts and dialogs.
  ForgeNotificationManager get notifications;

  /// Progress indicators.
  ForgeProgressManager get progress;

  /// Programmatic dialogs.
  ForgeDialogManager get dialogs;

  /// Terminal management.
  ForgeTerminalManager get terminals;

  /// Clipboard access.
  ForgeClipboard get clipboard;

  /// Environment utilities.
  ForgeEnvironment get environment;

  /// Per-module persistent storage.
  ForgeModuleStorage get storage;

  /// Undo/redo stack.
  ForgeUndoManager get undoManager;

  /// Secure secret storage.
  ForgeSecretStorage get secrets;

  /// File decoration registration.
  ForgeFileDecorationManager get fileDecorations;

  /// Virtual document content providers.
  ForgeVirtualDocumentManager get virtualDocuments;

  /// Outline provider registration.
  ForgeOutlineManager get outline;

  /// Workspace-wide text search.
  ForgeSearchManager get search;
}
