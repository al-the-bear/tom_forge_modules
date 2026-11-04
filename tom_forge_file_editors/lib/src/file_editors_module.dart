import 'package:tom_file_session/tom_file_session.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'env_file_editor.dart';
import 'file_kind.dart';
import 'markdown_file_editor.dart';
import 'protected_clipboard.dart';
import 'todo_file_editor.dart';
import 'yaml_file_editor.dart';

/// Builds the editor for one file: its session, the shell, and the shell
/// module the Forge editors integrate through.
typedef ForgeFileEditorBuilder =
    ForgeEditor Function(
      ForgeFileSession session,
      ForgeShellApi shell,
      TomForgeShellModule shellModule,
    );

/// The file editors as one module: it opens the files of the shell's file
/// system in the editor of their kind ([forgeFileKindOf]), each over a
/// [ForgeFileSession] that keeps the file's bytes and saves it — a file
/// already open is shown again rather than opened twice. A host replaces the
/// editor of a kind through [builders] (a GPL host injecting Webwork's rich
/// Markdown editing, say) and keeps files out through [claims].
class ForgeFileEditorsModule extends ForgeModule {
  ForgeFileEditorsModule({
    Map<ForgeFileKind, ForgeFileEditorBuilder> builders = const {},
    this.claims,
    ForgeProtectedClipboard? clipboard,
  }) : _clipboard = clipboard,
       _builders = {...defaultBuilders(clipboard), ...builders};

  final ForgeProtectedClipboard? _clipboard;

  /// The todo an aggregate row asked to select, by the path of its file.
  final Map<String, String> _pendingTodos = {};

  /// Whether this module opens [uri] (default: every file of the shell's file
  /// system); a host leaves a file to another module by answering false.
  final bool Function(Uri uri)? claims;

  final Map<ForgeFileKind, ForgeFileEditorBuilder> _builders;
  ForgeShellApi? _shell;
  final _editors = <ForgeEditor>[];

  /// The editors of four kinds; a todo file's ([ForgeTodoFileEditor]) is
  /// built by the module itself, which opens the todo an aggregate row names.
  static Map<ForgeFileKind, ForgeFileEditorBuilder> defaultBuilders([
    ForgeProtectedClipboard? clipboard,
  ]) => {
    ForgeFileKind.markdown: (session, _, shellModule) =>
        ForgeMarkdownFileEditor(session: session, module: shellModule),
    ForgeFileKind.yaml: (session, _, shellModule) =>
        ForgeYamlFileEditor(session: session, module: shellModule),
    ForgeFileKind.env: (session, shell, _) => ForgeEnvFileEditor(
      session: session,
      notifications: shell.notifications,
      clipboard: clipboard,
    ),
    ForgeFileKind.text: (session, _, shellModule) =>
        ForgePlainTextEditor(session: session, module: shellModule),
  };

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
    final kind = forgeFileKindOf(name);
    final builder = _builders[kind];
    final editor = builder != null
        ? builder(session, shell, shell.modules.get<TomForgeShellModule>())
        : ForgeTodoFileEditor(
            session: session,
            notifications: shell.notifications,
            clipboard: _clipboard,
            openTodo: _openTodo,
            selection: _pendingTodos.remove(path),
          );
    session.load();
    _editors.add(editor);
    return editor;
  }

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
