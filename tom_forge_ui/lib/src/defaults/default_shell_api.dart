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
import '../shell/forge_layout_controller.dart';
import '../shell/forge_module_registry.dart';
import '../shell/forge_shell_api.dart';
import '../shell/forge_status_bar_controller.dart';
import '../shell/forge_system_state.dart';

/// Default implementation of [ForgeShellApi].
///
/// Aggregates all default service implementations and provides them
/// as a single API surface for module activation.
class DefaultShellApi implements ForgeShellApi {
  @override
  final ForgeSystemState systemState;

  @override
  final ForgeLayoutController layout;

  @override
  final ForgeStatusBarController statusBar;

  @override
  final ForgeFileSystem fileSystem;

  @override
  final ForgeModuleRegistry modules;

  @override
  final ForgeOutputChannelManager output;

  @override
  final ForgeDiagnosticManager diagnostics;

  @override
  final ForgeConfigManager config;

  @override
  final ForgeNotificationManager notifications;

  @override
  final ForgeProgressManager progress;

  @override
  final ForgeDialogManager dialogs;

  @override
  final ForgeTerminalManager terminals;

  @override
  final ForgeClipboard clipboard;

  @override
  final ForgeEnvironment environment;

  @override
  final ForgeModuleStorage storage;

  @override
  final ForgeUndoManager undoManager;

  @override
  final ForgeSecretStorage secrets;

  @override
  final ForgeFileDecorationManager fileDecorations;

  @override
  final ForgeVirtualDocumentManager virtualDocuments;

  @override
  final ForgeOutlineManager outline;

  @override
  final ForgeSearchManager search;

  DefaultShellApi({
    required this.systemState,
    required this.layout,
    required this.statusBar,
    required this.fileSystem,
    required this.modules,
    required this.output,
    required this.diagnostics,
    required this.config,
    required this.notifications,
    required this.progress,
    required this.dialogs,
    required this.terminals,
    required this.clipboard,
    required this.environment,
    required this.storage,
    required this.undoManager,
    required this.secrets,
    required this.fileDecorations,
    required this.virtualDocuments,
    required this.outline,
    required this.search,
  });
}
