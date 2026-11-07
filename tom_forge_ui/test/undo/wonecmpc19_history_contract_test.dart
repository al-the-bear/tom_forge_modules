/// The shell's half of the history contract (wonecmpc19): a revision restore
/// replaces an open editor's content in place, or reopens an editor that
/// cannot take it, so no editor stays on the old text; and the one undo
/// depth setting reaches open editors.
library;

import 'dart:io';

import 'package:tom_file_system/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show ForgeTextSettings, StandardEditingActions;
import 'package:tom_forge_core/tom_forge_core.dart' show FileHandlingResult;
import 'package:tom_forge_ui/tom_forge_ui.dart';

void main() {
  late Directory workspace;
  late DefaultShellApi shell;
  late TomForgeShellModule module;
  late Uri file;

  setUp(() async {
    workspace = Directory.systemTemp.createTempSync('wonecmpc19_');
    final state = DefaultWorkspaceStateManager();
    await state.initialize(TomLocalFileSystem(workspace.path));
    final fileSystem = TomMemoryFileSystem();
    shell = DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: fileSystem,
      appName: 'History contract',
      navigatorKey: GlobalKey<NavigatorState>(),
      workspaceState: state,
    );
    module = TomForgeShellModule()..activate(shell);
    (shell.modules as DefaultModuleRegistry).register(module);
    file = fileSystem.uriOf('notes.txt');
    await fileSystem.writeText(file, 'current');
    await fileSystem.save(file);
  });

  tearDown(() => workspace.deleteSync(recursive: true));

  Future<String> revisionOf(String content) async =>
      (await shell.workspaceState.createRevision(file, content))!;

  group('HC revision restore', () {
    testWidgets('HC-1: an open editor takes the restored text in place, '
        'clean and with nothing to undo', (tester) async {
      final editor = ForgePlainTextEditor.fromContent(
        content: 'current',
        uri: file,
        module: module,
      );
      shell.layout.openEditor(editor, file);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Builder(builder: editor.buildMain))),
      );
      await tester.enterText(find.byType(TextField), 'current, edited');
      await tester.pump(const Duration(seconds: 1));
      expect(
        editor.isActionEnabled(StandardEditingActions.undoActionId),
        isTrue,
      );

      // Real file I/O (the revision store): outside the test's fake clock.
      final restored = await tester.runAsync(() async {
        final revision = await revisionOf('restored');
        return shell.restoreFileFromRevision(file, revision);
      });
      expect(restored, isTrue);
      await tester.pump();

      expect(shell.systemState.openEditors, contains(editor));
      expect(editor.session.text, 'restored');
      expect(find.text('restored'), findsOneWidget);
      expect(editor.isDirty.value, isFalse);
      expect(
        editor.isActionEnabled(StandardEditingActions.undoActionId),
        isFalse,
      );
      await tester.pump(const Duration(seconds: 2)); // the typing pause
    });

    test('HC-2: an editor that cannot take the text in place is closed and '
        'its file opened again', () async {
      final editor = _InPlaceRefused(file);
      shell.layout.openEditor(editor, file);
      final revision = await revisionOf('restored');
      expect(await shell.restoreFileFromRevision(file, revision), isTrue);
      await pumpEventQueue(); // opening the file again reads it
      expect(shell.systemState.openEditors, isNot(contains(editor)));
      expect(
        shell.systemState.openEditors.where((e) => e.uri == file),
        hasLength(1),
        reason: 'the file is open again, in a fresh editor',
      );
    });
  });

  group('HC undo depth', () {
    testWidgets('HC-3: changing maxUndoHistory reaches an open editor\'s '
        'history', (tester) async {
      final editor = ForgePlainTextEditor.fromContent(
        content: '',
        uri: file,
        module: module,
      );
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Builder(builder: editor.buildMain))),
      );
      for (final text in ['a', 'ab', 'abc']) {
        await tester.enterText(find.byType(TextField), text);
        await tester.pump(const Duration(seconds: 2));
      }
      shell.setTextSettings(
        'plaintext',
        const ForgeTextSettings(maxUndoHistory: 1),
      );
      await tester.pump();
      var undos = 0;
      while (editor.isActionEnabled(StandardEditingActions.undoActionId)) {
        editor.executeAction(StandardEditingActions.undoActionId);
        await tester.pump();
        undos++;
      }
      expect(undos, 1, reason: 'the history keeps one entry now');
      expect(editor.session.text, 'ab');
      await tester.pump(const Duration(seconds: 2)); // the typing pause
    });

    test('HC-4: setTextSettings notifies once per real change', () {
      var heard = 0;
      shell.textSettingsChanged.addListener(() => heard++);
      shell.setTextSettings('md', const ForgeTextSettings(maxUndoHistory: 7));
      shell.setTextSettings('md', const ForgeTextSettings(maxUndoHistory: 7));
      expect(heard, 1);
      expect(shell.getTextSettings('md').maxUndoHistory, 7);
    });
  });
}

/// An editor whose content cannot be replaced in place.
class _InPlaceRefused extends ForgeEditor {
  _InPlaceRefused(this.uri);

  @override
  final Uri uri;

  final _dirty = ValueNotifier(false);

  @override
  ValueNotifier<String> get title => ValueNotifier('notes.txt');

  @override
  ValueNotifier<String?> get titleExtension => ValueNotifier(null);

  @override
  IconData get icon => Icons.description;

  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.reject;

  @override
  ValueListenable<bool> get isDirty => _dirty;

  @override
  void markClean() => _dirty.value = false;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) => const Text('refuses');

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}
