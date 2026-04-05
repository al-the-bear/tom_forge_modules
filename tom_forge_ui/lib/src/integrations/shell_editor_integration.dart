import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart' as shared;

import '../actions/forge_action.dart' as shell;
import '../actions/forge_shortcut_binding.dart' as shell;
import '../defaults/default_undo_manager.dart';
import '../shell/forge_shell_api.dart';

/// Debug toggle for shell integration tracing.
bool kShellEditorIntegrationDebug = false;

/// Bridges text editors to [ForgeShellApi] in integrated shell mode.
class ShellEditorIntegration extends shared.ForgeEditorIntegration
    with shared.StandardActionsMixin {
  final ForgeShellApi _shellApi;
  final String _editorId;
  final String _editorTypeId;

  final List<shared.TextChangeCallback> _textChangeListeners = [];
  final List<shared.SelectionChangeCallback> _selectionChangeListeners = [];
  final StreamController<shared.ForgeTextContext> _contextStream =
      StreamController<shared.ForgeTextContext>.broadcast();
  final Map<String, bool Function()> _enabledQueries = {};

  final Map<String, shared.ForgeAction> _knownActions = {};

  shared.ForgeTextContext _context = shared.TextEditingContextImpl.withValues(
    text: '',
    selections: const [TextSelection.collapsed(offset: 0)],
    isDirty: false,
    canUndo: false,
    canRedo: false,
  );

  ShellEditorIntegration({
    required ForgeShellApi shellApi,
    required String editorId,
    required String editorTypeId,
  })  : _shellApi = shellApi,
        _editorId = editorId,
        _editorTypeId = editorTypeId;

  /// The editor's local undo handler, saved when the editor registers its
  /// `forge.edit.undo` action. Used by bridge entries to delegate undo.
  VoidCallback? _editorUndoHandler;

  /// The editor's local redo handler, saved when the editor registers its
  /// `forge.edit.redo` action. Used by bridge entries to delegate redo.
  VoidCallback? _editorRedoHandler;

  /// Notify the shell undo manager of a text edit in this editor.
  ///
  /// Creates a bridge [UndoEntry] that delegates undo/redo to the editor's
  /// own undo/redo mechanism. Call this each time the editor pushes an entry
  /// to its local undo stack.
  @override
  void notifyTextEdit({String? label}) {
    final undoManager = _shellApi.undoManager;
    if (undoManager is! DefaultUndoManager) return;

    final undoFn = _editorUndoHandler;
    final redoFn = _editorRedoHandler;
    if (undoFn == null || redoFn == null) return;

    final entryLabel = label ?? 'Text edit [$_editorId]';
    undoManager.push(UndoEntry(
      undo: () async => undoFn(),
      redo: () async => redoFn(),
      label: entryLabel,
      data: {
        'type': 'text-edit',
        'editorId': _editorId,
        'editorType': _editorTypeId,
        'timestamp': DateTime.now().toIso8601String(),
        'label': entryLabel,
      },
    ));

    if (kShellEditorIntegrationDebug) {
      // ignore: avoid_print
      print('[ShellEditorIntegration] pushed bridge entry: $entryLabel');
    }
  }

  @override
  void beginUndoGroup({String? label}) {
    final undoManager = _shellApi.undoManager;
    if (undoManager is DefaultUndoManager) {
      undoManager.beginUndoGroup(label: label);
    }
  }

  @override
  void endUndoGroup() {
    final undoManager = _shellApi.undoManager;
    if (undoManager is DefaultUndoManager) {
      undoManager.endUndoGroup();
    }
  }

  @override
  shared.ForgeTextContext get textContext => _context;

  @override
  shared.ForgeTextSettings get textSettings =>
      _shellApi.getTextSettings(_editorTypeId);

  @override
  set textSettings(shared.ForgeTextSettings settings) {
    _shellApi.setTextSettings(_editorTypeId, settings);
  }

  @override
  void addTextChangeListener(shared.TextChangeCallback callback) {
    _textChangeListeners.add(callback);
  }

  @override
  void removeTextChangeListener(shared.TextChangeCallback callback) {
    _textChangeListeners.remove(callback);
  }

  @override
  void addSelectionChangeListener(shared.SelectionChangeCallback callback) {
    _selectionChangeListeners.add(callback);
  }

  @override
  void removeSelectionChangeListener(shared.SelectionChangeCallback callback) {
    _selectionChangeListeners.remove(callback);
  }

  @override
  List<shared.ForgeAction> get supportedActions {
    return _knownActions.values.toList(growable: false);
  }

  /// Registers a complete Forge action and bridges it into shell registries.
  void registerShellAction(shared.ForgeAction action) {
    _knownActions[action.id] = action;
    registerAction(
      action.id,
      () {
        action.execute({});
      },
      isEnabled: action.isEnabled,
    );
    _registerWithShell(action);
  }

  /// Standard editing action IDs that are handled internally by the editor
  /// or by Flutter's built-in text editing. These should NOT be registered
  /// with the shell's shortcut manager to avoid duplicating shell-level
  /// actions (e.g. `edit.undo` vs `forge.edit.undo`).
  static const _editorInternalActions = {
    shared.StandardEditingActions.cutActionId,
    shared.StandardEditingActions.copyActionId,
    shared.StandardEditingActions.pasteActionId,
    shared.StandardEditingActions.selectAllActionId,
    shared.StandardEditingActions.undoActionId,
    shared.StandardEditingActions.redoActionId,
  };

  @override
  void registerAction(
    String actionId,
    VoidCallback handler, {
    bool Function()? isEnabled,
  }) {
    // Capture editor undo/redo handlers for the bridge.
    if (actionId == shared.StandardEditingActions.undoActionId) {
      _editorUndoHandler = handler;
    } else if (actionId == shared.StandardEditingActions.redoActionId) {
      _editorRedoHandler = handler;
    }

    super.registerAction(actionId, handler, isEnabled: isEnabled);
    if (isEnabled != null) {
      _enabledQueries[actionId] = isEnabled;
    }

    // Standard editing actions are handled by the editor's own Shortcuts
    // widget — don't register them with the shell to avoid duplicates.
    if (_editorInternalActions.contains(actionId)) return;

    final action = _knownActions[actionId] ?? _resolveAction(actionId, isEnabled);
    if (action != null) {
      _knownActions[actionId] = action;
      _registerWithShell(action);
    }
  }

  @override
  void unregisterAction(String actionId) {
    super.unregisterAction(actionId);
    _knownActions.remove(actionId);
    _enabledQueries.remove(actionId);
    _shellApi.actionRegistry.unregisterAction(actionId);
  }

  @override
  bool executeAction(String actionId) {
    final handledByEditor = super.executeAction(actionId);
    if (handledByEditor) {
      return true;
    }
    return _shellApi.executeAction(actionId);
  }

  @override
  bool isActionEnabled(String actionId) {
    final enabled = _enabledQueries[actionId];
    if (enabled != null) {
      return enabled();
    }
    return _shellApi.isActionEnabled(actionId);
  }

  @override
  shared.ForgeShortcutKey? getShortcutForAction(String actionId) {
    final binding = _shellApi.shortcuts.getBinding(actionId);
    if (binding != null) {
      // Chord bindings are handled by the shell's chord system — do NOT
      // expose the first key as a direct shortcut to the editor, otherwise
      // the editor's Shortcuts widget would intercept the first key press
      // and execute the action immediately, bypassing the chord popup.
      if (binding.isChord) return null;
      return _toSharedShortcut(binding.key);
    }
    return _knownActions[actionId]?.defaultShortcut;
  }

  /// Reports context changes to shell state.
  void onContextChanged(shared.ForgeTextContext context) {
    _context = _ProxyTextContext(context, _contextStream.stream);
    _shellApi.systemState.updateEditorContext(_editorId, _context);
    _contextStream.add(_context);

    for (final listener in List.of(_textChangeListeners)) {
      listener(_context.text);
    }
    final primarySelection = _context.selections.isEmpty
        ? const TextSelection.collapsed(offset: 0)
        : _context.selections.first;
    for (final listener in List.of(_selectionChangeListeners)) {
      listener(primarySelection);
    }
  }

  /// Gets context menu actions provided by the shell.
  List<shared.ForgeAction> getContextMenuActions() {
    return _shellApi
        .getContextActionsFor(_editorId)
        .map(_toSharedAction)
        .toList(growable: false);
  }

  @override
  void requestFocus() {}

  @override
  bool get hasFocus => _shellApi.systemState.focusedComponent != null;

  @override
  void setText(String text, {bool addToUndoHistory = true}) {}

  @override
  void setSelection(TextSelection selection) {}

  @override
  void insertText(String text) {}

  @override
  void dispose() {
    _contextStream.close();
  }

  void _registerWithShell(shared.ForgeAction action) {
    final shellAction = _toShellAction(action);
    _shellApi.actionRegistry.registerAction(shellAction);
    final shortcut = action.defaultShortcut;
    if (shortcut != null) {
      _shellApi.shortcuts.rebind(shellAction, _toShellShortcut(shortcut));
    }
  }

  shared.ForgeAction? _resolveAction(
    String actionId,
    bool Function()? enabled,
  ) {
    final allActions = <shared.ForgeAction>[
      ...shared.StandardEditingActions.all(),
      shared.DartEditorActions.triggerCompletion(),
      shared.DartEditorActions.openReference(),
      shared.DartEditorActions.toggleComment(),
      shared.DartEditorActions.deleteLine(),
      shared.DartEditorActions.duplicateLine(),
      shared.DartEditorActions.moveLineUp(),
      shared.DartEditorActions.moveLineDown(),
      shared.MdEditorActions.toggleBold(),
      shared.MdEditorActions.toggleItalic(),
      shared.MdEditorActions.toggleCode(),
      shared.MdEditorActions.insertLink(),
      shared.MdEditorActions.insertTable(),
      shared.MdEditorActions.insertHeading(),
      shared.MdEditorActions.toggleList(),
      shared.MdEditorActions.save(),
      shared.MdEditorActions.search(),
      shared.YamlEditorActions.addKey(),
      shared.YamlEditorActions.removeKey(),
      shared.YamlEditorActions.toggleTextMode(),
      shared.YamlEditorActions.save(),
      shared.YamlEditorActions.search(),
    ];

    for (final action in allActions) {
      if (action.id == actionId) {
        if (enabled == null) {
          return action;
        }
        return shared.ForgeAction(
          id: action.id,
          label: action.label,
          icon: action.icon,
          menu: action.menu,
          group: action.group,
          priority: action.priority,
          execute: action.execute,
          isEnabled: enabled,
          isVisible: action.isVisible,
          defaultShortcut: action.defaultShortcut,
          showInContextMenu: action.showInContextMenu,
          undo: action.undo,
        );
      }
    }
    return null;
  }

  shell.ForgeAction _toShellAction(shared.ForgeAction action) {
    return shell.ForgeAction(
      id: action.id,
      label: action.label,
      icon: action.icon,
      menu: _toShellMenu(action.menu),
      group: action.group,
      priority: action.priority,
      execute: action.execute,
      isEnabled: action.isEnabled,
      isVisible: action.isVisible,
      defaultShortcut: action.defaultShortcut == null
          ? null
          : _toShellShortcut(action.defaultShortcut!),
      showInContextMenu: action.showInContextMenu,
      undo: action.undo,
    );
  }

  shared.ForgeAction _toSharedAction(shell.ForgeAction action) {
    return shared.ForgeAction(
      id: action.id,
      label: action.label,
      icon: action.icon,
      menu: _toSharedMenu(action.menu),
      group: action.group,
      priority: action.priority,
      execute: action.execute,
      isEnabled: action.isEnabled,
      isVisible: action.isVisible,
      defaultShortcut: action.defaultShortcut == null
          ? null
          : _toSharedShortcut(action.defaultShortcut!),
      showInContextMenu: action.showInContextMenu,
      undo: action.undo,
    );
  }

  shell.ForgeShortcutKey _toShellShortcut(shared.ForgeShortcutKey key) {
    return shell.ForgeShortcutKey(
      key: key.key,
      primaryModifier: key.usePrimaryModifier,
      shift: key.shift,
      alt: key.alt,
    );
  }

  shared.ForgeShortcutKey _toSharedShortcut(shell.ForgeShortcutKey key) {
    return shared.ForgeShortcutKey(
      key: key.key,
      usePrimaryModifier: key.primaryModifier,
      shift: key.shift,
      alt: key.alt,
    );
  }

  shell.ForgeMenuLocation _toShellMenu(shared.ForgeMenuLocation menu) {
    switch (menu) {
      case shared.ForgeMenuLocation.file:
        return shell.ForgeMenuLocation.file;
      case shared.ForgeMenuLocation.edit:
        return shell.ForgeMenuLocation.edit;
      case shared.ForgeMenuLocation.view:
        return shell.ForgeMenuLocation.view;
      case shared.ForgeMenuLocation.go:
        return shell.ForgeMenuLocation.go;
      case shared.ForgeMenuLocation.run:
        return shell.ForgeMenuLocation.run;
      case shared.ForgeMenuLocation.tools:
        return shell.ForgeMenuLocation.tools;
      case shared.ForgeMenuLocation.help:
        return shell.ForgeMenuLocation.help;
      case shared.ForgeMenuLocation.contextMenu:
        return shell.ForgeMenuLocation.contextMenu;
      case shared.ForgeMenuLocation.commandPalette:
        return shell.ForgeMenuLocation.commandPalette;
    }
  }

  shared.ForgeMenuLocation _toSharedMenu(shell.ForgeMenuLocation menu) {
    switch (menu) {
      case shell.ForgeMenuLocation.file:
        return shared.ForgeMenuLocation.file;
      case shell.ForgeMenuLocation.edit:
        return shared.ForgeMenuLocation.edit;
      case shell.ForgeMenuLocation.view:
        return shared.ForgeMenuLocation.view;
      case shell.ForgeMenuLocation.go:
        return shared.ForgeMenuLocation.go;
      case shell.ForgeMenuLocation.run:
        return shared.ForgeMenuLocation.run;
      case shell.ForgeMenuLocation.tools:
        return shared.ForgeMenuLocation.tools;
      case shell.ForgeMenuLocation.help:
        return shared.ForgeMenuLocation.help;
      case shell.ForgeMenuLocation.contextMenu:
        return shared.ForgeMenuLocation.contextMenu;
      case shell.ForgeMenuLocation.commandPalette:
        return shared.ForgeMenuLocation.commandPalette;
    }
  }
}

class _ProxyTextContext implements shared.ForgeTextContext {
  final shared.ForgeTextContext _delegate;
  final Stream<shared.ForgeTextContext> _stream;

  _ProxyTextContext(this._delegate, this._stream);

  @override
  String get text => _delegate.text;

  @override
  List<TextSelection> get selections => _delegate.selections;

  @override
  int? get cursorOffset => _delegate.cursorOffset;

  @override
  int? get currentLine => _delegate.currentLine;

  @override
  int? get currentColumn => _delegate.currentColumn;

  @override
  bool get isDirty => _delegate.isDirty;

  @override
  bool get canUndo => _delegate.canUndo;

  @override
  bool get canRedo => _delegate.canRedo;

  @override
  Stream<shared.ForgeTextContext> get onContextChanged => _stream;
}
