import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show EditorCapabilities, EditorStateSnapshot, StandardEditingActions;
import 'package:tom_forge_core/tom_forge_core.dart' show FileHandlingResult;
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_pdf_editor/tom_pdf_editor.dart';

import 'forge_pdf_host.dart';
import 'forge_pdf_trail.dart';

/// The shell's Find action, which the PDF editors' Cmd+F runs: the shell's
/// find bar searches them as [ForgeFindTarget]s.
const forgePdfFindActionId = 'editor.find';

/// The PDFium editor as a Forge editor (choice `pdf.pdfium`, the default for
/// `.pdf`): `TomPdfEditor` over its controller, the shell's save, undo,
/// redo, copy and find routed to the controller, the dirty marker the
/// controller's (the annotation history's saved marker).
class ForgePdfEditor extends ForgeEditor implements ForgeFindTarget {
  /// An editor of [uri] over [host]; it opens the document at once.
  ForgePdfEditor({
    required this.uri,
    required this.host,
    this.decoder = decodeBgra,
  }) : controller = TomPdfEditorController(host) {
    _title = ValueNotifier(host.name);
    host.onHistoryChanged = _changed;
    controller.addListener(_changed);
    unawaited(controller.open());
    forgePdfTrail('pdfium editor for ${host.name}');
  }

  @override
  final Uri uri;

  /// The host.
  final ForgePdfHost host;

  /// Decodes rendered pixels (a test gives its own).
  final PdfImageDecoder decoder;

  /// The controller.
  final TomPdfEditorController controller;

  late final ValueNotifier<String> _title;
  final _titleExtension = ValueNotifier<String?>(null);
  final _dirty = ValueNotifier(false);
  final _states = StreamController<void>.broadcast();
  bool _closed = false;

  final _findStatus = ValueNotifier(ForgeFindStatus.none);

  void _changed() {
    if (_closed) return;
    _dirty.value = controller.isDirty;
    final hits = controller.hits.length;
    _findStatus.value = ForgeFindStatus(
      current: hits == 0 ? 0 : controller.currentHit + 1,
      total: hits,
      searching: controller.searching,
    );
    if (!_states.isClosed) _states.add(null);
  }

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => Icons.picture_as_pdf_outlined;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints(
    minSize: Size(240, 200),
    preferredSize: Size(800, 900),
  );

  @override
  FileHandlingResult canHandle(Uri uri) =>
      uri == this.uri ? FileHandlingResult.accept : FileHandlingResult.reject;

  @override
  ValueListenable<bool> get isDirty => _dirty;

  /// The controller keeps its own saved marker (it saves the file itself);
  /// the shell never marks this editor clean.
  @override
  void markClean() {}

  /// A binary document cannot take a string: the shell closes the editor
  /// and opens the file again (a new controller, an empty history).
  @override
  bool replaceContent(String content) => false;

  @override
  Set<String> get supportedActionIds => const {
    StandardEditingActions.saveActionId,
    StandardEditingActions.undoActionId,
    StandardEditingActions.redoActionId,
    StandardEditingActions.copyActionId,
  };

  @override
  bool isActionEnabled(String actionId) => switch (actionId) {
    StandardEditingActions.saveActionId =>
      controller.state == TomPdfEditorState.open && !controller.isReadOnly,
    StandardEditingActions.undoActionId => controller.canUndo,
    StandardEditingActions.redoActionId => controller.canRedo,
    StandardEditingActions.copyActionId =>
      controller.selection.isNotEmpty && controller.canCopy,
    _ => false,
  };

  @override
  bool executeAction(String actionId) {
    if (!supportedActionIds.contains(actionId)) return false;
    forgePdfTrail('pdfium: $actionId');
    try {
      switch (actionId) {
        case StandardEditingActions.saveActionId:
          unawaited(controller.save());
        case StandardEditingActions.undoActionId:
          unawaited(controller.undo());
        case StandardEditingActions.redoActionId:
          unawaited(controller.redo());
        case StandardEditingActions.copyActionId:
          unawaited(_copy());
      }
      return true;
    } catch (e, s) {
      forgePdfReport(e, s, 'pdfium: $actionId');
      return false;
    }
  }

  Future<void> _copy() async {
    final text = await controller.selectedText();
    if (text != null && text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: text));
    }
  }

  @override
  EditorCapabilities get capabilities => const EditorCapabilities(
    hasTextBuffer: false,
    supportsUndoRedo: true,
    supportsClipboard: true,
    supportsLineEditing: false,
    supportsSelection: true,
  );

  @override
  EditorStateSnapshot get stateSnapshot => EditorStateSnapshot(
    hasSelection: controller.selection.isNotEmpty,
    hasContent: controller.state == TomPdfEditorState.open,
    isEditable: controller.canAnnotate,
    canUndo: controller.canUndo,
    canRedo: controller.canRedo,
    isTextMode: false,
  );

  @override
  Stream<void> get onStateChanged => _states.stream;

  // ------------------------------------------------------------------ find

  /// The shell's find bar, opened by Cmd+F inside the editor.
  void _openShellFind() {
    forgePdfTrail('pdfium: find → the shell\'s find bar');
    host.shell.executeAction(forgePdfFindActionId);
  }

  @override
  void find(
    String query, {
    bool caseSensitive = false,
    bool wholeWord = false,
  }) {
    forgePdfTrail('pdfium: find ${query.length} chars');
    if (controller.hasTextLayer == false && query.isNotEmpty) {
      controller.showFind(); // says the PDF has no text layer
      return;
    }
    controller.find(query, matchCase: caseSensitive, wholeWord: wholeWord);
  }

  @override
  void findNext() => controller.nextHit();

  @override
  void findPrevious() => controller.previousHit();

  @override
  void clearFind() => controller.hideFind();

  @override
  ValueListenable<ForgeFindStatus> get findStatus => _findStatus;

  // ----------------------------------------------------------------- state

  /// The page, the offset into it and the zoom (`.forge/state/editors/`).
  @override
  Map<String, dynamic>? saveState() {
    final p = controller.viewPosition;
    return p == null ? null : {'route': 'pdfium', ...p.toJson()};
  }

  @override
  void restoreState(Map<String, dynamic> state) {
    final p = PdfViewPosition.fromJson(state);
    if (p == null) return;
    forgePdfTrail('pdfium: restore $p');
    controller.restoreView(p);
  }

  @override
  Widget buildMain(BuildContext context) => TomPdfEditor(
    controller: controller,
    decoder: decoder,
    onFind: _openShellFind,
  );

  /// A second view of the same document and history, with its own viewport.
  @override
  Widget buildCopy(BuildContext context) => TomPdfEditor(
    controller: controller,
    decoder: decoder,
    onFind: _openShellFind,
    showPageList: false,
  );

  /// The file changed on disk? (Asked when the window regains focus.)
  Future<void> checkExternal() => controller.checkExternal();

  /// Ends the editor: the document and the engine share are given up.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    forgePdfTrail('pdfium editor closed');
    controller.removeListener(_changed);
    host.onHistoryChanged = null;
    controller.dispose();
    await _states.close();
  }
}
