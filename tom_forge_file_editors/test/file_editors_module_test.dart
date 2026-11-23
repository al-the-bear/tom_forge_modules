/// The file editors in a Forge shell: the module opens a file in the editor
/// of its kind over a ForgeFileSession — its own `.env`, todo and text
/// kinds, and the kinds the application registered, asked in their order
/// after `.env` and todo files; edits are undone through the editor's
/// history and make it dirty; the editor saves its own file — the shell
/// writes nothing; a host replaces an editor, keeps a file for another
/// module, or offers another editor for some files beside the editor of
/// their kind (Open With). The Markdown and YAML kinds' own behaviour is
/// tested in their adapters.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_file_editors/tom_forge_file_editors.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show
        DefaultLayoutController,
        DefaultModuleRegistry,
        DefaultShellApi,
        ForgeModule,
        ForgePlainTextEditor,
        TomForgeShellModule;

const _undo = StandardEditingActions.undoActionId;
const _redo = StandardEditingActions.redoActionId;

/// The editor of a registered kind: a plain-text editor of its own type.
class _KindEditor extends ForgePlainTextEditor {
  _KindEditor(this.request)
    : super(session: request.session, module: request.module as ForgeModule);

  final ForgeFileKindRequest request;
}

/// A kind the application registers, standing in for an adapter's.
ForgeKitFileKind _kind(String id, String label, List<String> extensions) =>
    ForgeKitFileKind(
      id: id,
      label: label,
      icon: Icons.description_outlined,
      extensions: extensions,
      create: _KindEditor.new,
    );

final _markdown = _kind('markdown', 'Markdown Editor', ['md', 'markdown']);
final _yaml = _kind('yaml', 'YAML Editor', ['yaml', 'yml']);

class _Workspace {
  _Workspace({
    List<ForgeKitFileKind>? kinds,
    Map<String, ForgeFileEditorBuilder> builders = const {},
    List<ForgeFileEditorAlternative> alternatives = const [],
    bool Function(Uri uri)? claims,
  }) {
    shell = DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: fs,
      appName: 'File editors',
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(TomForgeShellModule()..activate(shell));
    module = ForgeFileEditorsModule(
      fileKinds: ForgeFileKindRegistry(kinds ?? [_markdown, _yaml]),
      builders: builders,
      alternatives: alternatives,
      claims: claims,
    )..activate(shell);
    registry.register(module);
  }

  final fs = TomMemoryFileSystem();
  late final DefaultShellApi shell;
  late final ForgeFileEditorsModule module;

  Future<void> write(String path, List<int> bytes) =>
      fs.write(fs.uriOf(path), Uint8List.fromList(bytes));

  Future<List<int>> read(String path) async =>
      (await fs.read(fs.uriOf(path))).bytes;

  /// Opens [path] and waits for its editor and its file.
  Future<ForgeEditor> open(WidgetTester tester, String path) async {
    final uri = fs.uriOf(path);
    shell.layout.openFile(uri);
    await tester.pumpAndSettle();
    final editor = shell.systemState.openEditors.firstWhere(
      (e) => e.uri == uri,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Builder(builder: editor.buildMain)),
      ),
    );
    await tester.pumpAndSettle();
    return editor;
  }
}

void main() {
  testWidgets('FE-1: each kind opens in its editor, once', (tester) async {
    final w = _Workspace();
    addTearDown(w.shell.dispose);
    await w.write('/a.md', utf8.encode('# A\n'));
    await w.write('/b.yaml', utf8.encode('b: 1\n'));
    await w.write('/.env', utf8.encode('KEY=secret\n'));
    await w.write('/c.txt', utf8.encode('c\n'));
    final markdown = await w.open(tester, '/a.md');
    expect(markdown, isA<_KindEditor>());
    expect(
      (markdown as _KindEditor).request.module,
      isA<TomForgeShellModule>(),
    );
    expect(markdown.request.api, same(w.shell));
    expect(markdown.request.session.path, w.fs.pathOf(w.fs.uriOf('/a.md')));
    expect(
      ((await w.open(tester, '/b.yaml')) as _KindEditor).request.session.path,
      w.fs.pathOf(w.fs.uriOf('/b.yaml')),
    );
    expect(await w.open(tester, '/.env'), isA<ForgeEnvFileEditor>());
    expect(await w.open(tester, '/c.txt'), isA<ForgePlainTextEditor>());
    final again = await w.open(tester, '/a.md');
    expect(
      w.shell.systemState.openEditors.where((e) => e.uri == again.uri),
      hasLength(1),
    );
    expect(forgeFileKindOf('.env.local'), ForgeFileKind.env);
  });

  testWidgets('FE-4: .env — the session is the history; a save writes it', (
    tester,
  ) async {
    final w = _Workspace();
    addTearDown(w.shell.dispose);
    await w.write('/.env', utf8.encode('KEY=secret\n'));
    final editor = await w.open(tester, '/.env') as ForgeEnvFileEditor;
    expect(find.text('secret'), findsNothing, reason: 'values hidden');
    editor.session.edit('KEY=secret\nOTHER=2\n', 'Add');
    await tester.pump();
    expect(editor.isDirty.value, isTrue);
    expect(editor.isActionEnabled(_undo), isTrue);
    editor.executeAction(_undo);
    await tester.pumpAndSettle();
    expect(editor.isDirty.value, isFalse);
    editor.executeAction(_redo);
    await tester.pumpAndSettle();
    expect(saveOwnedEditor(editor), isTrue);
    await tester.pumpAndSettle();
    expect(utf8.decode(await w.read('/.env')), 'KEY=secret\nOTHER=2\n');
    expect(editor.isDirty.value, isFalse);
  });

  testWidgets('FE-5: a host replaces a kind\'s editor and keeps a file for '
      'another module', (tester) async {
    ForgeEditor? built;
    final w = _Workspace(
      builders: {
        _markdown.id: (session, _, module) =>
            built = ForgePlainTextEditor(session: session, module: module),
      },
      claims: (uri) => !uri.path.endsWith('.skip'),
    );
    addTearDown(w.shell.dispose);
    await w.write('/a.md', utf8.encode('# A\n'));
    final editor = await w.open(tester, '/a.md');
    expect(editor, same(built));
    expect(w.module.openUri(w.fs.uriOf('/x.skip')), isFalse);
  });

  testWidgets('FE-7: Open With offers the editor of the kind and the '
      'alternatives that match; each opens its own editor, once', (
    tester,
  ) async {
    final built = <ForgeEditor>[];
    final w = _Workspace(
      alternatives: [
        ForgeFileEditorAlternative(
          id: 'spec',
          label: 'Spec Editor',
          icon: Icons.article_outlined,
          matches: (uri) => uri.path.endsWith('.spec.yaml'),
          build: (uri, shell) {
            final editor = ForgePlainTextEditor.fromContent(
              content: 'spec',
              uri: uri,
              module: shell.modules.get<TomForgeShellModule>(),
            );
            built.add(editor);
            return editor;
          },
        ),
      ],
    );
    addTearDown(w.shell.dispose);
    await w.write('/a.spec.yaml', utf8.encode('a: 1\n'));
    await w.write('/b.yaml', utf8.encode('b: 1\n'));
    final spec = w.fs.uriOf('/a.spec.yaml');

    expect(w.module.editorChoicesFor(w.fs.uriOf('/b.yaml')).map((c) => c.id), [
      'yaml',
    ], reason: 'no alternative matches it');
    final choices = w.module.editorChoicesFor(spec);
    expect(choices.map((c) => (c.id, c.label)), [
      ('yaml', 'YAML Editor'),
      ('spec', 'Spec Editor'),
    ]);

    // The shell's Open With shows the choice.
    final layout = w.shell.layout as DefaultLayoutController;
    await layout.openFileWith(spec);
    expect(layout.pendingEditorChoice.value?.$2.map((c) => c.id), [
      'yaml',
      'spec',
    ]);

    layout.resolveEditorChoice(choices[1], spec);
    await tester.pumpAndSettle();
    expect(built, hasLength(1));
    expect(w.shell.systemState.activeEditor, same(built.single));

    // Again: the alternative open on the file is shown, not made twice.
    choices[1].open(spec);
    await tester.pumpAndSettle();
    expect(built, hasLength(1));

    // The editor of its kind is its own editor beside it.
    choices[0].open(spec);
    await tester.pumpAndSettle();
    expect(w.shell.systemState.activeEditor, isA<_KindEditor>());
    expect(
      w.shell.systemState.openEditors.where((e) => e.uri == spec),
      hasLength(2),
    );
    // An ordinary open shows an editor of the module already on the file.
    w.shell.layout.openFile(spec);
    await tester.pumpAndSettle();
    expect(
      w.shell.systemState.openEditors.where((e) => e.uri == spec),
      hasLength(2),
    );
  });

  testWidgets('FE-6: a todo file opens in the todo-file editor; a checkbox '
      'is undone and saved through the session; an All files row opens its '
      'file with the todo selected', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final w = _Workspace();
    addTearDown(w.shell.dispose);
    const todos =
        'quest: garden\ntodos:\n'
        '  - id: gx1_ajka-plant\n    title: Plant\n    description: d\n'
        '    status: not-started\n';
    await w.write('/q/todos.garden.todo.yaml', utf8.encode(todos));
    await w.write(
      '/o/more.garden.todo.yaml',
      utf8.encode(
        'quest: garden\ntodos:\n'
        '  - id: sx1_ajka-ask\n    title: Ask\n    description: d\n'
        '    status: not-started\n',
      ),
    );
    expect(forgeFileKindOf('todos.garden.todo.yaml'), ForgeFileKind.todoFile);
    final editor =
        await w.open(tester, '/q/todos.garden.todo.yaml')
            as ForgeTodoFileEditor;
    expect(find.byKey(const Key('tom-todo-file-editor')), findsOneWidget);
    expect(find.text('Board'), findsNothing, reason: 'Forge has no board');

    await tester.tap(find.byKey(const Key('todo-done-gx1_ajka-plant')));
    await tester.pumpAndSettle();
    expect(editor.isDirty.value, isTrue);
    expect(editor.executeAction(_undo), isTrue);
    await tester.pumpAndSettle();
    expect(editor.isDirty.value, isFalse);
    expect(editor.executeAction(_redo), isTrue);
    await tester.pumpAndSettle();
    expect(saveOwnedEditor(editor), isTrue);
    await tester.pumpAndSettle();
    expect(
      utf8.decode(await w.read('/q/todos.garden.todo.yaml')),
      contains('status: completed'),
    );
    expect(editor.isDirty.value, isFalse);

    await tester.tap(find.text('All files'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('tom-todo-aggregate-row-sx1_ajka-ask')),
    );
    await tester.pumpAndSettle();
    final other = w.shell.systemState.openEditors
        .whereType<ForgeTodoFileEditor>()
        .firstWhere((e) => e.uri == w.fs.uriOf('/o/more.garden.todo.yaml'));
    expect(other.selection, 'sx1_ajka-ask');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('FE-8: without registered kinds Markdown and YAML open as plain '
      'text; .env and todo files stay this package\'s whatever is registered', (
    tester,
  ) async {
    final bare = _Workspace(kinds: const []);
    addTearDown(bare.shell.dispose);
    await bare.write('/a.md', utf8.encode('# A\n'));
    final text = await bare.open(tester, '/a.md');
    expect(text, isA<ForgePlainTextEditor>());
    expect(text, isNot(isA<_KindEditor>()));
    expect(
      bare.module.editorChoicesFor(bare.fs.uriOf('/a.md')).map((c) => c.id),
      ['text'],
    );

    // A kind that would take every YAML and .env file: the module's own
    // kinds are asked first.
    final w = _Workspace(
      kinds: [
        _kind('greedy', 'Greedy', ['todo.yaml', 'env', 'yaml']),
      ],
    );
    addTearDown(w.shell.dispose);
    await w.write('/x.env', utf8.encode('KEY=1\n'));
    await w.write('/q/todos.garden.todo.yaml', utf8.encode('todos: []\n'));
    await w.write('/c.yaml', utf8.encode('c: 1\n'));
    expect(w.module.editorFor(w.fs.uriOf('/x.env')), isA<ForgeEnvFileEditor>());
    expect(
      w.module.editorFor(w.fs.uriOf('/q/todos.garden.todo.yaml')),
      isA<ForgeTodoFileEditor>(),
    );
    expect(w.module.editorFor(w.fs.uriOf('/c.yaml')), isA<_KindEditor>());
    expect(
      w.module.editorChoicesFor(w.fs.uriOf('/c.yaml')).map((c) => c.label),
      ['Greedy'],
    );
    // A kind registered later is asked too.
    w.module.fileKinds.register(_kind('notes', 'Notes', ['notes']));
    await w.write('/d.notes', utf8.encode('d\n'));
    expect(w.module.editorChoicesFor(w.fs.uriOf('/d.notes')).map((c) => c.id), [
      'notes',
    ]);
    await tester.pump(const Duration(seconds: 2));
  });
}
