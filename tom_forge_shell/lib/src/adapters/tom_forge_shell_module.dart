import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart' as shared;

import '../actions/forge_action.dart';
import '../actions/forge_shortcut_binding.dart';
import '../components/forge_editor.dart';
import '../components/forge_view.dart';
import '../module/forge_module.dart';
import '../shell/forge_shell_api.dart';

/// The built-in shell module that registers the editor adapters for
/// known file types (Dart, Markdown, YAML) and provides the forge-level
/// shell shortcuts.
///
/// [TomForgeShellModule] owns the default editor adapters and exposes
/// them as typed members.  The [supportedExtensions] getter declares
/// which file extensions are handled at the framework level so that
/// layout controllers can resolve the correct owner module during
/// editor creation.
///
/// It also registers:
/// - Shell-level actions (command palette, panel toggling, focus, etc.)
/// - Editor-type–specific action descriptors from all built-in editors
/// - Standard editing action descriptors (cut, copy, paste, undo, redo, etc.)
///
/// The [ForgeShellScaffold] overrides the placeholder execute callbacks
/// via [ForgeActionRegistry.registerAction] when it initialises.
///
/// Usage:
/// ```dart
/// final module = TomForgeShellModule();
/// module.activate(shellApi);
/// print(module.supportedExtensions); // {dart, md, markdown, yaml, yml, txt}
/// ```
class TomForgeShellModule extends ForgeModule {
  final List<ForgeEditor> _editors = [];
  final List<ForgeAction> _actions = [];
  final List<ForgeShortcutBinding> _shortcuts = [];
  ForgeShellApi? _shell;

  /// Whether this module has been activated (i.e. [shellApi] is available).
  bool get isActivated => _shell != null;

  ForgeShellApi get shellApi {
    final shell = _shell;
    if (shell == null) {
      throw StateError('TomForgeShellModule has not been activated yet.');
    }
    return shell;
  }

  @override
  String get displayName => 'Tom Forge Editors';

  /// File extensions handled by this module's built-in editor adapters.
  static const Set<String> supportedExtensions = {
    'dart',
    'md',
    'markdown',
    'yaml',
    'yml',
    'txt',
  };

  /// Whether this module handles the given file extension.
  bool canHandleExtension(String ext) =>
      supportedExtensions.contains(ext.toLowerCase());

  /// The id of Go Back.
  static const navigateBackActionId = 'forge.navigate.back';

  /// The id of Go Forward.
  static const navigateForwardActionId = 'forge.navigate.forward';

  @override
  void activate(ForgeShellApi shell) {
    _shell = shell;
    _buildShellActions();
    _buildEditorDescriptorActions();
  }

  @override
  void deactivate() {
    _editors.clear();
    _actions.clear();
    _shortcuts.clear();
    _shell = null;
  }

  /// Registers an editor adapter with this module and returns it. The code
  /// editors' typed helpers (`registerMdEditor`, `mdEditors`, ...) are an
  /// extension in `tom_forge_code_editors`.
  E registerEditor<E extends ForgeEditor>(E editor) {
    _editors.add(editor);
    return editor;
  }

  @override
  List<ForgeEditor> get editors => List.unmodifiable(_editors);

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => List.unmodifiable(_actions);

  @override
  List<ForgeShortcutBinding> get shortcuts => List.unmodifiable(_shortcuts);

  // ── Shell-level actions ──

  /// Builds placeholder actions for the 13 shell-level shortcuts.
  ///
  /// These actions have no-op execute callbacks; the [ForgeShellScaffold]
  /// overrides them with widget-level implementations via
  /// [ForgeActionRegistry.registerAction].
  void _buildShellActions() {
    void add(String id, String label, ForgeShortcutKey key, {IconData? icon}) {
      final action = ForgeAction(
        id: id,
        label: label,
        icon: icon,
        menu: ForgeMenuLocation.commandPalette,
        execute: (_) async {
          // No-op placeholder. The scaffold overrides this via registerAction.
          return null;
        },
        isEnabled: () => true,
        isVisible: () => true,
        defaultShortcut: key,
      );
      _actions.add(action);
      _shortcuts.add(
        ForgeShortcutBinding(action: action, key: key, context: 'Shell'),
      );
    }

    // Single command palette action with two shortcut bindings.
    final paletteAction = ForgeAction(
      id: 'forge.commandPalette',
      label: 'Command Palette',
      icon: Icons.terminal,
      menu: ForgeMenuLocation.commandPalette,
      execute: (_) async {
        // No-op placeholder. The scaffold overrides this via registerAction.
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
      defaultShortcut: const ForgeShortcutKey(
        key: LogicalKeyboardKey.keyP,
        primaryModifier: true,
        shift: true,
      ),
    );
    _actions.add(paletteAction);
    _shortcuts.add(
      ForgeShortcutBinding(
        action: paletteAction,
        key: const ForgeShortcutKey(
          key: LogicalKeyboardKey.keyP,
          primaryModifier: true,
          shift: true,
        ),
        context: 'Shell',
      ),
    );
    _shortcuts.add(
      ForgeShortcutBinding(
        action: paletteAction,
        key: const ForgeShortcutKey(key: LogicalKeyboardKey.f1),
        context: 'Shell',
      ),
    );

    add(
      'forge.toggleLeftPanel',
      'Toggle Left Panel',
      const ForgeShortcutKey(
        key: LogicalKeyboardKey.keyL,
        primaryModifier: true,
      ),
      icon: Icons.view_sidebar,
    );
    add(
      'forge.toggleRightPanel',
      'Toggle Right Panel',
      const ForgeShortcutKey(
        key: LogicalKeyboardKey.keyR,
        primaryModifier: true,
      ),
      icon: Icons.vertical_split,
    );
    add(
      'forge.toggleBottomPanel',
      'Toggle Bottom Panel',
      const ForgeShortcutKey(
        key: LogicalKeyboardKey.keyB,
        primaryModifier: true,
      ),
      icon: Icons.view_stream,
    );
    add(
      'forge.focusSearch',
      'Focus Search',
      const ForgeShortcutKey(
        key: LogicalKeyboardKey.keyF,
        primaryModifier: true,
      ),
      icon: Icons.search,
    );
    add(
      'forge.focusPanel1',
      'Focus Panel 1',
      const ForgeShortcutKey(
        key: LogicalKeyboardKey.digit1,
        primaryModifier: true,
      ),
      icon: Icons.looks_one,
    );
    add(
      'forge.focusPanel2',
      'Focus Panel 2',
      const ForgeShortcutKey(
        key: LogicalKeyboardKey.digit2,
        primaryModifier: true,
      ),
      icon: Icons.looks_two,
    );
    add(
      'forge.focusPanel3',
      'Focus Panel 3',
      const ForgeShortcutKey(
        key: LogicalKeyboardKey.digit3,
        primaryModifier: true,
      ),
      icon: Icons.looks_3,
    );
    add(
      'forge.focusPanel4',
      'Focus Panel 4',
      const ForgeShortcutKey(
        key: LogicalKeyboardKey.digit4,
        primaryModifier: true,
      ),
      icon: Icons.looks_4,
    );
    add(
      'forge.saveAll',
      'Save All',
      const ForgeShortcutKey(
        key: LogicalKeyboardKey.keyS,
        primaryModifier: true,
      ),
      icon: Icons.save,
    );
    add(
      'forge.focusNextPanel',
      'Focus Next Panel',
      const ForgeShortcutKey(
        key: LogicalKeyboardKey.bracketRight,
        primaryModifier: true,
      ),
      icon: Icons.chevron_right,
    );
    add(
      'forge.focusPreviousPanel',
      'Focus Previous Panel',
      const ForgeShortcutKey(
        key: LogicalKeyboardKey.bracketLeft,
        primaryModifier: true,
      ),
      icon: Icons.chevron_left,
    );
    _addNavigationActions();
  }

  /// Go Back and Go Forward, as VS Code: ⌃- and ⌃⇧- on macOS, Ctrl+- and
  /// Ctrl+Shift+- on Windows and Linux. They run the shell's navigation
  /// history and are enabled exactly when it has somewhere to go.
  void _addNavigationActions() {
    final history = shellApi.navigationHistory;
    void navigate(
      String id,
      String label,
      ForgeShortcutKey key,
      IconData icon,
      bool Function() go,
      ValueListenable<bool> enabled,
    ) {
      final action = ForgeAction(
        id: id,
        label: label,
        icon: icon,
        menu: ForgeMenuLocation.commandPalette,
        execute: (_) async {
          go();
          return null;
        },
        isEnabled: () => enabled.value,
        isVisible: () => true,
        defaultShortcut: key,
      );
      _actions.add(action);
      _shortcuts.add(
        ForgeShortcutBinding(action: action, key: key, context: 'Shell'),
      );
    }

    navigate(
      navigateBackActionId,
      'Go Back',
      const ForgeShortcutKey(key: LogicalKeyboardKey.minus, control: true),
      Icons.arrow_back,
      history.goBack,
      history.canGoBack,
    );
    navigate(
      navigateForwardActionId,
      'Go Forward',
      const ForgeShortcutKey(
        key: LogicalKeyboardKey.minus,
        control: true,
        shift: true,
      ),
      Icons.arrow_forward,
      history.goForward,
      history.canGoForward,
    );
  }

  // ── Editor descriptor actions ──

  /// Builds placeholder actions for all editor-type descriptors (Standard
  /// editing, Dart, Markdown, YAML) so their shortcuts are visible in the
  /// Shortcut Editor from application start.
  ///
  /// When an editor opens, [ShellEditorIntegration._registerWithShell]
  /// overwrites these placeholders with the real editor actions.
  void _buildEditorDescriptorActions() {
    final allDescriptors = [
      ...shared.StandardEditingActions.descriptors,
      ...shared.DartEditorActions.descriptors,
      ...shared.MdEditorActions.descriptors,
      ...shared.YamlEditorActions.descriptors,
    ];

    for (final desc in allDescriptors) {
      final shortcut = desc.suggestedShortcut;
      if (shortcut == null) continue;

      // One ForgeShortcutKey for the shell and the editors.
      final shellShortcut = shortcut;

      final actionId = desc.id;

      // Note: Standard editing actions are routed through EditorActionProvider
      // in DefaultShellApi, not through the global registry. The registry's
      // isEnabled is only used for command palette and context menu display.

      final action = ForgeAction(
        id: actionId,
        label: desc.label,
        icon: desc.icon,
        menu: desc.showInContextMenu
            ? ForgeMenuLocation.contextMenu
            : ForgeMenuLocation.edit,
        execute: (_) async {
          shellApi.executeAction(actionId);
          return null;
        },
        isEnabled: () => shellApi.systemState.activeEditor != null,
        isVisible: () => true,
        defaultShortcut: shellShortcut,
        showInContextMenu: desc.showInContextMenu,
      );

      _actions.add(action);
      _shortcuts.add(
        ForgeShortcutBinding(
          action: action,
          key: shellShortcut,
          context: desc.category,
        ),
      );
    }
  }
}
