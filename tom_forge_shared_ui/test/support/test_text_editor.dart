/// A minimal [ForgeEditor] for the editor surface test: a line of text with
/// a selection and a history, the standard editing actions (undo, redo,
/// cut, copy, paste, select all) over the kit's clipboard, and a search of
/// its own ([ForgeFindTarget]).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show FileHandlingResult;
import 'package:tom_editors_shared/text_types.dart'
    show EditorStateSnapshot, StandardEditingActions;
import 'package:tom_forge_kit/tom_forge_kit.dart';

/// The widget key of the editor's text.
const Key testTextEditorTextKey = ValueKey('test.textEditor.text');

class TestTextEditor extends ForgeEditor implements ForgeFindTarget {
  TestTextEditor({required this.clipboard, String text = '', Uri? uri})
    : uri = uri ?? Uri.parse('memory:/test.txt'),
      _text = ValueNotifier(text);

  @override
  final Uri uri;

  /// The kit's clipboard the editor copies to and pastes from.
  final ForgeClipboard clipboard;

  final ValueNotifier<String> _text;
  int _start = 0;
  int _end = 0;
  final List<String> _undo = [];
  final List<String> _redo = [];
  final ValueNotifier<bool> _dirty = ValueNotifier(false);
  final StreamController<void> _changes = StreamController.broadcast();

  /// The actions the kit ran on the editor, in order.
  final List<String> executed = [];

  String get text => _text.value;

  /// The selected text.
  String get selection => text.substring(_start, _end);

  // ── Editing ──

  void select(int start, int end) {
    _start = start;
    _end = end;
    _changes.add(null);
  }

  /// Replaces the selection by [value], as typing does.
  void type(String value) {
    _undo.add(text);
    _redo.clear();
    _set(text.replaceRange(_start, _end, value));
    _start = _end = _start + value.length;
    _changes.add(null);
  }

  void _set(String value) {
    _text.value = value;
    _dirty.value = true;
    if (_end > value.length) _end = value.length;
    if (_start > _end) _start = _end;
  }

  // ── ForgeEditor ──

  @override
  Set<String> get supportedActionIds => const {
    StandardEditingActions.undoActionId,
    StandardEditingActions.redoActionId,
    StandardEditingActions.cutActionId,
    StandardEditingActions.copyActionId,
    StandardEditingActions.pasteActionId,
    StandardEditingActions.selectAllActionId,
  };

  @override
  EditorStateSnapshot get stateSnapshot => EditorStateSnapshot(
    hasSelection: _end > _start,
    hasContent: text.isNotEmpty,
    canUndo: _undo.isNotEmpty,
    canRedo: _redo.isNotEmpty,
  );

  @override
  Stream<void> get onStateChanged => _changes.stream;

  @override
  bool executeAction(String actionId) {
    executed.add(actionId);
    switch (actionId) {
      case StandardEditingActions.undoActionId:
        if (_undo.isEmpty) return false;
        _redo.add(text);
        _set(_undo.removeLast());
      case StandardEditingActions.redoActionId:
        if (_redo.isEmpty) return false;
        _undo.add(text);
        _set(_redo.removeLast());
      case StandardEditingActions.copyActionId:
        unawaited(clipboard.writeText(selection));
      case StandardEditingActions.cutActionId:
        unawaited(clipboard.writeText(selection));
        type('');
      case StandardEditingActions.pasteActionId:
        unawaited(clipboard.readText().then(type));
      case StandardEditingActions.selectAllActionId:
        select(0, text.length);
      default:
        return false;
    }
    _changes.add(null);
    return true;
  }

  @override
  ValueListenable<bool> get isDirty => _dirty;

  @override
  void markClean() => _dirty.value = false;

  @override
  String? getContent() => text;

  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.accept;

  @override
  ValueListenable<String> get title => ValueNotifier(uri.pathSegments.last);

  @override
  ValueListenable<String?> get titleExtension => ValueNotifier(null);

  @override
  IconData get icon => Icons.description;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: _text,
    builder: (context, value, _) => Text(value, key: testTextEditorTextKey),
  );

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);

  // ── ForgeFindTarget ──

  final ValueNotifier<ForgeFindStatus> _findStatus = ValueNotifier(
    ForgeFindStatus.none,
  );
  List<int> _matches = const [];

  /// The queries searched, in order.
  final List<String> queries = [];

  @override
  ValueListenable<ForgeFindStatus> get findStatus => _findStatus;

  @override
  void find(
    String query, {
    bool caseSensitive = false,
    bool wholeWord = false,
  }) {
    queries.add(query);
    _matches = [
      if (query.isNotEmpty)
        for (
          var i = text.indexOf(query);
          i >= 0;
          i = text.indexOf(query, i + 1)
        )
          i,
    ];
    _showMatch(0);
  }

  @override
  void findNext() => _showMatch(_findStatus.value.current % _matches.length);

  @override
  void findPrevious() => _showMatch(
    (_findStatus.value.current - 2 + _matches.length) % _matches.length,
  );

  void _showMatch(int index) {
    if (_matches.isEmpty) {
      _findStatus.value = ForgeFindStatus.none;
      return;
    }
    final query = queries.last;
    select(_matches[index], _matches[index] + query.length);
    _findStatus.value = ForgeFindStatus(
      current: index + 1,
      total: _matches.length,
    );
  }

  @override
  void clearFind() {
    _matches = const [];
    _findStatus.value = ForgeFindStatus.none;
  }
}
