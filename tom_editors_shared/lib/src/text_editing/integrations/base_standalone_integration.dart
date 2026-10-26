import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:tom_undo/tom_undo.dart';

import '../../forge_bridge/editor_action_descriptor.dart';
import '../../forge_bridge/forge_action.dart';
import '../../forge_bridge/forge_shortcut_key.dart';
import '../forge_editor_integration.dart';
import '../forge_text_context.dart';
import '../forge_text_settings.dart';
import '../standard_editing_actions.dart';
import '../text_undo_entry.dart';

/// Debug flag for BaseStandaloneIntegration.
bool kBaseStandaloneIntegrationDebug = false;

void _log(String message) {
  if (kBaseStandaloneIntegrationDebug) {
    // ignore: avoid_print
    print('[BaseStandaloneIntegration] $message');
  }
}

/// A base implementation of [ForgeEditorIntegration] for standalone text fields.
///
/// Provides:
/// - Built-in undo/redo stack
/// - Standard editing actions (cut, copy, paste, select all, undo, redo)
/// - Change notification support
///
/// Usage:
/// ```dart
/// final integration = BaseStandaloneIntegration(
///   controller: myTextController,
///   focusNode: myFocusNode,
/// );
/// ```
class BaseStandaloneIntegration extends ForgeEditorIntegration
    with StandardActionsMixin {
  /// The text editing controller.
  final TextEditingController controller;

  /// The focus node for this editor.
  final FocusNode focusNode;

  /// Maximum undo history size.
  final int maxUndoStackSize;

  /// Whether to automatically track text changes for undo/redo.
  ///
  /// When `true` (default), every text change detected from the controller
  /// is pushed to the undo stack automatically.
  ///
  /// When `false`, the undo stack is not populated automatically. The host
  /// editor must manage its own undo mechanism (e.g. debounced saving) and
  /// register custom undo/redo handlers via [registerAction].
  /// Text and selection change listeners are still notified regardless.
  final bool enableAutoUndoTracking;

  // State
  ForgeTextSettings _textSettings;
  late final TomUndoStack<TextUndoEntry> _history =
      TomUndoStack(maxEntries: maxUndoStackSize);

  // Listeners
  final List<TextChangeCallback> _textChangeListeners = [];
  final List<SelectionChangeCallback> _selectionChangeListeners = [];

  // Track previous state for undo entries
  String _previousText = '';
  TextSelection? _previousSelection;

  /// Creates a standalone integration with the given controller and focus node.
  BaseStandaloneIntegration({
    required this.controller,
    required this.focusNode,
    ForgeTextSettings? textSettings,
    this.maxUndoStackSize = 100,
    this.enableAutoUndoTracking = true,
  }) : _textSettings = textSettings ?? const ForgeTextSettings() {
    _previousText = controller.text;
    _previousSelection = controller.selection;

    // Listen to controller changes
    controller.addListener(_onControllerChanged);

    // Register standard actions
    _registerStandardActions();

    _log('Created with text length: ${controller.text.length}');
  }

  void _registerStandardActions() {
    registerAction(
      StandardEditingActions.cutActionId,
      _doCut,
      isEnabled: () => _hasSelection,
    );
    registerAction(
      StandardEditingActions.copyActionId,
      _doCopy,
      isEnabled: () => _hasSelection,
    );
    registerAction(
      StandardEditingActions.pasteActionId,
      _doPaste,
    );
    registerAction(
      StandardEditingActions.selectAllActionId,
      _doSelectAll,
      isEnabled: () => controller.text.isNotEmpty,
    );
    registerAction(
      StandardEditingActions.undoActionId,
      _doUndo,
      isEnabled: () => _history.canUndo,
    );
    registerAction(
      StandardEditingActions.redoActionId,
      _doRedo,
      isEnabled: () => _history.canRedo,
    );
    registerAction(
      StandardEditingActions.deleteLineActionId,
      _doDeleteLine,
      isEnabled: () => controller.text.isNotEmpty,
    );
    registerAction(
      StandardEditingActions.duplicateLineActionId,
      _doDuplicateLine,
      isEnabled: () => controller.text.isNotEmpty,
    );
    registerAction(
      StandardEditingActions.moveLineUpActionId,
      _doMoveLineUp,
      isEnabled: () => controller.text.isNotEmpty,
    );
    registerAction(
      StandardEditingActions.moveLineDownActionId,
      _doMoveLineDown,
      isEnabled: () => controller.text.isNotEmpty,
    );
    registerAction(
      StandardEditingActions.toggleCommentActionId,
      _doToggleComment,
      isEnabled: () => controller.text.isNotEmpty,
    );

    _log('Registered ${supportedActions.length} standard actions');
  }

  bool get _hasSelection {
    final selection = controller.selection;
    return selection.isValid &&
        !selection.isCollapsed &&
        selection.start >= 0 &&
        selection.end <= controller.text.length;
  }

  void _onControllerChanged() {
    final newText = controller.text;
    final newSelection = controller.selection;

    if (newText != _previousText) {
      _log('Text changed: ${_previousText.length} -> ${newText.length} chars');

      // Add to undo stack (only if auto-tracking is enabled)
      if (enableAutoUndoTracking) {
        _addUndoEntry(TextUndoEntry(
          oldText: _previousText,
          newText: newText,
          oldSelection: _previousSelection,
          newSelection: newSelection,
        ));
      }

      _previousText = newText;

      // Notify listeners
      for (final listener in List.of(_textChangeListeners)) {
        listener(newText);
      }
    }

    if (newSelection != _previousSelection) {
      _log('Selection changed: $newSelection');
      _previousSelection = newSelection;

      // Notify listeners
      for (final listener in List.of(_selectionChangeListeners)) {
        listener(newSelection);
      }
    }
  }

  void _addUndoEntry(TextUndoEntry entry) {
    _history.push(entry);

    // Notify bridge for shell undo manager integration.
    notifyTextEdit(label: entry.description);

    _log('Undo stack size: ${_history.undoCount}');
  }

  // Standard action implementations

  void _doCut() {
    if (!_hasSelection) return;
    final selection = controller.selection;
    final text = controller.text.substring(selection.start, selection.end);
    _log('Cut: "${_truncate(text)}"');
    Clipboard.setData(ClipboardData(text: text));
    controller.text = controller.text.substring(0, selection.start) +
        controller.text.substring(selection.end);
    controller.selection = TextSelection.collapsed(offset: selection.start);
  }

  void _doCopy() {
    if (!_hasSelection) return;
    final selection = controller.selection;
    final text = controller.text.substring(selection.start, selection.end);
    _log('Copy: "${_truncate(text)}"');
    Clipboard.setData(ClipboardData(text: text));
  }

  void _doPaste() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text == null) return;
    final pasteText = clipboardData!.text!;
    _log('Paste: "${_truncate(pasteText)}"');
    insertText(pasteText);
  }

  void _doSelectAll() {
    _log('Select all');
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }

  // Applied without triggering a new undo entry.
  void _doUndo() => _history.undo((entry) {
        _log('Undo: ${entry.description ?? "change"}');
        _applyTextWithoutUndo(entry.oldText, entry.oldSelection);
      });

  void _doRedo() => _history.redo((entry) {
        _log('Redo');
        _applyTextWithoutUndo(entry.newText, entry.newSelection);
      });

  // Line editing action implementations

  /// The comment prefix used by [_doToggleComment].
  ///
  /// Defaults to `// ` (Dart-style). Subclasses may override for other
  /// languages (e.g. `# ` for YAML, `<!-- -->` for HTML).
  String get commentPrefix => '// ';

  /// Get the start and end offsets of the line containing [offset].
  ({int start, int end}) _getLineRange(String text, int offset) {
    final clamped = offset.clamp(0, text.length);
    int start = clamped;
    while (start > 0 && text[start - 1] != '\n') {
      start--;
    }
    int end = clamped;
    while (end < text.length && text[end] != '\n') {
      end++;
    }
    return (start: start, end: end);
  }

  void _doDeleteLine() {
    final text = controller.text;
    final cursor = controller.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) return;

    final lineRange = _getLineRange(text, cursor);
    int deleteStart = lineRange.start;
    int deleteEnd = lineRange.end;
    if (deleteEnd < text.length && text[deleteEnd] == '\n') {
      deleteEnd++;
    } else if (deleteStart > 0 && text[deleteStart - 1] == '\n') {
      deleteStart--;
    }

    final newText = text.substring(0, deleteStart) + text.substring(deleteEnd);
    final newCursor = deleteStart.clamp(0, newText.length);
    _log('Delete line at offset $cursor');

    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: newCursor);
  }

  void _doDuplicateLine() {
    final text = controller.text;
    final cursor = controller.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) return;

    final lineRange = _getLineRange(text, cursor);
    final line = text.substring(lineRange.start, lineRange.end);
    final columnOffset = cursor - lineRange.start;

    final newText =
        '${text.substring(0, lineRange.end)}\n$line${text.substring(lineRange.end)}';
    final newCursor =
        (lineRange.end + 1 + columnOffset).clamp(0, newText.length);
    _log('Duplicate line at offset $cursor');

    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: newCursor);
  }

  void _doMoveLineUp() {
    final text = controller.text;
    final cursor = controller.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) return;

    final currentRange = _getLineRange(text, cursor);
    if (currentRange.start == 0) return; // Already at top

    final prevRange = _getLineRange(text, currentRange.start - 1);
    final currentLine = text.substring(currentRange.start, currentRange.end);
    final prevLine = text.substring(prevRange.start, prevRange.end);
    final columnOffset = cursor - currentRange.start;

    final newText =
        '${text.substring(0, prevRange.start)}$currentLine\n$prevLine${text.substring(currentRange.end)}';
    final newCursor =
        (prevRange.start + columnOffset).clamp(0, newText.length);
    _log('Move line up at offset $cursor');

    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: newCursor);
  }

  void _doMoveLineDown() {
    final text = controller.text;
    final cursor = controller.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) return;

    final currentRange = _getLineRange(text, cursor);
    if (currentRange.end >= text.length) return; // Already at bottom

    final nextRange = _getLineRange(text, currentRange.end + 1);
    final currentLine = text.substring(currentRange.start, currentRange.end);
    final nextLine = text.substring(nextRange.start, nextRange.end);
    final columnOffset = cursor - currentRange.start;

    final newText =
        '${text.substring(0, currentRange.start)}$nextLine\n$currentLine${text.substring(nextRange.end)}';
    final newCursor =
        (currentRange.start + nextLine.length + 1 + columnOffset)
            .clamp(0, newText.length);
    _log('Move line down at offset $cursor');

    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: newCursor);
  }

  void _doToggleComment() {
    final text = controller.text;
    final cursor = controller.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) return;

    final prefix = commentPrefix;
    final lineRange = _getLineRange(text, cursor);
    final line = text.substring(lineRange.start, lineRange.end);
    final trimmed = line.trimLeft();
    final indent = line.length - trimmed.length;

    String newLine;
    if (trimmed.startsWith(prefix)) {
      // Remove comment prefix
      newLine = line.substring(0, indent) + trimmed.substring(prefix.length);
    } else if (prefix.endsWith(' ') && trimmed.startsWith(prefix.trimRight())) {
      // Remove comment prefix without trailing space
      newLine = line.substring(0, indent) +
          trimmed.substring(prefix.trimRight().length);
    } else {
      // Add comment prefix
      newLine = '${line.substring(0, indent)}$prefix$trimmed';
    }

    final newText = text.substring(0, lineRange.start) +
        newLine +
        text.substring(lineRange.end);
    final cursorDelta = newLine.length - line.length;
    _log('Toggle comment at offset $cursor');

    controller.text = newText;
    controller.selection = TextSelection.collapsed(
      offset: (cursor + cursorDelta).clamp(0, newText.length),
    );
  }

  void _applyTextWithoutUndo(String text, TextSelection? selection) {
    // Temporarily remove listener to avoid adding to undo stack
    controller.removeListener(_onControllerChanged);

    controller.text = text;
    if (selection != null && selection.isValid) {
      controller.selection = selection;
    }

    _previousText = text;
    _previousSelection = selection;

    controller.addListener(_onControllerChanged);

    // Still notify listeners
    for (final listener in List.of(_textChangeListeners)) {
      listener(text);
    }
  }

  String _truncate(String text, {int maxLength = 30}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  // ForgeEditorIntegration implementation

  @override
  ForgeTextContext get textContext => TextEditingContextImpl.withValues(
        text: controller.text,
        selections: [controller.selection],
        canUndo: _history.canUndo,
        canRedo: _history.canRedo,
      );

  @override
  ForgeTextSettings get textSettings => _textSettings;

  @override
  set textSettings(ForgeTextSettings settings) {
    _log('Text settings updated');
    _textSettings = settings;
  }

  @override
  void addTextChangeListener(TextChangeCallback callback) {
    _textChangeListeners.add(callback);
  }

  @override
  void removeTextChangeListener(TextChangeCallback callback) {
    _textChangeListeners.remove(callback);
  }

  @override
  void addSelectionChangeListener(SelectionChangeCallback callback) {
    _selectionChangeListeners.add(callback);
  }

  @override
  void removeSelectionChangeListener(SelectionChangeCallback callback) {
    _selectionChangeListeners.remove(callback);
  }

  @override
  List<EditorActionDescriptor> get actionDescriptors =>
      StandardEditingActions.descriptors;

  @override
  List<ForgeAction> get supportedActions => [
        StandardEditingActions.cut(),
        StandardEditingActions.copy(),
        StandardEditingActions.paste(),
        StandardEditingActions.selectAll(),
        StandardEditingActions.undo(),
        StandardEditingActions.redo(),
        StandardEditingActions.deleteLine(),
        StandardEditingActions.duplicateLine(),
        StandardEditingActions.moveLineUp(),
        StandardEditingActions.moveLineDown(),
        StandardEditingActions.toggleComment(),
      ];

  @override
  ForgeShortcutKey? getShortcutForAction(String actionId) {
    // Return standard shortcuts
    switch (actionId) {
      case StandardEditingActions.cutActionId:
        return StandardEditingActions.cutShortcut;
      case StandardEditingActions.copyActionId:
        return StandardEditingActions.copyShortcut;
      case StandardEditingActions.pasteActionId:
        return StandardEditingActions.pasteShortcut;
      case StandardEditingActions.selectAllActionId:
        return StandardEditingActions.selectAllShortcut;
      case StandardEditingActions.undoActionId:
        return StandardEditingActions.undoShortcut;
      case StandardEditingActions.redoActionId:
        return StandardEditingActions.redoShortcut;
      case StandardEditingActions.deleteLineActionId:
        return StandardEditingActions.deleteLineShortcut;
      case StandardEditingActions.duplicateLineActionId:
        return StandardEditingActions.duplicateLineShortcut;
      case StandardEditingActions.moveLineUpActionId:
        return StandardEditingActions.moveLineUpShortcut;
      case StandardEditingActions.moveLineDownActionId:
        return StandardEditingActions.moveLineDownShortcut;
      case StandardEditingActions.toggleCommentActionId:
        return StandardEditingActions.toggleCommentShortcut;
      default:
        return null;
    }
  }

  @override
  void requestFocus() {
    _log('Requesting focus');
    focusNode.requestFocus();
  }

  @override
  bool get hasFocus => focusNode.hasFocus;

  @override
  void setText(String text, {bool addToUndoHistory = true}) {
    _log('setText: ${text.length} chars, addToUndo: $addToUndoHistory');
    if (addToUndoHistory) {
      controller.text = text;
    } else {
      _applyTextWithoutUndo(
        text,
        TextSelection.collapsed(offset: text.length),
      );
    }
  }

  @override
  void setSelection(TextSelection selection) {
    _log('setSelection: $selection');
    controller.selection = selection;
  }

  @override
  void insertText(String text) {
    final selection = controller.selection;
    final currentText = controller.text;

    String newText;
    int newOffset;

    if (selection.isValid && !selection.isCollapsed) {
      // Replace selection
      newText = currentText.substring(0, selection.start) +
          text +
          currentText.substring(selection.end);
      newOffset = selection.start + text.length;
    } else {
      // Insert at cursor
      final offset = selection.isValid ? selection.baseOffset : currentText.length;
      newText = currentText.substring(0, offset) +
          text +
          currentText.substring(offset);
      newOffset = offset + text.length;
    }

    _log('insertText: "${_truncate(text)}" at ${selection.baseOffset}');
    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: newOffset);
  }

  @override
  void dispose() {
    _log('Disposing');
    controller.removeListener(_onControllerChanged);
    _textChangeListeners.clear();
    _selectionChangeListeners.clear();
    _history.clear();
  }
}
