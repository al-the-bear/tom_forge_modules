import 'package:flutter/foundation.dart' show Listenable;
import 'package:tom_editors_shared/text_types.dart' show ForgeTextSettings;
import 'package:tom_file_system/tom_file_system.dart' show TomFileSystem;

import '../actions/forge_action.dart';
import '../services/forge_action_registry.dart';
import '../services/forge_clipboard.dart';
import '../services/forge_config_manager.dart';
import '../services/forge_diagnostic_manager.dart';
import '../services/forge_dialog_manager.dart';
import '../services/forge_file_decoration_manager.dart';
import '../services/forge_module_storage.dart';
import '../services/forge_notification_manager.dart';
import '../services/forge_outline_manager.dart';
import '../services/forge_output_channel_manager.dart';
import '../services/forge_progress_manager.dart';
import '../services/forge_search_manager.dart';
import '../services/forge_shortcut_manager.dart';
import '../services/forge_undo_manager.dart';
import '../services/forge_workspace_state_manager.dart';
import 'forge_context_menu_controller.dart';
import 'forge_editor_host.dart';
import 'forge_kit_state.dart';
import 'forge_state_store.dart';

/// The API a component sees: the state, the services and the editor host of
/// the application it runs in, with no layout in it.
///
/// Modules receive it in `ForgeKitModule.activate`. Where an editor appears
/// is the [editorHost]'s decision, which the application implements; the
/// panel shell's `ForgeShellApi` extends this API with its layout.
abstract class ForgeKitApi {
  /// Observable state: focus, editors, unsaved work, diagnostics.
  ForgeKitState get state;

  /// Shows, closes and brings forward editors, wherever the application
  /// places them.
  ForgeEditorHost get editorHost;

  /// The keyed documents the host persists.
  ForgeStateStore get stateStore;

  /// File system access.
  TomFileSystem get fileSystem;

  /// Output channel creation.
  ForgeOutputChannelManager get output;

  /// Diagnostic registration.
  ForgeDiagnosticManager get diagnostics;

  /// Configuration access.
  ForgeConfigManager get config;

  /// Notifications.
  ForgeNotificationManager get notifications;

  /// Progress reporting.
  ForgeProgressManager get progress;

  /// Programmatic dialogs (quick pick, input, file choosers).
  ForgeDialogManager get dialogs;

  /// Clipboard access.
  ForgeClipboard get clipboard;

  /// Per-module persistent storage.
  ForgeModuleStorage get storage;

  /// Undo/redo stack.
  ForgeUndoManager get undoManager;

  /// File decoration registration.
  ForgeFileDecorationManager get fileDecorations;

  /// Outline provider registration.
  ForgeOutlineManager get outline;

  /// Workspace-wide text search.
  ForgeSearchManager get search;

  /// Global action registry shared by the host and editor integrations.
  ForgeActionRegistry get actionRegistry;

  /// Global shortcut registry with runtime rebinding support.
  ForgeShortcutManager get shortcuts;

  /// Workspace-scoped state (the `.forge/` folder).
  ForgeWorkspaceStateManager get workspaceState;

  /// Module context-menu contributions, resolved at a target and drawn by
  /// the application.
  ForgeContextMenuController get contextMenus;

  /// Executes an action by id if available and enabled.
  bool executeAction(String actionId);

  /// Whether an action is currently enabled.
  bool isActionEnabled(String actionId);

  /// Resolves context menu actions for an editor.
  List<ForgeAction> getContextActionsFor(String editorId);

  /// Reads text settings for an editor type (for example: md, dart, yaml).
  ForgeTextSettings getTextSettings(String editorTypeId);

  /// Updates text settings for an editor type.
  void setTextSettings(String editorTypeId, ForgeTextSettings settings);

  /// Notifies after [setTextSettings] changed any editor type's settings.
  Listenable get textSettingsChanged;

  /// Reads editor-specific configuration for an editor type.
  Map<String, dynamic> getEditorSpecificConfig(String editorTypeId);

  /// Updates editor-specific configuration for an editor type.
  void setEditorSpecificConfig(
    String editorTypeId,
    Map<String, dynamic> config,
  );

  /// Reads preferred default editor ids by file extension (for example: .md).
  Map<String, String> getFileTypeDefaults();

  /// Sets the preferred default editor id for a file extension.
  void setFileTypeDefault(String extension, String editorTypeId);

  /// Clears a preferred default editor id for a file extension.
  void clearFileTypeDefault(String extension);

  /// Undoes the last change of the active editor; false when there is
  /// nothing to undo.
  bool undo();

  /// Redoes the last undone change of the active editor; false when there is
  /// nothing to redo.
  bool redo();

  /// Opens [uri]: asks every module first (`ForgeKitModule.openUri`), then
  /// the [editorHost]; answers whether something opened it.
  Future<bool> openFile(Uri uri);
}
