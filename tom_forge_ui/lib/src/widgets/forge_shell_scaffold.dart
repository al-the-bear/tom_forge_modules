import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import '../adapters/forge_dart_editor.dart';
import '../adapters/forge_md_editor.dart';
import '../adapters/forge_plain_text_editor.dart';
import '../adapters/forge_yaml_editor.dart';
import '../components/forge_editor.dart';
import '../components/forge_text_editor.dart';
import '../defaults/default_layout_controller.dart';
import '../defaults/default_dialog_manager.dart';
import '../defaults/default_shell_api.dart';
import '../services/forge_accessibility.dart';
import '../defaults/default_system_state.dart';
import '../defaults/default_workspace_state_manager.dart';
import '../model/forge_application.dart';
import '../services/forge_preferences_service.dart';
import '../services/forge_dialog_manager.dart';
import '../shell/forge_layout_controller.dart';
import '../shell/forge_status_bar_controller.dart';
import '../actions/forge_action.dart' as shell_action;
import '../actions/forge_shortcut_binding.dart';
import '../services/forge_shortcut_manager.dart';
import 'forge_chord_overlay.dart';
import 'forge_command_palette.dart';
import 'forge_configuration_dialog.dart';
import 'forge_drag_data.dart';
import 'forge_drop_zone_overlay.dart';
import 'forge_error_recovery_dialog.dart';
import 'forge_input_box_overlay.dart';
import 'forge_quick_pick_overlay.dart';
import 'forge_editor_tab_bar.dart';
import 'forge_menu_bar.dart';
import 'forge_notification_overlay.dart';
import 'forge_open_with_dialog.dart';
import 'forge_panel_widget.dart';
import 'forge_shortcut_menu_popup.dart';
import 'forge_status_bar_widget.dart';

/// Animation constants for shell UI.
class ForgeAnimations {
  /// When true, all durations return [Duration.zero] and curves use
  /// [Curves.linear]. Enabled automatically in high-contrast mode.
  static bool reduceMotion = false;

  static Duration get panelTransition =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 200);
  static Duration get tabTransition =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 150);
  static Duration get dropZoneFade =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 100);
  static Duration get shortcutPopupIn =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 150);
  static Duration get shortcutPopupOut =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 100);
  static Duration get notificationIn =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 200);
  static Duration get notificationOut =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 150);

  static Curve get panelCurve =>
      reduceMotion ? Curves.linear : Curves.easeOutCubic;
  static Curve get tabCurve => reduceMotion ? Curves.linear : Curves.easeOut;
  static Curve get popupCurve =>
      reduceMotion ? Curves.linear : Curves.easeOutBack;
}

/// Dimension constants for shell layout.
class ForgeDimensions {
  // Panels
  static const double leftPanelMinWidth = 180;
  static const double leftPanelMaxWidth = 600;
  static const double leftPanelDefaultWidth = 280;
  static const double rightPanelMinWidth = 180;
  static const double rightPanelMaxWidth = 600;
  static const double rightPanelDefaultWidth = 280;
  static const double bottomPanelMinHeight = 100;
  static const double bottomPanelMaxHeight = 500;
  static const double bottomPanelDefaultHeight = 200;
  static const double middlePanelMinWidth = 200;

  // Fixed elements
  static const double titleBarHeight = 48;
  static const double menuBarHeight = 32;
  static const double statusBarHeight = 24;
  static const double tabBarHeight = 36;
  static const double sectionHeaderHeight = 32;
  static const double sideTabBarCollapsed = 48;
  static const double sideTabBarExpanded = 200;

  // Interactive
  static const double dividerHitTarget = 14;
  static const double dividerVisual = 2;

  // Icons
  static const double iconTab = 20;
  static const double iconToolbar = 18;
}

/// Root shell layout widget.
///
/// Layout structure per concept doc §2:
/// ```
/// Column:
///   TitleBar
///   MenuBar (optional)
///   Expanded(
///     Row:
///       LeftPanel (with vertical icon strip)
///       Column:
///         MiddleEditorPanels
///         BottomPanel (between left/right)
///       RightPanel (with vertical icon strip)
///   )
///   StatusBar
/// ```
class ForgeShellScaffold extends StatefulWidget {
  final DefaultShellApi shell;
  final ForgeApplication application;
  final DefaultLayoutController layoutController;
  final DefaultSystemState systemState;
  final ForgeStatusBarController statusBarController;
  final DefaultNotificationManager notificationManager;
  final ForgePreferencesService? preferencesService;

  /// Callback invoked when the user requests to switch to a different application.
  /// The parent widget should handle rebuilding the scaffold with the new application.
  final void Function(ForgeApplication)? onApplicationSwitch;

  const ForgeShellScaffold({
    super.key,
    required this.shell,
    required this.application,
    required this.layoutController,
    required this.systemState,
    required this.statusBarController,
    required this.notificationManager,
    this.preferencesService,
    this.onApplicationSwitch,
  });

  @override
  State<ForgeShellScaffold> createState() => _ForgeShellScaffoldState();
}

class _ForgeShellScaffoldState extends State<ForgeShellScaffold> {
  static bool debugEnabled = false;
  static const Duration _layoutPersistDebounce = Duration(milliseconds: 500);

  static const String _actionFileSaveAll = 'file.saveAll';
  static const String _actionEditorFind = 'editor.find';
  static const String _actionEditReplace = 'edit.replace';
  static const String _actionEditFormatDocument = 'edit.formatDocument';
  static const String _actionForgeCut = 'forge.edit.cut';
  static const String _actionForgeCopy = 'forge.edit.copy';
  static const String _actionForgePaste = 'forge.edit.paste';

  static const ForgeDecorationType _findMatchesDecoration = ForgeDecorationType(
    key: 'shell.find.matches',
    backgroundColorValue: 0x3069A8FF,
  );

  static const ForgeDecorationType _findCurrentMatchDecoration =
      ForgeDecorationType(
        key: 'shell.find.current',
        backgroundColorValue: 0x66F2C94C,
        underlineStyle: ForgeUnderlineStyle.solid,
        underlineColorValue: 0xFFF2C94C,
      );

  DefaultLayoutController get _layout => widget.layoutController;
  bool _showCommandPalette = false;
  bool _showFindReplaceBar = false;
  bool _showReplaceFields = false;
  Widget? _dialogOverlay;
  late final ForgePreferencesService _preferences;
  final TextEditingController _findQueryController = TextEditingController();
  final TextEditingController _replaceValueController = TextEditingController();
  final FocusNode _findFieldFocusNode = FocusNode();
  final FocusNode _replaceFieldFocusNode = FocusNode();
  List<ForgeTextRange> _findMatches = const [];
  int _activeFindMatchIndex = -1;
  ForgeTextEditor? _decoratedFindEditor;
  StreamSubscription<Uri>? _saveSubscription;
  StreamSubscription<EditorListChangeEvent>? _editorChangeSubscription;
  StreamSubscription<DirtyStateEvent>? _dirtyStateSubscription;
  StreamSubscription<WindowFocusEvent>? _windowFocusSubscription;
  StreamSubscription<ConfigChangeEvent>? _configChangeSubscription;
  StreamSubscription<ForgeChordEvent>? _chordSubscription;
  StreamSubscription<ForgeShortcutMenuEvent>? _menuSubscription;
  StreamSubscription<ForgeTerminal>? _terminalOpenSubscription;
  StreamSubscription<ForgeTerminal>? _terminalCloseSubscription;
  StreamSubscription<ForgeTerminal?>? _terminalActiveSubscription;
  Timer? _autoSaveTimer;
  Timer? _layoutPersistTimer;

  /// Flex factors for middle editor panels (1.0 per panel by default).
  /// Adjusted during drag-resize of middle panel dividers.
  List<double> _middlePanelFlex = [];

  @override
  void initState() {
    super.initState();
    _preferences =
        widget.preferencesService ?? ForgePreferencesService.instance;
    _preferences.addListener(_onPreferencesChanged);
    _findQueryController.addListener(_onFindQueryChanged);
    widget.systemState.activeEditorListenable.addListener(
      _onActiveEditorChanged,
    );
    _registerFindReplaceActions();
    _initializePreferences();
    _wireDialogCallbacks();
    _wireTerminalCallbacks();
    _listenForSaveRevisions();
    _listenForEditorChanges();
    _listenForAutoSave();
    _listenForConfigChanges();
    _listenForLayoutChanges();
    _listenForChordCompletions();
    _listenForMenuSelections();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _saveSubscription?.cancel();
    _editorChangeSubscription?.cancel();
    _dirtyStateSubscription?.cancel();
    _windowFocusSubscription?.cancel();
    _configChangeSubscription?.cancel();
    _chordSubscription?.cancel();
    _menuSubscription?.cancel();
    _terminalOpenSubscription?.cancel();
    _terminalCloseSubscription?.cancel();
    _terminalActiveSubscription?.cancel();
    _layoutPersistTimer?.cancel();
    _detachLayoutListeners();
    widget.systemState.activeEditorListenable.removeListener(
      _onActiveEditorChanged,
    );
    _findQueryController.removeListener(_onFindQueryChanged);
    _clearFindDecorations();
    _findQueryController.dispose();
    _replaceValueController.dispose();
    _findFieldFocusNode.dispose();
    _replaceFieldFocusNode.dispose();
    _preferences.removeListener(_onPreferencesChanged);
    _saveAllEditorStates();
    _saveLayoutState();
    _saveWorkspaceState();
    widget.shell.dispose();
    super.dispose();
  }

  Future<void> _initializePreferences() async {
    try {
      if (!_preferences.isLoaded) {
        await _preferences.load();
      }
      _applyPreferenceTextSettings();
      _applyPreferenceFileTypeDefaults();
      _applyPreferenceShortcutOverrides();
      await _restoreLayoutState();
      await _restoreWorkspaceState();
    } catch (error, stackTrace) {
      debugPrint('[ForgeShellScaffold] initialize preferences failed: $error');
      debugPrint('$stackTrace');
    }
  }

  /// Wires [DefaultDialogManager] callbacks to actual widget-layer UI.
  void _wireDialogCallbacks() {
    final dialogs = widget.shell.dialogs;
    if (dialogs is! DefaultDialogManager) return;

    dialogs.onQuickPick =
        <T>(
          List<ForgeQuickPickItem<T>> items, {
          String? placeholder,
          bool canSelectMany = false,
        }) {
          final completer = Completer<T?>();
          setState(() {
            _dialogOverlay = ForgeQuickPickOverlay<T>(
              items: items,
              placeholder: placeholder,
              canSelectMany: canSelectMany,
              completer: completer,
            );
          });
          completer.future.whenComplete(() {
            if (mounted) setState(() => _dialogOverlay = null);
          });
          return completer.future;
        };

    dialogs.onInputBox =
        ({
          String? prompt,
          String? value,
          String? placeholder,
          String? Function(String)? validateInput,
        }) {
          final completer = Completer<String?>();
          setState(() {
            _dialogOverlay = ForgeInputBoxOverlay(
              prompt: prompt,
              value: value,
              placeholder: placeholder,
              validateInput: validateInput,
              completer: completer,
            );
          });
          completer.future.whenComplete(() {
            if (mounted) setState(() => _dialogOverlay = null);
          });
          return completer.future;
        };

    dialogs.onOpenDialog =
        ({
          String? title,
          bool canSelectMany = false,
          bool canSelectFolders = false,
          List<FileFilter>? filters,
        }) async {
          final result = await FilePicker.platform.pickFiles(
            dialogTitle: title ?? 'Open File',
            allowMultiple: canSelectMany,
            type: filters != null && filters.isNotEmpty
                ? FileType.custom
                : FileType.any,
            allowedExtensions: filters?.expand((f) => f.extensions).toList(),
          );
          if (result == null || result.files.isEmpty) return null;
          return result.files
              .where((f) => f.path != null)
              .map((f) => Uri.file(f.path!))
              .toList();
        };

    dialogs.onSaveDialog =
        ({String? title, Uri? defaultUri, List<FileFilter>? filters}) async {
          final result = await FilePicker.platform.saveFile(
            dialogTitle: title ?? 'Save File',
            fileName: defaultUri?.pathSegments.isNotEmpty == true
                ? defaultUri!.pathSegments.last
                : null,
            type: filters != null && filters.isNotEmpty
                ? FileType.custom
                : FileType.any,
            allowedExtensions: filters?.expand((f) => f.extensions).toList(),
          );
          if (result == null) return null;
          return Uri.file(result);
        };
  }

  /// Wires terminal lifecycle events to scaffold-level behavior:
  /// auto-opens the bottom panel on terminal creation and updates
  /// status when the active terminal changes.
  void _wireTerminalCallbacks() {
    final terminals = widget.shell.terminals;

    _terminalOpenSubscription = terminals.onDidOpen.listen((terminal) {
      // Auto-show bottom panel when a terminal is created.
      _layout.openPanel(ForgePanelLocation.bottom);
    });

    _terminalCloseSubscription = terminals.onDidClose.listen((terminal) {
      // Notify user when a terminal is closed.
      widget.shell.notifications.showInformation(
        'Terminal "${terminal.name}" closed',
      );
    });

    _terminalActiveSubscription = terminals.onDidChangeActive.listen((
      terminal,
    ) {
      // Refresh state to update status bar or other reactive UI.
      if (mounted) setState(() {});
    });
  }

  void _onPreferencesChanged() {
    try {
      _applyPreferenceTextSettings();
      _applyPreferenceFileTypeDefaults();
      _applyPreferenceShortcutOverrides();
      _propagateSettingsToActiveEditors();
      // High-contrast mode (ThemeMode.system) activates reduced motion.
      ForgeAnimations.reduceMotion = _preferences.themeMode == ThemeMode.system;
      if (mounted) {
        setState(() {});
      }
    } catch (error, stackTrace) {
      debugPrint('[ForgeShellScaffold] apply preferences failed: $error');
      debugPrint('$stackTrace');
    }
  }

  /// Pushes current text settings from the shell to any open text editors,
  /// converting [ForgeTextSettings] to [ForgeTextEditorOptions].
  void _propagateSettingsToActiveEditors() {
    for (final editor in widget.systemState.openEditors) {
      if (editor is ForgeTextEditor) {
        final typeId = _editorTypeId(editor);
        if (typeId != null) {
          final settings = widget.shell.getTextSettings(typeId);
          editor.updateOptions(
            ForgeTextEditorOptions(
              tabSize: settings.tabSize,
              insertSpaces: settings.insertSpaces,
              wordWrap: settings.wordWrap
                  ? ForgeWordWrap.on
                  : ForgeWordWrap.off,
              fontFamily: settings.fontFamily,
              fontSize: settings.fontSize,
              lineHeight: settings.lineHeight,
              showLineNumbers: settings.showLineNumbers,
              highlightCurrentLine: settings.highlightCurrentLine,
            ),
          );
        }
      }
    }
  }

  String? _editorTypeId(ForgeEditor editor) {
    if (editor is ForgeMdEditor) return 'md';
    if (editor is ForgeDartEditor) return 'dart';
    if (editor is ForgeYamlEditor) return 'yaml';
    if (editor is ForgePlainTextEditor) return 'plaintext';
    return null;
  }

  void _applyPreferenceTextSettings() {
    final settings = _preferences.editorTextSettings;
    for (final entry in settings.entries) {
      widget.shell.setTextSettings(entry.key, entry.value);
    }
    if (debugEnabled) {
      debugPrint(
        '[ForgeShellScaffold] applied persisted settings: ${settings.length}',
      );
    }
  }

  void _applyPreferenceFileTypeDefaults() {
    final defaults = _preferences.fileTypeDefaultEditors;
    for (final entry in defaults.entries) {
      widget.shell.setFileTypeDefault(entry.key, entry.value);
    }
  }

  void _applyPreferenceShortcutOverrides() {
    final overrides = _preferences.shortcutOverrides;
    for (final entry in overrides.entries) {
      final binding = widget.shell.shortcuts.getBinding(entry.key);
      if (binding != null) {
        widget.shell.shortcuts.rebind(binding.action, entry.value);
      }
    }
  }

  /// Restores panel sizes, visibility, and previously-open editors.
  ///
  /// Tries SharedPreferences first, then falls back to `.forge/state/`
  /// files for workspace-scoped recovery.
  Future<void> _restoreLayoutState() async {
    final savedSnapshot = _preferences.layoutSnapshot;
    if (savedSnapshot.isNotEmpty) {
      _applyLayoutSnapshot(savedSnapshot);
      return;
    }

    var sizes = _preferences.layoutPanelSizes;
    var visibility = _preferences.layoutPanelVisibility;
    var editorUris = _preferences.layoutOpenEditors;

    // Fall back to .forge/state/ if preferences are empty.
    final wsState = widget.shell.workspaceState;
    if (sizes.isEmpty && visibility.isEmpty && wsState.isInitialized) {
      try {
        final layoutData = await wsState.loadLayoutState();
        if (layoutData != null) {
          if (_isLayoutSnapshot(layoutData)) {
            _applyLayoutSnapshot(layoutData);
            return;
          }

          for (final entry in layoutData.entries) {
            if (entry.value is Map<String, dynamic>) {
              final panel = entry.value as Map<String, dynamic>;
              final size = panel['size'];
              final isVisible = panel['isVisible'];
              if (size is num) sizes[entry.key] = size.toDouble();
              if (isVisible is bool) visibility[entry.key] = isVisible;
            }
          }
        }
      } catch (e) {
        if (debugEnabled) {
          debugPrint('[ForgeShellScaffold] load .forge/ layout failed: $e');
        }
      }
    }

    if (editorUris.isEmpty && wsState.isInitialized) {
      try {
        editorUris = await wsState.loadOpenEditors();
      } catch (e) {
        if (debugEnabled) {
          debugPrint('[ForgeShellScaffold] load .forge/ editors failed: $e');
        }
      }
    }

    for (final entry in sizes.entries) {
      final location = _panelLocationFromName(entry.key);
      if (location != null) {
        _layout.setPanelSize(location, entry.value);
      }
    }
    for (final entry in visibility.entries) {
      final location = _panelLocationFromName(entry.key);
      if (location != null) {
        if (entry.value) {
          _layout.openPanel(location);
        } else {
          _layout.closePanel(location);
        }
      }
    }

    for (final uriStr in editorUris) {
      try {
        _layout.openFile(Uri.parse(uriStr));
      } catch (e) {
        if (debugEnabled) {
          debugPrint(
            '[ForgeShellScaffold] restore editor failed for $uriStr: $e',
          );
        }
      }
    }

    if (debugEnabled) {
      debugPrint(
        '[ForgeShellScaffold] restored layout: '
        '${sizes.length} sizes, ${visibility.length} visibility, '
        '${editorUris.length} editors',
      );
    }
  }

  /// Restores workspace state from `.forge/state/` files on startup.
  ///
  /// Loads per-application state (layout, open editors, active editor)
  /// when the workspace state manager is initialized.
  Future<void> _restoreWorkspaceState() async {
    final wsState = widget.shell.workspaceState;
    if (!wsState.isInitialized) return;

    // Restore config from .forge/config.json. On parse failure, notify
    // the user and continue with default configuration (CF001).
    try {
      final configData = await wsState.loadConfig();
      if (configData != null) {
        final configManager = widget.shell.config;
        if (configManager is DefaultConfigManager) {
          configManager.loadFromJson(configData);
        }
      }
    } catch (e) {
      if (debugEnabled) {
        debugPrint('[ForgeShellScaffold] restore config failed: $e');
      }
      widget.shell.notifications.showWarning(
        'Configuration could not be loaded — using defaults. ($e)',
      );
    }

    if (wsState is! DefaultWorkspaceStateManager) return;

    try {
      final appState = await wsState.loadApplicationState(
        widget.application.title,
      );
      if (appState == null) return;

      // Restore per-app layout if we didn't already restore from preferences.
      final layout = appState['layout'];
      if (layout is Map<String, dynamic> &&
          _preferences.layoutSnapshot.isEmpty &&
          _preferences.layoutPanelSizes.isEmpty) {
        if (_isLayoutSnapshot(layout)) {
          _applyLayoutSnapshot(layout);
        } else {
          for (final entry in layout.entries) {
            if (entry.value is Map<String, dynamic>) {
              final panel = entry.value as Map<String, dynamic>;
              final size = panel['size'];
              final isVisible = panel['isVisible'];
              final location = _panelLocationFromName(entry.key);
              if (location != null) {
                if (size is num) {
                  _layout.setPanelSize(location, size.toDouble());
                }
                if (isVisible is bool) {
                  if (isVisible) {
                    _layout.openPanel(location);
                  } else {
                    _layout.closePanel(location);
                  }
                }
              }
            }
          }
        }
      }

      // Restore active editor if we have one saved.
      final activeEditorStr = appState['activeEditor'];
      if (activeEditorStr is String && activeEditorStr.isNotEmpty) {
        try {
          final activeUri = Uri.parse(activeEditorStr);
          // If the editor is already open, just activate it.
          final existing = widget.systemState.openEditors
              .where((e) => e.uri == activeUri)
              .firstOrNull;
          if (existing != null) {
            widget.systemState.setActiveEditor(existing);
          }
        } catch (_) {}
      }

      if (debugEnabled) {
        debugPrint(
          '[ForgeShellScaffold] restored workspace state for '
          '"${widget.application.title}"',
        );
      }
    } catch (e) {
      if (debugEnabled) {
        debugPrint('[ForgeShellScaffold] restore workspace state failed: $e');
      }
    }
  }

  /// Persists current panel sizes, visibility, and open editor URIs.
  void _saveLayoutState() {
    try {
      _preferences.setLayoutSnapshot(_captureLayoutSnapshot());

      for (final location in ForgePanelLocation.values) {
        if (location == ForgePanelLocation.middle) continue;
        final config = _layout.getPanelConfig(location);
        if (config != null) {
          final name = location.name;
          _preferences.setLayoutPanelSize(name, config.size);
          _preferences.setLayoutPanelVisibility(name, config.isVisible);
        }
      }

      final openUris = widget.systemState.openEditors
          .map((e) => e.uri.toString())
          .toList();
      _preferences.setLayoutOpenEditors(openUris);

      unawaited(_preferences.save());

      if (debugEnabled) {
        debugPrint('[ForgeShellScaffold] saved layout state');
      }
    } catch (error, stackTrace) {
      debugPrint('[ForgeShellScaffold] save layout state failed: $error');
      debugPrint('$stackTrace');
    }
  }

  ForgePanelLocation? _panelLocationFromName(String name) {
    for (final loc in ForgePanelLocation.values) {
      if (loc.name == name) return loc;
    }
    return null;
  }

  /// Listens for file save events and creates revision snapshots.
  void _listenForSaveRevisions() {
    final wsState = widget.shell.workspaceState;
    if (!wsState.isInitialized) return;
    _saveSubscription = widget.shell.fileSystem.onDidSave.listen((uri) async {
      try {
        final content = await widget.shell.fileSystem.read(uri);
        await wsState.createRevision(uri, content);
        await wsState.pruneRevisions(uri);
      } catch (e) {
        if (debugEnabled) {
          debugPrint('[ForgeShellScaffold] revision on save failed: $e');
        }
      }

      _scheduleLayoutPersistence();
    });
  }

  /// Listens for editor open/close events to save/restore per-editor state.
  void _listenForEditorChanges() {
    final wsState = widget.shell.workspaceState;
    if (!wsState.isInitialized) return;
    _editorChangeSubscription = widget.systemState.onEditorsChanged.listen((
      event,
    ) async {
      // Save state for editors being closed.
      for (final closed in event.closed) {
        if (closed is ForgeEditor) {
          try {
            final state = closed.saveState();
            if (state != null) {
              await wsState.saveEditorState(closed.uri, state);
            }
          } catch (e) {
            if (debugEnabled) {
              debugPrint('[ForgeShellScaffold] save editor state failed: $e');
            }
          }
        }
      }
      // Restore state for editors being opened.
      for (final opened in event.opened) {
        if (opened is ForgeEditor) {
          try {
            final state = await wsState.loadEditorState(opened.uri);
            if (state != null) {
              opened.restoreState(state);
            }
            // Restore undo history metadata.
            final undoEntries = await wsState.loadUndoHistory(opened.uri);
            if (undoEntries.isNotEmpty) {
              opened.restoreUndoHistoryMetadata(undoEntries);
            }
          } catch (e) {
            if (debugEnabled) {
              debugPrint(
                '[ForgeShellScaffold] restore editor state failed: $e',
              );
            }
          }
        }
      }

      _scheduleLayoutPersistence();
    });
  }

  /// Sets up auto-save based on configuration.
  ///
  /// Auto-save triggers:
  /// - After idle delay when editor becomes dirty
  /// - On window focus loss (if enabled in config)
  void _listenForAutoSave() {
    final config = widget.shell.config.current;
    if (!config.autoSave.enabled) return;

    // Listen for dirty state changes to trigger auto-save timer.
    _dirtyStateSubscription = widget.systemState.onDirtyStateChanged.listen((
      event,
    ) {
      if (event.isDirty) {
        _scheduleAutoSave(config.autoSave.idleDelay);
      }
    });

    // Listen for window focus loss to trigger auto-save.
    if (config.autoSave.saveOnFocusLoss) {
      _windowFocusSubscription = widget.systemState.onWindowFocusChanged.listen(
        (event) {
          if (!event.focused && widget.systemState.hasUnsavedChanges) {
            _performAutoSave(SaveReason.focusLoss);
          }
        },
      );
    }
  }

  /// Schedules auto-save after the given delay.
  void _scheduleAutoSave(Duration delay) {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(delay, () => _performAutoSave(SaveReason.autoSave));
  }

  /// Performs auto-save on all dirty editors.
  Future<void> _performAutoSave(SaveReason reason) async {
    final dirtyEditors = widget.systemState.dirtyEditors.toList();
    for (final editor in dirtyEditors) {
      try {
        final content = editor.getContent();
        if (content != null) {
          await widget.shell.fileSystem.write(editor.uri, content);
        }
        await widget.shell.fileSystem.save(editor.uri);
        editor.markClean();
        if (debugEnabled) {
          debugPrint(
            '[ForgeShellScaffold] auto-saved: ${editor.uri} (reason: $reason)',
          );
        }
      } catch (e) {
        if (debugEnabled) {
          debugPrint(
            '[ForgeShellScaffold] auto-save failed for ${editor.uri}: $e',
          );
        }
      }
    }
  }

  /// Listens for config changes and persists to `.forge/config.json`.
  void _listenForConfigChanges() {
    final wsState = widget.shell.workspaceState;
    if (!wsState.isInitialized) return;
    final configManager = widget.shell.config;
    _configChangeSubscription = configManager.onDidChange.listen((_) async {
      try {
        if (configManager is DefaultConfigManager) {
          await wsState.saveConfig(configManager.toJson());
        }
      } catch (e) {
        if (debugEnabled) {
          debugPrint('[ForgeShellScaffold] save config failed: $e');
        }
      }
    });
  }

  /// Saves all open editor states to `.forge/state/editors/` on shutdown.
  void _saveAllEditorStates() {
    final wsState = widget.shell.workspaceState;
    if (!wsState.isInitialized) return;
    for (final editor in widget.systemState.openEditors) {
      try {
        final state = editor.saveState();
        if (state != null) {
          wsState.saveEditorState(editor.uri, state);
        }
        // Persist undo history metadata for this editor.
        final undoEntries = editor.getUndoHistoryMetadata();
        if (undoEntries != null && undoEntries.isNotEmpty) {
          wsState.saveUndoHistory(editor.uri, undoEntries);
        }
      } catch (e) {
        if (debugEnabled) {
          debugPrint('[ForgeShellScaffold] save editor state failed: $e');
        }
      }
    }
  }

  /// Saves workspace state (layout + open editors) to `.forge/` on shutdown.
  void _saveWorkspaceState() {
    final wsState = widget.shell.workspaceState;
    if (!wsState.isInitialized) return;
    try {
      // Save open editor URIs to .forge/state/open-editors.json
      final openUris = widget.systemState.openEditors
          .map((e) => e.uri.toString())
          .toList();
      wsState.saveOpenEditors(openUris);

      // Save full layout snapshot to .forge/state/layout.json
      final layoutData = _captureLayoutSnapshot();
      wsState.saveLayoutState(layoutData);

      // Save per-application state to .forge/state/apps/
      if (wsState is DefaultWorkspaceStateManager) {
        final activeUri = widget.systemState.activeEditor?.uri;
        final appState = <String, dynamic>{
          'openEditors': openUris,
          'activeEditor': activeUri?.toString(),
          'layout': layoutData,
        };
        wsState.saveApplicationState(widget.application.title, appState);
        wsState.saveActiveApplicationTitle(widget.application.title);
      }
    } catch (e) {
      debugPrint('[ForgeShellScaffold] save workspace state failed: $e');
    }
  }

  Future<void> _openSettings() async {
    await ForgeConfigurationDialog.show(context, _preferences, widget.shell);
    _onPreferencesChanged();
  }

  ForgeTextEditor? get _activeTextEditor {
    final active = widget.systemState.activeEditor;
    return active is ForgeTextEditor ? active : null;
  }

  void _registerFindReplaceActions() {
    widget.shell.actionRegistry.registerAction(
      shell_action.ForgeAction(
        id: _actionEditorFind,
        label: 'Find',
        menu: shell_action.ForgeMenuLocation.edit,
        execute: (_) async {
          _openFindReplaceBar(showReplaceFields: false);
          return null;
        },
        isEnabled: () => _activeTextEditor != null,
        isVisible: () => true,
      ),
    );

    widget.shell.actionRegistry.registerAction(
      shell_action.ForgeAction(
        id: _actionEditReplace,
        label: 'Replace',
        menu: shell_action.ForgeMenuLocation.edit,
        execute: (_) async {
          _openFindReplaceBar(showReplaceFields: true);
          return null;
        },
        isEnabled: () => _activeTextEditor != null,
        isVisible: () => true,
      ),
    );
  }

  void _onActiveEditorChanged() {
    if (!_showFindReplaceBar) {
      _clearFindDecorations();
      return;
    }

    final editor = _activeTextEditor;
    if (editor == null) {
      _clearFindDecorations();
      if (mounted) {
        setState(() {
          _findMatches = const [];
          _activeFindMatchIndex = -1;
        });
      }
      return;
    }

    _recomputeFindMatches(editor, moveToFirst: true);
  }

  void _onFindQueryChanged() {
    if (!_showFindReplaceBar) return;
    final editor = _activeTextEditor;
    if (editor == null) return;
    _recomputeFindMatches(editor, moveToFirst: true);
  }

  void _openFindReplaceBar({required bool showReplaceFields}) {
    final editor = _activeTextEditor;
    if (editor == null) {
      widget.shell.notifications.showWarning(
        'Find/Replace is available for text editors only.',
      );
      return;
    }

    if (_findQueryController.text.isEmpty && editor.hasSelection) {
      final selected = editor.selectedText.trim();
      if (selected.isNotEmpty) {
        _findQueryController.text = selected;
      }
    }

    setState(() {
      _showFindReplaceBar = true;
      _showReplaceFields = _showReplaceFields || showReplaceFields;
    });

    _recomputeFindMatches(editor, moveToFirst: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (showReplaceFields) {
        _replaceFieldFocusNode.requestFocus();
      } else {
        _findFieldFocusNode.requestFocus();
      }
    });
  }

  void _closeFindReplaceBar() {
    _clearFindDecorations();
    if (!mounted) return;
    setState(() {
      _showFindReplaceBar = false;
      _showReplaceFields = false;
      _findMatches = const [];
      _activeFindMatchIndex = -1;
    });
  }

  void _clearFindDecorations([ForgeTextEditor? editor]) {
    final target = editor ?? _decoratedFindEditor;
    if (target == null) return;
    try {
      target.clearDecorations(_findMatchesDecoration);
      target.clearDecorations(_findCurrentMatchDecoration);
    } catch (_) {
      // Ignore teardown races when editors are disposed while closing UI.
    }
    if (target == _decoratedFindEditor) {
      _decoratedFindEditor = null;
    }
  }

  Pattern _buildFindPattern(String query) {
    return RegExp(RegExp.escape(query), caseSensitive: false);
  }

  void _recomputeFindMatches(
    ForgeTextEditor editor, {
    required bool moveToFirst,
  }) {
    final query = _findQueryController.text;

    if (_decoratedFindEditor != null && _decoratedFindEditor != editor) {
      _clearFindDecorations(_decoratedFindEditor);
    }

    if (query.isEmpty) {
      _clearFindDecorations(editor);
      if (!mounted) return;
      setState(() {
        _findMatches = const [];
        _activeFindMatchIndex = -1;
      });
      return;
    }

    final matches = editor.findAll(_buildFindPattern(query));
    var nextIndex = _activeFindMatchIndex;
    if (matches.isEmpty) {
      nextIndex = -1;
    } else if (moveToFirst || nextIndex < 0 || nextIndex >= matches.length) {
      nextIndex = 0;
    }

    if (!mounted) return;
    setState(() {
      _findMatches = matches;
      _activeFindMatchIndex = nextIndex;
    });

    editor.setDecorations(
      _findMatchesDecoration,
      matches.map((range) => ForgeDecorationRange(range: range)).toList(),
    );

    if (nextIndex >= 0 && nextIndex < matches.length) {
      final activeRange = matches[nextIndex];
      editor.setDecorations(_findCurrentMatchDecoration, [
        ForgeDecorationRange(range: activeRange),
      ]);
      editor.setSelection(activeRange);
      editor.revealRange(activeRange);
    } else {
      editor.clearDecorations(_findCurrentMatchDecoration);
    }

    _decoratedFindEditor = editor;
  }

  void _selectFindMatch({required bool next}) {
    final editor = _activeTextEditor;
    if (editor == null || _findMatches.isEmpty) return;

    final lastIndex = _findMatches.length - 1;
    final targetIndex = next
        ? (_activeFindMatchIndex >= lastIndex ? 0 : _activeFindMatchIndex + 1)
        : (_activeFindMatchIndex <= 0 ? lastIndex : _activeFindMatchIndex - 1);

    setState(() {
      _activeFindMatchIndex = targetIndex;
    });

    final activeRange = _findMatches[targetIndex];
    editor.setDecorations(_findCurrentMatchDecoration, [
      ForgeDecorationRange(range: activeRange),
    ]);
    editor.setSelection(activeRange);
    editor.revealRange(activeRange);
  }

  void _replaceCurrentMatch() {
    final editor = _activeTextEditor;
    if (editor == null ||
        _findMatches.isEmpty ||
        _activeFindMatchIndex < 0 ||
        _activeFindMatchIndex >= _findMatches.length) {
      return;
    }

    final replacement = _replaceValueController.text;
    final range = _findMatches[_activeFindMatchIndex];
    editor.replaceRange(range, replacement);
    _recomputeFindMatches(editor, moveToFirst: false);
  }

  void _replaceAllMatches() {
    final editor = _activeTextEditor;
    final query = _findQueryController.text;
    if (editor == null || query.isEmpty) return;

    final replacement = _replaceValueController.text;
    final replacedCount = editor.replaceAll(
      _buildFindPattern(query),
      replacement,
    );
    _recomputeFindMatches(editor, moveToFirst: true);
    widget.shell.notifications.showInformation(
      'Replaced $replacedCount match${replacedCount == 1 ? '' : 'es'}.',
    );
  }

  bool _executeActionWithFallback(List<String> actionIds) {
    for (final id in actionIds) {
      if (widget.shell.executeAction(id)) {
        return true;
      }
    }
    return false;
  }

  List<PopupMenuEntry<String>> _buildEditorContextMenuItems(
    ForgeEditor editor,
  ) {
    final activeTextEditor = editor is ForgeTextEditor ? editor : null;
    final contextActions = widget.shell
        .getContextActionsFor(editor.uri.toString())
        .where(
          (action) =>
              action.id != _actionEditorFind &&
              action.id != _actionEditReplace &&
              action.id != _actionEditFormatDocument,
        )
        .toList(growable: false);

    final entries = <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        value: 'cmd.cut',
        enabled: activeTextEditor != null,
        child: const Text('Cut'),
      ),
      PopupMenuItem<String>(
        value: 'cmd.copy',
        enabled: activeTextEditor != null,
        child: const Text('Copy'),
      ),
      PopupMenuItem<String>(
        value: 'cmd.paste',
        enabled: activeTextEditor != null,
        child: const Text('Paste'),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'cmd.find',
        enabled: activeTextEditor != null,
        child: const Text('Find'),
      ),
      PopupMenuItem<String>(
        value: 'cmd.replace',
        enabled: activeTextEditor != null,
        child: const Text('Replace'),
      ),
      PopupMenuItem<String>(
        value: 'cmd.format',
        enabled: widget.shell.isActionEnabled(_actionEditFormatDocument),
        child: const Text('Format Document'),
      ),
    ];

    if (contextActions.isNotEmpty) {
      entries.add(const PopupMenuDivider());
      for (final action in contextActions) {
        entries.add(
          PopupMenuItem<String>(
            value: 'action.${action.id}',
            enabled: action.isEnabled(),
            child: Text(action.label),
          ),
        );
      }
    }

    return entries;
  }

  Future<void> _showEditorContextMenu(
    Offset globalPosition,
    ForgeEditor editor,
  ) async {
    widget.systemState.setActiveEditor(editor);

    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: _buildEditorContextMenuItems(editor),
    );

    if (!mounted || selected == null) return;

    switch (selected) {
      case 'cmd.cut':
        _executeActionWithFallback([_actionForgeCut, 'edit.cut']);
        break;
      case 'cmd.copy':
        _executeActionWithFallback([_actionForgeCopy, 'edit.copy']);
        break;
      case 'cmd.paste':
        _executeActionWithFallback([_actionForgePaste, 'edit.paste']);
        break;
      case 'cmd.find':
        _openFindReplaceBar(showReplaceFields: false);
        break;
      case 'cmd.replace':
        _openFindReplaceBar(showReplaceFields: true);
        break;
      case 'cmd.format':
        _executeActionWithFallback([_actionEditFormatDocument]);
        break;
      default:
        if (selected.startsWith('action.')) {
          final actionId = selected.substring('action.'.length);
          widget.shell.executeAction(actionId);
        }
        break;
    }
  }

  /// Listens for chord completions to execute the bound action.
  void _listenForChordCompletions() {
    _chordSubscription = widget.shell.shortcuts.onChordStateChanged.listen((
      event,
    ) {
      if (event.state == ForgeChordState.completed &&
          event.executedBinding != null) {
        widget.shell.executeAction(event.executedBinding!.action.id);
      }
    });
  }

  /// Listens for shortcut menu selections to execute the chosen action.
  void _listenForMenuSelections() {
    _menuSubscription = widget.shell.shortcuts.onMenuStateChanged.listen((
      event,
    ) {
      if (event.state == ForgeShortcutMenuState.selected &&
          event.selectedEntry != null) {
        widget.shell.executeAction(event.selectedEntry!.action.id);
      }
    });
  }

  /// Converts a [KeyEvent] to a [ForgeShortcutKey] for chord matching.
  ForgeShortcutKey? _keyEventToShortcutKey(KeyEvent event) {
    if (event is! KeyDownEvent) return null;
    final key = event.logicalKey;
    // Ignore bare modifier presses.
    if (key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight) {
      return null;
    }
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final useMeta = !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
    final hasPrimary = useMeta
        ? pressed.contains(LogicalKeyboardKey.metaLeft) ||
              pressed.contains(LogicalKeyboardKey.metaRight)
        : pressed.contains(LogicalKeyboardKey.controlLeft) ||
              pressed.contains(LogicalKeyboardKey.controlRight);
    final hasShift =
        pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);
    final hasAlt =
        pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight);
    return ForgeShortcutKey(
      key: key,
      primaryModifier: hasPrimary,
      shift: hasShift,
      alt: hasAlt,
    );
  }

  /// Key event handler that intercepts chord shortcut sequences and
  /// shortcut menu triggers.
  ///
  /// Returns [KeyEventResult.handled] when a chord is in progress or
  /// completed, or when a shortcut menu is opened or a follow-up key
  /// is matched, preventing the normal [Shortcuts] widget from processing
  /// the event.
  KeyEventResult _handleChordKeyEvent(FocusNode node, KeyEvent event) {
    // Cancel chord or close menu on Escape.
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      if (widget.shell.shortcuts.activeMenu != null) {
        widget.shell.shortcuts.closeMenu();
        return KeyEventResult.handled;
      }
      if (widget.shell.shortcuts.isChordPending) {
        widget.shell.shortcuts.cancelChord();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final shortcutKey = _keyEventToShortcutKey(event);
    if (shortcutKey == null) return KeyEventResult.ignored;

    // If a shortcut menu is open, route follow-up keys to it.
    if (widget.shell.shortcuts.activeMenu != null) {
      // The user may still hold Shift+Cmd/Ctrl — strip modifiers and
      // match on the bare key.
      widget.shell.shortcuts.handleMenuKey(shortcutKey.key);
      return KeyEventResult.handled;
    }

    // Detect Shift+PrimaryModifier+<key> to open a shortcut menu.
    if (shortcutKey.shift && shortcutKey.primaryModifier && !shortcutKey.alt) {
      if (widget.shell.shortcuts.openMenu(shortcutKey.key)) {
        return KeyEventResult.handled;
      }
    }

    final result = widget.shell.shortcuts.handleKeyForChord(shortcutKey);
    if (result != null) {
      // Chord completed — event consumed (action executed via listener).
      return KeyEventResult.handled;
    }
    if (widget.shell.shortcuts.isChordPending) {
      // First key of chord matched — consume event to prevent normal dispatch.
      return KeyEventResult.handled;
    }

    final directBinding = widget.shell.shortcuts.allBindings
        .where((binding) => !binding.isChord)
        .where((binding) => binding.key == shortcutKey)
        .firstOrNull;
    if (directBinding != null) {
      widget.shell.executeAction(directBinding.action.id);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Whether to use the native platform menu bar (macOS desktop).
  bool get _usePlatformMenu =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    Widget body = Focus(
      onKeyEvent: _handleChordKeyEvent,
      child: Shortcuts(
        shortcuts: _buildShortcuts(),
        child: Actions(
          actions: _buildActions(),
          child: Focus(
            autofocus: true,
            child: Material(
              child: Stack(
                children: [
                  Column(
                    children: [
                      _buildTitleBar(context),
                      // On macOS desktop, the menu is in the native menu bar.
                      if (!_usePlatformMenu)
                        ForgeMenuBar(
                          shellApi: widget.shell,
                          onCommandPalette: _toggleCommandPalette,
                          onSettings: _openSettings,
                          currentThemeMode: _preferences.themeMode,
                          onThemeModeChanged: (mode) {
                            _preferences.themeMode = mode;
                          },
                        ),
                      Expanded(child: _buildMainArea(context)),
                      ForgeStatusBarWidget(
                        controller: widget.statusBarController,
                        systemState: widget.systemState,
                        progressManager: widget.shell.progress,
                      ),
                    ],
                  ),
                  ForgeNotificationOverlay(manager: widget.notificationManager),
                  // Chord shortcut overlay (shows available second keys).
                  ForgeChordOverlay(shortcutManager: widget.shell.shortcuts),
                  // Shortcut menu overlay (concept §11.4).
                  ForgeShortcutMenuPopup(
                    shortcutManager: widget.shell.shortcuts,
                  ),
                  // Open With dialog when multiple editors can handle a file.
                  ValueListenableBuilder<(Uri, List<ForgeEditor>)?>(
                    valueListenable: _layout.pendingEditorChoice,
                    builder: (context, choice, _) {
                      if (choice == null) return const SizedBox.shrink();
                      final (uri, editors) = choice;
                      return FocusScope(
                        autofocus: true,
                        child: ForgeOpenWithDialog(
                          uri: uri,
                          editors: editors,
                          onEditorSelected: (editor) {
                            _layout.resolveEditorChoice(editor, uri);
                          },
                          onCancel: () {
                            _layout.pendingEditorChoice.value = null;
                          },
                        ),
                      );
                    },
                  ),
                  if (_showCommandPalette)
                    ForgeCommandPalette(
                      shellApi: widget.shell,
                      onDismiss: _toggleCommandPalette,
                    ),
                  if (_dialogOverlay != null) ...[_dialogOverlay!],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Wrap with native platform menu bar on macOS desktop.
    if (_usePlatformMenu) {
      body = PlatformMenuBar(menus: _buildPlatformMenus(), child: body);
    }

    return body;
  }

  /// Build native platform menu items for macOS.
  ///
  /// Only concept §11.3 standard shortcuts are shown as accelerators.
  /// Menu items for non-concept actions remain for discoverability but
  /// without keyboard accelerators — those actions are accessible via
  /// the command palette or custom shortcut menus (concept §11.4).
  List<PlatformMenuItem> _buildPlatformMenus() {
    return [
      PlatformMenu(
        label: 'File',
        menus: [
          PlatformMenuItem(
            label: 'New File',
            onSelected: () => widget.shell.executeAction('file.new'),
          ),
          PlatformMenuItem(
            label: 'Open Folder...',
            onSelected: () => widget.shell.executeAction('file.openFolder'),
          ),
          const PlatformMenuItemGroup(members: []),
          // Concept §11.3: Cmd+S = "Save all dirty editors".
          PlatformMenuItem(
            label: 'Save All',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyS,
              meta: true,
            ),
            onSelected: () => widget.shell.executeAction('file.saveAll'),
          ),
          const PlatformMenuItemGroup(members: []),
          PlatformMenuItem(
            label: 'Close Editor',
            onSelected: () => widget.shell.executeAction('file.close'),
          ),
          const PlatformMenuItemGroup(members: []),
          PlatformMenuItem(label: 'Settings...', onSelected: _openSettings),
        ],
      ),
      PlatformMenu(
        label: 'Edit',
        menus: [
          // Concept §11.3: Cmd+U = Undo.
          PlatformMenuItem(
            label: 'Undo',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyU,
              meta: true,
            ),
            onSelected: () => widget.shell.executeAction('edit.undo'),
          ),
          // Concept §11.3: Cmd+Z = Redo.
          PlatformMenuItem(
            label: 'Redo',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyZ,
              meta: true,
            ),
            onSelected: () => widget.shell.executeAction('edit.redo'),
          ),
          const PlatformMenuItemGroup(members: []),
          PlatformMenuItem(
            label: 'Cut',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyX,
              meta: true,
            ),
            onSelected: () => widget.shell.executeAction('edit.cut'),
          ),
          PlatformMenuItem(
            label: 'Copy',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyC,
              meta: true,
            ),
            onSelected: () => widget.shell.executeAction('edit.copy'),
          ),
          PlatformMenuItem(
            label: 'Paste',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyV,
              meta: true,
            ),
            onSelected: () => widget.shell.executeAction('edit.paste'),
          ),
          const PlatformMenuItemGroup(members: []),
          // Concept §11.3: Cmd+F = Find in focused component.
          PlatformMenuItem(
            label: 'Find',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyF,
              meta: true,
            ),
            onSelected: () => widget.shell.executeAction('editor.find'),
          ),
          PlatformMenuItem(
            label: 'Replace',
            onSelected: () => widget.shell.executeAction('edit.replace'),
          ),
        ],
      ),
      PlatformMenu(
        label: 'View',
        menus: [
          PlatformMenuItem(
            label: 'Command Palette...',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyP,
              meta: true,
            ),
            onSelected: _toggleCommandPalette,
          ),
          const PlatformMenuItemGroup(members: []),
          PlatformMenuItem(
            label: 'Toggle Left Panel',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyL,
              meta: true,
            ),
            onSelected: () =>
                widget.shell.layout.togglePanel(ForgePanelLocation.left),
          ),
          PlatformMenuItem(
            label: 'Toggle Right Panel',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyR,
              meta: true,
            ),
            onSelected: () =>
                widget.shell.layout.togglePanel(ForgePanelLocation.right),
          ),
        ],
      ),
      PlatformMenu(
        label: 'Go',
        menus: [
          PlatformMenuItem(label: 'Back', onSelected: () {}),
          PlatformMenuItem(label: 'Forward', onSelected: () {}),
          const PlatformMenuItemGroup(members: []),
          PlatformMenuItem(
            label: 'Go to File...',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyP,
              meta: true,
            ),
            onSelected: _toggleCommandPalette,
          ),
        ],
      ),
      PlatformMenu(label: 'Tools', menus: _buildToolsPlatformMenuItems()),
      PlatformMenu(
        label: 'Help',
        menus: [PlatformMenuItem(label: 'About Tom Forge', onSelected: () {})],
      ),
    ];
  }

  Map<String, List<shell_action.ForgeAction>> _toolActionsByModule() {
    final result = <String, List<shell_action.ForgeAction>>{};

    for (final module in widget.shell.modules.allModules) {
      final actions =
          module.actions
              .where(
                (action) => action.menu == shell_action.ForgeMenuLocation.tools,
              )
              .where((action) => action.isVisible())
              .toList(growable: false)
            ..sort((a, b) {
              final priority = a.priority.compareTo(b.priority);
              if (priority != 0) return priority;
              return a.label.compareTo(b.label);
            });
      if (actions.isNotEmpty) {
        result[module.displayName] = actions;
      }
    }

    return result;
  }

  List<PlatformMenuItem> _buildToolsPlatformMenuItems() {
    final grouped = _toolActionsByModule();
    if (grouped.isEmpty) {
      return [PlatformMenuItem(label: 'No Tools Available', onSelected: () {})];
    }

    final hasMultipleModules = grouped.length > 1;
    final items = <PlatformMenuItem>[];
    for (final entry in grouped.entries) {
      final moduleItems = entry.value
          .map(
            (action) => PlatformMenuItem(
              label: action.label,
              onSelected: () => widget.shell.executeAction(action.id),
            ),
          )
          .toList(growable: false);

      if (hasMultipleModules) {
        items.add(PlatformMenu(label: entry.key, menus: moduleItems));
      } else {
        items.addAll(moduleItems);
      }
    }

    return items;
  }

  Map<ShortcutActivator, Intent> _buildShortcuts() {
    try {
      final useMetaPrimary = defaultTargetPlatform == TargetPlatform.macOS;

      SingleActivator primaryActivator(
        LogicalKeyboardKey key, {
        bool shift = false,
      }) {
        return SingleActivator(
          key,
          meta: useMetaPrimary,
          control: !useMetaPrimary,
          shift: shift,
        );
      }

      final shortcuts = {
        primaryActivator(LogicalKeyboardKey.keyP):
            const _CommandPaletteIntent(),
        const SingleActivator(LogicalKeyboardKey.f1):
            const _CommandPaletteIntent(),
        primaryActivator(LogicalKeyboardKey.keyL):
            const _ToggleLeftPanelIntent(),
        primaryActivator(LogicalKeyboardKey.keyR):
            const _ToggleRightPanelIntent(),
        primaryActivator(LogicalKeyboardKey.digit1):
            const _FocusLeftPanelIntent(),
        primaryActivator(LogicalKeyboardKey.digit2): const _FocusCenterIntent(),
        primaryActivator(LogicalKeyboardKey.digit3):
            const _FocusRightPanelIntent(),
        primaryActivator(LogicalKeyboardKey.digit4):
            const _FocusBottomPanelIntent(),
        primaryActivator(LogicalKeyboardKey.bracketRight):
            const _FocusNextPanelIntent(),
        primaryActivator(LogicalKeyboardKey.bracketLeft):
            const _FocusPreviousPanelIntent(),
        primaryActivator(LogicalKeyboardKey.keyS): const _SaveIntent(),
      };

      if (debugEnabled) {
        debugPrint('[ForgeShellScaffold] shortcut count: ${shortcuts.length}');
      }

      return shortcuts;
    } catch (error, stackTrace) {
      debugPrint('[ForgeShellScaffold] build shortcuts failed: $error');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  Map<Type, Action<Intent>> _buildActions() {
    return {
      _CommandPaletteIntent: CallbackAction<_CommandPaletteIntent>(
        onInvoke: (_) {
          _toggleCommandPalette();
          return null;
        },
      ),
      _ToggleLeftPanelIntent: CallbackAction<_ToggleLeftPanelIntent>(
        onInvoke: (_) {
          widget.shell.layout.togglePanel(ForgePanelLocation.left);
          return null;
        },
      ),
      _ToggleRightPanelIntent: CallbackAction<_ToggleRightPanelIntent>(
        onInvoke: (_) {
          widget.shell.layout.togglePanel(ForgePanelLocation.right);
          return null;
        },
      ),
      _FocusLeftPanelIntent: CallbackAction<_FocusLeftPanelIntent>(
        onInvoke: (_) {
          widget.systemState.setFocusedPanelLocation(ForgePanelLocation.left);
          ForgeAccessibility.announcePolite('Left panel focused');
          return null;
        },
      ),
      _FocusCenterIntent: CallbackAction<_FocusCenterIntent>(
        onInvoke: (_) {
          widget.systemState.setFocusedPanelLocation(ForgePanelLocation.middle);
          ForgeAccessibility.announcePolite('Editor panel focused');
          return null;
        },
      ),
      _FocusRightPanelIntent: CallbackAction<_FocusRightPanelIntent>(
        onInvoke: (_) {
          widget.systemState.setFocusedPanelLocation(ForgePanelLocation.right);
          ForgeAccessibility.announcePolite('Right panel focused');
          return null;
        },
      ),
      _FocusBottomPanelIntent: CallbackAction<_FocusBottomPanelIntent>(
        onInvoke: (_) {
          widget.systemState.setFocusedPanelLocation(ForgePanelLocation.bottom);
          ForgeAccessibility.announcePolite('Bottom panel focused');
          return null;
        },
      ),
      _FocusNextPanelIntent: CallbackAction<_FocusNextPanelIntent>(
        onInvoke: (_) {
          widget.systemState.focusNextPanel();
          ForgeAccessibility.announcePolite('Next panel focused');
          return null;
        },
      ),
      _FocusPreviousPanelIntent: CallbackAction<_FocusPreviousPanelIntent>(
        onInvoke: (_) {
          widget.systemState.focusPreviousPanel();
          ForgeAccessibility.announcePolite('Previous panel focused');
          return null;
        },
      ),
      _SaveIntent: CallbackAction<_SaveIntent>(
        onInvoke: (_) {
          _executeSave();
          return null;
        },
      ),
    };
  }

  void _toggleCommandPalette() {
    setState(() => _showCommandPalette = !_showCommandPalette);
    if (_showCommandPalette) {
      ForgeAccessibility.announceAssertive('Command palette opened');
    }
  }

  void _executeSave() {
    try {
      // Concept §11.3: Cmd+S = "Save all dirty editors".
      widget.shell.executeAction(_actionFileSaveAll);
    } catch (error, stackTrace) {
      debugPrint('[ForgeShellScaffold] execute save failed: $error');
      debugPrint('$stackTrace');
      widget.shell.notifications.showError('Save failed: $error');
    }
  }

  Widget _buildTitleBar(BuildContext context) {
    const navClusterWidth = 112.0;
    final theme = Theme.of(context);
    return Container(
      height: ForgeDimensions.titleBarHeight,
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Back/Forward navigation (per concept §2.1)
          SizedBox(
            width: navClusterWidth,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    size: ForgeDimensions.iconToolbar,
                  ),
                  onPressed:
                      null, // Disabled until component history is implemented
                  tooltip: 'Back',
                ),
                IconButton(
                  icon: Icon(
                    Icons.arrow_forward,
                    size: ForgeDimensions.iconToolbar,
                  ),
                  onPressed: null,
                  tooltip: 'Forward',
                ),
              ],
            ),
          ),
          // Center cluster: search field + application switcher.
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth;
                  final switcherMaxWidth = availableWidth < 520 ? 120.0 : 180.0;
                  final searchWidth = (availableWidth - switcherMaxWidth - 20)
                      .clamp(220.0, 400.0)
                      .toDouble();

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        width: searchWidth,
                        height: 32,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Icon(
                                Icons.search,
                                size: 16,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                widget.application.title,
                                style: theme.textTheme.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      PopupMenuButton<ForgeApplication>(
                        tooltip: 'Switch Application',
                        onSelected: (app) {
                          if (app != widget.application) {
                            widget.systemState.setActiveApplication(app);
                            widget.onApplicationSwitch?.call(app);
                          }
                        },
                        itemBuilder: (context) {
                          final apps = widget.systemState.applications;
                          return apps.map((app) {
                            final isActive = app == widget.application;
                            return PopupMenuItem<ForgeApplication>(
                              value: app,
                              child: Row(
                                children: [
                                  if (app.icon != null)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Icon(app.icon, size: 16),
                                    ),
                                  Expanded(child: Text(app.title)),
                                  if (isActive)
                                    Icon(
                                      Icons.check,
                                      size: 16,
                                      color: theme.colorScheme.primary,
                                    ),
                                ],
                              ),
                            );
                          }).toList();
                        },
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: switcherMaxWidth,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.application.icon != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(
                                    widget.application.icon,
                                    size: 14,
                                  ),
                                ),
                              Flexible(
                                child: Text(
                                  widget.application.title,
                                  style: theme.textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          // Keep center cluster visually centered by mirroring nav width.
          const SizedBox(width: navClusterWidth),
        ],
      ),
    );
  }

  Widget _buildMainArea(BuildContext context) {
    return ValueListenableBuilder<LayoutPanelConfig>(
      valueListenable: _layout.leftPanel,
      builder: (context, leftConfig, _) {
        return ValueListenableBuilder<LayoutPanelConfig>(
          valueListenable: _layout.rightPanel,
          builder: (context, rightConfig, _) {
            return Row(
              children: [
                // Left Panel with vertical icon strip on LEFT edge
                if (leftConfig.isVisible)
                  _buildSidePanel(
                    context,
                    width: leftConfig.size,
                    tabs: widget.application.layout.leftPanel.tabs,
                    iconStripPosition: IconStripPosition.left,
                    panelArea: PanelArea.left,
                    showConfigTab: true,
                    onConfigTap: _openSettings,
                    configurationPanelBuilder: _buildConfigurationPanel,
                  ),
                if (leftConfig.isVisible)
                  _buildVerticalResizeHandle(
                    onDragDelta: _resizeLeftPanel,
                    onDoubleTap: () => _layout.setPanelSize(
                      ForgePanelLocation.left,
                      ForgeDimensions.leftPanelDefaultWidth,
                    ),
                  ),

                // Middle area: editor panels + bottom panel
                Expanded(child: _buildCenterColumn(context)),

                // Right Panel with vertical icon strip on RIGHT edge
                if (rightConfig.isVisible)
                  _buildVerticalResizeHandle(
                    onDragDelta: _resizeRightPanel,
                    onDoubleTap: () => _layout.setPanelSize(
                      ForgePanelLocation.right,
                      ForgeDimensions.rightPanelDefaultWidth,
                    ),
                  ),
                if (rightConfig.isVisible)
                  _buildSidePanel(
                    context,
                    width: rightConfig.size,
                    tabs: widget.application.layout.rightPanel.tabs,
                    iconStripPosition: IconStripPosition.right,
                    panelArea: PanelArea.right,
                    showConfigTab: false,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// Builds the center column containing middle panels and bottom panel.
  /// Bottom panel is positioned between left/right panels per concept §2.5.
  Widget _buildCenterColumn(BuildContext context) {
    return ValueListenableBuilder<LayoutPanelConfig>(
      valueListenable: _layout.bottomPanel,
      builder: (context, bottomConfig, _) {
        return Column(
          children: [
            // Middle editor panels
            Expanded(child: _buildMiddleArea(context)),
            // Bottom panel (between left/right, below middle)
            if (bottomConfig.isVisible)
              _buildHorizontalResizeHandle(
                onDragDelta: _resizeBottomPanel,
                onDoubleTap: () => _layout.setPanelSize(
                  ForgePanelLocation.bottom,
                  ForgeDimensions.bottomPanelDefaultHeight,
                ),
              ),
            if (bottomConfig.isVisible)
              _buildBottomPanel(context, bottomConfig),
          ],
        );
      },
    );
  }

  void _resizeLeftPanel(double deltaX) {
    final current = _layout.leftPanel.value;
    final nextSize = (current.size + deltaX).clamp(
      ForgeDimensions.leftPanelMinWidth,
      ForgeDimensions.leftPanelMaxWidth,
    );
    _layout.setPanelSize(ForgePanelLocation.left, nextSize);
  }

  void _resizeRightPanel(double deltaX) {
    final current = _layout.rightPanel.value;
    final nextSize = (current.size - deltaX).clamp(
      ForgeDimensions.rightPanelMinWidth,
      ForgeDimensions.rightPanelMaxWidth,
    );
    _layout.setPanelSize(ForgePanelLocation.right, nextSize);
  }

  void _resizeBottomPanel(double deltaY) {
    final current = _layout.bottomPanel.value;
    final nextSize = (current.size - deltaY).clamp(
      ForgeDimensions.bottomPanelMinHeight,
      ForgeDimensions.bottomPanelMaxHeight,
    );
    _layout.setPanelSize(ForgePanelLocation.bottom, nextSize);
  }

  /// Resize middle panels by adjusting flex factors of adjacent panels.
  void _resizeMiddlePanelDivider(int leftIdx, int rightIdx, double delta) {
    if (leftIdx < 0 || rightIdx >= _middlePanelFlex.length) return;
    const minFlex = 0.15;
    final totalFlex = _middlePanelFlex[leftIdx] + _middlePanelFlex[rightIdx];
    // Convert pixel delta to flex delta (rough: assume equal share baseline).
    final flexDelta = delta / 300.0;
    var newLeft = (_middlePanelFlex[leftIdx] + flexDelta).clamp(
      minFlex,
      totalFlex - minFlex,
    );
    var newRight = totalFlex - newLeft;
    setState(() {
      _middlePanelFlex[leftIdx] = newLeft;
      _middlePanelFlex[rightIdx] = newRight;
    });
    _scheduleLayoutPersistence();
  }

  /// Reset all middle panel flex factors to equal distribution.
  void _resetMiddlePanelFlex() {
    setState(() {
      _middlePanelFlex = List.filled(_middlePanelFlex.length, 1.0);
    });
    _scheduleLayoutPersistence();
  }

  void _listenForLayoutChanges() {
    _layout.leftPanel.addListener(_onLayoutChanged);
    _layout.rightPanel.addListener(_onLayoutChanged);
    _layout.bottomPanel.addListener(_onLayoutChanged);
    _layout.middlePanels.addListener(_onLayoutChanged);
    _layout.activeMiddlePanelIndexNotifier.addListener(_onLayoutChanged);
  }

  void _detachLayoutListeners() {
    _layout.leftPanel.removeListener(_onLayoutChanged);
    _layout.rightPanel.removeListener(_onLayoutChanged);
    _layout.bottomPanel.removeListener(_onLayoutChanged);
    _layout.middlePanels.removeListener(_onLayoutChanged);
    _layout.activeMiddlePanelIndexNotifier.removeListener(_onLayoutChanged);
  }

  void _onLayoutChanged() {
    _scheduleLayoutPersistence();
  }

  void _scheduleLayoutPersistence() {
    _layoutPersistTimer?.cancel();
    _layoutPersistTimer = Timer(_layoutPersistDebounce, () {
      _saveLayoutState();
      _saveWorkspaceState();
    });
  }

  bool _isLayoutSnapshot(Map<String, dynamic> data) {
    return data.containsKey('panels') && data.containsKey('middlePanels');
  }

  void _applyLayoutSnapshot(Map<String, dynamic> snapshot) {
    _layout.loadLayoutSnapshot(snapshot);

    final middleFlex = snapshot['middlePanelFlex'];
    if (middleFlex is List) {
      final parsed = middleFlex
          .whereType<num>()
          .map((value) => value.toDouble())
          .where((value) => value > 0)
          .toList(growable: false);
      if (parsed.isNotEmpty) {
        _middlePanelFlex = parsed;
      }
    }

    if (debugEnabled) {
      debugPrint('[ForgeShellScaffold] restored layout snapshot');
    }
  }

  Map<String, dynamic> _captureLayoutSnapshot() {
    final snapshot = _layout.toLayoutSnapshot();
    snapshot['middlePanelFlex'] = List<double>.from(_middlePanelFlex);
    return snapshot;
  }

  Widget _buildVerticalResizeHandle({
    required ValueChanged<double> onDragDelta,
    VoidCallback? onDoubleTap,
  }) {
    return _ResizeHandle(
      axis: Axis.horizontal,
      onDragDelta: onDragDelta,
      onDoubleTap: onDoubleTap,
    );
  }

  Widget _buildHorizontalResizeHandle({
    required ValueChanged<double> onDragDelta,
    VoidCallback? onDoubleTap,
  }) {
    return _ResizeHandle(
      axis: Axis.vertical,
      onDragDelta: onDragDelta,
      onDoubleTap: onDoubleTap,
    );
  }

  Widget _buildSidePanel(
    BuildContext context, {
    required double width,
    required List<PanelTabConfig> tabs,
    required IconStripPosition iconStripPosition,
    required PanelArea panelArea,
    bool showConfigTab = false,
    VoidCallback? onConfigTap,
    WidgetBuilder? configurationPanelBuilder,
  }) {
    if (tabs.isEmpty && !showConfigTab) {
      return SizedBox(width: width);
    }
    return SizedBox(
      width: width,
      child: ForgeSidePanelWidget(
        tabs: tabs,
        iconStripPosition: iconStripPosition,
        showConfigTab: showConfigTab,
        onConfigTap: onConfigTap,
        configurationPanelBuilder: configurationPanelBuilder,
        panelArea: panelArea,
        onTabDropped: (data) => _handlePanelTabDrop(data, panelArea),
      ),
    );
  }

  Widget _buildConfigurationPanel(BuildContext context) {
    final theme = Theme.of(context);

    Widget buildPanelToggle({
      required String label,
      required ValueListenable<LayoutPanelConfig> config,
      required ForgePanelLocation location,
    }) {
      return ValueListenableBuilder<LayoutPanelConfig>(
        valueListenable: config,
        builder: (context, panelConfig, _) {
          return SwitchListTile(
            title: Text(label),
            value: panelConfig.isVisible,
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged: (nextValue) {
              if (nextValue != panelConfig.isVisible) {
                _layout.togglePanel(location);
              }
            },
          );
        },
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Configuration', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Panel visibility and editor settings.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          buildPanelToggle(
            label: 'Show left panel',
            config: _layout.leftPanel,
            location: ForgePanelLocation.left,
          ),
          buildPanelToggle(
            label: 'Show right panel',
            config: _layout.rightPanel,
            location: ForgePanelLocation.right,
          ),
          buildPanelToggle(
            label: 'Show bottom panel',
            config: _layout.bottomPanel,
            location: ForgePanelLocation.bottom,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _openSettings,
              icon: const Icon(Icons.tune),
              label: const Text('Open Full Settings'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiddleArea(BuildContext context) {
    return ValueListenableBuilder<List<List<ForgeEditor>>>(
      valueListenable: _layout.middlePanels,
      builder: (context, panels, _) {
        return ValueListenableBuilder<int>(
          valueListenable: _layout.activeMiddlePanelIndexNotifier,
          builder: (context, activeIdx, _) {
            if (panels.isEmpty || panels.every((p) => p.isEmpty)) {
              return Center(
                child: Text(
                  'Open a file to get started',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              );
            }
            // Ensure flex list matches panel count.
            while (_middlePanelFlex.length < panels.length) {
              _middlePanelFlex.add(1.0);
            }
            if (_middlePanelFlex.length > panels.length) {
              _middlePanelFlex = _middlePanelFlex.sublist(0, panels.length);
            }
            return Row(
              children: [
                for (var i = 0; i < panels.length; i++) ...[
                  if (i > 0)
                    _ResizeHandle(
                      axis: Axis.horizontal,
                      onDragDelta: (delta) =>
                          _resizeMiddlePanelDivider(i - 1, i, delta),
                      onDoubleTap: () => _resetMiddlePanelFlex(),
                    ),
                  Flexible(
                    flex: (_middlePanelFlex[i] * 1000).round(),
                    child: _buildEditorPanel(
                      context,
                      editors: panels[i],
                      isActive: i == activeIdx,
                      panelIndex: i,
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEditorPanel(
    BuildContext context, {
    required List<ForgeEditor> editors,
    required bool isActive,
    required int panelIndex,
  }) {
    final panelCount = _layout.middlePanels.value.length;

    if (editors.isEmpty) {
      return EmptyPanelDropTarget(
        panelIndex: panelIndex,
        onDrop: (data, position, {bool isCopy = false}) {
          _handleDropZone(data, position, panelIndex, isCopy: isCopy);
        },
      );
    }
    return ValueListenableBuilder<ForgeEditor?>(
      valueListenable: widget.systemState.activeEditorListenable,
      builder: (context, activeEditor, _) {
        final currentEditor =
            (activeEditor != null && editors.contains(activeEditor))
            ? activeEditor
            : editors.last;
        final showFindBar =
            _showFindReplaceBar && currentEditor is ForgeTextEditor;

        return EditorDropZoneOverlay(
          panelIndex: panelIndex,
          canSplit: panelCount < 4,
          onDrop: (data, position, {bool isCopy = false}) {
            _handleDropZone(data, position, panelIndex, isCopy: isCopy);
          },
          child: Column(
            children: [
              ForgeEditorTabBar(
                editors: editors,
                activeEditor: currentEditor,
                panelIndex: panelIndex,
                onSelect: (editor) {
                  setState(() {
                    _layout.setActiveMiddlePanelIndex(panelIndex);
                    widget.systemState.setActiveEditor(editor);
                  });
                },
                onClose: (editor) => _handleCloseEditor(editor),
                onEditorDropped: (editor, {bool isCopy = false}) {
                  if (isCopy) {
                    _layout.copyComponent(editor, panelIndex);
                  } else {
                    _layout.moveComponent(editor, panelIndex);
                  }
                  widget.systemState.setActiveEditor(editor);
                },
              ),
              if (showFindBar) _buildFindReplaceBar(),
              Expanded(
                child: GestureDetector(
                  key: ValueKey('editor-area-context-target-$panelIndex'),
                  behavior: HitTestBehavior.translucent,
                  onSecondaryTapDown: (details) {
                    _showEditorContextMenu(
                      details.globalPosition,
                      currentEditor,
                    );
                  },
                  child: SizedBox.expand(
                    child: currentEditor.buildMain(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFindReplaceBar() {
    final theme = Theme.of(context);
    final hasMatches = _findMatches.isNotEmpty;
    final counterText = hasMatches
        ? '${_activeFindMatchIndex + 1}/${_findMatches.length}'
        : '0/0';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.65,
        ),
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                key: const Key('find-bar-query-field'),
                controller: _findQueryController,
                focusNode: _findFieldFocusNode,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Find',
                  prefixIcon: Icon(Icons.search, size: 18),
                ),
                onSubmitted: (_) => _selectFindMatch(next: true),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              key: const Key('find-prev-button'),
              tooltip: 'Previous match',
              onPressed: hasMatches
                  ? () => _selectFindMatch(next: false)
                  : null,
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            IconButton(
              key: const Key('find-next-button'),
              tooltip: 'Next match',
              onPressed: hasMatches ? () => _selectFindMatch(next: true) : null,
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
            Text(
              counterText,
              key: const Key('find-match-counter'),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(width: 8),
            TextButton(
              key: const Key('find-toggle-replace-button'),
              onPressed: () {
                setState(() {
                  _showReplaceFields = !_showReplaceFields;
                });
              },
              child: Text(_showReplaceFields ? 'Hide Replace' : 'Replace'),
            ),
            if (_showReplaceFields) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 220,
                child: TextField(
                  key: const Key('find-bar-replace-field'),
                  controller: _replaceValueController,
                  focusNode: _replaceFieldFocusNode,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Replace with',
                    prefixIcon: Icon(Icons.find_replace, size: 18),
                  ),
                  onSubmitted: (_) => _replaceCurrentMatch(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                key: const Key('find-replace-button'),
                onPressed: hasMatches ? _replaceCurrentMatch : null,
                child: const Text('Replace'),
              ),
              const SizedBox(width: 6),
              FilledButton.tonal(
                key: const Key('find-replace-all-button'),
                onPressed: _findQueryController.text.isEmpty
                    ? null
                    : _replaceAllMatches,
                child: const Text('Replace All'),
              ),
            ],
            const SizedBox(width: 8),
            IconButton(
              key: const Key('find-close-button'),
              tooltip: 'Close find/replace',
              onPressed: _closeFindReplaceBar,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }

  /// Handles drop zone actions for editor panels (center/left/right split).
  void _handleDropZone(
    TabDragData data,
    DropPosition position,
    int panelIndex, {
    bool isCopy = false,
  }) {
    switch (position) {
      case DropPosition.center:
        if (isCopy) {
          _layout.copyComponent(data.editor, panelIndex);
        } else {
          _layout.moveComponent(data.editor, panelIndex);
        }
      case DropPosition.left:
        _layout.splitAndInsertPanel(panelIndex, data.editor);
      case DropPosition.right:
        _layout.splitAndInsertPanel(panelIndex + 1, data.editor);
    }
    widget.systemState.setActiveEditor(data.editor);
  }

  /// Handles a tab being dropped from one panel area to another.
  ///
  /// This enables moving tabs between left, right, and bottom panels
  /// (Section 9, Row 7: side/bottom tabs moved between panels).
  void _handlePanelTabDrop(PanelTabDragData data, PanelArea targetArea) {
    if (data.sourceArea == targetArea) return;

    final layout = widget.application.layout;

    // Resolve source panel tabs.
    final sourceTabs = switch (data.sourceArea) {
      PanelArea.left => layout.leftPanel.tabs,
      PanelArea.right => layout.rightPanel.tabs,
      PanelArea.bottom => layout.bottomPanel.tabs,
    };

    // Resolve target panel tabs.
    final targetTabs = switch (targetArea) {
      PanelArea.left => layout.leftPanel.tabs,
      PanelArea.right => layout.rightPanel.tabs,
      PanelArea.bottom => layout.bottomPanel.tabs,
    };

    // Validate index.
    if (data.tabIndex < 0 || data.tabIndex >= sourceTabs.length) return;

    // Move the tab config from source to target.
    final tab = sourceTabs.removeAt(data.tabIndex);
    targetTabs.add(tab);

    // Trigger rebuild.
    setState(() {});
  }

  /// Handles editor close with dirty-state check.
  ///
  /// If the editor has unsaved changes, prompts the user to save, discard,
  /// or cancel before closing.
  Future<void> _handleCloseEditor(ForgeEditor editor) async {
    if (editor.isDirty.value) {
      final result = await showDialog<_DirtyCloseAction>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: Text(
            'Do you want to save the changes to "${editor.title.value}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _DirtyCloseAction.cancel),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, _DirtyCloseAction.discard),
              child: const Text("Don't Save"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, _DirtyCloseAction.save),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      switch (result) {
        case _DirtyCloseAction.save:
          try {
            widget.shell.executeAction('file.save');
            _layout.closeEditor(editor);
          } catch (e) {
            if (!mounted) return;
            final recovery = await ForgeErrorRecoveryDialog.show(
              context,
              title: 'Save Failed',
              message: 'Could not save "${editor.title.value}": $e',
              showOverwrite: true,
            );
            switch (recovery) {
              case ErrorRecoveryAction.retry:
                _handleCloseEditor(editor); // retry the whole flow
              case ErrorRecoveryAction.overwrite:
                _layout.closeEditor(editor); // discard and close
              case ErrorRecoveryAction.cancel:
              case null:
                break; // stay open
            }
          }
        case _DirtyCloseAction.discard:
          _layout.closeEditor(editor);
        case _DirtyCloseAction.cancel:
        case null:
          // Do nothing — user cancelled.
          break;
      }
    } else {
      _layout.closeEditor(editor);
    }
  }

  Widget _buildBottomPanel(BuildContext context, LayoutPanelConfig config) {
    final tabs = widget.application.layout.bottomPanel.tabs;
    if (tabs.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: config.size,
      // Bottom panel is docked below the editor region; top resize handle
      // is rendered by _buildCenterColumn to keep panel boundaries explicit.
      child: ForgePanelWidget(
        tabs: tabs,
        panelArea: PanelArea.bottom,
        onTabDropped: (data) => _handlePanelTabDrop(data, PanelArea.bottom),
      ),
    );
  }
}

// ── Intents for keyboard shortcuts ──

/// Result of the dirty-close confirmation dialog.
enum _DirtyCloseAction { save, discard, cancel }

class _CommandPaletteIntent extends Intent {
  const _CommandPaletteIntent();
}

class _ToggleLeftPanelIntent extends Intent {
  const _ToggleLeftPanelIntent();
}

class _ToggleRightPanelIntent extends Intent {
  const _ToggleRightPanelIntent();
}

class _FocusLeftPanelIntent extends Intent {
  const _FocusLeftPanelIntent();
}

class _FocusCenterIntent extends Intent {
  const _FocusCenterIntent();
}

class _FocusRightPanelIntent extends Intent {
  const _FocusRightPanelIntent();
}

class _FocusBottomPanelIntent extends Intent {
  const _FocusBottomPanelIntent();
}

class _FocusNextPanelIntent extends Intent {
  const _FocusNextPanelIntent();
}

class _FocusPreviousPanelIntent extends Intent {
  const _FocusPreviousPanelIntent();
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}

class _ResizeHandle extends StatefulWidget {
  const _ResizeHandle({
    required this.axis,
    required this.onDragDelta,
    this.onDoubleTap,
  });

  final Axis axis;
  final ValueChanged<double> onDragDelta;
  final VoidCallback? onDoubleTap;

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _isHovering = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVerticalDivider = widget.axis == Axis.horizontal;

    final activeColor = theme.colorScheme.primary.withValues(alpha: 0.9);
    final hoverColor = theme.colorScheme.primary.withValues(alpha: 0.45);
    final idleColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.9);

    final gripColor = _isDragging
        ? activeColor
        : (_isHovering ? hoverColor : idleColor);

    final gripThickness = _isDragging ? 5.0 : (_isHovering ? 3.0 : 1.0);

    final grip = isVerticalDivider
        ? AnimatedContainer(
            duration: ForgeAnimations.panelTransition,
            curve: ForgeAnimations.panelCurve,
            margin: EdgeInsets.symmetric(
              horizontal:
                  (ForgeDimensions.dividerHitTarget - gripThickness) / 2,
            ),
            decoration: BoxDecoration(
              color: gripColor,
              borderRadius: BorderRadius.circular(2),
            ),
          )
        : AnimatedContainer(
            duration: ForgeAnimations.panelTransition,
            curve: ForgeAnimations.panelCurve,
            margin: EdgeInsets.symmetric(
              vertical: (ForgeDimensions.dividerHitTarget - gripThickness) / 2,
            ),
            decoration: BoxDecoration(
              color: gripColor,
              borderRadius: BorderRadius.circular(2),
            ),
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: widget.onDoubleTap,
      onHorizontalDragStart: isVerticalDivider
          ? (_) => setState(() => _isDragging = true)
          : null,
      onHorizontalDragUpdate: isVerticalDivider
          ? (details) => widget.onDragDelta(details.delta.dx)
          : null,
      onHorizontalDragEnd: isVerticalDivider
          ? (_) => setState(() => _isDragging = false)
          : null,
      onHorizontalDragCancel: isVerticalDivider
          ? () => setState(() => _isDragging = false)
          : null,
      onVerticalDragStart: !isVerticalDivider
          ? (_) => setState(() => _isDragging = true)
          : null,
      onVerticalDragUpdate: !isVerticalDivider
          ? (details) => widget.onDragDelta(details.delta.dy)
          : null,
      onVerticalDragEnd: !isVerticalDivider
          ? (_) => setState(() => _isDragging = false)
          : null,
      onVerticalDragCancel: !isVerticalDivider
          ? () => setState(() => _isDragging = false)
          : null,
      child: MouseRegion(
        cursor: isVerticalDivider
            ? SystemMouseCursors.resizeColumn
            : SystemMouseCursors.resizeRow,
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() {
          _isHovering = false;
          _isDragging = false;
        }),
        child: SizedBox(
          width: isVerticalDivider ? ForgeDimensions.dividerHitTarget : null,
          height: isVerticalDivider ? null : ForgeDimensions.dividerHitTarget,
          child: grip,
        ),
      ),
    );
  }
}
