/// The Markdown file kind's editor under Forge's undo conformance harness
/// (`package:tom_forge_ui_testing/tom_forge_ui_testing.dart`): how to drive
/// a [ForgeMarkdownFileEditor] the caller made, as a [ForgeUndoSubject] —
/// the adapter's suite builds it through the kind
/// (`ForgeFileKindTestBed`), an app's suite through the file module it
/// composes, so both run the same checks.
///
/// Test-only: a package of its own, taken as a dev_dependency by the suites
/// that drive the editor; nothing a product links depends on it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart' show ForgeFileSaveOutcome;
import 'package:tom_forge_md_editor/tom_forge_md_editor.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';
import 'package:tom_md_editor/tom_md_editor.dart' show MdRawTextEditor;

/// The Markdown file editor, typed into in its raw text view.
class ForgeMarkdownFileSubject extends ForgeUndoSubject {
  ForgeMarkdownFileSubject(this.editor);

  @override
  final ForgeMarkdownFileEditor editor;

  @override
  TextEditingController controllerOf(WidgetTester tester, Finder view) => tester
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
