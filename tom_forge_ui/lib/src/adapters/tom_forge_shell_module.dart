import 'package:flutter/services.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart' as shared;

import '../actions/forge_action.dart';
import '../actions/forge_shortcut_binding.dart';
import '../components/forge_editor.dart';
import '../components/forge_view.dart';
import '../module/forge_module.dart';
import '../shell/forge_shell_api.dart';
import 'forge_dart_editor.dart';
import 'forge_md_editor.dart';
import 'forge_yaml_editor.dart';

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

  /// Register a [ForgeMdEditor] adapter and return it.
  ForgeMdEditor registerMdEditor(ForgeMdEditor editor) {
    _editors.add(editor);
    return editor;
  }

  /// Register a [ForgeDartEditor] adapter and return it.
  ForgeDartEditor registerDartEditor(ForgeDartEditor editor) {
    _editors.add(editor);
    return editor;
  }

  /// Register a [ForgeYamlEditor] adapter and return it.
  ForgeYamlEditor registerYamlEditor(ForgeYamlEditor editor) {
    _editors.add(editor);
    return editor;
  }

  /// All registered Dart editors.
  List<ForgeDartEditor> get dartEditors =>
      _editors.whereType<ForgeDartEditor>().toList();

  /// All registered Markdown editors.
  List<ForgeMdEditor> get mdEditors =>
      _editors.whereType<ForgeMdEditor>().toList();

  /// All registered YAML editors.
  List<ForgeYamlEditor> get yamlEditors =>
      _editors.whereType<ForgeYamlEditor>().toList();

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
    void add(String id, String label, ForgeShortcutKey key) {
      final action = ForgeAction(
        id: id,
        label: label,
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
      _shortcuts
          .add(ForgeShortcutBinding(action: action, key: key, context: 'Shell'));
    }

    add(
      'forge.commandPalette',
      'Command Palette',
      const ForgeShortcutKey(
        key: LogicalKeyboardKey.keyP,
        primaryModifier: true,
        shift: true,
      ),
    );
    add(
      'forge.commandPaletteFull',
      'Command Palette',
      const ForgeShortcutKey(key: LogicalKeyboardKey.f1),
    );
    add(
      'forge.toggleLeftPanel',
      'Toggle Left Panel',
      const ForgeShortcutKey(
        key: LogicalKeyboardKey.keyL,
        primaryModifier: true,
      ),
    );
    add(
      'forge.toggleRightPanel',
      'Toggle Right Panel',
      const ForgeShortcutKey(
        key: LogicalKeyboardKey.keyR,
        primaryModifier: true,
      ),
    );
    add(
      'forge.toggleBottomPanel',
      'Toggle Bottom Panel',
      const ForgeShortcutKey(
        key: LogicalKeyboardKey.keyB,
        primaryModifier: true,
      ),
    );
    add(
      'forge.focusSearch',
      'Focus Search',
      const ForgeShortcutKey(
        key: LogicalKeyboardKey.keyF,
        primaryModifier: true,
      ),
    );
    add(
      'forge.focusPanel1',
      'Focus Panel 1',
      const ForgeShortcutKey(
        key: LogicalKeyboardKey.digit1,
        primaryModifier: true,
      ),
    );
    add(
      'forge.focusPanel2',
      'Focus Panel 2',
      const ForgeShortcutKey(
        key: LogicalKeyboardKey.digit2,
        primaryModifier: true,
      ),
    );
    add(
      'forge.focusPanel3',
      'Focus Panel 3',
      const ForgeShortcutKey(
        key: LogicalKeyboardKey.digit3,
        primaryModifier: true,
      ),
    );
    add(
      'forge.focusPanel4',
      'Focus Panel 4',
      const ForgeShortcutKey(
        key: LogicalKeyboardKey.digit4,
        primaryModifier: true,
      ),
    );
    add(
      'forge.saveAll',
      'Save All',
      const ForgeShortcutKey(
        key: LogicalKeyboardKey.keyS,
        primaryModifier: true,
      ),
    );
    add(
      'forge.focusNextPanel',
      'Focus Next Panel',
      const ForgeShortcutKey(
        key: LogicalKeyboardKey.bracketRight,
        primaryModifier: true,
      ),
    );
    add(
      'forge.focusPreviousPanel',
      'Focus Previous Panel',
      const ForgeShortcutKey(
        key: LogicalKeyboardKey.bracketLeft,
        primaryModifier: true,
      ),
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

      final shellShortcut = ForgeShortcutKey(
        key: shortcut.key,
        primaryModifier: shortcut.usePrimaryModifier,
        shift: shortcut.shift,
        alt: shortcut.alt,
      );

      final actionId = desc.id;
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
      _shortcuts.add(ForgeShortcutBinding(
        action: action,
        key: shellShortcut,
        context: desc.category,
      ));
    }
  }
}
