/// The file editors in a Forge shell: the module opens a file in the editor
/// of its kind over a ForgeFileSession; edits are undone through the
/// editor's history and make it dirty; the editor saves its own file — the
/// shell writes nothing — keeping its encoding, byte-order mark and line
/// endings; a file changed on disk is not written over; a host replaces an
/// editor or keeps a file for another module.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_file_editors/tom_forge_file_editors.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart' show kYamlEditorDebug;

const _undo = StandardEditingActions.undoActionId;
const _redo = StandardEditingActions.redoActionId;

class _Workspace {
  _Workspace({
    Map<ForgeFileKind, ForgeFileEditorBuilder> builders = const {},
    bool Function(Uri uri)? claims,
  }) {
    shell = DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: fs,
      appName: 'File editors',
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(TomForgeShellModule()..activate(shell));
    module = ForgeFileEditorsModule(builders: builders, claims: claims)
      ..activate(shell);
    registry.register(module);
  }

  final fs = TomMemoryFileSystem();
  late final DefaultShellApi shell;
  late final ForgeFileEditorsModule module;

  Future<void> write(String path, List<int> bytes) =>
      fs.write(fs.uriOf(path), Uint8List.fromList(bytes));

  Future<List<int>> read(String path) async => (await fs.read(fs.uriOf(path))).bytes;

  /// Opens [path] and waits for its editor and its file.
  Future<ForgeEditor> open(WidgetTester tester, String path) async {
    final uri = fs.uriOf(path);
    shell.layout.openFile(uri);
    await tester.pumpAndSettle();
    final editor = shell.systemState.openEditors.firstWhere((e) => e.uri == uri);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Builder(builder: editor.buildMain))),
    );
    await tester.pumpAndSettle();
    return editor;
  }
}

List<int> _bom(String text) => [0xEF, 0xBB, 0xBF, ...utf8.encode(text)];

void main() {
  setUp(() => kYamlEditorDebug = false);

  testWidgets('FE-1: each kind opens in its editor, once', (tester) async {
    final w = _Workspace();
    addTearDown(w.shell.dispose);
    await w.write('/a.md', utf8.encode('# A\n'));
    await w.write('/b.yaml', utf8.encode('b: 1\n'));
    await w.write('/.env', utf8.encode('KEY=secret\n'));
    await w.write('/c.txt', utf8.encode('c\n'));
    expect(await w.open(tester, '/a.md'), isA<ForgeMarkdownFileEditor>());
    expect(await w.open(tester, '/b.yaml'), isA<ForgeYamlFileEditor>());
    expect(await w.open(tester, '/.env'), isA<ForgeEnvFileEditor>());
    expect(await w.open(tester, '/c.txt'), isA<ForgePlainTextEditor>());
    final again = await w.open(tester, '/a.md');
    expect(
      w.shell.systemState.openEditors.where((e) => e.uri == again.uri),
      hasLength(1),
    );
    expect(forgeFileKindOf('.env.local'), ForgeFileKind.env);
  });

  testWidgets('FE-2: Markdown — undo, dirty and a save that keeps the BOM '
      'and the CRLF line endings', (tester) async {
    final w = _Workspace();
    addTearDown(w.shell.dispose);
    await w.write('/a.md', _bom('# A\r\n\r\nfirst\r\n'));
    final editor = await w.open(tester, '/a.md') as ForgeMarkdownFileEditor;
    expect(editor.controller.markdown, '# A\n\nfirst\n');
    expect(editor.getContent(), isNull, reason: 'the shell writes nothing');
    editor.controller.applyEdit('# A\n\nfirst\nsecond\n');
    await tester.pump();
    expect(editor.isDirty.value, isTrue);
    expect(editor.executeAction(_undo), isTrue);
    await tester.pump();
    expect(editor.isDirty.value, isFalse);
    expect(editor.executeAction(_redo), isTrue);
    await tester.pump();
    expect(saveOwnedEditor(editor), isTrue);
    await tester.pumpAndSettle();
    expect(await w.read('/a.md'), _bom('# A\r\n\r\nfirst\r\nsecond\r\n'));
    expect(editor.isDirty.value, isFalse);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('FE-3: YAML — an edit saved in place; a file changed on disk is '
      'not written over until the user keeps theirs', (tester) async {
    final w = _Workspace();
    addTearDown(w.shell.dispose);
    await w.write('/b.yaml', utf8.encode('b: 1\n'));
    final editor = await w.open(tester, '/b.yaml') as ForgeYamlFileEditor;
    editor.controller.textMode = true;
    editor.controller.editSource('b: 2\n', const TextSelection.collapsed(offset: 4));
    await w.write('/b.yaml', utf8.encode('b: 3\n'));
    await tester.pumpAndSettle();
    expect(editor.executeAction(StandardEditingActions.saveActionId), isTrue);
    await tester.pumpAndSettle();
    expect(utf8.decode(await w.read('/b.yaml')), 'b: 3\n');
    expect(find.byKey(const Key('forge-file-changed-on-disk')), findsOneWidget);
    expect(editor.isDirty.value, isTrue);
    await tester.tap(find.text('Keep mine'));
    await tester.pumpAndSettle();
    expect(editor.executeAction(StandardEditingActions.saveActionId), isTrue);
    await tester.pumpAndSettle();
    expect(utf8.decode(await w.read('/b.yaml')), 'b: 2\n');
    expect(editor.isDirty.value, isFalse);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('FE-4: .env — the session is the history; a save writes it',
      (tester) async {
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
        ForgeFileKind.markdown: (session, _, module) =>
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
}
