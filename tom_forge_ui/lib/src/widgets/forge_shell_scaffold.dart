import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;

import '../adapters/forge_dart_editor.dart';
import '../adapters/forge_md_editor.dart';
import '../adapters/forge_plain_text_editor.dart';
import '../adapters/forge_yaml_editor.dart';
import '../components/forge_component.dart';
import '../components/forge_editor.dart';
import '../components/forge_text_editor.dart';
import '../components/forge_view.dart';
import '../defaults/default_layout_controller.dart';
import '../defaults/default_dialog_manager.dart';
import '../defaults/default_shell_api.dart';
import '../defaults/stub_services.dart';
import '../services/forge_accessibility.dart';
import '../defaults/default_system_state.dart';
import '../defaults/editor_save.dart';
import '../defaults/default_workspace_state_manager.dart';
import '../model/forge_application.dart';
import '../services/forge_preferences_service.dart';
import '../services/forge_dialog_manager.dart';
import '../shell/forge_layout_controller.dart';
import '../shell/forge_status_bar_controller.dart';
import '../actions/forge_action.dart' as shell_action;
import '../actions/forge_shortcut_binding.dart';
import '../services/forge_shortcut_manager.dart';
import 'forge_configuration_panel.dart';
import 'forge_quick_open.dart';
import 'forge_drag_data.dart';
import 'forge_drop_zone_overlay.dart';
import 'forge_error_recovery_dialog.dart';
import 'forge_input_box_overlay.dart';
import 'forge_notification_popup.dart';
import 'forge_quick_pick_overlay.dart';
import 'forge_editor_tab_bar.dart';
import 'forge_menu_bar.dart';
import 'forge_notification_overlay.dart';
import 'forge_open_with_dialog.dart';
import 'forge_panel_widget.dart';
import 'forge_shortcut_menu_popup.dart';
import 'forge_status_bar_widget.dart';
import '../views/forge_terminal_view.dart';

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
  // Panels – no upper limits; users may drag to any size.
  static const double panelMinSize = 50;
  static const double leftPanelDefaultWidth = 280;
  static const double rightPanelDefaultWidth = 280;
  static const double bottomPanelDefaultHeight = 200;
  static const double middlePanelMinWidth = 200;

  /// Minimum width at which panel content stops shrinking and gets clipped.
  static const double panelContentMinWidth = 400;

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

  /// Callback invoked when the user selects File > Open Folder.
  /// The selected [Directory] is passed to the callback so the parent can
  /// reinitialise the workspace. When null, the action is a no-op.
  final void Function(Directory)? onOpenFolder;

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
    this.onOpenFolder,
  });

  @override
  State<ForgeShellScaffold> createState() => _ForgeShellScaffoldState();
}

class _ForgeShellScaffoldState extends State<ForgeShellScaffold> {
  static bool debugEnabled = false;
  static const Duration _layoutPersistDebounce = Duration(milliseconds: 500);

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
  QuickOpenMode? _quickOpenMode;
  final TextEditingController _quickOpenSearchController =
      TextEditingController();
  final FocusNode _quickOpenFocusNode = FocusNode();

  /// Key event handler for the search field focus node.
  /// Intercepts palette shortcuts (F1, Ctrl+Shift+P) and Escape so they
  /// work even when the text field has focus.
  KeyEventResult _handleSearchFieldKeyEvent(
    FocusNode node,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    // Escape closes the palette when open.
    if (key == LogicalKeyboardKey.escape && _quickOpenMode != null) {
      _closeQuickOpen();
      return KeyEventResult.handled;
    }

    // F1 toggles the command palette.
    if (key == LogicalKeyboardKey.f1) {
      _toggleCommandPalette();
      return KeyEventResult.handled;
    }

    // Ctrl+Shift+P (or Cmd+Shift+P) toggles the command palette.
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
    if (hasPrimary && hasShift && key == LogicalKeyboardKey.keyP) {
      _toggleCommandPalette();
      return KeyEventResult.handled;
    }

    // Ctrl+P (or Cmd+P) toggles the actions-only quick open.
    if (hasPrimary && !hasShift && key == LogicalKeyboardKey.keyP) {
      if (_quickOpenMode == QuickOpenMode.actions) {
        _closeQuickOpen();
      } else {
        _openQuickOpen(QuickOpenMode.actions);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
  final GlobalKey _searchBoxKey = GlobalKey();
  final GlobalKey _quickOpenWidgetKey = GlobalKey();
  ForgeShortcutKey? _chordFirstKeyForQuickOpen;
  List<ForgeShortcutBinding> _chordCompletionsForQuickOpen = const [];
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
  StreamSubscription<void>? _selectionChangeSubscription;
  Timer? _autoSaveTimer;
  Timer? _layoutPersistTimer;

  /// Minimum interval between revisions for the same file (throttle).
  static const _revisionMinInterval = Duration(seconds: 30);

  /// Tracks the last revision timestamp per URI to throttle revision creation.
  final Map<Uri, DateTime> _lastRevisionTime = {};

  bool _notificationPopupVisible = false;

  /// Stable view instances for terminal sections, keyed by terminal identity.
  final Map<ForgeTerminal, SingleTerminalView> _terminalSectionViews = {};

  /// Flex factors for middle editor panels (1.0 per panel by default).
  /// Adjusted during drag-resize of middle panel dividers.
  List<double> _middlePanelFlex = [];

  /// Cached pixel width of the middle editor area for accurate drag-resize.
  double _middleAreaWidth = 0;

  /// Active tab indices per panel for persistence.
  int _leftPanelActiveTab = 0;
  bool _leftPanelShowConfig = false;
  int _rightPanelActiveTab = 0;
  int _bottomPanelActiveTab = 0;

  /// Accordion section state per panel area and tab index.
  final Map<String, Map<int, AccordionSectionState>> _accordionStates = {
    'left': {},
    'right': {},
    'bottom': {},
  };

  /// True while restoring layout state from preferences — suppresses
  /// persistence so we don't overwrite the saved state with a
  /// partially-restored snapshot.
  bool _isRestoringLayout = false;

  /// Notifier to externally open/close the left panel configuration tab.
  final ValueNotifier<bool> _configPanelVisible = ValueNotifier<bool>(false);

  /// Target accordion section index to expand when the config panel opens.
  final ValueNotifier<int?> _configSectionTarget = ValueNotifier<int?>(null);

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
    _registerShellShortcuts();
    _initializePreferences();
    _quickOpenSearchController.addListener(_onSearchFieldChanged);
    _wireDialogCallbacks();
    _wireTerminalCallbacks();
    _listenForSaveRevisions();
    _listenForEditorChanges();
    _listenForAutoSave();
    _listenForConfigChanges();
    _listenForLayoutChanges();
    _listenForChordCompletions();
    _listenForMenuSelections();
    widget.notificationManager.popupVisible.addListener(
      _onNotificationPopupChanged,
    );
  }

  @override
  void didUpdateWidget(covariant ForgeShellScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shell != widget.shell) {
      // The shell changed (e.g. placeholder → real shell).
      // Re-wire ALL shell-dependent listeners.

      // Layout listeners.
      _detachLayoutListeners();
      _listenForLayoutChanges();
      _layoutPersistTimer?.cancel();

      // Terminal subscriptions.
      _terminalOpenSubscription?.cancel();
      _terminalCloseSubscription?.cancel();
      _terminalActiveSubscription?.cancel();
      _terminalSectionViews.clear();
      _wireTerminalCallbacks();

      // Save and revision subscriptions (depend on fileSystem/systemState).
      _autoSaveTimer?.cancel();
      _saveSubscription?.cancel();
      _dirtyStateSubscription?.cancel();
      _windowFocusSubscription?.cancel();
      _listenForSaveRevisions();
      _listenForAutoSave();

      // Editor change tracking (depends on systemState).
      _editorChangeSubscription?.cancel();
      _listenForEditorChanges();

      // Config change persistence (depends on workspaceState/config).
      _configChangeSubscription?.cancel();
      _listenForConfigChanges();

      // Chord and menu subscriptions (depend on shortcutManager).
      _chordSubscription?.cancel();
      _menuSubscription?.cancel();
      _listenForChordCompletions();
      _listenForMenuSelections();

      // Active editor listener (depends on systemState).
      oldWidget.systemState.activeEditorListenable.removeListener(
        _onActiveEditorChanged,
      );
      widget.systemState.activeEditorListenable.addListener(
        _onActiveEditorChanged,
      );

      // Notification popup listener.
      oldWidget.notificationManager.popupVisible.removeListener(
        _onNotificationPopupChanged,
      );
      widget.notificationManager.popupVisible.addListener(
        _onNotificationPopupChanged,
      );

      // Dialog callbacks (depend on shell.dialogs).
      _wireDialogCallbacks();

      // Re-register shell shortcut overrides on the new shell's action registry.
      _registerShellShortcuts();

      // Restore layout from preferences into the new controller.
      _initializePreferences();
    }
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
    _selectionChangeSubscription?.cancel();
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
    _quickOpenSearchController.removeListener(_onSearchFieldChanged);
    _quickOpenSearchController.dispose();
    _quickOpenFocusNode.dispose();
    _configPanelVisible.dispose();
    _configSectionTarget.dispose();
    _preferences.removeListener(_onPreferencesChanged);
    widget.notificationManager.popupVisible.removeListener(
      _onNotificationPopupChanged,
    );
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
      _isRestoringLayout = true;
      try {
        await _restoreLayoutState();
        await _restoreWorkspaceState();
      } finally {
        _isRestoringLayout = false;
      }
      if (mounted) setState(() {});
    } catch (error, stackTrace) {
      _isRestoringLayout = false;
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
  /// auto-opens the bottom panel on terminal creation, updates
  /// status when the active terminal changes, and keeps the
  /// Terminal tab's sections list in sync with the terminal manager.
  void _wireTerminalCallbacks() {
    final terminals = widget.shell.terminals;

    // Initial sync of terminal sections.
    _syncTerminalSections();

    _terminalOpenSubscription = terminals.onDidOpen.listen((terminal) {
      // Auto-show bottom panel when a terminal is created.
      _layout.openPanel(ForgePanelLocation.bottom);
      _syncTerminalSections();
      if (mounted) setState(() {});
    });

    _terminalCloseSubscription = terminals.onDidClose.listen((terminal) {
      // Notify user when a terminal is closed.
      widget.shell.notifications.showInformation(
        'Terminal "${terminal.name}" closed',
      );
      _syncTerminalSections();
      if (mounted) setState(() {});
    });

    _terminalActiveSubscription = terminals.onDidChangeActive.listen((
      terminal,
    ) {
      // Refresh state to update status bar or other reactive UI.
      if (mounted) setState(() {});
    });

    // Listen for editor state changes (e.g. selection, undo stack) so the
    // action bar re-evaluates enablement via EditorActionProvider.
    _subscribeToEditorStateChanges();
  }

  /// Finds the Terminal tab in the bottom panel configuration.
  PanelTabConfig? get _terminalTab {
    final tabs = widget.application.layout.bottomPanel.tabs;
    for (final tab in tabs) {
      if (tab.title == 'Terminal') return tab;
    }
    return null;
  }

  /// Synchronises the Terminal tab's sections list with the terminal
  /// manager's current terminals, keeping stable [SingleTerminalView]
  /// instances across rebuilds.
  void _syncTerminalSections() {
    final tab = _terminalTab;
    if (tab == null) return;
    final terminals = widget.shell.terminals;

    // Remove views for terminals no longer in the manager.
    _terminalSectionViews.removeWhere(
      (t, _) => !terminals.terminals.contains(t),
    );

    // Add views for newly opened terminals.
    for (final t in terminals.terminals) {
      _terminalSectionViews.putIfAbsent(
        t,
        () => SingleTerminalView(terminal: t),
      );
    }

    // Update the sections list preserving terminal manager order.
    // Some layouts declare tabs/sections with const constructors, making
    // `tab.sections` unmodifiable at runtime. In that case we replace the
    // terminal tab entry with a new mutable sections list.
    final nextSections =
        terminals.terminals.map((t) => _terminalSectionViews[t]!).toList();
    try {
      tab.sections
        ..clear()
        ..addAll(nextSections);
    } on UnsupportedError {
      final tabs = widget.application.layout.bottomPanel.tabs;
      final index = tabs.indexOf(tab);
      if (index >= 0) {
        try {
          tabs[index] = PanelTabConfig(
            title: tab.title,
            icon: tab.icon,
            sections: nextSections,
          );
        } on UnsupportedError {
          // If the tabs list itself is immutable, skip syncing instead of
          // crashing the scaffold. Existing sections remain as-is.
        }
      }
    }
  }

  void _onNotificationPopupChanged() {
    if (mounted) {
      setState(() {
        _notificationPopupVisible =
            widget.notificationManager.popupVisible.value;
      });
    }
  }

  void _onPreferencesChanged() {
    try {
      _applyPreferenceTextSettings();
      _applyPreferenceFileTypeDefaults();
      _applyPreferenceShortcutOverrides();
      _propagateSettingsToActiveEditors();
      ForgeAnimations.reduceMotion = _preferences.reduceMotion;
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
      final typeId = _editorTypeId(editor);
      if (typeId == null) continue;
      final settings = widget.shell.getTextSettings(typeId);
      final options = ForgeTextEditorOptions(
        tabSize: settings.tabSize,
        insertSpaces: settings.insertSpaces,
        wordWrap: settings.wordWrap ? ForgeWordWrap.on : ForgeWordWrap.off,
        fontFamily: settings.fontFamily,
        fontSize: settings.fontSize,
        lineHeight: settings.lineHeight,
        showLineNumbers: settings.showLineNumbers,
        highlightCurrentLine: settings.highlightCurrentLine,
      );
      if (editor is ForgeTextEditor) {
        editor.updateOptions(options);
      } else if (editor is ForgeYamlEditor) {
        editor.updateOptions(options);
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
    // Also propagate editor-specific config.
    for (final editorTypeId in ['dart', 'md', 'yaml']) {
      final config = _preferences.getEditorSpecificConfig(editorTypeId);
      if (config.isNotEmpty) {
        widget.shell.setEditorSpecificConfig(editorTypeId, config);
      }
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
    final shortcuts = widget.shell.shortcuts;
    final isDeferrable = shortcuts is DefaultShortcutManager;

    // Load user-deleted bindings so rebind() skips them.
    if (isDeferrable) {
      shortcuts.loadSuppressedActions(_preferences.deletedBindings);
      // Clear deferred overrides before re-populating from current
      // preferences so removed overrides are cleaned up.
      shortcuts.clearDeferredOverrides();
    }

    final overrides = _preferences.shortcutOverrides;
    for (final entry in overrides.entries) {
      // Always store in deferred map so rebind() uses the override
      // even when modules re-register actions later.
      if (isDeferrable && !entry.key.startsWith('*.')) {
        shortcuts.setDeferredShortcutOverride(entry.key, entry.value);
      }
      final binding = shortcuts.getBinding(entry.key);
      if (binding != null) {
        shortcuts.rebind(binding.action, entry.value);
      } else if (entry.key.startsWith('*.')) {
        // Wildcard action override: create a placeholder action for
        // the wildcard binding. The actual dispatch happens in
        // DefaultShellApi.executeAction which resolves the wildcard.
        final suffix = entry.key.substring(2);
        final wildcardAction = shell_action.ForgeAction(
          id: entry.key,
          label: '$suffix (all editors)',
          menu: shell_action.ForgeMenuLocation.commandPalette,
          execute: (_) async => null,
          isEnabled: () => true,
          isVisible: () => true,
        );
        widget.shell.actionRegistry.registerAction(wildcardAction);
        shortcuts.rebind(wildcardAction, entry.value);
      }
    }
    final chordOverrides = _preferences.chordOverrides;
    for (final entry in chordOverrides.entries) {
      if (isDeferrable) {
        // Unsuppress the action so rebindChord doesn't skip it
        // (chord override takes precedence over a previous deletion).
        shortcuts.unsuppressAction(entry.key);
        // Always store in deferred map so rebind() redirects to
        // rebindChord() even when modules re-register actions later.
        shortcuts.setDeferredChordOverride(entry.key, entry.value);
      }
      final binding = shortcuts.getBinding(entry.key);
      if (binding != null) {
        shortcuts.rebindChord(binding.action, entry.value);
      } else {
        // Action may be registered in the action registry but have no
        // shortcut binding yet. Look it up and create a chord binding
        // directly instead of deferring.
        final action = widget.shell.actionRegistry.getAction(entry.key);
        if (action != null) {
          shortcuts.rebindChord(action, entry.value);
        }
      }
    }
  }

  /// Restores panel sizes, visibility, and previously-open editors.
  ///
  /// Tries SharedPreferences first, then falls back to `.forge/state/`
  /// files for workspace-scoped recovery.
  Future<void> _restoreLayoutState() async {
    // If the user checked "Reset UI", skip all restoration.
    if (_preferences.layoutResetRequested) {
      _preferences.clearLayoutResetRequest();
      return;
    }

    final savedSnapshot = _preferences.layoutSnapshot;
    if (savedSnapshot.isNotEmpty) {
      await _applyLayoutSnapshot(savedSnapshot);
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
            await _applyLayoutSnapshot(layoutData);
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
          await _applyLayoutSnapshot(layout);
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
      // Throttle: skip if a revision was created less than 30s ago.
      final now = DateTime.now();
      final lastTime = _lastRevisionTime[uri];
      if (lastTime != null && now.difference(lastTime) < _revisionMinInterval) {
        _scheduleLayoutPersistence();
        return;
      }
      try {
        final content = await widget.shell.fileSystem.read(uri);
        await wsState.createRevision(uri, content);
        await wsState.pruneRevisions(uri);
        _lastRevisionTime[uri] = now;
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
      if (saveOwnedEditor(editor, trigger: ForgeSaveTrigger.automatic) != null) {
        continue;
      }
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

  /// Saves the active editor's content to the file system and marks it clean.
  void _saveActiveEditor() {
    final editor = widget.systemState.activeEditor;
    if (editor == null || !editor.isDirty.value) return;
    if (saveOwnedEditor(editor) != null) return;
    final content = editor.getContent();
    if (content == null) return;
    widget.shell.fileSystem.write(editor.uri, content).then((_) {
      return widget.shell.fileSystem.save(editor.uri);
    }).then((_) {
      editor.markClean();
      if (debugEnabled) {
        debugPrint('[ForgeShellScaffold] saved: ${editor.uri}');
      }
    }).catchError((Object e) {
      if (debugEnabled) {
        debugPrint('[ForgeShellScaffold] save failed for ${editor.uri}: $e');
      }
    });
  }

  /// Saves all dirty editors' content to the file system and marks them clean.
  void _saveAllDirtyEditors() {
    final dirtyEditors = widget.systemState.dirtyEditors.toList();
    for (final editor in dirtyEditors) {
      if (saveOwnedEditor(editor) != null) continue;
      final content = editor.getContent();
      if (content == null) continue;
      widget.shell.fileSystem.write(editor.uri, content).then((_) {
        return widget.shell.fileSystem.save(editor.uri);
      }).then((_) {
        editor.markClean();
        if (debugEnabled) {
          debugPrint('[ForgeShellScaffold] saved all: ${editor.uri}');
        }
      }).catchError((Object e) {
        if (debugEnabled) {
          debugPrint(
            '[ForgeShellScaffold] save all failed for ${editor.uri}: $e',
          );
        }
      });
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
    // Ensure the left panel is visible.
    final leftPanel = _layout.leftPanel.value;
    if (!leftPanel.isVisible) {
      _layout.openPanel(ForgePanelLocation.left);
    }
    // Ensure the right panel is visible so the user sees the full layout.
    final rightPanel = _layout.rightPanel.value;
    if (!rightPanel.isVisible) {
      _layout.openPanel(ForgePanelLocation.right);
    }
    // Toggle the config panel inside the left side panel.
    _configPanelVisible.value = true;
  }

  /// Resets all panel sizes (left, right, bottom) to their defaults.
  void _resetPanelSizes() {
    _layout.resetPanelSizes(
      leftSize: _preferences.leftPanelDefaultWidth,
      rightSize: _preferences.rightPanelDefaultWidth,
      bottomSize: _preferences.bottomPanelDefaultHeight,
    );
    setState(() {});
  }

  /// Moves cross-panel items back to their original locations:
  /// - Editors that were dragged to side/bottom panels return to the middle.
  /// - Views that were dragged to the middle panel are closed there.
  void _resetPanelLocations() {
    final layout = widget.application.layout;

    // Collect editors wrapped as views in side/bottom panels and move back.
    for (final panel in [layout.leftPanel, layout.rightPanel, layout.bottomPanel]) {
      for (final tab in panel.tabs) {
        final adapters = tab.sections
            .whereType<_EditorViewAdapter>()
            .toList();
        for (final adapter in adapters) {
          tab.sections.remove(adapter);
          // Re-open the wrapped editor in the middle panel.
          _layout.moveComponent(adapter.editor, _layout.activeMiddlePanelIndex);
        }
      }
    }

    // Close view-wrapping adapters from the middle panel.
    final middlePanels = _layout.middlePanels.value;
    for (final panel in middlePanels) {
      final viewAdapters = panel
          .whereType<_ViewEditorAdapter>()
          .toList();
      for (final adapter in viewAdapters) {
        _layout.closeEditor(adapter);
      }
    }

    setState(() {});
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

  /// Overrides the placeholder execute callbacks registered by
  /// [TomForgeShellModule] with widget-level implementations that have
  /// access to scaffold state (command palette, find bar, layout, etc.).
  ///
  /// The module provides the actions and shortcut bindings so they appear
  /// in the Shortcut Editor.  This method only replaces the execute logic.
  void _registerShellShortcuts() {
    void overrideAction(
      String id,
      String label,
      VoidCallback handler, {
      bool Function()? isEnabled,
    }) {
      final action = shell_action.ForgeAction(
        id: id,
        label: label,
        menu: shell_action.ForgeMenuLocation.commandPalette,
        execute: (_) async {
          handler();
          return null;
        },
        isEnabled: isEnabled ?? () => true,
        isVisible: () => true,
      );
      widget.shell.actionRegistry.registerAction(action);
    }

    overrideAction(
      'forge.commandPalette',
      'Command Palette',
      _toggleCommandPalette,
    );
    overrideAction(
      'forge.openSettings',
      'Open Settings',
      _openSettings,
    );
    overrideAction(
      'forge.toggleLeftPanel',
      'Toggle Left Panel',
      () => widget.shell.layout.togglePanel(ForgePanelLocation.left),
    );
    overrideAction(
      'forge.toggleRightPanel',
      'Toggle Right Panel',
      () => widget.shell.layout.togglePanel(ForgePanelLocation.right),
    );
    overrideAction(
      'forge.toggleBottomPanel',
      'Toggle Bottom Panel',
      () => widget.shell.layout.togglePanel(ForgePanelLocation.bottom),
    );
    overrideAction(
      'forge.focusSearch',
      'Focus Search',
      () => _openFindReplaceBar(showReplaceFields: false),
      isEnabled: () => _activeTextEditor != null,
    );
    overrideAction(
      'forge.focusPanel1',
      'Focus Panel 1',
      () {
        if ((_layout.middlePanels.value).isNotEmpty) {
          _layout.setActiveMiddlePanelIndex(0);
        }
        widget.systemState.setFocusedPanelLocation(ForgePanelLocation.middle);
      },
    );
    overrideAction(
      'forge.focusPanel2',
      'Focus Panel 2',
      () {
        if ((_layout.middlePanels.value).length > 1) {
          _layout.setActiveMiddlePanelIndex(1);
        }
        widget.systemState.setFocusedPanelLocation(ForgePanelLocation.middle);
      },
    );
    overrideAction(
      'forge.focusPanel3',
      'Focus Panel 3',
      () {
        if ((_layout.middlePanels.value).length > 2) {
          _layout.setActiveMiddlePanelIndex(2);
        }
        widget.systemState.setFocusedPanelLocation(ForgePanelLocation.middle);
      },
    );
    overrideAction(
      'forge.focusPanel4',
      'Focus Panel 4',
      () {
        if ((_layout.middlePanels.value).length > 3) {
          _layout.setActiveMiddlePanelIndex(3);
        }
        widget.systemState.setFocusedPanelLocation(ForgePanelLocation.middle);
      },
    );
    overrideAction(
      'forge.saveAll',
      'Save All',
      () => widget.shell.executeAction('file.saveAll'),
    );
    overrideAction(
      'forge.focusNextPanel',
      'Focus Next Panel',
      () => widget.systemState.focusNextPanel(),
    );
    overrideAction(
      'forge.focusPreviousPanel',
      'Focus Previous Panel',
      () => widget.systemState.focusPreviousPanel(),
    );

    // ── File save actions ──
    // These are the concrete save implementations that menu items
    // and keyboard shortcuts delegate to (file.save, file.saveAll).
    overrideAction(
      'file.save',
      'Save',
      () => _saveActiveEditor(),
    );
    overrideAction(
      'file.saveAll',
      'Save All',
      () => _saveAllDirtyEditors(),
    );
    overrideAction(
      'file.close',
      'Close Editor',
      () {
        final editor = widget.systemState.activeEditor;
        if (editor != null && mounted) {
          // ignore: discarded_futures
          _handleCloseEditor(editor);
        }
      },
      isEnabled: () => widget.systemState.activeEditor != null,
    );
    overrideAction(
      'file.openFolder',
      'Open Folder...',
      () {
        // ignore: discarded_futures
        _handleOpenFolder();
      },
    );
  }

  Future<void> _handleOpenFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Open Workspace Folder',
    );
    if (result == null || !mounted) return;
    widget.onOpenFolder?.call(Directory(result));
  }

  /// Subscribes to the active editor's [onStateChanged] stream so the
  /// action bar re-evaluates enablement when selection or undo state changes.
  /// Cancels any previous subscription first.
  void _subscribeToEditorStateChanges() {
    _selectionChangeSubscription?.cancel();
    _selectionChangeSubscription = null;
    final editor = widget.systemState.activeEditor;
    if (editor != null) {
      _selectionChangeSubscription = editor.onStateChanged.listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _onActiveEditorChanged() {
    // Re-subscribe to the new active editor's state-change stream so the
    // action bar refreshes enablement when selection/undo state changes.
    _subscribeToEditorStateChanges();

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
      const PopupMenuDivider(),
      const PopupMenuItem<String>(
        value: 'cmd.editActionBar',
        child: Text('Edit Action Bar...'),
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
      case 'cmd.editActionBar':
        _showEditActionBarDialog(editor);
        break;
      default:
        if (selected.startsWith('action.')) {
          final actionId = selected.substring('action.'.length);
          widget.shell.executeAction(actionId);
        }
        break;
    }
  }

  /// Shows a dialog to edit the action bar for the current editor type.
  Future<void> _showEditActionBarDialog(ForgeEditor editor) async {
    final editorTypeId = _editorTypeId(editor);
    if (editorTypeId == null) {
      widget.shell.notifications.showWarning(
        'Cannot edit action bar for this editor type',
      );
      return;
    }

    // Get current action bar configuration.
    final currentActions = _preferences.getActionBarActions(editorTypeId);
    final effectiveActions = currentActions.isNotEmpty
        ? currentActions
        : List<String>.from(_defaultActionBarActions);

    // Get all available actions with icons from the action registry.
    // This includes actions without shortcuts (like Open Reference).
    final allActions = widget.shell.actionRegistry.allActions;
    final availableActions = <(String, String, IconData?)>[];
    final seenIds = <String>{};
    for (final action in allActions) {
      if (!seenIds.add(action.id)) continue;
      if (action.icon == null) continue; // Only show actions with icons.
      availableActions.add((action.id, action.label, action.icon));
    }

    // Sort available actions: current editor first, then by label.
    final editorPrefix = _actionPrefixForEditorType(editorTypeId);
    availableActions.sort((a, b) {
      final aIsEditor = a.$1.startsWith(editorPrefix);
      final bIsEditor = b.$1.startsWith(editorPrefix);
      if (aIsEditor && !bIsEditor) return -1;
      if (bIsEditor && !aIsEditor) return 1;
      return a.$2.compareTo(b.$2);
    });

    final result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => _EditActionBarDialog(
        editorTypeId: editorTypeId,
        currentActions: effectiveActions,
        availableActions: availableActions,
      ),
    );

    if (result != null && mounted) {
      _preferences.setActionBarActions(editorTypeId, result);
      await _preferences.save();
      setState(() {}); // Rebuild to show new action bar.
    }
  }

  /// Returns the action ID prefix for an editor type.
  String _actionPrefixForEditorType(String editorTypeId) {
    switch (editorTypeId) {
      case 'dart':
        return 'dart.';
      case 'md':
        return 'md.';
      case 'yaml':
        return 'yaml.';
      default:
        return 'forge.edit.';
    }
  }

  /// Listens for chord completions to execute the bound action.
  ///
  /// When a chord is entered, opens the quick-open dropdown in chord mode.
  /// When a chord completes or is cancelled, closes the quick-open.
  void _listenForChordCompletions() {
    _chordSubscription = widget.shell.shortcuts.onChordStateChanged.listen((
      event,
    ) {
      switch (event.state) {
        case ForgeChordState.entered:
          // Open quick-open in chord mode with the completions.
          _openQuickOpenChord(event.firstKey!, event.completions);
        case ForgeChordState.completed:
          if (event.executedBinding != null) {
            widget.shell.executeAction(event.executedBinding!.action.id);
          }
          _closeQuickOpen();
        case ForgeChordState.cancelled:
          _closeQuickOpen();
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
    // However, if the user presses the menu trigger combo again
    // (Shift+PrimaryModifier+key), close the current menu first and
    // attempt to open a new one instead of routing into handleMenuKey.
    if (widget.shell.shortcuts.activeMenu != null) {
      if (shortcutKey.shift && shortcutKey.primaryModifier && !shortcutKey.alt) {
        widget.shell.shortcuts.closeMenu();
        // Fall through to the openMenu check below.
      } else {
        // The user may still hold Shift+Cmd/Ctrl — strip modifiers and
        // match on the bare key.
        widget.shell.shortcuts.handleMenuKey(shortcutKey.key);
        return KeyEventResult.handled;
      }
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
    Widget body = Shortcuts(
      shortcuts: _buildShortcuts(),
      child: Actions(
        actions: _buildActions(),
        child: Focus(
          onKeyEvent: _handleChordKeyEvent,
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
                  // Notification popup anchored above the status bar.
                  if (_notificationPopupVisible)
                    Positioned(
                      bottom: ForgeDimensions.statusBarHeight + 4,
                      right: 12,
                      child: ForgeNotificationPopup(
                        manager: widget.notificationManager,
                        onClose: () => widget
                            .notificationManager.popupVisible.value = false,
                      ),
                    ),
                  // Shortcut menu overlay (concept §11.4).
                  ForgeShortcutMenuPopup(
                    shortcutManager: widget.shell.shortcuts,
                  ),
                  // Chord completions are shown via the quick-open dropdown
                  // in chord mode (_openQuickOpenChord). The standalone
                  // ForgeChordOverlay was removed to avoid duplicate display.
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
                  if (_showCommandPalette && _quickOpenMode != null)
                    _buildQuickOpenOverlay(),
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
        label: widget.application.title,
        menus: [
          PlatformMenuItemGroup(members: [
            const PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.about,
            ),
          ]),
          PlatformMenuItemGroup(members: [
            const PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.quit,
            ),
          ]),
        ],
      ),
      PlatformMenu(
        label: 'File',
        menus: [
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: 'New File',
              onSelected: () => widget.shell.executeAction('file.new'),
            ),
            PlatformMenuItem(
              label: 'Open Folder...',
              onSelected: () => widget.shell.executeAction('file.openFolder'),
            ),
          ]),
          // Concept §11.3: Cmd+S = "Save all dirty editors".
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: 'Save All',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyS,
                meta: true,
              ),
              onSelected: () => widget.shell.executeAction('file.saveAll'),
            ),
            PlatformMenuItem(
              label: 'Close Editor',
              onSelected: () => widget.shell.executeAction('file.close'),
            ),
          ]),
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(label: 'Settings...', onSelected: _openSettings),
          ]),
        ],
      ),
      PlatformMenu(
        label: 'Edit',
        menus: [
          // Concept §11.3: Cmd+U = Undo, Cmd+Z = Redo.
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: 'Undo',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyU,
                meta: true,
              ),
              onSelected: () => widget.shell.executeAction('edit.undo'),
            ),
            PlatformMenuItem(
              label: 'Redo',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyZ,
                meta: true,
              ),
              onSelected: () => widget.shell.executeAction('edit.redo'),
            ),
          ]),
          PlatformMenuItemGroup(members: [
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
          ]),
          // Concept §11.3: Cmd+F = Find in focused component.
          PlatformMenuItemGroup(members: [
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
          ]),
        ],
      ),
      PlatformMenu(
        label: 'View',
        menus: [
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: 'Command Palette...',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyP,
                meta: true,
                shift: true,
              ),
              onSelected: _toggleCommandPalette,
            ),
          ]),
          PlatformMenuItemGroup(members: [
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
          ]),
        ],
      ),
      PlatformMenu(
        label: 'Go',
        menus: [
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(label: 'Back', onSelected: () {}),
            PlatformMenuItem(label: 'Forward', onSelected: () {}),
          ]),
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: 'Go to File...',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyP,
                meta: true,
                shift: true,
              ),
              onSelected: _toggleCommandPalette,
            ),
          ]),
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

      final shortcuts = <ShortcutActivator, Intent>{
        primaryActivator(LogicalKeyboardKey.keyP):
          const _ActionPaletteIntent(),
        primaryActivator(LogicalKeyboardKey.keyP, shift: true):
            const _CommandPaletteIntent(),
        const SingleActivator(LogicalKeyboardKey.f1):
            const _CommandPaletteIntent(),
        primaryActivator(LogicalKeyboardKey.keyL):
            const _ToggleLeftPanelIntent(),
        primaryActivator(LogicalKeyboardKey.keyR):
            const _ToggleRightPanelIntent(),
        primaryActivator(LogicalKeyboardKey.keyB):
            const _ToggleBottomPanelIntent(),
        primaryActivator(LogicalKeyboardKey.keyF):
            const _FocusSearchIntent(),
        primaryActivator(LogicalKeyboardKey.digit1):
            const _FocusMiddlePanelIntent(0),
        primaryActivator(LogicalKeyboardKey.digit2):
            const _FocusMiddlePanelIntent(1),
        primaryActivator(LogicalKeyboardKey.digit3):
            const _FocusMiddlePanelIntent(2),
        primaryActivator(LogicalKeyboardKey.digit4):
            const _FocusMiddlePanelIntent(3),
        primaryActivator(LogicalKeyboardKey.bracketRight):
            const _FocusNextPanelIntent(),
        primaryActivator(LogicalKeyboardKey.bracketLeft):
            const _FocusPreviousPanelIntent(),
        primaryActivator(LogicalKeyboardKey.keyS): const _SaveIntent(),
      };

      // Module direct (non-chord) bindings are dispatched by
      // _handleChordKeyEvent via the allBindings lookup.  They are NOT
      // duplicated here to avoid showing duplicate entries in the
      // shortcut configuration UI.

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
      _ActionPaletteIntent: CallbackAction<_ActionPaletteIntent>(
        onInvoke: (_) {
          if (_quickOpenMode == QuickOpenMode.actions) {
            _closeQuickOpen();
          } else {
            _openQuickOpen(QuickOpenMode.actions);
          }
          return null;
        },
      ),
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
      _ToggleBottomPanelIntent: CallbackAction<_ToggleBottomPanelIntent>(
        onInvoke: (_) {
          widget.shell.layout.togglePanel(ForgePanelLocation.bottom);
          return null;
        },
      ),
      _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
        onInvoke: (_) {
          _openFindReplaceBar(showReplaceFields: false);
          return null;
        },
      ),
      _FocusMiddlePanelIntent: CallbackAction<_FocusMiddlePanelIntent>(
        onInvoke: (intent) {
          final panelIndex = intent.panelIndex;
          final panelCount =
              (_layout.middlePanels.value).length;
          if (panelIndex < panelCount) {
            _layout.setActiveMiddlePanelIndex(panelIndex);
          }
          widget.systemState.setFocusedPanelLocation(ForgePanelLocation.middle);
          ForgeAccessibility.announcePolite(
            'Middle panel ${panelIndex + 1} focused',
          );
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
          widget.shell.executeAction('file.saveAll');
          return null;
        },
      ),
      _ModuleActionIntent: CallbackAction<_ModuleActionIntent>(
        onInvoke: (intent) {
          widget.shell.executeAction(intent.actionId);
          return null;
        },
      ),
    };
  }

  void _toggleCommandPalette() {
    if (_quickOpenMode != null) {
      _closeQuickOpen();
    } else {
      _openQuickOpen(QuickOpenMode.all);
    }
  }

  /// Opens the quick-open palette when the user starts typing in the search
  /// field while the palette is not already visible.
  void _onSearchFieldChanged() {
    if (_quickOpenMode != null) return;
    if (_quickOpenSearchController.text.isNotEmpty) {
      setState(() {
        _showCommandPalette = true;
        _quickOpenMode = QuickOpenMode.all;
      });
    }
  }

  void _openQuickOpen(QuickOpenMode mode) {
    setState(() {
      _showCommandPalette = true;
      _quickOpenMode = mode;
      _quickOpenSearchController.clear();
    });
    _quickOpenFocusNode.requestFocus();
    ForgeAccessibility.announceAssertive(
      mode == QuickOpenMode.actions
          ? 'Action palette opened'
          : 'Quick open search opened',
    );
  }

  void _openQuickOpenChord(
    ForgeShortcutKey firstKey,
    List<ForgeShortcutBinding> completions,
  ) {
    // Cancel the auto-close timer — the UI now owns the chord lifecycle.
    final shortcuts = widget.shell.shortcuts;
    if (shortcuts is DefaultShortcutManager) {
      shortcuts.cancelChordTimer();
    }
    setState(() {
      _showCommandPalette = true;
      _quickOpenMode = QuickOpenMode.chord;
      _chordFirstKeyForQuickOpen = firstKey;
      _chordCompletionsForQuickOpen = completions;
      _quickOpenSearchController.clear();
    });
    _quickOpenFocusNode.requestFocus();
    ForgeAccessibility.announceAssertive(
      'Chord shortcut: press second key',
    );
  }

  void _closeQuickOpen() {
    // Cancel any pending chord state so subsequent key presses work normally.
    if (widget.shell.shortcuts.isChordPending) {
      widget.shell.shortcuts.cancelChord();
    }
    setState(() {
      _showCommandPalette = false;
      _quickOpenMode = null;
      _chordFirstKeyForQuickOpen = null;
      _chordCompletionsForQuickOpen = const [];
      _quickOpenSearchController.clear();
    });
    // Return focus to the scaffold so keyboard shortcuts work again.
    // The search field TextField steals focus; unfocusing it lets the
    // scaffold's Focus(autofocus: true) reclaim events.
    _quickOpenFocusNode.unfocus();
  }

  void _openHelpDocument() {
    // Write the help markdown to the workspace and open it.
    final root = widget.systemState.workspaceRootPath;
    final helpPath = '$root/.forge/help/keyboard_shortcuts.md';
    final helpFile = File(helpPath);
    if (!helpFile.existsSync()) {
      helpFile.parent.createSync(recursive: true);
      helpFile.writeAsStringSync(_keyboardShortcutsHelpContent);
    }
    _layout.openFile(Uri.file(helpPath));
  }

  static const _keyboardShortcutsHelpContent = '''
# Keyboard Shortcuts

## Quick Open

| Shortcut | Action |
|----------|--------|
| Click search bar | Search files, actions, and settings |
| Ctrl+P / Cmd+P | Search actions only |
| F1 | Open quick open (all) |
| Escape | Close quick open |

## Navigation

| Shortcut | Action |
|----------|--------|
| Ctrl+L / Cmd+L | Toggle left panel |
| Ctrl+R / Cmd+R | Toggle right panel |
| Ctrl+1 / Cmd+1 | Focus middle panel 1 |
| Ctrl+2 / Cmd+2 | Focus middle panel 2 |
| Ctrl+3 / Cmd+3 | Focus middle panel 3 |
| Ctrl+4 / Cmd+4 | Focus middle panel 4 |

## Chord Shortcuts

Press the first key combination, then the second key to execute.

When a chord is active, the search bar shows available completions.
Press "?" for this help document.

## Editing

| Shortcut | Action |
|----------|--------|
| Ctrl+S / Cmd+S | Save all |

---

*This document will be expanded with more shortcuts as they are added.*
''';

  Widget _buildQuickOpenOverlay() {
    // Position the dropdown below the search bar.
    return GestureDetector(
      onTap: _closeQuickOpen,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned(
              top: ForgeDimensions.titleBarHeight,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {}, // Prevent dismiss when tapping dropdown.
                  child: SizedBox(
                    width: 400,
                    child: ForgeQuickOpen(
                      key: _quickOpenWidgetKey,
                      shellApi: widget.shell,
                      mode: _quickOpenMode!,
                      onDismiss: _closeQuickOpen,
                      initialQuery: _quickOpenSearchController.text,
                      chordFirstKey: _chordFirstKeyForQuickOpen,
                      chordCompletions: _chordCompletionsForQuickOpen,
                      searchController: _quickOpenSearchController,
                      searchFocusNode: _quickOpenFocusNode,
                      searchConfig: _preferences.searchConfig,
                      onOpenFile: (uri) => _layout.openFile(uri),
                      onOpenHelp: _openHelpDocument,
                      onOpenSettings: _openSettings,
                      configSectionTarget: _configSectionTarget,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: ForgeDimensions.titleBarHeight,
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Left cluster: action bar.
          _buildActionBar(context),
          const SizedBox(width: 8),
          // Center cluster: nav buttons + search field + application switcher.
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth;
                  final switcherMaxWidth = availableWidth < 520 ? 120.0 : 180.0;
                  // Fixed-width siblings the search box shares the row with:
                  // the two 48px back/forward IconButtons plus the inter-child
                  // spacing (8 before the search box, 12 after it). These must
                  // be reserved so the min-sized row never overflows.
                  const navButtonsWidth = 96.0;
                  const rowSpacing = 8.0 + 12.0;
                  final searchWidth = (availableWidth -
                          navButtonsWidth -
                          switcherMaxWidth -
                          rowSpacing)
                      .clamp(180.0, 400.0)
                      .toDouble();

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Back/Forward navigation (per concept §2.1)
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
                      const SizedBox(width: 8),
                      SizedBox(
                        key: _searchBoxKey,
                        width: searchWidth,
                        height: 32,
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              // Command Palette icon button.
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  icon: Icon(
                                    Icons.terminal,
                                    size: 16,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                  tooltip: 'Command Palette',
                                  onPressed: _toggleCommandPalette,
                                ),
                              ),
                              Expanded(
                                child: Focus(
                                  onKeyEvent: _handleSearchFieldKeyEvent,
                                  child: TextField(
                                    controller: _quickOpenSearchController,
                                    focusNode: _quickOpenFocusNode,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: _quickOpenMode == QuickOpenMode.actions
                                        ? 'Type an action...'
                                        : _quickOpenMode == QuickOpenMode.chord
                                            ? 'Search shortcuts or press key...'
                                            : 'Search files, actions, and settings',
                                    hintStyle:
                                        theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    isDense: true,
                                  ),
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                                  Expanded(child: Text(app.displayTitle)),
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
                                  widget.application.displayTitle,
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
          // Right cluster: layout reset buttons.
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.flip_to_front,
              size: ForgeDimensions.iconToolbar,
            ),
            onPressed: _resetPanelLocations,
            tooltip: 'Reset Panel Locations',
          ),
          IconButton(
            icon: Icon(
              Icons.fit_screen_outlined,
              size: ForgeDimensions.iconToolbar,
            ),
            onPressed: _resetPanelSizes,
            tooltip: 'Reset Panel Sizes',
          ),
        ],
      ),
    );
  }

  /// Default action IDs shown in the action bar when no custom config exists.
  static const List<String> _defaultActionBarActions = [
    'forge.edit.cut',
    'forge.edit.copy',
    'forge.edit.paste',
    'forge.edit.undo',
    'forge.edit.redo',
  ];

  /// Builds the action bar with quick-access action buttons.
  ///
  /// Shows actions from the user's preference, or defaults if none configured.
  Widget _buildActionBar(BuildContext context) {
    final theme = Theme.of(context);
    final activeEditor = widget.systemState.activeEditor;
    final editorTypeId = activeEditor != null ? _editorTypeId(activeEditor) : null;

    // Get configured actions for current editor type, or fall back to defaults.
    List<String> actionIds;
    if (editorTypeId != null) {
      final configured = _preferences.getActionBarActions(editorTypeId);
      actionIds = configured.isNotEmpty ? configured : _defaultActionBarActions;
    } else {
      actionIds = _defaultActionBarActions;
    }

    // Build action buttons.
    final buttons = <Widget>[];
    final isStandardAction = StandardEditingActions.standardActionIds.contains;
    final snapshot = activeEditor?.stateSnapshot;
    for (final actionId in actionIds) {
      // Find the action in the registry for icon/label/shortcut metadata.
      final action = widget.shell.actionRegistry.getAction(actionId);
      if (action == null) continue;

      // Standard editing actions derive enablement from the editor's
      // state snapshot; other actions use the registry's isEnabled().
      final bool isEnabled;
      if (isStandardAction(actionId) && snapshot != null) {
        final rule = StandardEditingActions.enablementRule(actionId);
        isEnabled = rule(snapshot);
      } else {
        isEnabled = action.isEnabled();
      }

      // Get shortcut display string if available.
      final binding = widget.shell.shortcuts.getBinding(actionId);

      buttons.add(
        Tooltip(
          message: binding != null
              ? '${action.label}\n${binding.displayString}'
              : action.label,
          child: InkWell(
            onTap: isEnabled
                ? () => widget.shell.executeAction(actionId)
                : null,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                action.icon ?? Icons.extension,
                size: ForgeDimensions.iconToolbar,
                color: isEnabled
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      );
    }

    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: buttons,
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
                // Left Panel — always in tree to preserve state
                Visibility(
                  visible: leftConfig.isVisible,
                  maintainState: true,
                  child: _buildSidePanel(
                    context,
                    width: leftConfig.size,
                    tabs: widget.application.layout.leftPanel.tabs,
                    iconStripPosition: IconStripPosition.left,
                    panelArea: PanelArea.left,
                    showConfigTab: true,
                    configurationPanelBuilder: _buildConfigurationPanel,
                    configPanelVisible: _configPanelVisible,
                    initialActiveTabIndex: _leftPanelActiveTab,
                    initialShowConfig: _leftPanelShowConfig,
                    onTabChanged: (idx, showConfig) {
                      _leftPanelActiveTab = idx;
                      _leftPanelShowConfig = showConfig;
                      _scheduleLayoutPersistence();
                    },
                  ),
                ),
                if (leftConfig.isVisible)
                  _buildVerticalResizeHandle(
                    onDragDelta: _resizeLeftPanel,
                    onDoubleTap: () => _layout.setPanelSize(
                      ForgePanelLocation.left,
                      _preferences.leftPanelDefaultWidth,
                    ),
                  ),

                // Middle area: editor panels + bottom panel
                Expanded(child: _buildCenterColumn(context)),

                // Right Panel — always in tree to preserve state
                if (rightConfig.isVisible)
                  _buildVerticalResizeHandle(
                    onDragDelta: _resizeRightPanel,
                    onDoubleTap: () => _layout.setPanelSize(
                      ForgePanelLocation.right,
                      _preferences.rightPanelDefaultWidth,
                    ),
                  ),
                Visibility(
                  visible: rightConfig.isVisible,
                  maintainState: true,
                  child: _buildSidePanel(
                    context,
                    width: rightConfig.size,
                    tabs: widget.application.layout.rightPanel.tabs,
                    iconStripPosition: IconStripPosition.right,
                    panelArea: PanelArea.right,
                    showConfigTab: false,
                    initialActiveTabIndex: _rightPanelActiveTab,
                    onTabChanged: (idx, _) {
                      _rightPanelActiveTab = idx;
                      _scheduleLayoutPersistence();
                    },
                  ),
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
            // Bottom panel — always in tree to preserve state
            if (bottomConfig.isVisible)
              _buildHorizontalResizeHandle(
                onDragDelta: _resizeBottomPanel,
                onDoubleTap: () => _layout.setPanelSize(
                  ForgePanelLocation.bottom,
                  _preferences.bottomPanelDefaultHeight,
                ),
              ),
            Visibility(
              visible: bottomConfig.isVisible,
              maintainState: true,
              child: _buildBottomPanel(context, bottomConfig),
            ),
          ],
        );
      },
    );
  }

  void _resizeLeftPanel(double deltaX) {
    final current = _layout.leftPanel.value;
    final nextSize = (current.size + deltaX).clamp(
      ForgeDimensions.panelMinSize,
      double.infinity,
    );
    _layout.setPanelSize(ForgePanelLocation.left, nextSize);
  }

  void _resizeRightPanel(double deltaX) {
    final current = _layout.rightPanel.value;
    final nextSize = (current.size - deltaX).clamp(
      ForgeDimensions.panelMinSize,
      double.infinity,
    );
    _layout.setPanelSize(ForgePanelLocation.right, nextSize);
  }

  void _resizeBottomPanel(double deltaY) {
    final current = _layout.bottomPanel.value;
    final nextSize = (current.size - deltaY).clamp(
      ForgeDimensions.panelMinSize,
      double.infinity,
    );
    _layout.setPanelSize(ForgePanelLocation.bottom, nextSize);
  }

  /// Resize middle panels by adjusting flex factors of adjacent panels.
  void _resizeMiddlePanelDivider(int leftIdx, int rightIdx, double delta) {
    if (leftIdx < 0 || rightIdx >= _middlePanelFlex.length) return;
    const minFlex = 0.15;
    final totalFlex = _middlePanelFlex[leftIdx] + _middlePanelFlex[rightIdx];
    // Convert pixel delta to flex delta using actual middle-area width.
    final width = _middleAreaWidth;
    if (width <= 0) return;
    final flexDelta = delta * totalFlex / width;
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
      _middlePanelFlex =
          List<double>.filled(_middlePanelFlex.length, 1.0, growable: true);
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
    if (_isRestoringLayout) return;
    _layoutPersistTimer?.cancel();
    _layoutPersistTimer = Timer(_layoutPersistDebounce, () {
      _saveLayoutState();
      _saveWorkspaceState();
    });
  }

  bool _isLayoutSnapshot(Map<String, dynamic> data) {
    return data.containsKey('panels') && data.containsKey('middlePanels');
  }

  Future<void> _applyLayoutSnapshot(Map<String, dynamic> snapshot) async {
    _layout.loadLayoutSnapshot(snapshot);

    final middleFlex = snapshot['middlePanelFlex'];
    if (middleFlex is List) {
      final parsed = middleFlex
          .whereType<num>()
          .map((value) => value.toDouble())
          .where((value) => value > 0)
          .toList();
      if (parsed.isNotEmpty) {
        _middlePanelFlex = parsed;
      }
    }

    // Restore user-created tabs that are not part of the application layout.
    final panelTabs = snapshot['panelTabs'];
    if (panelTabs is Map<String, dynamic>) {
      _restoreCustomTabs(
        panelTabs['left'],
        widget.application.layout.leftPanel.tabs,
      );
      _restoreCustomTabs(
        panelTabs['right'],
        widget.application.layout.rightPanel.tabs,
      );
      _restoreCustomTabs(
        panelTabs['bottom'],
        widget.application.layout.bottomPanel.tabs,
      );
    }

    // Restore editors in side/bottom panels.
    final sidePanelEditors = snapshot['sidePanelEditors'];
    if (sidePanelEditors is Map<String, dynamic>) {
      await _restorePanelEditors(
        sidePanelEditors['left'],
        widget.application.layout.leftPanel.tabs,
      );
      await _restorePanelEditors(
        sidePanelEditors['right'],
        widget.application.layout.rightPanel.tabs,
      );
      await _restorePanelEditors(
        sidePanelEditors['bottom'],
        widget.application.layout.bottomPanel.tabs,
      );
    }

    // Restore active tab indices per panel.
    final panelActiveTabs = snapshot['panelActiveTabs'];
    if (panelActiveTabs is Map<String, dynamic>) {
      final leftIdx = panelActiveTabs['left'];
      if (leftIdx is int) _leftPanelActiveTab = leftIdx;
      final leftConfig = panelActiveTabs['leftShowConfig'];
      if (leftConfig is bool) _leftPanelShowConfig = leftConfig;
      final rightIdx = panelActiveTabs['right'];
      if (rightIdx is int) _rightPanelActiveTab = rightIdx;
      final bottomIdx = panelActiveTabs['bottom'];
      if (bottomIdx is int) _bottomPanelActiveTab = bottomIdx;
    }

    // Restore accordion section state per panel area.
    final accordionData = snapshot['panelAccordionState'];
    if (accordionData is Map<String, dynamic>) {
      for (final area in ['left', 'right', 'bottom']) {
        final areaTabs = accordionData[area];
        if (areaTabs is Map<String, dynamic>) {
          final restored = <int, AccordionSectionState>{};
          for (final entry in areaTabs.entries) {
            final tabIdx = int.tryParse(entry.key);
            if (tabIdx != null && entry.value is Map<String, dynamic>) {
              restored[tabIdx] = AccordionSectionState.fromJson(
                entry.value as Map<String, dynamic>,
              );
            }
          }
          _accordionStates[area] = restored;
        }
      }
    }

    if (debugEnabled) {
      debugPrint('[ForgeShellScaffold] restored layout snapshot');
    }
  }

  /// Restores user-created tabs that are not already in the application layout.
  void _restoreCustomTabs(
    dynamic tabsData,
    List<PanelTabConfig> targetTabs,
  ) {
    if (tabsData is! List) return;
    final existingTitles = targetTabs.map((t) => t.title).toSet();
    for (final tabData in tabsData) {
      if (tabData is! Map<String, dynamic>) continue;
      final title = tabData['title'];
      if (title is! String || existingTitles.contains(title)) continue;
      final codePoint = tabData['iconCodePoint'];
      final fontFamily = tabData['iconFontFamily'];
      if (codePoint is! int) continue;
      try {
        targetTabs.add(PanelTabConfig(
          title: title,
          // codePoint/fontFamily are restored from persisted panel data, so
          // they are genuinely runtime values and cannot be const. The newer
          // SDK analyzer flags non-const IconData (it defeats icon tree-shaking);
          // that trade-off is intentional for dynamically restored tabs.
          icon: IconData(
            // ignore: non_const_argument_for_const_parameter
            codePoint,
            // ignore: non_const_argument_for_const_parameter
            fontFamily: fontFamily is String ? fontFamily : 'MaterialIcons',
          ),
          sections: [], // mutable list for later editor drops
        ));
      } on UnsupportedError {
        // Tabs list is unmodifiable (const default). Skip restoration.
        return;
      }
      existingTitles.add(title);
    }
  }

  /// Restores editors saved within side/bottom panel tabs.
  ///
  /// If a tab already exists at the corresponding index (app-defined or
  /// restored via [_restoreCustomTabs]), editors are appended to it.
  /// Otherwise a new tab is created (legacy snapshot fallback).
  Future<void> _restorePanelEditors(
    dynamic tabsData,
    List<PanelTabConfig> targetTabs,
  ) async {
    if (tabsData is! List) return;
    for (var i = 0; i < tabsData.length; i++) {
      final tabUris = tabsData[i];
      if (tabUris is! List || tabUris.isEmpty) continue;
      final sections = <ForgeView>[];
      for (final uriStr in tabUris) {
        if (uriStr is! String) continue;
        try {
          final uri = Uri.parse(uriStr);
          final editor = await _layout.createEditorForUri(uri);
          if (editor != null) {
            sections.add(_EditorViewAdapter(editor));
          }
        } catch (_) {}
      }
      if (sections.isEmpty) continue;
      if (i < targetTabs.length) {
        // Add sections to the existing tab (app-defined or restored custom).
        try {
          targetTabs[i].sections.addAll(sections);
        } on UnsupportedError {
          // Sections list is unmodifiable (const default). Skip.
          continue;
        }
      } else {
        // Legacy fallback: create a new tab from the first editor's metadata.
        final firstEditor = sections.first;
        try {
          targetTabs.add(PanelTabConfig(
            title: firstEditor.title.value,
            icon: firstEditor.icon,
            sections: sections,
          ));
        } on UnsupportedError {
          // Tabs list is unmodifiable (const default). Skip restoration.
          return;
        }
      }
    }
  }

  Map<String, dynamic> _captureLayoutSnapshot() {
    final snapshot = _layout.toLayoutSnapshot();
    snapshot['middlePanelFlex'] = List<double>.from(_middlePanelFlex);

    // Serialize side/bottom panel editor tabs.
    List<List<String>> extractEditorUris(List<PanelTabConfig> tabs) {
      return tabs.map((tab) {
        return tab.sections
            .whereType<_EditorViewAdapter>()
            .map((adapter) => adapter.editor.uri.toString())
            .toList();
      }).toList();
    }

    // Serialize tab metadata (title + icon) so user-created tabs survive
    // restart.
    List<Map<String, dynamic>> serializeTabs(List<PanelTabConfig> tabs) {
      return tabs.map((tab) {
        return <String, dynamic>{
          'title': tab.title,
          'iconCodePoint': tab.icon.codePoint,
          'iconFontFamily': tab.icon.fontFamily,
        };
      }).toList();
    }

    final layout = widget.application.layout;
    snapshot['sidePanelEditors'] = {
      'left': extractEditorUris(layout.leftPanel.tabs),
      'right': extractEditorUris(layout.rightPanel.tabs),
      'bottom': extractEditorUris(layout.bottomPanel.tabs),
    };
    snapshot['panelTabs'] = {
      'left': serializeTabs(layout.leftPanel.tabs),
      'right': serializeTabs(layout.rightPanel.tabs),
      'bottom': serializeTabs(layout.bottomPanel.tabs),
    };
    snapshot['panelActiveTabs'] = {
      'left': _leftPanelActiveTab,
      'leftShowConfig': _leftPanelShowConfig,
      'right': _rightPanelActiveTab,
      'bottom': _bottomPanelActiveTab,
    };
    // Serialize accordion section state per panel area.
    snapshot['panelAccordionState'] = _accordionStates.map(
      (area, tabs) => MapEntry(
        area,
        tabs.map((k, v) => MapEntry(k.toString(), v.toJson())),
      ),
    );
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
      hitTarget: _preferences.dividerHitTarget,
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
      hitTarget: _preferences.dividerHitTarget,
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
    ValueNotifier<bool>? configPanelVisible,
    int initialActiveTabIndex = 0,
    bool initialShowConfig = false,
    void Function(int tabIndex, bool showConfig)? onTabChanged,
  }) {
    if (tabs.isEmpty && !showConfigTab) {
      return SizedBox(width: width);
    }
    return SizedBox(
      width: width,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: _preferences.panelContentMinWidth,
          maxWidth: double.infinity,
          child: SizedBox(
            width: width < _preferences.panelContentMinWidth
                ? _preferences.panelContentMinWidth
                : width,
            child: ForgeSidePanelWidget(
        tabs: tabs,
        iconStripPosition: iconStripPosition,
        showConfigTab: showConfigTab,
        onConfigTap: onConfigTap,
        configurationPanelBuilder: configurationPanelBuilder,
        configPanelVisible: configPanelVisible,
        panelArea: panelArea,
        initialActiveTabIndex: initialActiveTabIndex,
        initialShowConfig: initialShowConfig,
        onTabChanged: onTabChanged,
        onTabDropped: (data) => _handlePanelTabDrop(data, panelArea),
        onEditorDropped: (data) => _handleEditorDropOnPanel(data, panelArea),
        onEditorDroppedAsSection: (data, tabIndex) =>
            _handleEditorDropAsSection(data, panelArea, tabIndex),
        onSectionDroppedFromPanel: (data, tabIndex) =>
            _handleSectionDropOnPanel(data, panelArea, tabIndex),
        onReorder: (tabIndex, from, to) =>
            _handleSectionReorder(panelArea, tabIndex, from, to),
        onTabDelete: (tabIndex) => _handleTabDelete(panelArea, tabIndex),
        onSectionDroppedOnTabBar: (data) =>
            _handleSectionDropOnTabBar(data, panelArea),
        initialAccordionState: _accordionStates[panelArea.name],
        onAccordionStateChanged: (tabIndex, state) {
          _accordionStates[panelArea.name]![tabIndex] = state;
          _scheduleLayoutPersistence();
        },
      ),
      ),
      ),
      ),
    );
  }

  Widget _buildConfigurationPanel(BuildContext context) {
    final modulePanels = widget.shell.modules.allModules
        .expand((m) => m.configPanels)
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    return ForgeConfigurationPanel(
      preferencesService: _preferences,
      shellApi: widget.shell,
      modulePanels: modulePanels,
      onSettingsChanged: _onPreferencesChanged,
      expandSection: _configSectionTarget,
    );
  }

  bool _isPrimaryEditorRender(int panelIndex, ForgeEditor editor) {
    final panels = _layout.middlePanels.value;
    for (var idx = 0; idx < panels.length; idx++) {
      if (panels[idx].contains(editor)) {
        return idx == panelIndex;
      }
    }
    return true;
  }

  Widget _buildMiddleArea(BuildContext context) {
    return ValueListenableBuilder<List<List<ForgeEditor>>>(
      valueListenable: _layout.middlePanels,
      builder: (context, panels, _) {
        return ValueListenableBuilder<int>(
          valueListenable: _layout.activeMiddlePanelIndexNotifier,
          builder: (context, activeIdx, _) {
            if (panels.isEmpty || panels.every((p) => p.isEmpty)) {
              return EmptyPanelDropTarget(
                panelIndex: 0,
                onDrop: (data, position, {bool isCopy = false}) {
                  _handleDropZone(data, position, 0, isCopy: isCopy);
                },
              );
            }
            // Ensure flex list matches panel count.
            while (_middlePanelFlex.length < panels.length) {
              _middlePanelFlex.add(1.0);
            }
            if (_middlePanelFlex.length > panels.length) {
              _middlePanelFlex = _middlePanelFlex.sublist(0, panels.length);
            }
            return LayoutBuilder(
              builder: (context, outerConstraints) {
                _middleAreaWidth = outerConstraints.maxWidth;
                return Row(
              children: [
                for (var i = 0; i < panels.length; i++) ...[
                  if (i > 0)
                    _ResizeHandle(
                      axis: Axis.horizontal,
                      onDragDelta: (delta) =>
                          _resizeMiddlePanelDivider(i - 1, i, delta),
                      onDoubleTap: () => _resetMiddlePanelFlex(),
                      hitTarget: _preferences.dividerHitTarget,
                    ),
                  Flexible(
                    flex: (_middlePanelFlex[i] * 1000).round(),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final minW = _preferences.panelContentMinWidth;
                        final actualW = constraints.maxWidth;
                        final child = _buildEditorPanel(
                          context,
                          editors: panels[i],
                          isActive: i == activeIdx,
                          panelIndex: i,
                        );
                        if (actualW >= minW) return child;
                        return ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topLeft,
                            minWidth: minW,
                            maxWidth: minW,
                            child: child,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            );
              },
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
        final useMainRender = _isPrimaryEditorRender(panelIndex, currentEditor);
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
                onClose: (editor) =>
                  _handleCloseEditor(editor, panelIndex: panelIndex),
                onEditorDropped: (editor, {bool isCopy = false}) {
                  if (isCopy) {
                    _layout.copyComponent(editor, panelIndex);
                  } else {
                    _layout.moveComponent(editor, panelIndex);
                  }
                  widget.systemState.setActiveEditor(editor);
                },
                onViewDropped: (data) =>
                    _handleViewDropOnMiddle(data, panelIndex),
                onPanelTabDropped: (data) {
                  _handleDropZone(data, DropPosition.center, panelIndex);
                },
                onEditActionBar: _showEditActionBarDialog,
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
                    child: KeyedSubtree(
                      key: ValueKey(
                        'editor-${currentEditor.uri}-$panelIndex-'
                        '${useMainRender ? 'main' : 'copy'}',
                      ),
                      child: useMainRender
                          ? currentEditor.buildMain(context)
                          : currentEditor.buildCopy(context),
                    ),
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
  ///
  /// Accepts both [TabDragData] (editor from another middle panel) and
  /// [SectionDragData] (view from a side/bottom panel), adapting views
  /// into editor wrappers when needed.
  void _handleDropZone(
    ForgeDragData data,
    DropPosition position,
    int panelIndex, {
    bool isCopy = false,
  }) {
    switch (data) {
      case TabDragData tabData:
        switch (position) {
          case DropPosition.center:
            if (isCopy) {
              _layout.copyComponent(tabData.editor, panelIndex);
            } else {
              _layout.moveComponent(tabData.editor, panelIndex);
            }
          case DropPosition.left:
            _layout.splitAndInsertPanel(panelIndex, tabData.editor);
          case DropPosition.right:
            _layout.splitAndInsertPanel(panelIndex + 1, tabData.editor);
        }
        widget.systemState.setActiveEditor(tabData.editor);

      case SectionDragData sectionData:
        // Wrap the view as an editor for the middle panel.
        final adapter = _ViewEditorAdapter(sectionData.section);
        switch (position) {
          case DropPosition.center:
            _layout.moveComponent(adapter, panelIndex);
          case DropPosition.left:
            _layout.splitAndInsertPanel(panelIndex, adapter);
          case DropPosition.right:
            _layout.splitAndInsertPanel(panelIndex + 1, adapter);
        }
        // Remove from source side/bottom panel section list.
        _removeSectionFromPanel(sectionData);
        widget.systemState.setActiveEditor(adapter);

      case PanelTabDragData panelTabData:
        // Wrap each section as an editor adapter for the middle panel.
        for (final section in panelTabData.sections) {
          final adapter = _ViewEditorAdapter(section);
          switch (position) {
            case DropPosition.center:
              _layout.moveComponent(adapter, panelIndex);
            case DropPosition.left:
              _layout.splitAndInsertPanel(panelIndex, adapter);
            case DropPosition.right:
              _layout.splitAndInsertPanel(panelIndex + 1, adapter);
          }
          widget.systemState.setActiveEditor(adapter);
        }
        // Remove the tab from its source panel.
        _removePanelTab(panelTabData);
    }
  }

  /// Removes a section from its source side/bottom panel after a cross-panel
  /// move (view dragged to middle panel).
  void _removeSectionFromPanel(SectionDragData data) {
    // If the section provides its own removal callback (e.g. terminals
    // managed by ForgeTerminalManager), invoke it instead of manipulating
    // the panel sections list directly.
    if (data.onRemoved != null) {
      data.onRemoved!();
      setState(() {});
      return;
    }
    // Terminal sections need to detach from the manager so that
    // _syncTerminalSections keeps the sections list consistent.
    if (data.section is SingleTerminalView) {
      final view = data.section as SingleTerminalView;
      widget.shell.terminals.detach(view.terminal);
      // onDidClose listener will call _syncTerminalSections + setState.
      return;
    }
    if (data.sourceArea == null || data.sourceTabIndex == null) return;
    final layout = widget.application.layout;
    final tabs = switch (data.sourceArea!) {
      PanelArea.left => layout.leftPanel.tabs,
      PanelArea.right => layout.rightPanel.tabs,
      PanelArea.bottom => layout.bottomPanel.tabs,
    };
    final tabIdx = data.sourceTabIndex!;
    if (tabIdx >= 0 && tabIdx < tabs.length) {
      final sections = tabs[tabIdx].sections;
      if (data.sourceIndex >= 0 && data.sourceIndex < sections.length) {
        sections.removeAt(data.sourceIndex);
        setState(() {});
      }
    }
  }

  /// Removes an entire tab from its source panel after a cross-panel move
  /// (panel tab dragged to middle panel).
  void _removePanelTab(PanelTabDragData data) {
    final layout = widget.application.layout;
    final tabs = switch (data.sourceArea) {
      PanelArea.left => layout.leftPanel.tabs,
      PanelArea.right => layout.rightPanel.tabs,
      PanelArea.bottom => layout.bottomPanel.tabs,
    };
    if (data.tabIndex >= 0 && data.tabIndex < tabs.length) {
      tabs.removeAt(data.tabIndex);
      setState(() {});
    }
  }

  /// Handles an editor tab being dropped onto a side or bottom panel.
  ///
  /// Wraps the editor as a [ForgeView] via [_EditorViewAdapter] and
  /// adds it as a section in the target panel's active tab.
  void _handleEditorDropOnPanel(TabDragData data, PanelArea targetArea) {
    final layout = widget.application.layout;

    // Target panel tabs.
    final targetTabs = switch (targetArea) {
      PanelArea.left => layout.leftPanel.tabs,
      PanelArea.right => layout.rightPanel.tabs,
      PanelArea.bottom => layout.bottomPanel.tabs,
    };

    // Always create a new tab with the editor as its content.
    targetTabs.add(PanelTabConfig(
      title: data.editor.title.value,
      icon: data.editor.icon,
      sections: [_EditorViewAdapter(data.editor)],
    ));

    // Remove from middle panel.
    _layout.closeEditor(data.editor);
    setState(() {});
  }

  /// Handles an editor tab being dropped on the accordion content area
  /// of a panel tab. Instead of creating a new tab, adds the editor as
  /// a new accordion section in the target tab.
  void _handleEditorDropAsSection(
    TabDragData data,
    PanelArea targetArea,
    int tabIndex,
  ) {
    final layout = widget.application.layout;

    final targetTabs = switch (targetArea) {
      PanelArea.left => layout.leftPanel.tabs,
      PanelArea.right => layout.rightPanel.tabs,
      PanelArea.bottom => layout.bottomPanel.tabs,
    };

    if (tabIndex < 0 || tabIndex >= targetTabs.length) return;

    // Convert the editor to a ForgeView for the accordion section.
    // If it's a _ViewEditorAdapter wrapping a ForgeView, unwrap it.
    final ForgeView section;
    if (data.editor is _ViewEditorAdapter) {
      section = (data.editor as _ViewEditorAdapter).view;
    } else {
      section = _EditorViewAdapter(data.editor);
    }

    targetTabs[tabIndex].sections.add(section);

    // Remove from middle panel.
    _layout.closeEditor(data.editor);
    setState(() {});
  }

  /// Handles a section being dropped from one side/bottom panel into another.
  void _handleSectionDropOnPanel(
    SectionDragData data,
    PanelArea targetArea,
    int tabIndex,
  ) {
    final layout = widget.application.layout;

    final targetTabs = switch (targetArea) {
      PanelArea.left => layout.leftPanel.tabs,
      PanelArea.right => layout.rightPanel.tabs,
      PanelArea.bottom => layout.bottomPanel.tabs,
    };

    if (tabIndex < 0 || tabIndex >= targetTabs.length) return;

    // Add the section to the target panel tab.
    targetTabs[tabIndex].sections.add(data.section);

    // Remove from the source panel.
    _removeSectionFromPanel(data);
  }

  /// Handles a section being dropped on the tab bar to create a new tab.
  void _handleSectionDropOnTabBar(
    SectionDragData data,
    PanelArea targetArea,
  ) {
    final layout = widget.application.layout;

    final targetTabs = switch (targetArea) {
      PanelArea.left => layout.leftPanel.tabs,
      PanelArea.right => layout.rightPanel.tabs,
      PanelArea.bottom => layout.bottomPanel.tabs,
    };

    // Create a new tab with the section.
    targetTabs.add(PanelTabConfig(
      title: data.section.title.value,
      icon: data.section.icon,
      sections: [data.section],
    ));

    // Remove from the source panel.
    _removeSectionFromPanel(data);
    setState(() {});
    _scheduleLayoutPersistence();
  }

  /// Reorders sections within a panel tab's accordion.
  void _handleSectionReorder(
    PanelArea area,
    int tabIndex,
    int fromIndex,
    int toIndex,
  ) {
    final layout = widget.application.layout;

    final tabs = switch (area) {
      PanelArea.left => layout.leftPanel.tabs,
      PanelArea.right => layout.rightPanel.tabs,
      PanelArea.bottom => layout.bottomPanel.tabs,
    };

    if (tabIndex < 0 || tabIndex >= tabs.length) return;
    final sections = tabs[tabIndex].sections;
    if (fromIndex < 0 || fromIndex >= sections.length) return;
    if (toIndex < 0 || toIndex > sections.length) return;

    final section = sections.removeAt(fromIndex);
    sections.insert(toIndex, section);
    setState(() {});
  }

  /// Deletes a tab from a panel. Only allowed when the tab has no sections.
  void _handleTabDelete(PanelArea area, int tabIndex) {
    final layout = widget.application.layout;

    final tabs = switch (area) {
      PanelArea.left => layout.leftPanel.tabs,
      PanelArea.right => layout.rightPanel.tabs,
      PanelArea.bottom => layout.bottomPanel.tabs,
    };

    if (tabIndex < 0 || tabIndex >= tabs.length) return;
    if (tabs[tabIndex].sections.isNotEmpty) return;

    setState(() {
      tabs.removeAt(tabIndex);
    });
    _scheduleLayoutPersistence();
  }

  /// Handles a view section being dropped onto the editor tab bar from
  /// a side/bottom panel.
  void _handleViewDropOnMiddle(SectionDragData data, int panelIndex) {
    final section = data.section;
    // If the section is an _EditorViewAdapter, unwrap to recover the original
    // editor instead of double-wrapping.
    final ForgeEditor editor;
    if (section is _EditorViewAdapter) {
      editor = section.editor;
    } else {
      editor = _ViewEditorAdapter(section);
    }
    _layout.moveComponent(editor, panelIndex);
    // Remove the section from its source side/bottom panel.
    _removeSectionFromPanel(data);
    widget.systemState.setActiveEditor(editor);
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
  Future<void> _handleCloseEditor(
    ForgeEditor editor, {
    int? panelIndex,
  }) async {
    void closeRequestedEditor() {
      if (panelIndex != null) {
        _layout.closeEditorInPanel(editor, panelIndex);
      } else {
        _layout.closeEditor(editor);
      }
    }

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
            closeRequestedEditor();
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
                _handleCloseEditor(
                  editor,
                  panelIndex: panelIndex,
                ); // retry the whole flow
              case ErrorRecoveryAction.overwrite:
                closeRequestedEditor(); // discard and close
              case ErrorRecoveryAction.cancel:
              case null:
                break; // stay open
            }
          }
        case _DirtyCloseAction.discard:
          closeRequestedEditor();
        case _DirtyCloseAction.cancel:
        case null:
          // Do nothing — user cancelled.
          break;
      }
    } else {
      closeRequestedEditor();
    }
  }

  /// Shows a context menu for a bottom-panel tab.
  void _showBottomTabContextMenu(
    int tabIndex,
    Offset position,
    List<PanelTabConfig> tabs,
  ) {
    if (tabIndex < 0 || tabIndex >= tabs.length) return;
    final tab = tabs[tabIndex];

    final items = <PopupMenuEntry<String>>[];

    // Terminal tabs have create action.
    if (tab.title == 'Terminal') {
      items.add(const PopupMenuItem(
        value: 'new_terminal',
        child: Row(
          children: [
            Icon(Icons.add, size: 16),
            SizedBox(width: 8),
            Text('New Terminal'),
          ],
        ),
      ));
    }

    // Empty tabs can be deleted.
    if (tab.sections.isEmpty) {
      items.add(const PopupMenuItem(
        value: 'delete_tab',
        child: Row(
          children: [
            Icon(Icons.delete_outline, size: 16),
            SizedBox(width: 8),
            Text('Delete Tab'),
          ],
        ),
      ));
    }

    if (items.isEmpty) return;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: items,
    ).then((value) {
      if (value == 'new_terminal') {
        widget.shell.terminals.create();
      } else if (value == 'delete_tab') {
        _handleTabDelete(PanelArea.bottom, tabIndex);
      }
    });
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
        initialActiveTabIndex: _bottomPanelActiveTab,
        onTabChanged: (idx) {
          _bottomPanelActiveTab = idx;
          _scheduleLayoutPersistence();
        },
        onTabDropped: (data) => _handlePanelTabDrop(data, PanelArea.bottom),
        onEditorDropped: (data) =>
            _handleEditorDropOnPanel(data, PanelArea.bottom),
        onEditorDroppedAsSection: (data, tabIndex) =>
            _handleEditorDropAsSection(data, PanelArea.bottom, tabIndex),
        onSectionDroppedFromPanel: (data, tabIndex) =>
            _handleSectionDropOnPanel(data, PanelArea.bottom, tabIndex),
        onReorder: (tabIndex, from, to) =>
            _handleSectionReorder(PanelArea.bottom, tabIndex, from, to),
        onTabContextMenu: (tabIndex, position) =>
            _showBottomTabContextMenu(tabIndex, position, tabs),
        onTabDelete: (tabIndex) => _handleTabDelete(PanelArea.bottom, tabIndex),
        onSectionDroppedOnTabBar: (data) =>
            _handleSectionDropOnTabBar(data, PanelArea.bottom),
        initialAccordionState: _accordionStates['bottom'],
        onAccordionStateChanged: (tabIndex, state) {
          _accordionStates['bottom']![tabIndex] = state;
          _scheduleLayoutPersistence();
        },
      ),
    );
  }
}

// ── Intents for keyboard shortcuts ──

/// Result of the dirty-close confirmation dialog.
enum _DirtyCloseAction { save, discard, cancel }

// ── Cross-panel drag adapters ──

/// Wraps a [ForgeEditor] as a [ForgeView] so it can appear as a section
/// in a side or bottom panel. The editor's main widget is displayed
/// directly; editor-specific capabilities (save, dirty) are not surfaced.
class _EditorViewAdapter extends ForgeView {
  final ForgeEditor editor;
  _EditorViewAdapter(this.editor);

  @override
  ValueListenable<String> get title => editor.title;
  @override
  ValueListenable<String?> get titleExtension => editor.titleExtension;
  @override
  IconData get icon => editor.icon;
  @override
  ForgeComponentSizeHints get sizeHints => editor.sizeHints;
  @override
  Widget buildMain(BuildContext context) => editor.buildMain(context);
  @override
  Widget buildCopy(BuildContext context) => editor.buildCopy(context);
  @override
  List<shell_action.ForgeAction> get actions => editor.actions;
  @override
  List<shell_action.ForgeAction> get headerActions => editor.headerActions;
}

/// Wraps a [ForgeView] as a [ForgeEditor] so it can appear as a tab
/// in the middle (editor) panel. Editor-specific methods return safe
/// defaults (not dirty, no URI handling).
class _ViewEditorAdapter extends ForgeEditor {
  final ForgeView view;
  final _isDirtyNotifier = ValueNotifier<bool>(false);
  final Uri _syntheticUri;

  _ViewEditorAdapter(this.view)
      : _syntheticUri = Uri.parse(
            'forge-view://${view.title.value.replaceAll(' ', '-').toLowerCase()}');

  @override
  ValueListenable<String> get title => view.title;
  @override
  ValueListenable<String?> get titleExtension => view.titleExtension;
  @override
  IconData get icon => view.icon;
  @override
  ForgeComponentSizeHints get sizeHints => view.sizeHints;
  @override
  Widget buildMain(BuildContext context) => view.buildMain(context);
  @override
  Widget buildCopy(BuildContext context) => view.buildCopy(context);
  @override
  List<shell_action.ForgeAction> get actions => view.actions;
  @override
  List<shell_action.ForgeAction> get headerActions => view.headerActions;
  @override
  Uri get uri => _syntheticUri;
  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.reject;
  @override
  ValueListenable<bool> get isDirty => _isDirtyNotifier;
  @override
  void markClean() {}
}

class _CommandPaletteIntent extends Intent {
  const _CommandPaletteIntent();
}

class _ActionPaletteIntent extends Intent {
  const _ActionPaletteIntent();
}

class _ToggleLeftPanelIntent extends Intent {
  const _ToggleLeftPanelIntent();
}

class _ToggleRightPanelIntent extends Intent {
  const _ToggleRightPanelIntent();
}

class _ToggleBottomPanelIntent extends Intent {
  const _ToggleBottomPanelIntent();
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _FocusMiddlePanelIntent extends Intent {
  final int panelIndex;
  const _FocusMiddlePanelIntent(this.panelIndex);
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

/// Intent that dynamically dispatches a module action by its ID.
class _ModuleActionIntent extends Intent {
  final String actionId;
  const _ModuleActionIntent(this.actionId);
}

class _ResizeHandle extends StatefulWidget {
  const _ResizeHandle({
    required this.axis,
    required this.onDragDelta,
    this.onDoubleTap,
    this.hitTarget = ForgeDimensions.dividerHitTarget,
  });

  final Axis axis;
  final ValueChanged<double> onDragDelta;
  final VoidCallback? onDoubleTap;
  final double hitTarget;

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
                  (widget.hitTarget - gripThickness) / 2,
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
              vertical: (widget.hitTarget - gripThickness) / 2,
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
          width: isVerticalDivider ? widget.hitTarget : null,
          height: isVerticalDivider ? null : widget.hitTarget,
          child: grip,
        ),
      ),
    );
  }
}

/// Dialog for editing the action bar configuration.
class _EditActionBarDialog extends StatefulWidget {
  const _EditActionBarDialog({
    required this.editorTypeId,
    required this.currentActions,
    required this.availableActions,
  });

  final String editorTypeId;
  final List<String> currentActions;
  final List<(String, String, IconData?)> availableActions;

  @override
  State<_EditActionBarDialog> createState() => _EditActionBarDialogState();
}

class _EditActionBarDialogState extends State<_EditActionBarDialog> {
  late List<String> _selectedActions;

  @override
  void initState() {
    super.initState();
    _selectedActions = List<String>.from(widget.currentActions);
  }

  String get _editorTitle {
    switch (widget.editorTypeId) {
      case 'dart':
        return 'Dart Editor';
      case 'md':
        return 'Markdown Editor';
      case 'yaml':
        return 'YAML Editor';
      case 'plaintext':
        return 'Plain Text Editor';
      default:
        return 'Editor';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('Edit Action Bar - $_editorTitle'),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current action bar:',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _buildCurrentActions(theme),
            const SizedBox(height: 16),
            Text(
              'Available actions:',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildAvailableActions(theme)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _selectedActions.clear();
              _selectedActions.addAll(
                _ForgeShellScaffoldState._defaultActionBarActions,
              );
            });
          },
          child: const Text('Reset to Defaults'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_selectedActions),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildCurrentActions(ThemeData theme) {
    if (_selectedActions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'No actions selected',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _selectedActions.map((actionId) {
          final actionInfo = widget.availableActions
              .cast<(String, String, IconData?)?>()
              .firstWhere((a) => a?.$1 == actionId, orElse: () => null);
          final label = actionInfo?.$2 ?? actionId;
          final icon = actionInfo?.$3;

          return Chip(
            avatar: icon != null ? Icon(icon, size: 16) : null,
            label: Text(label, style: const TextStyle(fontSize: 12)),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: () {
              setState(() => _selectedActions.remove(actionId));
            },
            visualDensity: VisualDensity.compact,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAvailableActions(ThemeData theme) {
    return ListView.builder(
      itemCount: widget.availableActions.length,
      itemBuilder: (context, index) {
        final (actionId, label, icon) = widget.availableActions[index];
        final isSelected = _selectedActions.contains(actionId);

        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: icon != null
              ? Icon(icon, size: 20)
              : const Icon(Icons.extension, size: 20),
          title: Text(label, style: const TextStyle(fontSize: 13)),
          subtitle: Text(
            actionId,
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          trailing: isSelected
              ? Icon(Icons.check, size: 18, color: theme.colorScheme.primary)
              : null,
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedActions.remove(actionId);
              } else {
                _selectedActions.add(actionId);
              }
            });
          },
        );
      },
    );
  }
}
