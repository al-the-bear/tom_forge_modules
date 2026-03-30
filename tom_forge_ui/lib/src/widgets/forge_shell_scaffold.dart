import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import '../adapters/forge_dart_editor.dart';
import '../adapters/forge_md_editor.dart';
import '../adapters/forge_plain_text_editor.dart';
import '../adapters/forge_yaml_editor.dart';
import '../components/forge_editor.dart';
import '../components/forge_text_editor.dart';
import '../defaults/default_layout_controller.dart';
import '../defaults/default_shell_api.dart';
import '../defaults/default_system_state.dart';
import '../defaults/default_workspace_state_manager.dart';
import '../model/forge_application.dart';
import '../services/forge_preferences_service.dart';
import '../shell/forge_layout_controller.dart';
import '../shell/forge_status_bar_controller.dart';
import '../actions/forge_shortcut_binding.dart';
import '../services/forge_shortcut_manager.dart';
import 'forge_chord_overlay.dart';
import 'forge_command_palette.dart';
import 'forge_configuration_dialog.dart';
import 'forge_drag_data.dart';
import 'forge_drop_zone_overlay.dart';
import 'forge_editor_tab_bar.dart';
import 'forge_menu_bar.dart';
import 'forge_notification_overlay.dart';
import 'forge_open_with_dialog.dart';
import 'forge_panel_widget.dart';
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

  static const String _actionFileSave = 'file.save';
  static const String _actionFileSaveAll = 'file.saveAll';

  DefaultLayoutController get _layout => widget.layoutController;
  bool _showCommandPalette = false;
  late final ForgePreferencesService _preferences;
  StreamSubscription<Uri>? _saveSubscription;
  StreamSubscription<EditorListChangeEvent>? _editorChangeSubscription;
  StreamSubscription<DirtyStateEvent>? _dirtyStateSubscription;
  StreamSubscription<WindowFocusEvent>? _windowFocusSubscription;
  StreamSubscription<ConfigChangeEvent>? _configChangeSubscription;
  StreamSubscription<ForgeChordEvent>? _chordSubscription;
  Timer? _autoSaveTimer;

  /// Flex factors for middle editor panels (1.0 per panel by default).
  /// Adjusted during drag-resize of middle panel dividers.
  List<double> _middlePanelFlex = [];

  @override
  void initState() {
    super.initState();
    _preferences = widget.preferencesService ?? ForgePreferencesService.instance;
    _preferences.addListener(_onPreferencesChanged);
    _initializePreferences();
    _listenForSaveRevisions();
    _listenForEditorChanges();
    _listenForAutoSave();
    _listenForConfigChanges();
    _listenForChordCompletions();
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
      await _restoreLayoutState();
      await _restoreWorkspaceState();
    } catch (error, stackTrace) {
      debugPrint('[ForgeShellScaffold] initialize preferences failed: $error');
      debugPrint('$stackTrace');
    }
  }

  void _onPreferencesChanged() {
    try {
      _applyPreferenceTextSettings();
      _propagateSettingsToActiveEditors();
      // High-contrast mode (ThemeMode.system) activates reduced motion.
      ForgeAnimations.reduceMotion =
          _preferences.themeMode == ThemeMode.system;
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
          editor.updateOptions(ForgeTextEditorOptions(
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
          ));
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
      debugPrint('[ForgeShellScaffold] applied persisted settings: ${settings.length}');
    }
  }

  /// Restores panel sizes, visibility, and previously-open editors.
  ///
  /// Tries SharedPreferences first, then falls back to `.forge/state/`
  /// files for workspace-scoped recovery.
  Future<void> _restoreLayoutState() async {
    var sizes = _preferences.layoutPanelSizes;
    var visibility = _preferences.layoutPanelVisibility;
    var editorUris = _preferences.layoutOpenEditors;

    // Fall back to .forge/state/ if preferences are empty.
    final wsState = widget.shell.workspaceState;
    if (sizes.isEmpty && visibility.isEmpty && wsState.isInitialized) {
      try {
        final layoutData = await wsState.loadLayoutState();
        if (layoutData != null) {
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
          debugPrint('[ForgeShellScaffold] restore editor failed for $uriStr: $e');
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
          _preferences.layoutPanelSizes.isEmpty) {
        for (final entry in layout.entries) {
          if (entry.value is Map<String, dynamic>) {
            final panel = entry.value as Map<String, dynamic>;
            final size = panel['size'];
            final isVisible = panel['isVisible'];
            final location = _panelLocationFromName(entry.key);
            if (location != null) {
              if (size is num) _layout.setPanelSize(location, size.toDouble());
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
        debugPrint('[ForgeShellScaffold] restored workspace state for '
            '"${widget.application.title}"');
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

      _preferences.save();

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
    });
  }

  /// Listens for editor open/close events to save/restore per-editor state.
  void _listenForEditorChanges() {
    final wsState = widget.shell.workspaceState;
    if (!wsState.isInitialized) return;
    _editorChangeSubscription =
        widget.systemState.onEditorsChanged.listen((event) async {
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
              debugPrint(
                  '[ForgeShellScaffold] save editor state failed: $e');
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
                  '[ForgeShellScaffold] restore editor state failed: $e');
            }
          }
        }
      }
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
    _dirtyStateSubscription = widget.systemState.onDirtyStateChanged.listen((event) {
      if (event.isDirty) {
        _scheduleAutoSave(config.autoSave.idleDelay);
      }
    });

    // Listen for window focus loss to trigger auto-save.
    if (config.autoSave.saveOnFocusLoss) {
      _windowFocusSubscription = widget.systemState.onWindowFocusChanged.listen((event) {
        if (!event.focused && widget.systemState.hasUnsavedChanges) {
          _performAutoSave(SaveReason.focusLoss);
        }
      });
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
          debugPrint('[ForgeShellScaffold] auto-saved: ${editor.uri} (reason: $reason)');
        }
      } catch (e) {
        if (debugEnabled) {
          debugPrint('[ForgeShellScaffold] auto-save failed for ${editor.uri}: $e');
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

      // Save layout state to .forge/state/layout.json
      final layoutData = <String, dynamic>{};
      for (final location in ForgePanelLocation.values) {
        if (location == ForgePanelLocation.middle) continue;
        final config = _layout.getPanelConfig(location);
        if (config != null) {
          layoutData[location.name] = {
            'size': config.size,
            'isVisible': config.isVisible,
          };
        }
      }
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

  void _openSettings() {
    ForgeConfigurationDialog.show(context, _preferences, widget.shell);
  }

  /// Listens for chord completions to execute the bound action.
  void _listenForChordCompletions() {
    _chordSubscription =
        widget.shell.shortcuts.onChordStateChanged.listen((event) {
      if (event.state == ForgeChordState.completed &&
          event.executedBinding != null) {
        widget.shell.executeAction(event.executedBinding!.action.id);
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
    final useMeta =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
    final hasPrimary = useMeta
        ? pressed.contains(LogicalKeyboardKey.metaLeft) ||
            pressed.contains(LogicalKeyboardKey.metaRight)
        : pressed.contains(LogicalKeyboardKey.controlLeft) ||
            pressed.contains(LogicalKeyboardKey.controlRight);
    final hasShift = pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);
    final hasAlt = pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight);
    return ForgeShortcutKey(
      key: key,
      primaryModifier: hasPrimary,
      shift: hasShift,
      alt: hasAlt,
    );
  }

  /// Key event handler that intercepts chord shortcut sequences.
  ///
  /// Returns [KeyEventResult.handled] when a chord is in progress or
  /// completed, preventing the normal [Shortcuts] widget from processing
  /// the event.
  KeyEventResult _handleChordKeyEvent(FocusNode node, KeyEvent event) {
    // Cancel chord on Escape.
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      if (widget.shell.shortcuts.isChordPending) {
        widget.shell.shortcuts.cancelChord();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final shortcutKey = _keyEventToShortcutKey(event);
    if (shortcutKey == null) return KeyEventResult.ignored;

    final result = widget.shell.shortcuts.handleKeyForChord(shortcutKey);
    if (result != null) {
      // Chord completed — event consumed (action executed via listener).
      return KeyEventResult.handled;
    }
    if (widget.shell.shortcuts.isChordPending) {
      // First key of chord matched — consume event to prevent normal dispatch.
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
                  // Open With dialog when multiple editors can handle a file.
                  ValueListenableBuilder<(Uri, List<ForgeEditor>)?>(
                    valueListenable: _layout.pendingEditorChoice,
                    builder: (context, choice, _) {
                      if (choice == null) return const SizedBox.shrink();
                      final (uri, editors) = choice;
                      return ForgeOpenWithDialog(
                        uri: uri,
                        editors: editors,
                        onEditorSelected: (editor) {
                          _layout.resolveEditorChoice(editor, uri);
                        },
                        onCancel: () {
                          _layout.pendingEditorChoice.value = null;
                        },
                      );
                    },
                  ),
                  if (_showCommandPalette)
                    ForgeCommandPalette(
                      shellApi: widget.shell,
                      onDismiss: _toggleCommandPalette,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Wrap with native platform menu bar on macOS desktop.
    if (_usePlatformMenu) {
      body = PlatformMenuBar(
        menus: _buildPlatformMenus(),
        child: body,
      );
    }

    return body;
  }

  /// Build native platform menu items for macOS.
  List<PlatformMenuItem> _buildPlatformMenus() {
    return [
      PlatformMenu(
        label: 'File',
        menus: [
          PlatformMenuItem(
            label: 'New File',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyN,
              meta: true,
            ),
            onSelected: () => widget.shell.executeAction('file.new'),
          ),
          PlatformMenuItem(
            label: 'Open Folder...',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyO,
              meta: true,
            ),
            onSelected: () => widget.shell.executeAction('file.openFolder'),
          ),
          const PlatformMenuItemGroup(members: []),
          PlatformMenuItem(
            label: 'Save',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyS,
              meta: true,
            ),
            onSelected: () => widget.shell.executeAction('file.save'),
          ),
          PlatformMenuItem(
            label: 'Save All',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyS,
              meta: true,
              shift: true,
            ),
            onSelected: () => widget.shell.executeAction('file.saveAll'),
          ),
          const PlatformMenuItemGroup(members: []),
          PlatformMenuItem(
            label: 'Close Editor',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyW,
              meta: true,
            ),
            onSelected: () => widget.shell.executeAction('file.close'),
          ),
          const PlatformMenuItemGroup(members: []),
          PlatformMenuItem(
            label: 'Settings...',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.comma,
              meta: true,
            ),
            onSelected: _openSettings,
          ),
        ],
      ),
      PlatformMenu(
        label: 'Edit',
        menus: [
          PlatformMenuItem(
            label: 'Undo',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyZ,
              meta: true,
            ),
            onSelected: () => widget.shell.executeAction('edit.undo'),
          ),
          PlatformMenuItem(
            label: 'Redo',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyZ,
              meta: true,
              shift: true,
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
          PlatformMenuItem(
            label: 'Find',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyF,
              meta: true,
            ),
            onSelected: () => widget.shell.executeAction('edit.find'),
          ),
          PlatformMenuItem(
            label: 'Replace',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyF,
              meta: true,
              alt: true,
            ),
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
          PlatformMenuItem(
            label: 'Back',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.minus,
              control: true,
            ),
            onSelected: () {},
          ),
          PlatformMenuItem(
            label: 'Forward',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.minus,
              control: true,
              shift: true,
            ),
            onSelected: () {},
          ),
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
      PlatformMenu(
        label: 'Help',
        menus: [
          PlatformMenuItem(
            label: 'About Tom Forge',
            onSelected: () {},
          ),
        ],
      ),
    ];
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
          return null;
        },
      ),
      _FocusCenterIntent: CallbackAction<_FocusCenterIntent>(
        onInvoke: (_) {
          widget.systemState.setFocusedPanelLocation(ForgePanelLocation.middle);
          return null;
        },
      ),
      _FocusRightPanelIntent: CallbackAction<_FocusRightPanelIntent>(
        onInvoke: (_) {
          widget.systemState.setFocusedPanelLocation(ForgePanelLocation.right);
          return null;
        },
      ),
      _FocusBottomPanelIntent: CallbackAction<_FocusBottomPanelIntent>(
        onInvoke: (_) {
          widget.systemState.setFocusedPanelLocation(ForgePanelLocation.bottom);
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
  }

  void _executeSave() {
    try {
      if (widget.shell.executeAction(_actionFileSave)) {
        return;
      }

      widget.shell.executeAction(_actionFileSaveAll);
    } catch (error, stackTrace) {
      debugPrint('[ForgeShellScaffold] execute save failed: $error');
      debugPrint('$stackTrace');
      widget.shell.notifications.showError(
        'Save failed: $error',
      );
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
                  icon: Icon(Icons.arrow_back, size: ForgeDimensions.iconToolbar),
                  onPressed: null, // Disabled until component history is implemented
                  tooltip: 'Back',
                ),
                IconButton(
                  icon: Icon(Icons.arrow_forward, size: ForgeDimensions.iconToolbar),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    width: 400,
                    height: 32,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.search,
                            size: 16,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.application.icon != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(widget.application.icon, size: 14),
                          ),
                        Text(widget.application.title, style: theme.textTheme.bodySmall),
                        const Icon(Icons.arrow_drop_down, size: 18),
                      ],
                    ),
                  ),
                ],
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
            if (bottomConfig.isVisible) _buildBottomPanel(context, bottomConfig),
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
    var newLeft = (_middlePanelFlex[leftIdx] + flexDelta).clamp(minFlex, totalFlex - minFlex);
    var newRight = totalFlex - newLeft;
    setState(() {
      _middlePanelFlex[leftIdx] = newLeft;
      _middlePanelFlex[rightIdx] = newRight;
    });
  }

  /// Reset all middle panel flex factors to equal distribution.
  void _resetMiddlePanelFlex() {
    setState(() {
      _middlePanelFlex = List.filled(_middlePanelFlex.length, 1.0);
    });
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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
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
            editors.contains(activeEditor) ? activeEditor : editors.last;

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
              Expanded(
                child: currentEditor?.buildMain(context) ??
                    const SizedBox.expand(),
              ),
            ],
          ),
        );
      },
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
              onPressed: () =>
                  Navigator.pop(context, _DirtyCloseAction.cancel),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, _DirtyCloseAction.discard),
              child: const Text("Don't Save"),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, _DirtyCloseAction.save),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      switch (result) {
        case _DirtyCloseAction.save:
          widget.shell.executeAction('file.save');
          _layout.closeEditor(editor);
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

    final gripThickness = _isDragging
        ? 5.0
        : (_isHovering ? 3.0 : 1.0);

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
