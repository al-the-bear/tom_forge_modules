import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show EditorCapabilities, EditorStateSnapshot, StandardEditingActions;
import 'package:tom_forge_core/tom_forge_core.dart' show FileHandlingResult;
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_office_editor/tom_office_editor.dart';

import 'forge_office_host.dart';
import 'forge_office_kind.dart';
import 'forge_office_trail.dart';

/// The text MIME type the clipboard exchanges with LibreOffice.
const _textMime = 'text/plain;charset=utf-8';

/// What the missing-LibreOffice panel of a [ForgeOfficeEditor] can do
/// besides showing detection's state (`part-forge-integration`, *The tab
/// when LibreOffice is missing*). The module gives them.
class ForgeOfficePanelActions {
  /// The panel's actions; each adds its button when given.
  const ForgeOfficePanelActions({
    this.checkAgain,
    this.chooseLibreOffice,
    this.openLibreOffice,
    this.openAlternative,
    this.alternativeLabel = 'Open with another editor',
    this.alternativeIcon = Icons.open_in_new,
    this.alternativeAvailable,
  });

  /// *Check again*: detection runs again with the path setting; the panel
  /// turns into the editor in place when it reports `found`.
  final Future<void> Function()? checkAgain;

  /// *Choose LibreOffice…*: the user picks the app, which becomes the path
  /// setting `forge.tools.libreoffice.path`; then detection runs again.
  final Future<void> Function()? chooseLibreOffice;

  /// *Open LibreOffice* (a quarantined copy at [path]).
  final void Function(String path)? openLibreOffice;

  /// Another route for the file that needs no installed LibreOffice (in
  /// Forge: *Open with ZetaOffice*, the ZetaOffice adapter's editor), as the
  /// application wires it ([ForgeOfficeAlternativeRoute]); null: no button.
  final VoidCallback? openAlternative;

  /// The alternative's button label, e.g. `Open with ZetaOffice`.
  final String alternativeLabel;

  /// The alternative's button icon.
  final IconData alternativeIcon;

  /// Whether the alternative is offered (ZetaOffice: not when its files are
  /// not cached and the machine is offline). `null`: always.
  final ValueListenable<bool>? alternativeAvailable;
}

/// The LibreOfficeKit editor as a Forge editor (choice `office.lok`, the
/// default for the office kinds): `TomOfficeEditor` over its controller, the
/// application's save, undo, redo, copy, cut and paste routed to the
/// controller, the dirty marker the controller's (`.uno:ModifiedStatus`).
/// Without a usable LibreOffice the tab shows detection's state panel with
/// *Check again*, *Choose LibreOffice…*, *Open LibreOffice* and the
/// alternative route the application wired (*Open with ZetaOffice*), and
/// turns into the editor in place once detection finds one.
class ForgeOfficeEditor extends ForgeEditor {
  /// An editor of [uri] over [host]. It opens the document once [detected]
  /// completes (the module's detection of LibreOffice). [decoder] decodes
  /// tiles (default: `decodeImageFromPixels`; a test gives its own).
  ForgeOfficeEditor({
    required this.uri,
    required this.host,
    required this.kind,
    Future<void>? detected,
    this.panelActions = const ForgeOfficePanelActions(),
    TomOfficeImageDecoder? decoder,
  }) : controller = TomOfficeEditorController(host: host, decoder: decoder) {
    _title = ValueNotifier(host.name);
    host.onHistoryChanged = _changed;
    controller.addListener(_changed);
    unawaited(
      (detected ?? Future<void>.value()).then((_) {
        if (_closed) return null;
        return controller.open();
      }),
    );
    forgeOfficeTrail('lok editor for ${host.name} (${kind.name})');
  }

  @override
  final Uri uri;

  /// The host.
  final ForgeOfficeHost host;

  /// The file's kind.
  final ForgeOfficeKind kind;

  /// The missing-LibreOffice panel's actions.
  final ForgeOfficePanelActions panelActions;

  /// The controller.
  final TomOfficeEditorController controller;

  late final ValueNotifier<String> _title;
  final _titleExtension = ValueNotifier<String?>(null);
  final _dirty = ValueNotifier(false);
  final _states = StreamController<void>.broadcast();
  bool _closed = false;
  TomOfficeEditorState? _lastState;
  int? _pendingPart;

  /// Bumped when detection ran again and the panel still shows: the state
  /// is unchanged, the installation it shows is not.
  final _panelRevision = ValueNotifier(0);
  late final Listenable _views = Listenable.merge([controller, _panelRevision]);

  void _changed() {
    if (_closed) return;
    _dirty.value = controller.isDirty;
    final state = controller.state;
    if (state != _lastState) {
      _lastState = state;
      if (state == TomOfficeEditorState.unavailable) {
        forgeOfficeTrail(
          'state panel: ${controller.installation?.state.name ?? 'missing'}',
        );
      }
      if (state == TomOfficeEditorState.open) {
        final part = _pendingPart;
        _pendingPart = null;
        if (part != null && part != controller.currentPart) {
          controller.setPart(part);
        }
      }
    }
    _titleExtension.value = controller.isReadOnly ? 'read-only' : null;
    if (!_states.isClosed) _states.add(null);
  }

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => kind.icon;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints(
    minSize: Size(320, 240),
    preferredSize: Size(1000, 900),
  );

  @override
  FileHandlingResult canHandle(Uri uri) =>
      uri == this.uri ? FileHandlingResult.accept : FileHandlingResult.reject;

  @override
  ValueListenable<bool> get isDirty => _dirty;

  /// The controller keeps the dirty state (LibreOffice's modified flag); the
  /// application never marks this editor clean.
  @override
  void markClean() {}

  /// A binary document cannot take a string: the application closes the editor
  /// and opens the file again (a new helper, an empty history).
  @override
  bool replaceContent(String content) => false;

  bool get _open => controller.state == TomOfficeEditorState.open;

  @override
  Set<String> get supportedActionIds => const {
    StandardEditingActions.saveActionId,
    StandardEditingActions.undoActionId,
    StandardEditingActions.redoActionId,
    StandardEditingActions.copyActionId,
    StandardEditingActions.cutActionId,
    StandardEditingActions.pasteActionId,
  };

  @override
  bool isActionEnabled(String actionId) => switch (actionId) {
    StandardEditingActions.saveActionId => _open && !controller.isReadOnly,
    StandardEditingActions.undoActionId => controller.canUndo,
    StandardEditingActions.redoActionId => controller.canRedo,
    StandardEditingActions.copyActionId =>
      _open && controller.selection.isNotEmpty,
    StandardEditingActions.cutActionId =>
      _open && !controller.isReadOnly && controller.selection.isNotEmpty,
    StandardEditingActions.pasteActionId => _open && !controller.isReadOnly,
    _ => false,
  };

  @override
  bool executeAction(String actionId) {
    if (!supportedActionIds.contains(actionId)) return false;
    forgeOfficeTrail('lok: $actionId');
    try {
      switch (actionId) {
        case StandardEditingActions.saveActionId:
          unawaited(
            controller.save().then(
              (outcome) => forgeOfficeTrail('lok: save → ${outcome.name}'),
            ),
          );
        case StandardEditingActions.undoActionId:
          controller.undo();
        case StandardEditingActions.redoActionId:
          controller.redo();
        case StandardEditingActions.copyActionId:
          unawaited(_toClipboard(controller.copySelection()));
        case StandardEditingActions.cutActionId:
          unawaited(_toClipboard(controller.cutSelection()));
        case StandardEditingActions.pasteActionId:
          unawaited(_paste());
      }
      return true;
    } catch (e, s) {
      forgeOfficeReport(e, s, 'lok: $actionId');
      return false;
    }
  }

  Future<void> _toClipboard(Future<Map<String, String>> data) async {
    try {
      final text = (await data)[_textMime];
      if (text != null && text.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: text));
      }
    } catch (e, s) {
      forgeOfficeReport(e, s, 'lok: copy');
    }
  }

  Future<void> _paste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text != null && text.isNotEmpty) controller.paste(_textMime, text);
    } catch (e, s) {
      forgeOfficeReport(e, s, 'lok: paste');
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
    hasContent: _open,
    isEditable: _open && !controller.isReadOnly,
    canUndo: controller.canUndo,
    canRedo: controller.canRedo,
    isTextMode: false,
  );

  @override
  Stream<void> get onStateChanged => _states.stream;

  // ----------------------------------------------------------------- state

  /// The part (sheet or slide) shown (`.forge/state/editors/`). The zoom and
  /// the scroll position are the view's own; the base component does not
  /// expose them.
  @override
  Map<String, dynamic>? saveState() =>
      _open ? {'route': 'lok', 'part': controller.currentPart} : null;

  @override
  void restoreState(Map<String, dynamic> state) {
    final part = state['part'];
    if (part is! int) return;
    forgeOfficeTrail('lok: restore part $part');
    if (_open) {
      controller.setPart(part);
    } else {
      _pendingPart = part;
    }
  }

  // ----------------------------------------------------------------- views

  @override
  Widget buildMain(BuildContext context) => ListenableBuilder(
    listenable: _views,
    builder: (context, _) =>
        controller.state == TomOfficeEditorState.unavailable
        ? _MissingLibreOfficePanel(editor: this)
        : TomOfficeEditor(
            controller: controller,
            onCheckAgain: _checkAgain,
            onChooseLibreOffice: _choose,
            onOpenLibreOffice: _openLibreOffice,
          ),
  );

  /// A second view of the same document and history, with its own viewport.
  @override
  Widget buildCopy(BuildContext context) => ListenableBuilder(
    listenable: _views,
    builder: (context, _) =>
        controller.state == TomOfficeEditorState.unavailable
        ? _MissingLibreOfficePanel(editor: this)
        : TomOfficeEditor(controller: controller, showRibbon: false),
  );

  VoidCallback? get _checkAgain {
    final a = panelActions.checkAgain;
    return a == null ? null : () => unawaited(a());
  }

  VoidCallback? get _choose {
    final a = panelActions.chooseLibreOffice;
    return a == null ? null : () => unawaited(a());
  }

  VoidCallback? get _openLibreOffice {
    final a = panelActions.openLibreOffice;
    final path = controller.installation?.bundlePath;
    return a == null || path == null ? null : () => a(path);
  }

  /// The file changed on disk? (Asked when the window regains focus.)
  Future<void> checkExternal() async {
    if (_open) await controller.checkExternal();
  }

  /// Detection found LibreOffice after the panel was shown: the document
  /// opens in place.
  Future<void> reopenIfUnavailable() async {
    if (_closed || controller.state != TomOfficeEditorState.unavailable) {
      return;
    }
    forgeOfficeTrail('lok: detection changed, opening again');
    await controller.open();
    if (!_closed) _panelRevision.value++;
  }

  /// Ends the editor: the helper is closed.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    forgeOfficeTrail('lok editor closed');
    controller.removeListener(_changed);
    host.onHistoryChanged = null;
    await controller.close();
    controller.dispose();
    await _states.close();
  }
}

/// Detection's state panel (`TomOfficeDetectionView`) with the alternative
/// route's button (*Open with ZetaOffice*) below it.
class _MissingLibreOfficePanel extends StatelessWidget {
  const _MissingLibreOfficePanel({required this.editor});

  final ForgeOfficeEditor editor;

  @override
  Widget build(BuildContext context) {
    final c = editor.controller;
    final actions = editor.panelActions;
    final alternative = actions.openAlternative;
    final available = actions.alternativeAvailable;
    Widget alternativeButton() => OutlinedButton.icon(
      key: const ValueKey('forge-office-open-alternative'),
      onPressed: alternative,
      icon: Icon(actions.alternativeIcon),
      label: Text(actions.alternativeLabel),
    );
    return Column(
      key: const ValueKey('forge-office-missing-panel'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: TomOfficeDetectionView(
            installation:
                c.installation ??
                const LibreOfficeInstallation(state: LibreOfficeState.missing),
            onCheckAgain: editor._checkAgain,
            onChooseLibreOffice: editor._choose,
            onOpenLibreOffice: editor._openLibreOffice,
            onOpenDownloadPage: () =>
                editor.host.openLink(kLibreOfficeDownloadUrl),
          ),
        ),
        if (alternative != null)
          available == null
              ? alternativeButton()
              : ValueListenableBuilder<bool>(
                  valueListenable: available,
                  builder: (context, ok, _) =>
                      ok ? alternativeButton() : const SizedBox.shrink(),
                ),
        const SizedBox(height: 24),
      ],
    );
  }
}
