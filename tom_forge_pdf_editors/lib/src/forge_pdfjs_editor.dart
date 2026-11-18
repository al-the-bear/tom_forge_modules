import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show EditorCapabilities, EditorStateSnapshot, StandardEditingActions;
import 'package:tom_file_session/io.dart' show TomLocalContentServer;
import 'package:tom_forge_core/tom_forge_core.dart' show FileHandlingResult;
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_pdf_editor/pdfjs.dart';

import 'forge_pdf_editor.dart' show forgePdfFindActionId;
import 'forge_pdf_host.dart';
import 'forge_pdf_trail.dart';

/// The pdf.js view as a Forge editor (choice `pdf.pdfjs`, the comparison
/// route): `TomPdfJsView` in `components` mode, switched to `integrated` or
/// `full` from the tab's actions (*pdf.js view: components / integrated /
/// full*, DPPJ-5). Save, undo, redo and find go to the view's controller;
/// history and dirty are pdf.js's own.
class ForgePdfJsEditor extends ForgeEditor {
  /// An editor of [uri] over [host] in [mode]. [channelForTesting] replaces
  /// the webview; [testBaseUri] keeps the controller offline (widget tests
  /// under a fake clock).
  ForgePdfJsEditor({
    required this.uri,
    required this.host,
    TomPdfJsMode mode = TomPdfJsMode.components,
    this.server,
    this.channelForTesting,
    this.testBaseUri,
    this.onShowMain,
  }) {
    _title = ValueNotifier(host.name);
    host.onHistoryChanged = _changed;
    _controller = ValueNotifier(_make(mode));
    forgePdfTrail('pdf.js editor for ${host.name} (${mode.name})');
  }

  @override
  final Uri uri;

  /// The host.
  final ForgePdfHost host;

  /// The content server (default: the process's shared one).
  final TomLocalContentServer? server;

  /// Replaces the webview in widget tests.
  final TomPdfJsChannel? channelForTesting;

  /// Keeps the controller offline in widget tests.
  final Uri? testBaseUri;

  /// Brings the main view forward (the split copy's button).
  final VoidCallback? onShowMain;

  late final ValueNotifier<String> _title;
  final _titleExtension = ValueNotifier<String?>(null);
  final _dirty = ValueNotifier(false);
  final _states = StreamController<void>.broadcast();
  late final ValueNotifier<TomPdfJsController> _controller;
  final _mainView = GlobalKey<TomPdfJsViewState>();
  bool _closed = false;

  /// The view's controller now (a mode switch makes a new one).
  TomPdfJsController get controller => _controller.value;

  /// The mode shown.
  TomPdfJsMode get mode => controller.mode;

  TomPdfJsController _make(TomPdfJsMode mode) {
    final c = TomPdfJsController(
      host,
      mode: mode,
      server: server,
      testBaseUri: testBaseUri,
    );
    c.addListener(_changed);
    return c;
  }

  void _changed() {
    if (_closed) return;
    _dirty.value = controller.isDirty;
    _titleExtension.value = controller.mode == TomPdfJsMode.components
        ? null
        : 'pdf.js ${controller.mode.name}';
    if (!_states.isClosed) _states.add(null);
  }

  /// Shows the document in [next] mode. A document with unsaved changes is
  /// not switched (the page is loaded anew): answers false with a notice.
  bool setMode(TomPdfJsMode next) {
    if (next == mode) return true;
    if (controller.isDirty) {
      unawaited(
        host.shell.notifications.showWarning(
          'Save the PDF before switching the pdf.js view.',
        ),
      );
      return false;
    }
    forgePdfTrail('pdf.js view: ${mode.name} → ${next.name}');
    final old = controller;
    old.removeListener(_changed);
    _controller.value = _make(next);
    unawaited(old.close().then((_) => old.dispose()));
    _changed();
    return true;
  }

  @override
  List<ForgeAction> get headerActions => [
    for (final (m, icon) in const [
      (TomPdfJsMode.components, Icons.view_compact_outlined),
      (TomPdfJsMode.integrated, Icons.view_sidebar_outlined),
      (TomPdfJsMode.full, Icons.web_asset_outlined),
    ])
      ForgeAction(
        id: 'pdf.pdfjs.mode.${m.name}',
        label: 'pdf.js view: ${m.name}',
        icon: icon,
        execute: (_) async => setMode(m),
        isEnabled: () => mode != m,
        isVisible: () => true,
      ),
  ];

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => Icons.picture_as_pdf;

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

  /// pdf.js keeps the modified state; the shell never marks this editor
  /// clean.
  @override
  void markClean() {}

  @override
  bool replaceContent(String content) => false;

  @override
  Set<String> get supportedActionIds => const {
    StandardEditingActions.saveActionId,
    StandardEditingActions.undoActionId,
    StandardEditingActions.redoActionId,
    forgePdfFindActionId,
  };

  @override
  bool isActionEnabled(String actionId) => switch (actionId) {
    StandardEditingActions.saveActionId =>
      controller.state == TomPdfJsState.open && !controller.isReadOnly,
    StandardEditingActions.undoActionId => controller.canUndo,
    StandardEditingActions.redoActionId => controller.canRedo,
    forgePdfFindActionId => controller.state == TomPdfJsState.open,
    _ => false,
  };

  @override
  bool executeAction(String actionId) {
    if (!supportedActionIds.contains(actionId)) return false;
    forgePdfTrail('pdf.js: $actionId');
    try {
      switch (actionId) {
        case StandardEditingActions.saveActionId:
          unawaited(controller.save());
        case StandardEditingActions.undoActionId:
          unawaited(controller.undo());
        case StandardEditingActions.redoActionId:
          unawaited(controller.redo());
        case forgePdfFindActionId:
          _mainView.currentState?.showFind();
      }
      return true;
    } catch (e, s) {
      forgePdfReport(e, s, 'pdf.js: $actionId');
      return false;
    }
  }

  @override
  EditorCapabilities get capabilities => const EditorCapabilities(
    hasTextBuffer: false,
    supportsUndoRedo: true,
    supportsClipboard: false,
    supportsLineEditing: false,
    supportsSelection: false,
  );

  @override
  EditorStateSnapshot get stateSnapshot => EditorStateSnapshot(
    hasContent: controller.state == TomPdfJsState.open,
    isEditable: !controller.isReadOnly,
    canUndo: controller.canUndo,
    canRedo: controller.canRedo,
    isTextMode: false,
  );

  @override
  Stream<void> get onStateChanged => _states.stream;

  @override
  Widget buildMain(BuildContext context) =>
      ValueListenableBuilder<TomPdfJsController>(
        valueListenable: _controller,
        builder: (context, controller, _) => TomPdfJsView(
          key: _mainView,
          controller: controller,
          channelForTesting: channelForTesting,
        ),
      );

  /// A webview page cannot be shown twice: the copy says so.
  @override
  Widget buildCopy(BuildContext context) => Center(
    key: const ValueKey('forge-pdfjs-no-split'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('This view cannot be split.'),
        if (onShowMain != null)
          TextButton(
            onPressed: onShowMain,
            child: const Text('Show the main view'),
          ),
      ],
    ),
  );

  /// The file changed on disk? (Asked when the window regains focus.)
  Future<void> checkExternal() => controller.checkExternal();

  /// Ends the editor: the page, its content site and the webview go.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    forgePdfTrail('pdf.js editor closed');
    final c = controller;
    c.removeListener(_changed);
    host.onHistoryChanged = null;
    await c.close();
    c.dispose();
    await _states.close();
  }
}
