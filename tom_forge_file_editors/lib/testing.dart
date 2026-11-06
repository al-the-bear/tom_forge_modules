/// The file editors under Forge's undo conformance harness
/// (`package:tom_forge_ui/testing.dart`): how to drive each one, as a
/// [ForgeUndoSubject] over an editor the caller made — this package's suite
/// builds them directly, an app's suite through the module it composes
/// ([ForgeFileEditorsModule.editorFor]), so both run the same checks.
///
/// Test-only: a suite imports it; nothing a product links does.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_session/tom_file_session.dart';
import 'package:tom_forge_ui/testing.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_md_editor/tom_md_editor.dart' show MdRawTextEditor;
import 'package:tom_reusable_ui/tom_reusable_ui.dart' show TomYamlFileEditor;

import 'tom_forge_file_editors.dart';

Future<void> _save(ForgeFileSession session) async {
  expect(await session.save(), isNot(ForgeFileSaveOutcome.conflict));
}

/// The Markdown file editor, typed into in its raw text view.
class ForgeMarkdownFileSubject extends ForgeUndoSubject {
  ForgeMarkdownFileSubject(this.editor);

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

/// The YAML file editor, in its source view.
class ForgeYamlFileSubject extends ForgeUndoSubject {
  ForgeYamlFileSubject(this.editor) {
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

/// The plain-text editor over its file session.
class ForgeTextFileSubject extends ForgeUndoSubject {
  ForgeTextFileSubject(this.editor);

  @override
  final ForgePlainTextEditor editor;

  @override
  String textOf(WidgetTester tester) => editor.session.text;

  @override
  Future<void> saved() => _save(editor.session);
}

/// The `.env` editor, edited in its raw view with the values shown (the
/// table edits entry by entry through dialogs).
class ForgeEnvFileSubject extends ForgeUndoSubject {
  ForgeEnvFileSubject(this.editor);

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

/// The todo-file editor, edited in its YAML source view (the list edits todo
/// by todo through rows and dialogs).
class ForgeTodoFileSubject extends ForgeUndoSubject {
  ForgeTodoFileSubject(this.editor);

  @override
  final ForgeTodoFileEditor editor;

  Future<void> _source(WidgetTester tester) async {
    for (final key in [forgeUndoMainView, forgeUndoCopyView]) {
      final view = find.byKey(key);
      if (view.evaluate().isEmpty) continue;
      final source = find.descendant(of: view, matching: find.text('Source'));
      if (source.evaluate().isEmpty) continue;
      if (find
          .descendant(of: view, matching: find.byType(TomYamlFileEditor))
          .evaluate()
          .isNotEmpty) {
        continue;
      }
      await tester.tap(source);
      await tester.pumpAndSettle();
    }
  }

  @override
  Future<void> type(WidgetTester tester, String text) async {
    await _source(tester);
    await super.type(tester, text);
  }

  @override
  Future<void> moveCaret(WidgetTester tester, int offset) async {
    await _source(tester);
    await super.moveCaret(tester, offset);
  }

  @override
  String textOf(WidgetTester tester) => editor.session.text;

  @override
  Future<void> saved() => _save(editor.session);
}
