import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:tom_undo/tom_undo.dart';

import '../forge_text_settings.dart';
import '../text_undo_entry.dart';

/// How long a pause in typing ends one entry and starts the next. The same
/// pause `ForgeFileSession` groups a file's typing by.
const Duration forgeTypingPause = Duration(milliseconds: 1500);

/// A text document's state: its text and its selection.
@immutable
class ForgeTextState {
  const ForgeTextState(this.text, this.selection);

  /// [text] with the caret at its end.
  ForgeTextState.atEnd(this.text)
    : selection = TextSelection.collapsed(offset: text.length);

  final String text;
  final TextSelection selection;

  @override
  bool operator ==(Object other) =>
      other is ForgeTextState &&
      other.text == text &&
      other.selection == selection;

  @override
  int get hashCode => Object.hash(text, selection);

  @override
  String toString() => 'ForgeTextState(${text.length} chars, $selection)';
}

/// One text document's undo history, kept the way every Forge editor keeps
/// it.
///
/// * **Typing is grouped by gesture.** Edits that follow each other with no
///   pause longer than [typingPause] and no caret move between them are one
///   entry; a pause, a caret move ([selected]) or a history boundary
///   ([flush]) ends the entry.
/// * **Each entry stores the text and the selection before and after**, so
///   undo puts the caret back where it was before the edit and redo where it
///   was after.
/// * **Pending typing is flushed at every boundary.** [undo] and [redo] flush
///   first, so a word typed within the pause is undone rather than lost; an
///   editor flushes on save, mode switch and blur.
/// * **No entry for a change that changed nothing**, and an entry is recorded
///   only for an edit that already applied — [edited] reports one.
/// * **Applied first, moved second** ([TomUndoStack]): an [undo] whose
///   application throws leaves the entry undoable.
///
/// The history keeps no dirty flag: dirty is the [ForgeSavedMarker]'s, and
/// [replace] (load, reload, external change, revision restore) is the one way
/// content arrives from outside it.
class ForgeTextHistory extends ChangeNotifier {
  ForgeTextHistory(
    ForgeTextState initial, {
    int maxEntries = ForgeTextDefaults.defaultMaxUndoHistory,
    this.typingPause = forgeTypingPause,
  }) : _current = initial,
       _stack = TomUndoStack<TextUndoEntry>(maxEntries: maxEntries);

  final TomUndoStack<TextUndoEntry> _stack;

  /// The pause that ends an entry.
  final Duration typingPause;

  ForgeTextState _current;

  /// The state the typing in progress started from, or null.
  ForgeTextState? _pendingBefore;
  Timer? _pauseTimer;

  /// True while [undo] or [redo] hands a state to the editor, so the edit
  /// that applying it causes is not recorded as a new one.
  var _applying = false;

  /// The document's state as the history last heard it.
  ForgeTextState get current => _current;

  /// How many entries the history keeps; the oldest beyond it are dropped.
  /// Set it from [ForgeTextSettings.maxUndoHistory].
  int get maxEntries => _stack.maxEntries;
  set maxEntries(int value) {
    if (value == _stack.maxEntries) return;
    _stack.maxEntries = value;
    notifyListeners();
  }

  /// Whether typing not yet made an entry is pending.
  bool get hasPendingTyping => _pendingBefore != null;

  bool get canUndo => _stack.canUndo || hasPendingTyping;
  bool get canRedo => _stack.canRedo && !hasPendingTyping;

  /// The recorded entries, oldest first (without pending typing).
  List<TextUndoEntry> get entries => _stack.undoEntries;

  /// The document changed to [after] — called after the edit applied.
  ///
  /// A change of the selection alone is a caret move ([selected]); a change
  /// of the text joins the typing in progress or starts it.
  void edited(ForgeTextState after) {
    if (_applying) {
      _current = after;
      return;
    }
    if (after.text == _current.text) {
      selected(after.selection);
      return;
    }
    _pendingBefore ??= _current;
    _current = after;
    _pauseTimer?.cancel();
    _pauseTimer = Timer(typingPause, flush);
    notifyListeners();
  }

  /// The caret moved without the text changing: the gesture in progress ends.
  void selected(TextSelection selection) {
    if (_applying || selection == _current.selection) {
      _current = ForgeTextState(_current.text, selection);
      return;
    }
    flush();
    _current = ForgeTextState(_current.text, selection);
  }

  /// Ends the typing in progress, making it an entry — unless the text came
  /// back to where it started, which is no change.
  void flush() {
    _pauseTimer?.cancel();
    _pauseTimer = null;
    final before = _pendingBefore;
    if (before == null) return;
    _pendingBefore = null;
    if (before.text != _current.text) {
      _stack.push(
        TextUndoEntry(
          oldText: before.text,
          newText: _current.text,
          oldSelection: before.selection,
          newSelection: _current.selection,
        ),
      );
    }
    notifyListeners();
  }

  /// Takes back the newest entry: flushes pending typing, then hands
  /// [apply] the state before it. Returns whether there was one.
  bool undo(void Function(ForgeTextState before) apply) {
    flush();
    final entry = _stack.undo((entry) {
      final before = ForgeTextState(
        entry.oldText,
        entry.oldSelection ?? TextSelection.collapsed(offset: entry.oldText.length),
      );
      _apply(before, apply);
    });
    if (entry == null) return false;
    notifyListeners();
    return true;
  }

  /// Puts the newest undone entry back: hands [apply] the state after it.
  /// Typing pending since the undo ends the redo future, so there is then
  /// nothing to redo.
  bool redo(void Function(ForgeTextState after) apply) {
    flush();
    final entry = _stack.redo((entry) {
      final after = ForgeTextState(
        entry.newText,
        entry.newSelection ?? TextSelection.collapsed(offset: entry.newText.length),
      );
      _apply(after, apply);
    });
    if (entry == null) return false;
    notifyListeners();
    return true;
  }

  void _apply(ForgeTextState state, void Function(ForgeTextState) apply) {
    _applying = true;
    try {
      apply(state);
    } finally {
      _applying = false;
    }
    _current = state;
  }

  /// Content arrived from outside the history — a load, a reload, an
  /// external change, a revision restore: the history is cleared, since an
  /// entry made against the old text would apply to text it was not made on.
  void replace(ForgeTextState state) {
    _pauseTimer?.cancel();
    _pauseTimer = null;
    _pendingBefore = null;
    _stack.clear();
    _current = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    super.dispose();
  }
}
