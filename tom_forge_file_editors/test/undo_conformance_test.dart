/// The four file editors under Forge's undo conformance harness, with no
/// check skipped: the Markdown and YAML editors (their controllers keep the
/// history), the plain-text and `.env` editors (the file session keeps it).
/// Save saves through the session.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_session/tom_file_session.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_file_editors/tom_forge_file_editors.dart';
import 'package:tom_forge_ui/testing.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_md_editor/tom_md_editor.dart' show MdRawTextEditor;
import 'package:tom_yaml_editor/tom_yaml_editor.dart' show kYamlEditorDebug;

TomForgeShellModule _module() => TomForgeShellModule()
  ..activate(
    DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'File editors',
      navigatorKey: GlobalKey<NavigatorState>(),
    ),
  );

/// A session over [name] holding [text], ready at once.
ForgeFileSession _session(String name, String text) {
  final fs = TomMemoryFileSystem(seed: {name: text});
  return ForgeFileSession(fileSystem: fs, path: name)..adoptText(text);
}

Future<void> _save(ForgeFileSession session) async {
  expect(await session.save(), isNot(ForgeFileSaveOutcome.conflict));
}

void main() {
  setUp(() => kYamlEditorDebug = false);

  runForgeUndoConformance('Markdown file editor', _MarkdownSubject.new);
  runForgeUndoConformance('YAML file editor', _YamlSubject.new);
  runForgeUndoConformance('text file editor', _TextSubject.new);
  runForgeUndoConformance('.env file editor', _EnvSubject.new);
}

class _MarkdownSubject extends ForgeUndoSubject {
  _MarkdownSubject(String saved)
    : editor = ForgeMarkdownFileEditor(
        session: _session('notes.md', saved),
        module: _module(),
      );

  @override
  final ForgeMarkdownFileEditor editor;

  @override
  TextEditingController controllerOf(WidgetTester tester, Finder view) =>
      tester
          .widget<EditableText>(
            find
                .descendant(
                  of: find.descendant(
                    of: view,
                    matching: find.byType(MdRawTextEditor),
                  ),
                  matching: find.byType(EditableText),
                )
                .first,
          )
          .controller;

  @override
  String textOf(WidgetTester tester) => editor.controller.markdown;

  @override
  Future<void> saved() async {
    expect(await editor.file.save(), isNot(ForgeFileSaveOutcome.conflict));
  }
}

class _YamlSubject extends ForgeUndoSubject {
  _YamlSubject(String saved)
    : editor = ForgeYamlFileEditor(
        session: _session('config.yaml', saved),
        module: _module(),
      ) {
    editor.controller.textMode = true;
  }

  @override
  final ForgeYamlFileEditor editor;

  @override
  String textOf(WidgetTester tester) => editor.controller.sourceText;

  @override
  Future<void> saved() async {
    expect(await editor.file.save(), isNot(ForgeFileSaveOutcome.conflict));
  }
}

class _TextSubject extends ForgeUndoSubject {
  _TextSubject(String saved)
    : editor = ForgePlainTextEditor(
        session: _session('notes.txt', saved),
        module: _module(),
      );

  @override
  final ForgePlainTextEditor editor;

  @override
  String textOf(WidgetTester tester) => editor.session.text;

  @override
  Future<void> saved() => _save(editor.session);
}

/// The `.env` editor, edited in its raw view with the values shown (the
/// table edits entry by entry through dialogs).
class _EnvSubject extends ForgeUndoSubject {
  _EnvSubject(String saved)
    : editor = ForgeEnvFileEditor(
        session: _session('.env', saved),
        notifications: null,
      );

  @override
  final ForgeEnvFileEditor editor;

  Future<void> _raw(WidgetTester tester) async {
    for (final key in [forgeUndoMainView, forgeUndoCopyView]) {
      final view = find.byKey(key);
      if (view.evaluate().isEmpty) continue;
      if (find
          .descendant(of: view, matching: find.byKey(const ValueKey('raw')))
          .evaluate()
          .isNotEmpty) {
        continue;
      }
      await tester.tap(find.descendant(of: view, matching: find.text('Raw')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: view,
          matching: find.byKey(const Key('tom-env-show-values')),
        ),
      );
      await tester.pumpAndSettle();
    }
  }

  @override
  Future<void> type(WidgetTester tester, String text) async {
    await _raw(tester);
    await super.type(tester, text);
  }

  @override
  Future<void> moveCaret(WidgetTester tester, int offset) async {
    await _raw(tester);
    await super.moveCaret(tester, offset);
  }

  @override
  String textOf(WidgetTester tester) => editor.session.text;

  @override
  Future<void> saved() => _save(editor.session);
}
