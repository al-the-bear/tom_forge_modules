import '../services/forge_clipboard.dart';
import '../services/forge_action_registry.dart';
import '../services/forge_config_manager.dart';
import '../services/forge_dialog_manager.dart';
import '../services/forge_diagnostic_manager.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show ForgeExecutionMonitor;
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
import '../services/forge_shortcut_manager.dart';
import '../services/forge_terminal_manager.dart';
import '../services/forge_undo_manager.dart';
import '../services/forge_virtual_document_manager.dart';
import '../services/forge_workspace_state_manager.dart';
import '../actions/forge_action.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show ForgeTextSettings;
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

  /// Execution monitoring for running processes, builds, and tasks.
  ForgeExecutionMonitor get executions;

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

  /// Global action registry shared by shell and editor integrations.
  ForgeActionRegistry get actionRegistry;

  /// Global shortcut registry with runtime rebinding support.
  ForgeShortcutManager get shortcuts;

  /// Workspace-scoped state manager for `.forge/` directory.
  ForgeWorkspaceStateManager get workspaceState;

  /// Execute an action by id if available and enabled.
  bool executeAction(String actionId);

  /// Check if an action is currently enabled.
  bool isActionEnabled(String actionId);

  /// Resolve context menu actions for an editor.
  List<ForgeAction> getContextActionsFor(String editorId);

  /// Reads text settings for an editor type (for example: md, dart, yaml).
  ForgeTextSettings getTextSettings(String editorTypeId);

  /// Updates text settings for an editor type.
  void setTextSettings(String editorTypeId, ForgeTextSettings settings);

  /// Reads editor-specific configuration for an editor type.
  Map<String, dynamic> getEditorSpecificConfig(String editorTypeId);

  /// Updates editor-specific configuration for an editor type.
  void setEditorSpecificConfig(
      String editorTypeId, Map<String, dynamic> config);

  /// Reads preferred default editor ids by file extension (for example: .md).
  Map<String, String> getFileTypeDefaults();

  /// Sets the preferred default editor id for a file extension.
  void setFileTypeDefault(String extension, String editorTypeId);
}
