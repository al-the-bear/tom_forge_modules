import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_basics/utilities.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:tom_file_session/tom_file_session.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show FileHandlingResult;
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_file_editors/tom_file_editors.dart';
import 'package:tom_todo_ui/tom_todo_ui.dart';

import 'protected_clipboard.dart';

/// A `*.todo.yaml` file in `tom_todo_ui`'s todo-file editor: the todos as
/// a list, edited with the todo row and details editor, every change one
/// entry in the file's history; the file's schema checked; archive and
/// delete as a move to the `-archived` / `-deleted` sibling; every todo file
/// under the shell's root as one list; and the YAML source.
///
/// Read and saved through its [ForgeFileSession]. A board and moving todos to
/// other places are a host's additions the editor offers only where a host
/// supplies them; Forge supplies neither.
class ForgeTodoFileEditor extends ForgeEditor {
  ForgeTodoFileEditor({
    required this.session,
    required this.notifications,
    required this.openTodo,
    this.selection,
    ForgeProtectedClipboard? clipboard,
    DateTime Function()? clock,
  }) : clipboard = clipboard ?? ForgeSystemProtectedClipboard(),
       clock = clock ?? DateTime.now {
    session.addListener(_onSession);
    _onSession();
  }

  /// The file.
  final ForgeFileSession session;

  /// Where notices go; null shows them in the editor's own snack bar.
  final ForgeNotificationManager? notifications;

  /// Opens the todo [id] of the todo file at [path] — an aggregate row.
  final void Function(String path, String id) openTodo;

  /// A todo to select once the editor shows, or null.
  String? selection;

  /// The clipboard a protected value is copied to.
  final ForgeProtectedClipboard clipboard;

  /// Today, for date stamps and minted ids.
  final DateTime Function() clock;

  late final _host = _ForgeTodoFileHost(this);
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
    uri.pathSegments.isEmpty ? session.path : uri.pathSegments.last,
  );
  final _titleExtension = ValueNotifier<String?>(null);

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => Icons.checklist;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  /// Opened by its module, never routed by name.
  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.reject;

  @override
  ValueListenable<bool> get isDirty => _dirty;

  /// Clears nothing: the editor saves its own file through the session.
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
    child: TomTodoFileEditor(host: _host),
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
    isTextMode: false,
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

/// What the todo-file editor needs, from the Forge shell: the session's file
/// system for the file, its siblings and its schema; Forge's notifications;
/// no author (Forge keeps no identity), board or transfer.
class _ForgeTodoFileHost implements TomTodoFileEditorHost {
  _ForgeTodoFileHost(this.editor);

  final ForgeTodoFileEditor editor;

  TomFileSystem get _fileSystem => editor.session.fileSystem;

  @override
  ForgeFileSession get session => editor.session;

  @override
  String get name => editor.title.value;

  @override
  String get filePath => editor.session.path;

  @override
  late final TomSchemaCache schemas = TomSchemaCache(
    read: (path) async {
      final uri = _fileSystem.uriOf(path);
      if (await _fileSystem.stat(uri) == null) return null;
      return tomDecodeTextBytes((await _fileSystem.read(uri)).bytes).text;
    },
  );

  @override
  late final TomTodoFileValidator validator = TomTodoFileValidator(
    schemas: schemas,
  );

  @override
  late final TomTodoRelocator relocator = TomTodoRelocator(
    clock: editor.clock,
  );

  @override
  DateTime Function() get clock => editor.clock;

  @override
  String? author() => null;

  @override
  String? takeSelection() {
    final selection = editor.selection;
    editor.selection = null;
    return selection;
  }

  @override
  Future<bool> save(BuildContext context) async {
    final outcome = await editor._file.save();
    return outcome == ForgeFileSaveOutcome.saved ||
        outcome == ForgeFileSaveOutcome.clean;
  }

  @override
  late final TomTodoAggregateSource aggregate = _ForgeTodoAggregate(editor);

  @override
  TomTodoFileTransfer? get transfer => null;

  @override
  Widget Function(BuildContext, TomTodoFileController)? get board => null;

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

/// Every todo file of the shell's file system.
class _ForgeTodoAggregate implements TomTodoAggregateSource {
  _ForgeTodoAggregate(this.editor);

  final ForgeTodoFileEditor editor;

  @override
  TomFileSystem get tree => editor.session.fileSystem;

  @override
  bool get includeSiblings => true;

  @override
  void openTodo(String path, String id) => editor.openTodo(path, id);
}
