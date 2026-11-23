import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show ForgeTextRange;
import 'package:tom_forge_kit/tom_forge_kit.dart';

import '../forge_dimensions.dart';

/// The widget key of an editor surface's find field.
const Key forgeEditorSurfaceFindFieldKey = ValueKey(
  'forge.editorSurface.findField',
);

/// The widget key of an editor surface's find status (`2/5`, `No results`).
const Key forgeEditorSurfaceFindStatusKey = ValueKey(
  'forge.editorSurface.findStatus',
);

/// Shows any [ForgeEditor] (its `buildMain`) and connects it to the kit, the
/// way the panel shell connects the editors of its tabs, without a layout:
///
/// - **State.** The editor is reported open to [api]'s state while the
///   surface is in the tree, and active — the editor the kit's actions go
///   to — when the focus enters it (a state that is a
///   [ForgeEditorStateSink], such as `DefaultKitState`).
/// - **Keys.** A key the editor itself leaves unhandled is looked up in the
///   kit's binding table ([forgeActionIdForKey]) and run through
///   [ForgeKitApi.executeAction]; a key whose action did nothing is passed
///   on. The standard editing actions and their keys are installed in the
///   kit when missing ([installForgeStandardEditingActions]), so undo,
///   redo, cut, copy, paste and select all reach the editor by key, by
///   `api.undo()` / `api.redo()` and by `api.executeAction(id)` alike, as
///   the shell routes them: through the editor's `EditorActionProvider`.
///   The editor writes and reads the clipboard through the kit's
///   (`api.clipboard`).
/// - **Find.** While no one else has registered Find ([forgeFindActionId],
///   bound to the primary modifier + F when that key is free), the active
///   surface registers it: it opens a find field above the editor that
///   searches a [ForgeFindTarget] through its own search, a
///   [ForgeTextEditor] through `findAll`, selecting and revealing each
///   match; Enter and Shift+Enter move to the next and previous match,
///   Escape closes it.
class ForgeEditorSurface extends StatefulWidget {
  const ForgeEditorSurface({
    super.key,
    required this.api,
    required this.editor,
    this.autofocus = false,
  });

  final ForgeKitApi api;
  final ForgeEditor editor;

  /// Whether the editor takes the focus when shown.
  final bool autofocus;

  @override
  State<ForgeEditorSurface> createState() => ForgeEditorSurfaceState();
}

/// The state of a [ForgeEditorSurface]: [openFind] and [closeFind] for a
/// host that drives the find field itself.
class ForgeEditorSurfaceState extends State<ForgeEditorSurface> {
  /// The Find action a surface registered, per kit: the one surface whose
  /// find field Find opens is the one that registered it last.
  static final Expando<ForgeAction> _surfaceFindActions = Expando();

  final FocusNode _editorFocus = FocusNode(debugLabel: 'ForgeEditorSurface');
  final FocusNode _findFocus = FocusNode(debugLabel: 'ForgeEditorSurface.find');
  final TextEditingController _findQuery = TextEditingController();
  bool _findOpen = false;

  /// The matches in a text editor, and the current one.
  List<ForgeTextRange> _textMatches = const [];
  int _textMatch = 0;

  ForgeEditorStateSink? get _sink {
    final state = widget.api.state;
    return state is ForgeEditorStateSink ? state as ForgeEditorStateSink : null;
  }

  /// Whether the editor can be searched.
  bool get canFind =>
      widget.editor is ForgeFindTarget || widget.editor is ForgeTextEditor;

  /// Whether the find field is open.
  bool get isFindOpen => _findOpen;

  @override
  void initState() {
    super.initState();
    installForgeStandardEditingActions(widget.api);
    _sink?.addOpenEditor(widget.editor);
  }

  @override
  void didUpdateWidget(ForgeEditorSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.editor, widget.editor) ||
        !identical(oldWidget.api, widget.api)) {
      _releaseFind(oldWidget.api);
      final oldState = oldWidget.api.state;
      if (oldState is ForgeEditorStateSink) {
        (oldState as ForgeEditorStateSink).removeOpenEditor(oldWidget.editor);
      }
      installForgeStandardEditingActions(widget.api);
      _sink?.addOpenEditor(widget.editor);
      _textMatches = const [];
      if (_editorFocus.hasFocus) _activate();
    }
  }

  @override
  void dispose() {
    _releaseFind(widget.api);
    _sink?.removeOpenEditor(widget.editor);
    _editorFocus.dispose();
    _findFocus.dispose();
    _findQuery.dispose();
    super.dispose();
  }

  // ── State ──

  /// The editor is the one the user works in: it becomes the kit's active
  /// editor, and Find opens this surface's field.
  void _activate() {
    if (!identical(widget.api.state.activeEditor, widget.editor)) {
      _sink?.setActiveEditor(widget.editor);
    }
    _claimFind();
  }

  // ── Keys ──

  KeyEventResult _onEditorKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = ForgeShortcutKey.fromPressed(
      event.logicalKey,
      HardwareKeyboard.instance.logicalKeysPressed,
    );
    if (key == null) return KeyEventResult.ignored;
    final actionId = forgeActionIdForKey(widget.api.shortcuts, key);
    if (actionId == null) return KeyEventResult.ignored;
    _activate();
    // A key whose action did nothing is not consumed, so whatever is above
    // the surface gets it.
    return widget.api.executeAction(actionId)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  // ── Find ──

  /// Registers Find for this surface unless another owner (an application
  /// with a find of its own) has it.
  void _claimFind() {
    final registry = widget.api.actionRegistry;
    final current = registry.getAction(forgeFindActionId);
    final ours = _surfaceFindActions[widget.api];
    if (current != null && !identical(current, ours)) return;
    final action = ForgeAction(
      id: forgeFindActionId,
      label: 'Find',
      menu: ForgeMenuLocation.edit,
      defaultShortcut: const ForgeShortcutKey(
        key: LogicalKeyboardKey.keyF,
        primaryModifier: true,
      ),
      execute: (_) async {
        openFind();
        return null;
      },
      isEnabled: () => mounted && canFind,
      isVisible: () => true,
    );
    registry.registerAction(action);
    _surfaceFindActions[widget.api] = action;
    _ownedFind = action;
    final shortcut = action.defaultShortcut!;
    if (widget.api.shortcuts.getBinding(forgeFindActionId) == null &&
        widget.api.shortcuts.conflictsWith(shortcut) == null) {
      widget.api.shortcuts.rebind(action, shortcut);
    }
  }

  ForgeAction? _ownedFind;

  /// Removes the Find this surface registered, if it is still the
  /// registered one.
  void _releaseFind(ForgeKitApi api) {
    final owned = _ownedFind;
    if (owned == null) return;
    _ownedFind = null;
    if (identical(api.actionRegistry.getAction(forgeFindActionId), owned)) {
      api.actionRegistry.unregisterAction(forgeFindActionId);
      _surfaceFindActions[api] = null;
    }
  }

  /// Opens the find field (or focuses it) and searches its query again.
  void openFind() {
    if (!canFind || !mounted) return;
    setState(() => _findOpen = true);
    _findFocus.requestFocus();
    _findQuery.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _findQuery.text.length,
    );
    if (_findQuery.text.isNotEmpty) _search(_findQuery.text);
  }

  /// Closes the find field, ends the search and gives the editor the focus.
  void closeFind() {
    if (!_findOpen) return;
    final editor = widget.editor;
    if (editor is ForgeFindTarget) (editor as ForgeFindTarget).clearFind();
    setState(() {
      _findOpen = false;
      _textMatches = const [];
    });
    _editorFocus.requestFocus();
  }

  void _search(String query) {
    final editor = widget.editor;
    if (editor is ForgeFindTarget) {
      (editor as ForgeFindTarget).find(query);
      return;
    }
    if (editor is ForgeTextEditor) {
      setState(() {
        _textMatches = query.isEmpty
            ? const []
            : editor.findAll(
                RegExp(RegExp.escape(query), caseSensitive: false),
              );
        _textMatch = 0;
      });
      _showTextMatch();
    }
  }

  void _move({required bool forward}) {
    final editor = widget.editor;
    if (editor is ForgeFindTarget) {
      final target = editor as ForgeFindTarget;
      forward ? target.findNext() : target.findPrevious();
      return;
    }
    if (_textMatches.isEmpty) return;
    setState(() {
      final count = _textMatches.length;
      _textMatch = (_textMatch + (forward ? 1 : count - 1)) % count;
    });
    _showTextMatch();
  }

  void _showTextMatch() {
    final editor = widget.editor;
    if (editor is! ForgeTextEditor || _textMatches.isEmpty) return;
    final range = _textMatches[_textMatch];
    editor.setSelection(range);
    editor.revealRange(range);
  }

  KeyEventResult _onFindKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      closeFind();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _move(forward: !HardwareKeyboard.instance.isShiftPressed);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_findOpen) _buildFindBar(context),
      Expanded(
        child: Focus(
          focusNode: _editorFocus,
          autofocus: widget.autofocus,
          onFocusChange: (focused) {
            if (focused) _activate();
          },
          onKeyEvent: _onEditorKey,
          child: Builder(builder: widget.editor.buildMain),
        ),
      ),
    ],
  );

  Widget _buildFindBar(BuildContext context) {
    final theme = Theme.of(context);
    final editor = widget.editor;
    final status = editor is ForgeFindTarget
        ? ValueListenableBuilder<ForgeFindStatus>(
            valueListenable: (editor as ForgeFindTarget).findStatus,
            builder: (context, status, _) =>
                _statusText(context, status.current, status.total),
          )
        : _statusText(
            context,
            _textMatches.isEmpty ? 0 : _textMatch + 1,
            _textMatches.length,
          );
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SizedBox(
        height: ForgeDimensions.menuBarHeight,
        child: Row(
          children: [
            const SizedBox(width: 8),
            Expanded(
              child: Focus(
                onKeyEvent: _onFindKey,
                child: TextField(
                  key: forgeEditorSurfaceFindFieldKey,
                  controller: _findQuery,
                  focusNode: _findFocus,
                  onChanged: _search,
                  style: theme.textTheme.bodySmall,
                  decoration: const InputDecoration(
                    hintText: 'Find',
                    isDense: true,
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            status,
            IconButton(
              tooltip: 'Previous match',
              iconSize: 16,
              icon: const Icon(Icons.arrow_upward),
              onPressed: () => _move(forward: false),
            ),
            IconButton(
              tooltip: 'Next match',
              iconSize: 16,
              icon: const Icon(Icons.arrow_downward),
              onPressed: () => _move(forward: true),
            ),
            IconButton(
              tooltip: 'Close',
              iconSize: 16,
              icon: const Icon(Icons.close),
              onPressed: closeFind,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusText(BuildContext context, int current, int total) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Text(
      _findQuery.text.isEmpty
          ? ''
          : total == 0
          ? 'No results'
          : '$current/$total',
      key: forgeEditorSurfaceFindStatusKey,
      style: Theme.of(context).textTheme.labelSmall,
    ),
  );
}
