/// The undo conformance harness (wonecmpc19), run against a reference editor
/// built only from the shared helpers — one [ForgeTextHistory] and one
/// [ForgeSavedMarker] per document, every view on them, Flutter's own text
/// undo off ([ForgeEditorOwnsUndo]) — which meets every check. An editor
/// that keeps the contract the same way passes the same way; each editor's
/// own suite runs the harness against itself.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show
        ForgeEditorOwnsUndo,
        ForgeSavedMarker,
        ForgeTextHistory,
        ForgeTextState,
        StandardEditingActions;
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

void main() {
  runForgeUndoConformance('reference editor', _ReferenceSubject.new);
}

class _ReferenceSubject extends ForgeUndoSubject {
  _ReferenceSubject(String saved) : editor = _ReferenceEditor(saved);

  @override
  final _ReferenceEditor editor;

  @override
  void dispose() => editor.dispose();
}

/// One document: its state, its history and its saved marker, shared by
/// every view.
class _ReferenceEditor extends ForgeEditor {
  _ReferenceEditor(String saved)
    : document = ValueNotifier(ForgeTextState.atEnd(saved)),
      history = ForgeTextHistory(ForgeTextState.atEnd(saved)),
      marker = ForgeSavedMarker(saved);

  final ValueNotifier<ForgeTextState> document;
  final ForgeTextHistory history;
  final ForgeSavedMarker<String> marker;

  /// A view reports an edit that applied.
  void edited(ForgeTextState state) {
    if (state == document.value) return;
    document.value = state;
    history.edited(state);
    marker.compare(state.text);
  }

  void _show(ForgeTextState state) {
    document.value = state;
    marker.compare(state.text);
  }

  @override
  Set<String> get supportedActionIds => const {
    StandardEditingActions.undoActionId,
    StandardEditingActions.redoActionId,
  };

  @override
  bool isActionEnabled(String actionId) => switch (actionId) {
    StandardEditingActions.undoActionId => history.canUndo,
    StandardEditingActions.redoActionId => history.canRedo,
    _ => false,
  };

  @override
  bool executeAction(String actionId) => switch (actionId) {
    StandardEditingActions.undoActionId => history.undo(_show),
    StandardEditingActions.redoActionId => history.redo(_show),
    _ => false,
  };

  @override
  bool replaceContent(String content) {
    final state = ForgeTextState.atEnd(content);
    history.replace(state);
    document.value = state;
    marker.markSaved(content);
    return true;
  }

  @override
  String? getContent() => document.value.text;

  @override
  ValueListenable<bool> get isDirty => marker.isDirty;

  @override
  void markClean() {
    history.flush();
    marker.markSaved(document.value.text);
  }

  @override
  Widget buildMain(BuildContext context) => _ReferenceView(this);

  @override
  Widget buildCopy(BuildContext context) => _ReferenceView(this);

  @override
  ValueListenable<String> get title => ValueNotifier('reference.txt');

  @override
  ValueListenable<String?> get titleExtension => ValueNotifier(null);

  @override
  IconData get icon => Icons.description;

  @override
  Uri get uri => Uri.parse('file:///reference.txt');

  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.reject;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  void dispose() {
    history.dispose();
    marker.dispose();
    document.dispose();
  }
}

/// A view: its own text field, on the editor's one document.
class _ReferenceView extends StatefulWidget {
  const _ReferenceView(this.editor);

  final _ReferenceEditor editor;

  @override
  State<_ReferenceView> createState() => _ReferenceViewState();
}

class _ReferenceViewState extends State<_ReferenceView> {
  late final TextEditingController _controller = TextEditingController.fromValue(
    _valueOf(widget.editor.document.value),
  );

  static TextEditingValue _valueOf(ForgeTextState state) =>
      TextEditingValue(text: state.text, selection: state.selection);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onEdited);
    widget.editor.document.addListener(_onDocument);
  }

  void _onEdited() => widget.editor.edited(
    ForgeTextState(_controller.text, _controller.selection),
  );

  void _onDocument() {
    final state = widget.editor.document.value;
    if (_controller.text == state.text &&
        _controller.selection == state.selection) {
      return;
    }
    _controller.removeListener(_onEdited);
    _controller.value = _valueOf(state);
    _controller.addListener(_onEdited);
  }

  @override
  void dispose() {
    widget.editor.document.removeListener(_onDocument);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ForgeEditorOwnsUndo(
    child: TextField(controller: _controller, maxLines: null),
  );
}
