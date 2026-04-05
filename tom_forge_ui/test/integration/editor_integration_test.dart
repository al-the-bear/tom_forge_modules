import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart';
import 'package:tom_md_editor/tom_md_editor.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ForgeTestDocument', () {
    test('starts empty with single line', () {
      final doc = ForgeTestDocument();
      expect(doc.text, '');
      expect(doc.lineCount, 1);
      expect(doc.lineAt(0), '');
      expect(doc.version, 0);
      expect(doc.isUntitled, isTrue);
      expect(doc.languageId, 'plaintext');
    });

    test('initializes with content', () {
      final doc = ForgeTestDocument(content: 'line1\nline2\nline3');
      expect(doc.lineCount, 3);
      expect(doc.lineAt(0), 'line1');
      expect(doc.lineAt(1), 'line2');
      expect(doc.lineAt(2), 'line3');
      expect(doc.text, 'line1\nline2\nline3');
    });

    test('insert increments version and fires changes', () async {
      final doc = ForgeTestDocument(content: 'hello world');
      final changes = <DocumentChangeEvent>[];
      doc.onDidChange.listen(changes.add);

      doc.insert(const ForgeTextPosition(line: 0, column: 5), ' dear');

      expect(doc.text, 'hello dear world');
      expect(doc.version, 1);

      // Allow stream to deliver.
      await Future<void>.delayed(Duration.zero);
      expect(changes, hasLength(1));
    });

    test('replace within single line', () {
      final doc = ForgeTestDocument(content: 'hello world');
      doc.replace(
        const ForgeTextRange(
          start: ForgeTextPosition(line: 0, column: 6),
          end: ForgeTextPosition(line: 0, column: 11),
        ),
        'dart',
      );
      expect(doc.text, 'hello dart');
      expect(doc.version, 1);
    });

    test('replace across multiple lines', () {
      final doc = ForgeTestDocument(content: 'aaa\nbbb\nccc');
      doc.replace(
        const ForgeTextRange(
          start: ForgeTextPosition(line: 0, column: 1),
          end: ForgeTextPosition(line: 2, column: 1),
        ),
        'X',
      );
      expect(doc.text, 'aXcc');
    });

    test('findAll locates pattern matches', () {
      final doc = ForgeTestDocument(content: 'foo bar foo\nbaz foo');
      final results = doc.findAll('foo');
      expect(results, hasLength(3));
      expect(results[0].start.line, 0);
      expect(results[0].start.column, 0);
      expect(results[1].start.line, 0);
      expect(results[1].start.column, 8);
      expect(results[2].start.line, 1);
      expect(results[2].start.column, 4);
    });

    test('replaceAll substitutes all occurrences', () {
      final doc = ForgeTestDocument(content: 'aaa bbb aaa\naaa');
      final count = doc.replaceAll('aaa', 'X');
      expect(count, 3);
      expect(doc.text, 'X bbb X\nX');
    });

    test('textInRange returns correct text', () {
      final doc = ForgeTestDocument(content: 'abc\ndef\nghi');
      expect(
        doc.textInRange(const ForgeTextRange(
          start: ForgeTextPosition(line: 0, column: 1),
          end: ForgeTextPosition(line: 0, column: 3),
        )),
        'bc',
      );
    });

    test('custom uri preserves scheme', () {
      final doc = ForgeTestDocument(uri: Uri.parse('file:///hello.txt'));
      expect(doc.uri.scheme, 'file');
      expect(doc.isUntitled, isFalse);
    });
  });

  group('ForgeTestTextEditor', () {
    late ForgeTestModule module;
    late ForgeTestTextEditor editor;

    setUp(() {
      module = ForgeTestModule();
      editor = module.testTextEditor;
    });

    test('initial state', () {
      expect(editor.uri.scheme, 'test');
      expect(editor.isDirty.value, isFalse);
      expect(editor.hasSelection, isFalse);
      expect(editor.selectedText, '');
      expect(editor.cursorPosition.value.line, 0);
      expect(editor.cursorPosition.value.column, 0);
    });

    test('insertText marks dirty and modifies document', () {
      editor.insertText('hello');
      expect(editor.document.text, 'hello');
      expect(editor.isDirty.value, isTrue);
    });

    test('replaceRange modifies document', () {
      editor.insertText('hello world');
      editor.replaceRange(
        const ForgeTextRange(
          start: ForgeTextPosition(line: 0, column: 6),
          end: ForgeTextPosition(line: 0, column: 11),
        ),
        'dart',
      );
      expect(editor.document.text, 'hello dart');
    });

    test('deleteRange removes text', () {
      editor.insertText('hello world');
      editor.deleteRange(const ForgeTextRange(
        start: ForgeTextPosition(line: 0, column: 5),
        end: ForgeTextPosition(line: 0, column: 11),
      ));
      expect(editor.document.text, 'hello');
    });

    test('setCursorPosition updates value notifier', () {
      const pos = ForgeTextPosition(line: 3, column: 7);
      editor.setCursorPosition(pos);
      expect(editor.cursorPosition.value, pos);
    });

    test('setSelection updates selection and selections', () {
      const range = ForgeTextRange(
        start: ForgeTextPosition(line: 0, column: 0),
        end: ForgeTextPosition(line: 0, column: 5),
      );
      editor.setSelection(range);
      expect(editor.selection.value, range);
      expect(editor.selections.value, [range]);
      expect(editor.hasSelection, isTrue);
    });

    test('selectAll covers entire document', () {
      editor.insertText('line1\nline2');
      editor.selectAll();
      final sel = editor.selection.value!;
      expect(sel.start.line, 0);
      expect(sel.start.column, 0);
      expect(sel.end.line, 1);
      expect(sel.end.column, 5);
    });

    test('findAll and replaceAll work via document', () {
      editor.insertText('aaa bbb aaa');
      final found = editor.findAll('aaa');
      expect(found, hasLength(2));

      final count = editor.replaceAll('aaa', 'X');
      expect(count, 2);
      expect(editor.document.text, 'X bbb X');
      expect(editor.isDirty.value, isTrue);
    });

    test('setDecorations and clearDecorations', () {
      const type = ForgeDecorationType(
        key: 'search',
        backgroundColorValue: 0xFFFFFF00,
      );
      final ranges = [
        const ForgeDecorationRange(
          range: ForgeTextRange(
            start: ForgeTextPosition(line: 0, column: 0),
            end: ForgeTextPosition(line: 0, column: 3),
          ),
        ),
      ];

      editor.setDecorations(type, ranges);
      expect(editor.appliedDecorations['search'], equals(ranges));

      editor.clearDecorations(type);
      expect(editor.appliedDecorations.containsKey('search'), isFalse);
    });

    test('revealPosition updates visible range', () {
      editor.revealPosition(const ForgeTextPosition(line: 50, column: 0));
      expect(editor.visibleRange.value.start.line, 40);
      expect(editor.visibleRange.value.end.line, 60);
    });

    test('markClean clears dirty state', () {
      editor.insertText('dirty');
      expect(editor.isDirty.value, isTrue);
      editor.markClean();
      expect(editor.isDirty.value, isFalse);
    });

    test('canHandle accepts .test files', () {
      expect(
        editor.canHandle(Uri.parse('file:///foo.test')),
        FileHandlingResult.accept,
      );
      expect(
        editor.canHandle(Uri.parse('file:///foo.dart')),
        FileHandlingResult.reject,
      );
    });

    test('updateOptions replaces options', () {
      const newOpts = ForgeTextEditorOptions(tabSize: 4, insertSpaces: false);
      editor.updateOptions(newOpts);
      expect(editor.options.tabSize, 4);
      expect(editor.options.insertSpaces, isFalse);
    });
  });

  group('ForgeTestModule', () {
    late ForgeTestModule module;

    setUp(() {
      module = ForgeTestModule();
    });

    test('provides display name and editors', () {
      expect(module.displayName, 'Test Module');
      expect(module.editors, hasLength(1));
      expect(module.editors.first, isA<ForgeTestTextEditor>());
    });

    test('actions include test.insertText', () {
      expect(module.actions, hasLength(1));
      expect(module.actions.first.id, 'test.insertText');
    });

    test('action executes insertText on test editor', () async {
      await module.actions.first.execute({});
      expect(module.testTextEditor.document.text, '[TEST]');
    });
  });

  group('ForgeTestWorkspace', () {
    late ForgeTestWorkspace workspace;

    setUp(() async {
      workspace = await ForgeTestWorkspace.create();
    });

    tearDown(() async {
      await workspace.dispose();
    });

    test('creates directory structure with expected files', () {
      expect(workspace.root.existsSync(), isTrue);
      expect(
        File('${workspace.root.path}/readme.md').existsSync(),
        isTrue,
      );
      expect(
        File('${workspace.root.path}/main.dart').existsSync(),
        isTrue,
      );
      expect(
        File('${workspace.root.path}/config.yaml').existsSync(),
        isTrue,
      );
      expect(
        File('${workspace.root.path}/src/lib.dart').existsSync(),
        isTrue,
      );
      expect(
        File('${workspace.root.path}/schema/form.yaml').existsSync(),
        isTrue,
      );
    });

    test('file contents are correct', () {
      final md = File('${workspace.root.path}/readme.md').readAsStringSync();
      expect(md, contains('# Test Workspace'));

      final dart = File('${workspace.root.path}/main.dart').readAsStringSync();
      expect(dart, contains('void main()'));
    });

    test('rootUri points to workspace root', () {
      expect(workspace.rootUri.scheme, 'file');
      expect(workspace.rootUri.path, endsWith('/'));
    });

    test('dispose removes directory', () async {
      final path = workspace.root.path;
      await workspace.dispose();
      expect(Directory(path).existsSync(), isFalse);
    });
  });

  group('Adapter canHandle resolution', () {
    late TomForgeShellModule shellModule;

    setUp(() {
      shellModule = TomForgeShellModule();
    });

    test('ForgeMdEditor accepts .md files', () {
      final editor = shellModule.registerMdEditor(ForgeMdEditor(
        controller: MdEditorController(),
        module: shellModule,
      ));
      expect(
        editor.canHandle(Uri.parse('file:///doc.md')),
        FileHandlingResult.accept,
      );
      expect(
        editor.canHandle(Uri.parse('file:///doc.markdown')),
        FileHandlingResult.accept,
      );
      expect(
        editor.canHandle(Uri.parse('file:///doc.dart')),
        FileHandlingResult.reject,
      );
    });

    test('ForgeDartEditor accepts .dart files', () {
      final editor = shellModule.registerDartEditor(ForgeDartEditor(
        controller: DartCodeController(),
        module: shellModule,
      ));
      expect(
        editor.canHandle(Uri.parse('file:///main.dart')),
        FileHandlingResult.accept,
      );
      expect(
        editor.canHandle(Uri.parse('file:///doc.md')),
        FileHandlingResult.reject,
      );
    });

    test('TomForgeShellModule collects editors', () {
      shellModule.registerMdEditor(ForgeMdEditor(
        controller: MdEditorController(),
        module: shellModule,
      ));
      shellModule.registerDartEditor(ForgeDartEditor(
        controller: DartCodeController(),
        module: shellModule,
      ));
      expect(shellModule.editors, hasLength(2));
    });

    test('deactivate clears editors', () {
      shellModule.registerMdEditor(ForgeMdEditor(
        controller: MdEditorController(),
        module: shellModule,
      ));
      expect(shellModule.editors, hasLength(1));
      shellModule.deactivate();
      expect(shellModule.editors, isEmpty);
    });
  });
}
