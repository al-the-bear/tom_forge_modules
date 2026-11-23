import 'package:flutter/material.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show ForgeEditorChoice, ForgeModule, ForgeShellApi, TomForgeShellModule;
import 'package:tom_forge_plain_text_editor/tom_forge_plain_text_editor.dart'
    show ForgePlainTextEditor;

import 'env_file_editor.dart';
import 'file_kind.dart';
import 'protected_clipboard.dart';
import 'todo_file_editor.dart';

/// Builds the editor for one file: its session, the shell, and the shell
/// module the Forge editors integrate through. A host gives one under the id
/// of the kind it replaces ([ForgeFileKind.name], or a registered
/// [ForgeKitFileKind.id]).
typedef ForgeFileEditorBuilder =
    ForgeEditor Function(
      ForgeFileSession session,
      ForgeShellApi shell,
      TomForgeShellModule shellModule,
    );

/// Another editor a host offers for some files beside the editor of their
/// kind — **Open With** lists both (the TomSpecs editor for a
/// `*.docspecs.yaml`, say, beside the YAML editor).
class ForgeFileEditorAlternative {
  const ForgeFileEditorAlternative({
    required this.id,
    required this.label,
    required this.icon,
    required this.matches,
    required this.build,
    this.description,
  });

  /// The choice's id, the key a file-type default names.
  final String id;
  final String label;
  final String? description;
  final IconData icon;

  /// Whether it is offered for [uri].
  final bool Function(Uri uri) matches;

  /// The editor for [uri] in [shell].
  final ForgeEditor Function(Uri uri, ForgeShellApi shell) build;
}

/// The file editors as one module: it opens the files of the shell's file
/// system in the editor of their kind, each over a [ForgeFileSession] that
/// keeps the file's bytes and saves it — a file already open is shown again
/// rather than opened twice.
///
/// The kind of a file is asked in this order: this package's own `.env` and
/// todo files ([forgeFileKindOf]), then the kinds the application registered
/// in [fileKinds] (the Markdown and YAML adapters' `forgeMarkdownFileKind`
/// and `forgeYamlFileKind`), in their order, then plain text. The module
/// names no registered kind: an application that registers none opens
/// Markdown and YAML as plain text, and takes neither editor with it.
///
/// A host replaces the editor of a kind through [builders], keyed by the
/// kind's id (a GPL host injecting Webwork's rich Markdown editing, say),
/// offers other editors for some files beside the editor of their kind
/// through [alternatives] (Open With: [editorChoicesFor]) and keeps files out
/// through [claims].
class ForgeFileEditorsModule extends ForgeModule {
  ForgeFileEditorsModule({
    ForgeFileKindRegistry? fileKinds,
    Map<String, ForgeFileEditorBuilder> builders = const {},
    this.alternatives = const [],
    this.claims,
    ForgeProtectedClipboard? clipboard,
  }) : fileKinds = fileKinds ?? ForgeFileKindRegistry(),
       _clipboard = clipboard,
       _builders = {...defaultBuilders(clipboard), ...builders};

  /// The kinds the application registered, asked after `.env` and todo files
  /// and before plain text; registering one before a file opens is enough.
  final ForgeFileKindRegistry fileKinds;

  final ForgeProtectedClipboard? _clipboard;

  /// The todo an aggregate row asked to select, by the path of its file.
  final Map<String, String> _pendingTodos = {};

  /// Whether this module opens [uri] (default: every file of the shell's file
  /// system); a host leaves a file to another module by answering false.
  final bool Function(Uri uri)? claims;

  /// The other editors offered for some files beside the editor of their
  /// kind.
  final List<ForgeFileEditorAlternative> alternatives;

  final Map<String, ForgeFileEditorBuilder> _builders;
  ForgeShellApi? _shell;
  final _editors = <ForgeEditor>[];

  /// The editors of this package's `.env` and text kinds, by kind id; a
  /// todo file's ([ForgeTodoFileEditor]) is built by the module itself, which
  /// opens the todo an aggregate row names, and a registered kind's by the
  /// kind ([ForgeKitFileKind.create]).
  static Map<String, ForgeFileEditorBuilder> defaultBuilders([
    ForgeProtectedClipboard? clipboard,
  ]) => {
    ForgeFileKind.env.name: (session, shell, _) => ForgeEnvFileEditor(
      session: session,
      notifications: shell.notifications,
      clipboard: clipboard,
    ),
    ForgeFileKind.text.name: (session, _, shellModule) =>
        ForgePlainTextEditor(session: session, module: shellModule),
  };

  /// The kind of the file named [name]: this package's `.env` or todo file,
  /// else the first registered kind that takes it (as the second value),
  /// else plain text.
  (ForgeFileKind, ForgeKitFileKind?) _kindOf(String name) {
    final own = forgeFileKindOf(name);
    if (own != ForgeFileKind.text) return (own, null);
    return (own, fileKinds.kindOf(name));
  }

  @override
  String get displayName => 'File editors';

  @override
  void activate(ForgeShellApi shell) => _shell = shell;

  @override
  void deactivate() => _shell = null;

  @override
  List<ForgeEditor> get editors => List.unmodifiable(_editors);

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  /// The editor for [uri] over a new session, or null when this module does
  /// not open it.
  ForgeEditor? editorFor(Uri uri) {
    final shell = _shell;
    if (shell == null || !(claims?.call(uri) ?? true)) return null;
    final fileSystem = shell.fileSystem;
    final path = fileSystem.pathOf(uri);
    if (path == null) return null;
    final session = ForgeFileSession(fileSystem: fileSystem, path: path);
    final name = uri.pathSegments.isEmpty ? path : uri.pathSegments.last;
    final (own, registered) = _kindOf(name);
    final builder = _builders[registered?.id ?? own.name];
    final shellModule = shell.modules.get<TomForgeShellModule>();
    final ForgeEditor editor;
    if (builder != null) {
      editor = builder(session, shell, shellModule);
    } else if (registered != null) {
      editor = registered.create(
        ForgeFileKindRequest(session: session, module: shellModule, api: shell),
      );
    } else {
      editor = ForgeTodoFileEditor(
        session: session,
        notifications: shell.notifications,
        clipboard: _clipboard,
        openTodo: _openTodo,
        selection: _pendingTodos.remove(path),
      );
    }
    session.load();
    _editors.add(editor);
    return editor;
  }

  /// The names of the editor of each of this package's kinds, as Open With
  /// shows them (a registered kind names its own).
  static const _kindLabels = {
    ForgeFileKind.todoFile: ('Todo File Editor', Icons.checklist),
    ForgeFileKind.env: ('.env Editor', Icons.key),
    ForgeFileKind.text: ('Plain Text Editor', Icons.notes),
  };

  /// The editor of [uri]'s kind and every alternative that matches it — none
  /// for a file this module does not open.
  @override
  List<ForgeEditorChoice> editorChoicesFor(Uri uri) {
    final shell = _shell;
    if (shell == null || !(claims?.call(uri) ?? true)) return const [];
    if (shell.fileSystem.pathOf(uri) == null) return const [];
    final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final (own, registered) = _kindOf(name);
    final (label, icon) = registered != null
        ? (registered.label, registered.icon)
        : _kindLabels[own]!;
    return [
      ForgeEditorChoice(
        id: registered?.id ?? own.name,
        label: label,
        icon: icon,
        open: (uri, {middlePanelIndex}) =>
            _openKindEditor(uri, middlePanelIndex: middlePanelIndex),
      ),
      for (final alternative in alternatives)
        if (alternative.matches(uri))
          ForgeEditorChoice(
            id: alternative.id,
            label: alternative.label,
            description: alternative.description,
            icon: alternative.icon,
            open: (uri, {middlePanelIndex}) => _openAlternative(
              alternative,
              uri,
              middlePanelIndex: middlePanelIndex,
            ),
          ),
    ];
  }

  /// Opens [uri] in the editor of its kind — the one already open for it
  /// when there is one, never an alternative open on it.
  void _openKindEditor(Uri uri, {int? middlePanelIndex}) {
    final shell = _shell;
    if (shell == null) return;
    final alternatives = _alternativeEditors.values.toSet();
    for (final open in shell.systemState.openEditors) {
      if (open.uri == uri &&
          _editors.contains(open) &&
          !alternatives.contains(open)) {
        shell.layout.openEditor(open, uri, middlePanelIndex: middlePanelIndex);
        return;
      }
    }
    final editor = editorFor(uri);
    if (editor == null) return;
    shell.layout.openEditor(editor, uri, middlePanelIndex: middlePanelIndex);
  }

  /// Opens [uri] in [alternative] — the one already open for it when there
  /// is one.
  void _openAlternative(
    ForgeFileEditorAlternative alternative,
    Uri uri, {
    int? middlePanelIndex,
  }) {
    final shell = _shell;
    if (shell == null) return;
    final open = _alternativeEditors[(alternative.id, uri)];
    if (open != null && shell.systemState.openEditors.contains(open)) {
      shell.layout.openEditor(open, uri, middlePanelIndex: middlePanelIndex);
      return;
    }
    final editor = alternative.build(uri, shell);
    _alternativeEditors[(alternative.id, uri)] = editor;
    _editors.add(editor);
    shell.layout.openEditor(editor, uri, middlePanelIndex: middlePanelIndex);
  }

  /// The alternative editors made, by alternative and file.
  final _alternativeEditors = <(String, Uri), ForgeEditor>{};

  /// Opens the todo file at [path] with [id] selected.
  void _openTodo(String path, String id) {
    final shell = _shell;
    if (shell == null) return;
    final uri = shell.fileSystem.uriOf(path);
    for (final open in shell.systemState.openEditors) {
      if (open is ForgeTodoFileEditor && open.uri == uri) {
        open.selection = id;
        shell.layout.openEditor(open, uri);
        return;
      }
    }
    _pendingTodos[path] = id;
    openUri(uri);
  }

  @override
  bool openUri(Uri uri, {int? middlePanelIndex}) {
    final shell = _shell;
    if (shell == null) return false;
    for (final open in shell.systemState.openEditors) {
      if (open.uri == uri && _editors.contains(open)) {
        shell.layout.openEditor(open, uri, middlePanelIndex: middlePanelIndex);
        return true;
      }
    }
    final editor = editorFor(uri);
    if (editor == null) return false;
    shell.layout.openEditor(editor, uri, middlePanelIndex: middlePanelIndex);
    return true;
  }
}
