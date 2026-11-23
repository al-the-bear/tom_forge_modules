import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show EditorCapabilities, EditorStateSnapshot, StandardEditingActions;
import 'package:tom_forge_core/tom_forge_core.dart' show FileHandlingResult;
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_office_editor/zetaoffice.dart';

import 'forge_office_host.dart';
import 'forge_office_kind.dart';
import 'forge_office_trail.dart';

/// ZetaOffice in the webview as a Forge editor (choice `office.zetaoffice`,
/// the comparison route): `TomZetaOfficeView` over its controller — the
/// download prompt before the files are cached, ZetaOffice's full interface.
/// Save, undo, redo and dirty go through the same host contract as the
/// native editor; ZetaOffice runs in one tab at a time.
class ForgeZetaOfficeEditor extends ForgeEditor {
  /// An editor of [uri] over [host], with ZetaOffice's cached [files],
  /// served by [serving]. [channelForTesting] replaces the webview.
  ForgeZetaOfficeEditor({
    required this.uri,
    required this.host,
    required this.kind,
    required TomZetaOfficeFiles files,
    required TomZetaOfficeServing serving,
    this.channelForTesting,
    this.onShowMain,
  }) : controller = TomZetaOfficeController(
         host: host,
         files: files,
         serving: serving,
       ) {
    _title = ValueNotifier(host.name);
    host.onHistoryChanged = _changed;
    controller.addListener(_changed);
    unawaited(controller.prepare());
    forgeOfficeTrail('zetaoffice editor for ${host.name} (${kind.name})');
  }

  @override
  final Uri uri;

  /// The host.
  final ForgeOfficeHost host;

  /// The file's kind.
  final ForgeOfficeKind kind;

  /// The controller.
  final TomZetaOfficeController controller;

  /// Replaces the webview in widget tests.
  final TomZetaOfficeChannel? channelForTesting;

  /// Brings the main view forward (the split copy's button).
  final VoidCallback? onShowMain;

  late final ValueNotifier<String> _title;
  final _titleExtension = ValueNotifier<String?>('ZetaOffice');
  final _dirty = ValueNotifier(false);
  final _states = StreamController<void>.broadcast();
  bool _closed = false;

  void _changed() {
    if (_closed) return;
    _dirty.value = controller.isDirty;
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

  /// The controller keeps the dirty state (ZetaOffice's modified flag, and a
  /// failed save); the shell never marks this editor clean.
  @override
  void markClean() {}

  /// A binary document cannot take a string: the shell closes the editor
  /// and opens the file again.
  @override
  bool replaceContent(String content) => false;

  bool get _open => controller.state == TomZetaOfficeState.open;

  @override
  Set<String> get supportedActionIds => const {
    StandardEditingActions.saveActionId,
    StandardEditingActions.undoActionId,
    StandardEditingActions.redoActionId,
  };

  @override
  bool isActionEnabled(String actionId) => switch (actionId) {
    StandardEditingActions.saveActionId => _open,
    StandardEditingActions.undoActionId => _open && controller.canUndo,
    StandardEditingActions.redoActionId => _open && controller.canRedo,
    _ => false,
  };

  @override
  bool executeAction(String actionId) {
    if (!supportedActionIds.contains(actionId)) return false;
    forgeOfficeTrail('zetaoffice: $actionId');
    try {
      switch (actionId) {
        case StandardEditingActions.saveActionId:
          unawaited(
            controller.save().then(
              (outcome) =>
                  forgeOfficeTrail('zetaoffice: save → ${outcome.name}'),
            ),
          );
        case StandardEditingActions.undoActionId:
          unawaited(controller.undo());
        case StandardEditingActions.redoActionId:
          unawaited(controller.redo());
      }
      return true;
    } catch (e, s) {
      forgeOfficeReport(e, s, 'zetaoffice: $actionId');
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
    hasSelection: false,
    hasContent: _open,
    isEditable: _open,
    canUndo: controller.canUndo,
    canRedo: controller.canRedo,
    isTextMode: false,
  );

  @override
  Stream<void> get onStateChanged => _states.stream;

  @override
  Widget buildMain(BuildContext context) => TomZetaOfficeView(
    controller: controller,
    channelForTesting: channelForTesting,
  );

  /// A webview page cannot be shown twice: the copy says so.
  @override
  Widget buildCopy(BuildContext context) => Center(
    key: const ValueKey('forge-zetaoffice-no-split'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('This view cannot be split.'),
        const SizedBox(height: 12),
        if (onShowMain != null)
          OutlinedButton(
            onPressed: onShowMain,
            child: const Text('Show the document'),
          ),
      ],
    ),
  );

  /// The file changed on disk? (Asked when the window regains focus.)
  Future<void> checkExternal() async {
    if (_open) await controller.checkExternal();
  }

  /// Ends the editor: the page and its local site are closed, and the
  /// ZetaOffice slot is free for another tab.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    forgeOfficeTrail('zetaoffice editor closed');
    controller.removeListener(_changed);
    host.onHistoryChanged = null;
    await controller.close();
    controller.dispose();
    await _states.close();
  }
}
