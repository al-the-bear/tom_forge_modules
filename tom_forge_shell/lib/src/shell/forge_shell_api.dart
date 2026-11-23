import 'package:flutter/foundation.dart' show Listenable;
import 'package:tom_editors_shared/text_types.dart' show ForgeTextSettings;
import 'package:tom_file_system/tom_file_system.dart' show TomFileSystem;
import 'package:tom_forge_core/tom_forge_core.dart' show ForgeExecutionMonitor;
import 'package:tom_forge_kit/tom_forge_kit.dart';

import '../model/forge_application.dart';
import '../services/forge_environment.dart';
import '../services/forge_secret_storage.dart';
import '../services/forge_terminal_manager.dart';
import '../services/forge_virtual_document_manager.dart';
import 'forge_layout_controller.dart';
import 'forge_module_registry.dart';
import 'forge_status_bar_controller.dart';
import 'forge_system_state.dart';

/// The main API surface provided to modules by the forge shell.
///
/// Modules receive this via [ForgeModule.activate] and use it to
/// access system state, layout, services, and cross-module references.
/// It is the kit's [ForgeKitApi] with the panel layout: [state] is
/// [systemState], and the [editorHost] places editors as tabs of the
/// middle panels.
abstract class ForgeShellApi extends ForgeKitApi {
  /// Observable system state.
  ForgeSystemState get systemState;

  /// The kit's view of the state: [systemState].
  @override
  ForgeSystemState get state;

  /// The open applications, the active one, and the operations that add,
  /// rename, remove and switch them at run time.
  ForgeApplicationRegistry get applications;

  /// Layout control.
  ForgeLayoutController get layout;

  /// Go Back / Go Forward across editors and the places within them.
  ForgeNavigationHistory get navigationHistory;

  /// Status bar control.
  ForgeStatusBarController get statusBar;

  /// File system access.
  @override
  TomFileSystem get fileSystem;

  /// Module cross-references.
  ForgeModuleRegistry get modules;

  /// Output channel creation.
  @override
  ForgeOutputChannelManager get output;

  /// Diagnostic registration.
  @override
  ForgeDiagnosticManager get diagnostics;

  /// Configuration access.
  @override
  ForgeConfigManager get config;

  /// Notification toasts and dialogs.
  @override
  ForgeNotificationManager get notifications;

  /// Progress indicators.
  @override
  ForgeProgressManager get progress;

  /// Programmatic dialogs.
  @override
  ForgeDialogManager get dialogs;

  /// Terminal management.
  ForgeTerminalManager get terminals;

  /// Clipboard access.
  @override
  ForgeClipboard get clipboard;

  /// Environment utilities.
  ForgeEnvironment get environment;

  /// Execution monitoring for running processes, builds, and tasks.
  ForgeExecutionMonitor get executions;

  /// Per-module persistent storage.
  @override
  ForgeModuleStorage get storage;

  /// Undo/redo stack.
  @override
  ForgeUndoManager get undoManager;

  /// Secure secret storage.
  ForgeSecretStorage get secrets;

  /// File decoration registration.
  @override
  ForgeFileDecorationManager get fileDecorations;

  /// Virtual document content providers.
  ForgeVirtualDocumentManager get virtualDocuments;

  /// Outline provider registration.
  @override
  ForgeOutlineManager get outline;

  /// Workspace-wide text search.
  @override
  ForgeSearchManager get search;

  /// Global action registry shared by shell and editor integrations.
  @override
  ForgeActionRegistry get actionRegistry;

  /// Global shortcut registry with runtime rebinding support.
  @override
  ForgeShortcutManager get shortcuts;

  /// Workspace-scoped state manager for `.forge/` directory.
  @override
  ForgeWorkspaceStateManager get workspaceState;

  /// Module context-menu contributions, resolved at a target and drawn by the
  /// shell. A view or editor that knows what is under the pointer calls
  /// `contextMenus.show(target, position)`.
  @override
  ForgeContextMenuController get contextMenus;

  /// Execute an action by id if available and enabled.
  @override
  bool executeAction(String actionId);

  /// Check if an action is currently enabled.
  @override
  bool isActionEnabled(String actionId);

  /// Resolve context menu actions for an editor.
  @override
  List<ForgeAction> getContextActionsFor(String editorId);

  /// Reads text settings for an editor type (for example: md, dart, yaml).
  @override
  ForgeTextSettings getTextSettings(String editorTypeId);

  /// Updates text settings for an editor type.
  @override
  void setTextSettings(String editorTypeId, ForgeTextSettings settings);

  /// Notifies after [setTextSettings] changed any editor type's settings, so
  /// an open editor can follow them (its history depth,
  /// [ForgeTextSettings.maxUndoHistory]).
  @override
  Listenable get textSettingsChanged;

  /// Reads editor-specific configuration for an editor type.
  @override
  Map<String, dynamic> getEditorSpecificConfig(String editorTypeId);

  /// Updates editor-specific configuration for an editor type.
  @override
  void setEditorSpecificConfig(
    String editorTypeId,
    Map<String, dynamic> config,
  );

  /// Reads preferred default editor ids by file extension (for example: .md).
  @override
  Map<String, String> getFileTypeDefaults();

  /// Sets the preferred default editor id for a file extension.
  @override
  void setFileTypeDefault(String extension, String editorTypeId);

  /// Clears a preferred default editor id for a file extension.
  @override
  void clearFileTypeDefault(String extension);
}
