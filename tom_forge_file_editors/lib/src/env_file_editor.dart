import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:tom_file_session/tom_file_session.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show FileHandlingResult;
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_file_editors/tom_file_editors.dart';

import 'protected_clipboard.dart';
import 'session_file.dart';

/// A `.env` file in tom_file_editors' `.env` editor, hosted by Forge: the
/// entries in a table with every value hidden until shown, the raw text
/// beside it. The file's session is its one history (typing one entry per
/// burst); the editor saves its own file, and a file changed on disk is not
/// written over.
class ForgeEnvFileEditor extends ForgeEditor {
  ForgeEnvFileEditor({
    required this.session,
    required this.notifications,
    ForgeProtectedClipboard? clipboard,
  }) : clipboard = clipboard ?? ForgeSystemProtectedClipboard() {
    session.addListener(_onSession);
    _onSession();
  }

  final ForgeFileSession session;

  /// Where the editor says something to the user.
  final ForgeNotificationManager? notifications;

  /// Where a value goes when copied.
  final ForgeProtectedClipboard clipboard;

  late final _host = _ForgeTomFileEditorHost(this);
  late final _file = ForgeSessionFile(
    session: session,
    textOf: () => session.text,
    adopt: (_) {},
    markSaved: () {},
  );
  final _dirty = ValueNotifier(false);
  final _states = StreamController<void>.broadcast();

  void _onSession() {
    _dirty.value = session.dirty;
    if (!_states.isClosed) _states.add(null);
  }

  @override
  Uri get uri => session.uri;

  late final _title = ValueNotifier(
    uri.pathSegments.isEmpty ? '.env' : uri.pathSegments.last,
  );
  final _titleExtension = ValueNotifier<String?>(null);

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => Icons.vpn_key_outlined;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.reject;

  @override
  ValueListenable<bool> get isDirty => _dirty;

  /// The session saves the file and keeps the saved text.
  @override
  void markClean() {}

  @override
  bool replaceContent(String content) {
    session.adoptText(content);
    return true;
  }

  @override
  Widget buildMain(BuildContext context) => ForgeSessionFileFrame(
    file: _file,
    child: TomEnvFileEditor(host: _host),
  );

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);

  @override
  Set<String> get supportedActionIds => const {
    StandardEditingActions.undoActionId,
    StandardEditingActions.redoActionId,
    StandardEditingActions.saveActionId,
  };

  @override
  EditorStateSnapshot get stateSnapshot => EditorStateSnapshot(
    hasSelection: false,
    hasContent: session.text.isNotEmpty,
    isEditable: session.readOnlyReason == null,
    canUndo: session.canUndo,
    canRedo: session.canRedo,
    isTextMode: true,
  );

  @override
  bool isActionEnabled(String actionId) => switch (actionId) {
    StandardEditingActions.undoActionId => session.canUndo,
    StandardEditingActions.redoActionId => session.canRedo,
    StandardEditingActions.saveActionId => _file.canSave,
    _ => false,
  };

  @override
  bool executeAction(String actionId) {
    if (!isActionEnabled(actionId)) return false;
    switch (actionId) {
      case StandardEditingActions.undoActionId:
        unawaited(session.undo());
      case StandardEditingActions.redoActionId:
        unawaited(session.redo());
      case StandardEditingActions.saveActionId:
        unawaited(_file.save());
    }
    return true;
  }

  @override
  Stream<void> get onStateChanged => _states.stream;

  void dispose() {
    session.removeListener(_onSession);
    _file.dispose();
    unawaited(_states.close());
    _dirty.dispose();
    _title.dispose();
    _titleExtension.dispose();
  }
}

/// Forge as the host of a tom_file_editors file editor: the session, its
/// undo and redo, notices to the shell's notifications, the protected
/// clipboard.
class _ForgeTomFileEditorHost implements TomFileEditorHost {
  _ForgeTomFileEditorHost(this.editor);

  final ForgeEnvFileEditor editor;

  @override
  ForgeFileSession get session => editor.session;

  @override
  String get name => editor.uri.pathSegments.isEmpty
      ? '.env'
      : editor.uri.pathSegments.last;

  @override
  String get filePath => editor.uri.toFilePath();

  @override
  Future<void> undo(BuildContext context) async {
    if (session.canUndo) await session.undo();
  }

  @override
  Future<void> redo(BuildContext context) async {
    if (session.canRedo) await session.redo();
  }

  @override
  void notice(BuildContext context, String message, {required String kind}) {
    final manager = editor.notifications;
    if (manager != null) {
      unawaited(manager.showInformation(message));
    } else {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Future<void> copyProtected(String value) => editor.clipboard.copy(value);
}
